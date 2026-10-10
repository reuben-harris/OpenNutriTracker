import 'dart:async';
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
  @override
  Future<List<MealEntity>> search(String query) => results(query);
  @override
  Future<MealEntity?> getById(String id) async => null;
}

class Cache extends RemoteSearchCacheDataSource {
  List<MealEntity> meals = [];
  final writes = <MealDBO>[];
  Completer<void>? writeGate;
  @override
  Future<List<MealDBO>> search(String query, {String? language}) async =>
      meals.map(MealDBO.fromMealEntity).toList();
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
  final sessions = <FoodSearchSession>[];
  String context = 'profile-a:en';
  setUp(() {
    catalogue = Catalogue();
    cache = Cache();
    online = Online();
    context = 'profile-a:en';
    engine = FoodSearchEngine(
      catalogue: catalogue,
      cache: cache,
      online: online,
      savedMeals: () async => [],
      recentMeals: () async => [],
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
          food('recipe', 'Orange cake', source: MealSourceEntity.recipe),
        ],
        recentMeals: () async =>
            throw StateError('All must not read diary history'),
        contextIdentity: () => context,
      );
      final session = search('orange');
      final local = await until(session, (s) => s.meals.length == 3);
      expect(local.meals.first.code, 'usda:1');
      expect(local.pending, {FoodSearchSource.online});
      cache.writeGate = Completer<void>();
      online.responses.single.complete(
        OffFoodSearchPage([food('fresh', 'Orange')], hasMore: true),
      );
      final fresh = await until(
        session,
        (s) => s.hasMore && s.meals.length == 4,
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
  test(
    'cancel, profile change and language change reject late results and writes',
    () async {
      for (final change in ['cancel', 'profile-b:en', 'profile-a:de']) {
        final session = search('orange');
        await until(
          session,
          (s) => !s.pending.contains(FoodSearchSource.cache),
        );
        final before = session.state;
        if (change == 'cancel') {
          session.cancel();
        } else {
          context = change;
        }
        online.responses.last.complete(
          OffFoodSearchPage([food('late', 'Orange')], hasMore: false),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(identical(session.state, before), isTrue);
        expect(cache.writes, isEmpty);
        context = 'profile-a:en';
      }
    },
  );
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
