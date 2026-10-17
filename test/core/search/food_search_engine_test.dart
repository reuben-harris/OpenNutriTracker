import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/search/off_food_search_source.dart';
import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

MealEntity food(
  String id,
  String name, {
  MealSourceEntity source = MealSourceEntity.off,
  bool detailed = false,
}) => MealEntity(
  code: id,
  name: name,
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: 'g',
  servingSize: null,
  nutriments: MealNutrimentsEntity.empty(),
  source: source,
  detailed: detailed,
);

class Catalogue implements FoodCatalogue {
  Future<List<MealEntity>> Function(String) results = (_) async => [];
  final queries = <String>[];
  @override
  Future<List<MealEntity>> search(String query) {
    queries.add(query);
    return results(query);
  }

  @override
  Future<MealEntity?> getById(String id) async => null;
}

class Cache extends RemoteSearchCacheDataSource {
  List<MealEntity> meals = [];
  final writes = <MealDBO>[];
  final queries = <String>[];
  Completer<void>? writeGate;
  @override
  Future<List<MealDBO>> search(String query, {String? language}) async {
    queries.add(query);
    return meals.map(MealDBO.fromMealEntity).toList();
  }

  @override
  Future<void> cacheFromSearch(
    Iterable<MealDBO> incoming, {
    int? generation,
    String? language,
  }) async {
    writes.addAll(incoming);
    await writeGate?.future;
  }
}

class Online extends OffFoodSearchSource {
  final calls = <(String, int)>[];
  final responses = <Completer<OffFoodSearchPage>>[];
  int cancelled = 0;
  @override
  OffFoodSearchCall search(
    String query, {
    required String language,
    int page = 1,
  }) {
    calls.add((query, page));
    final response = Completer<OffFoodSearchPage>();
    responses.add(response);
    return OffFoodSearchCall(response.future, () => cancelled++);
  }
}

Future<FoodSearchSnapshot> until(
  FoodSearchSession session,
  bool Function(FoodSearchSnapshot) done,
) async => done(session.state)
    ? session.state
    : await session.updates
          .firstWhere(done)
          .timeout(const Duration(seconds: 5));
