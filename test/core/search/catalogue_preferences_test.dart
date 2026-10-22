import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/search/catalogue_preferences.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_search_controller.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import '../../helpers/fake_food_catalogue.dart';
import 'food_search_engine_test.dart' show Cache, Online, food;

void main() {
  late FakeFoodCatalogue catalogue;
  late Map<String, bool> stored;
  late CataloguePreferences preferences;
  setUp(() {
    stored = {};
    catalogue = FakeFoodCatalogue([
      catalogueSource('usda', 'FoodData Central'),
      catalogueSource('other', 'Another database'),
    ]);
    preferences = CataloguePreferences(
      catalogue: catalogue,
      read: () async => stored,
      write: (next) async => stored = Map.from(next),
    );
  });
  tearDown(() => preferences.dispose());

  test(
    'defaults, all-off overrides and newly added databases survive recreation',
    () async {
      expect(await preferences.enabledSourceIds(), {'usda', 'other'});
      await preferences.setEnabled('usda', false);
      await preferences.setEnabled('other', false);
      expect(await preferences.enabledSourceIds(), isEmpty);
      catalogue.sourceList.add(catalogueSource('new', 'New database'));
      final recreated = CataloguePreferences(
        catalogue: catalogue,
        read: () async => stored,
        write: (_) async {},
      );
      addTearDown(recreated.dispose);
      expect(await recreated.enabledSourceIds(), {'new'});
      expect(stored, {'usda': false, 'other': false});
    },
  );

  test(
    'failed writes do not publish changes and later writes recover',
    () async {
      var fail = true;
      final failing = CataloguePreferences(
        catalogue: catalogue,
        read: () async => {},
        write: (_) async {
          if (fail) throw StateError('disk unavailable');
        },
      );
      addTearDown(failing.dispose);
      await expectLater(failing.setEnabled('usda', false), throwsStateError);
      expect(failing.isEnabled('usda'), isTrue);
      expect(failing.revision, 0);
      fail = false;
      await failing.setEnabled('usda', false);
      expect(failing.isEnabled('usda'), isFalse);
      expect(failing.revision, 1);
    },
  );

  test(
    'concurrent writes merge and retain preferences for absent sources',
    () async {
      stored = {'removed': false};
      await Future.wait([
        preferences.setEnabled('usda', false),
        preferences.setEnabled('other', false),
      ]);
      expect(stored, {'removed': false, 'usda': false, 'other': false});
    },
  );

  test(
    'active searches restart and reject results from disabled sources',
    () async {
      await preferences.load();
      final started = Completer<void>();
      final old = Completer<List<MealEntity>>();
      catalogue.onSearch = (_, selected) {
        if (selected!.contains('usda')) {
          if (!started.isCompleted) started.complete();
          return old.future;
        }
        return Future.value([
          food('other:A1', 'Apple', source: MealSourceEntity.catalogue),
        ]);
      };
      final engine = FoodSearchEngine(
        catalogue: catalogue,
        cataloguePreferences: preferences,
        cache: Cache(),
        online: Online(),
        savedMeals: () async => [],
        savedRecipes: () async => [],
        recentMeals: () async => [],
        contextIdentity: () => 'profile:en',
      );
      final controller = FoodSearchController(engine);
      addTearDown(controller.close);
      controller.search('apple', FoodSearchFilter.food);
      await started.future;
      final updated = controller.stream.firstWhere(
        (snapshot) => snapshot.meals.isNotEmpty,
      );
      await preferences.setEnabled('usda', false);
      expect((await updated).meals.single.code, 'other:A1');
      old.complete([
        food('usda:1', 'Apple', source: MealSourceEntity.catalogue),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.meals.single.code, 'other:A1');
      expect(catalogue.selections.last, {'other'});
    },
  );
}