void main() {
  late Catalogue catalogue;
  late Cache cache;
  late Online online;
  late FoodSearchEngine engine;
  late Future<List<MealEntity>> Function() recipes;
  int savedReads = 0, recentReads = 0;
  final sessions = <FoodSearchSession>[];
  String context = 'profile-a:en';
  setUp(() {
    catalogue = Catalogue();
    cache = Cache();
    online = Online();
    context = 'profile-a:en';
    recipes = () async => [];
    savedReads = recentReads = 0;
    engine = FoodSearchEngine(
      catalogue: catalogue,
      cache: cache,
      online: online,
      savedMeals: () async {
        savedReads++;
        return [];
      },
      savedRecipes: () => recipes(),
      recentMeals: () async {
        recentReads++;
        return [];
      },
      contextIdentity: () => context,
    );
  });
  tearDown(() {
    for (final session in sessions) {
      session.cancel();
    }
    sessions.clear();
    for (final response in online.responses) {
      if (!response.isCompleted) {
        response.complete(const OffFoodSearchPage([], hasMore: false));
      }
    }
  });
  FoodSearchSession search(
    String query, {
    FoodSearchFilter filter = FoodSearchFilter.all,
    bool immediate = true,
  }) {
    final session = engine.search(
      FoodSearchRequest(query, filter: filter, language: 'en'),
      immediate: immediate,
    );
    sessions.add(session);
    return session;
  }

  test(
    'catalogue, cache and saved results appear while OFF remains pending',
    () async {
      catalogue.results = (_) async => [
        food('usda:1', 'Orange, raw', source: MealSourceEntity.fdc),
      ];
      cache.meals = [food('cached', 'Orange chocolate')];
      engine = FoodSearchEngine(
        catalogue: catalogue,
        cache: cache,
        online: online,
        savedMeals: () async => [
          food('custom', 'Orange smoothie', source: MealSourceEntity.custom),
        ],
        savedRecipes: () async => [
          food('recipe', 'Orange cake', source: MealSourceEntity.recipe),
        ],
        recentMeals: () async =>
            throw StateError('All must not read diary history'),
        contextIdentity: () => context,
      );
      final session = search('orange');
      final local = await until(session, (s) => s.meals.length == 4);
      expect(local.meals.first.code, 'usda:1');
      expect(
        local.meals.map((meal) => meal.source),
        containsAll([MealSourceEntity.custom, MealSourceEntity.recipe]),
      );
      expect(local.pending, {FoodSearchSource.online});
      cache.writeGate = Completer<void>();
      online.responses.single.complete(
        OffFoodSearchPage([food('fresh', 'Orange')], hasMore: true),
      );
      final fresh = await until(
        session,
        (s) => s.hasMore && s.meals.length == 5,
      );
      expect(fresh.meals.take(2).map((m) => m.code), contains('fresh'));
      expect(cache.writeGate!.isCompleted, isFalse);
      cache.writeGate!.complete();
    },
  );
  test(
    'same candidates rank identically when arriving from cache or OFF',
    () async {
      final candidates = [food('b', 'Orange chocolate'), food('a', 'Orange')];
      final cold = await rankFoodCandidates(
        'orange',
        candidates,
        remoteIdentities: candidates.map(foodIdentity).toSet(),
      );
      final warm = await rankFoodCandidates(
        'orange',
        candidates.reversed.toList(),
      );
      expect(cold.map(foodIdentity), warm.map(foodIdentity));
      expect(cold.first.code, 'a');
    },
  );
  test(
    'literal tokens, final prefix and accents use standard FTS matching',
    () async {
      final candidates = [
        food('1', 'Café orange'),
        food('2', 'Orange chocolate'),
        food('3', 'Pineapple'),
      ];
      expect(
        (await rankFoodCandidates('CAFE, "or"!', candidates)).single.code,
        '1',
      );
      expect(
        await rankFoodCandidates('orange OR chocolate', candidates),
        isEmpty,
      );
      expect(await rankFoodCandidates('ora chocolate', candidates), isEmpty);
    },
  );
  test(
    'duplicates update in place and later pages append without moving earlier rows',
    () async {
      cache.meals = [food('same', 'Orange chocolate', detailed: true)];
      final session = search('orange');
      await until(session, (s) => s.meals.isNotEmpty);
      online.responses.single.complete(
        OffFoodSearchPage([
          food('same', 'Orange'),
          food('b', 'Orange juice'),
        ], hasMore: true),
      );
      final first = await until(
        session,
        (s) => s.hasMore && s.meals.length == 2,
      );
      expect(first.meals.first.code, 'same');
      expect(first.meals.first.detailed, isTrue);
      session.loadMore();
      expect(online.calls.last.$2, 2);
      online.responses.last.complete(
        OffFoodSearchPage([
          food('c', 'Orange'),
          food('b', 'Orange juice refreshed'),
        ], hasMore: false),
      );
      final more = await until(
        session,
        (s) => !s.hasMore && s.meals.length == 3,
      );
      expect(more.meals.map((m) => m.code), ['same', 'b', 'c']);
      expect(more.meals[1].name, 'Orange juice refreshed');
    },
  );
  test(
    'failure preserves local results, retry uses the same service and page',
    () async {
      cache.meals = [food('cached', 'Orange')];
      final session = search('orange');
      await until(session, (s) => s.meals.isNotEmpty);
      online.responses.single.completeError(StateError('offline'));
      final failed = await until(
        session,
        (s) => s.failures.containsKey(FoodSearchSource.online),
      );
      expect(failed.meals.single.code, 'cached');
      expect(online.calls.length, 1);
      await Future<void>.delayed(Duration.zero);
      session.retry();
      expect(online.calls, [('orange', 1), ('orange', 1)]);
      online.responses.last.complete(
        const OffFoodSearchPage([], hasMore: false),
      );
      final retried = await until(
        session,
        (s) => s.failures.isEmpty && s.pending.isEmpty,
      );
      expect(retried.meals.single.code, 'cached');
    },
  );
  for (final change in ['cancel', 'profile-b:en', 'profile-a:de']) {
    test('$change rejects late online results and cache writes', () {
      fakeAsync((time) {
        final session = search('orange');
        time.flushMicrotasks();
        expect(online.calls, [('orange', 1)]);
        final before = session.state;
        if (change == 'cancel') {
          session.cancel();
        } else {
          context = change;
        }
        online.responses.single.complete(
          OffFoodSearchPage([food('late', 'Orange')], hasMore: false),
        );
        time.flushMicrotasks();
        expect(session.state, same(before));
        expect(cache.writes, isEmpty);
        session.cancel();
      });
    });
  }

  test(
    'online debounce fires once at its boundary and cancellation removes it',
    () {
      fakeAsync((time) {
        final first = search('orange', immediate: false);
        time.flushMicrotasks();
        time.elapse(engine.debounce - const Duration(microseconds: 1));
        expect(online.calls, isEmpty);
        time.elapse(const Duration(microseconds: 1));
        expect(online.calls, [('orange', 1)]);
        first.submit();
        expect(online.calls, hasLength(1));
        first.cancel();
        online.responses.single.complete(
          const OffFoodSearchPage([], hasMore: false),
        );
        time.flushMicrotasks();
        final cancelled = search('pear', immediate: false);
        time.flushMicrotasks();
        cancelled.cancel();
        time.elapse(engine.debounce);
        expect(online.calls, hasLength(1));
        expect(time.pendingTimers, isEmpty);
      });
    },
  );

  test('Recipes never schedules online work after debounce or submission', () {
    fakeAsync((time) {
      final session = search(
        'orange',
        filter: FoodSearchFilter.recipes,
        immediate: false,
      );
      time.flushMicrotasks();
      session.submit();
      session.loadMore();
      time.elapse(const Duration(minutes: 1));
      expect(online.calls, isEmpty);
      expect(time.pendingTimers, isEmpty);
      session.cancel();
    });
  });

  test(
    'keyboard submit flushes debounce once, including before session startup',
    () async {
      final session = search('orange', immediate: false);
      session.submit();
      await until(session, (s) => !s.pending.contains(FoodSearchSource.cache));
      expect(online.calls, [('orange', 1)]);
      session.submit();
      expect(online.calls.length, 1);
      online.responses.single.complete(
        const OffFoodSearchPage([], hasMore: false),
      );
      await until(session, (s) => s.pending.isEmpty);
      session.submit();
      expect(online.calls.length, 1);
    },
  );
  test(
    'local source failure is independent of other local and online results',
    () async {
      catalogue.results = (_) async =>
          throw StateError('catalogue unavailable');
      cache.meals = [food('cached', 'Orange')];
      final session = search('orange');
      final partial = await until(
        session,
        (s) =>
            s.failures.containsKey(FoodSearchSource.catalogue) &&
            s.meals.isNotEmpty,
      );
      expect(partial.pending, {FoodSearchSource.online});
      online.responses.single.complete(
        OffFoodSearchPage([food('fresh', 'Orange juice')], hasMore: false),
      );
      final result = await until(session, (s) => s.meals.length == 2);
      expect(result.failures.keys, [FoodSearchSource.catalogue]);
    },
  );
  test('Food never calls OFF and short input never calls OFF', () async {
    final foodOnly = search('orange', filter: FoodSearchFilter.food);
    await until(foodOnly, (s) => s.pending.isEmpty);
    final short = search('o');
    await until(short, (s) => s.pending.isEmpty);
    expect(online.calls, isEmpty);
  });
  test('Recipes browses alphabetically with stable identity ties', () async {
    recipes = () async => [
      food('z', 'Zucchini soup', source: MealSourceEntity.recipe),
      food('b', 'apple cake', source: MealSourceEntity.recipe),
      food('a', 'Apple cake', source: MealSourceEntity.recipe),
    ];
    for (final query in ['', '   ', '?!']) {
      final session = search(query, filter: FoodSearchFilter.recipes);
      final result = await until(session, (s) => s.pending.isEmpty);
      expect(result.meals.map((meal) => meal.code), ['a', 'b', 'z']);
      expect(result.hasMore, isFalse);
    }
    expect(catalogue.queries, isEmpty);
    expect(cache.queries, isEmpty);
    expect(savedReads, 0);
    expect(recentReads, 0);
    expect(online.calls, isEmpty);
  });
  test(
    'Recipes matches names and stays local on submit and load more',
    () async {
      recipes = () async => [
        food('cake', 'Orange cake', source: MealSourceEntity.recipe),
        food('soup', 'Onion soup', source: MealSourceEntity.recipe),
        food('exact', 'Orange', source: MealSourceEntity.recipe),
      ];
      final session = search(
        'ORAN',
        filter: FoodSearchFilter.recipes,
        immediate: false,
      );
      session.submit();
      final matches = await until(session, (s) => s.pending.isEmpty);
      expect(matches.meals.map((meal) => meal.code), ['exact', 'cake']);
      session.submit();
      session.loadMore();
      expect(online.calls, isEmpty);
      expect(catalogue.queries, isEmpty);
      expect(cache.queries, isEmpty);
      expect(savedReads, 0);
      expect(recentReads, 0);
      final noMatch = search('pear', filter: FoodSearchFilter.recipes);
      expect((await until(noMatch, (s) => s.pending.isEmpty)).meals, isEmpty);
    },
  );
  test(
    'Recipes reports loading, handles an empty library and retries failure',
    () async {
      final gate = Completer<List<MealEntity>>();
      recipes = () => gate.future;
      final session = search('', filter: FoodSearchFilter.recipes);
      expect(session.state.pending, {FoodSearchSource.recipes});
      await Future<void>.delayed(Duration.zero);
      gate.completeError(StateError('recipes unavailable'));
      final failed = await until(session, (s) => s.failures.isNotEmpty);
      expect(failed.failures.keys, [FoodSearchSource.recipes]);
      expect(failed.pending, isEmpty);
      recipes = () async => [];
      session.retry();
      final retried = await until(
        session,
        (s) => s.failures.isEmpty && s.pending.isEmpty,
      );
      expect(retried.meals, isEmpty);
      expect(online.calls, isEmpty);
    },
  );
  test(
    'Recipes rejects late results after cancellation or profile change',
    () async {
      for (final cancel in [true, false]) {
        final gate = Completer<List<MealEntity>>();
        recipes = () => gate.future;
        final session = search('', filter: FoodSearchFilter.recipes);
        await Future<void>.delayed(Duration.zero);
        final before = session.state;
        if (cancel) {
          session.cancel();
        } else {
          context = 'profile-b:en';
        }
        gate.complete([
          food('late', 'Apple cake', source: MealSourceEntity.recipe),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(identical(session.state, before), isTrue);
        context = 'profile-a:en';
      }
    },
  );
  test('Products, Food and Recent do not load saved recipes', () async {
    recipes = () async => throw StateError('must not load recipes');
    for (final filter in [
      FoodSearchFilter.products,
      FoodSearchFilter.food,
      FoodSearchFilter.recent,
    ]) {
      final session = search('orange', filter: filter);
      if (filter == FoodSearchFilter.products) {
        await Future<void>.delayed(Duration.zero);
        online.responses.last.complete(
          const OffFoodSearchPage([], hasMore: false),
        );
      }
      final result = await until(session, (s) => s.pending.isEmpty);
      expect(result.failures, isEmpty);
    }
  });
  test(
    'empty OFF page with more upstream pages still permits load more',
    () async {
      final session = search('orange');
      await until(session, (s) => !s.pending.contains(FoodSearchSource.cache));
      online.responses.single.complete(
        const OffFoodSearchPage([], hasMore: true),
      );
      await until(session, (s) => s.hasMore && s.pending.isEmpty);
      session.loadMore();
      expect(online.calls.last.$2, 2);
    },
  );
}
