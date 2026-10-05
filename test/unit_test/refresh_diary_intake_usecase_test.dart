import 'package:opennutritracker/core/utils/extensions.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/recipe_data_source.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/explode_recipe_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/refresh_diary_intake_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

MealEntity food({
  MealSourceEntity source = MealSourceEntity.custom,
  double? kcal = 100,
  double? carbs = 10,
  bool quick = false,
  String code = 'food',
}) => MealEntity(
  code: code,
  name: 'Food',
  url: null,
  mealQuantity: '100',
  mealUnit: 'gml',
  servingQuantity: null,
  servingUnit: 'gml',
  servingSize: '',
  source: source,
  isQuickAdd: quick,
  nutriments: MealNutrimentsEntity(
    energyKcal100: kcal,
    carbohydrates100: carbs,
    fat100: 0,
    proteins100: 0,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);

class _Products extends Fake implements ProductsRepository {
  int calls = 0;
  Completer<MealEntity>? response;
  MealEntity? result;
  Object? failure;
  Future<MealEntity> fetch() async {
    calls++;
    if (failure != null) throw failure!;
    return response == null ? result! : response!.future;
  }

  @override
  Future<MealEntity> getOFFProductByBarcode(String barcode) => fetch();
}

class _Catalogue implements FoodCatalogue {
  final ids = <String>[];
  Completer<MealEntity?>? pending;

  @override
  Future<MealEntity?> getById(String id) {
    ids.add(id);
    return pending!.future;
  }

  @override
  Future<List<MealEntity>> search(String query) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Box<IntakeDBO> intakes;
  late Box<MealDBO> custom, cache;
  late Box<RecipeDBO> recipes;
  late Box<ConfigDBO> config;
  late Box<TrackedDayDBO> days;
  late FakeHiveDBProvider db;
  late IntakeRepository repo;
  late RefreshDiaryIntakeUsecase refresh;
  late _Products products;
  late _Catalogue catalogue;
  final moment = DateTime(2026, 10, 3, 2);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('refresh-test');
    Hive.init(dir.path);
    registerHiveAdaptersOnce();
    intakes = await Hive.openBox<IntakeDBO>('intakes');
    custom = await Hive.openBox<MealDBO>('custom');
    cache = await Hive.openBox<MealDBO>('cache');
    recipes = await Hive.openBox<RecipeDBO>('recipes');
    config = await Hive.openBox<ConfigDBO>('config');
    days = await Hive.openBox<TrackedDayDBO>('days');
    final c = ConfigDBO.empty()..dayStartOffsetHours = 6;
    await config.put('ConfigKey', c);
    db = FakeHiveDBProvider(
      intakeBox: intakes,
      customMealBox: custom,
      recipeBox: recipes,
      configBox: config,
      trackedDayBox: days,
    );
    repo = IntakeRepository(IntakeDataSource(db));
    products = _Products();
    catalogue = _Catalogue();
    refresh = RefreshDiaryIntakeUsecase(
      db,
      repo,
      products,
      CustomMealDataSource(db),
      RecipeRepository(RecipeDataSource(db)),
      RemoteSearchCacheDataSource(cache, await Hive.openBox<int>('timestamps')),
      catalogue: catalogue,
    );
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Future<void> log(MealEntity meal, {String id = 'entry'}) => repo.addIntake(
    IntakeEntity(
      id: id,
      unit: 'g',
      amount: 150,
      type: IntakeTypeEntity.lunch,
      dateTime: moment,
      meal: meal,
    ),
  );
  for (final quick in [false, true]) {
    test(
      'custom refresh removes nutrients on one occurrence, quick=$quick',
      () async {
        await log(food(quick: quick));
        await log(food(quick: quick), id: 'other');
        await custom.add(
          MealDBO.fromMealEntity(food(kcal: null, carbs: 0, quick: quick)),
        );
        final updated = (await refresh.refresh('entry'))!;
        expect(updated.amount, 150);
        expect(updated.dateTime, moment);
        expect(updated.type, IntakeTypeEntity.lunch);
        expect(updated.meal.nutriments.energyKcal100, isNull);
        expect(updated.meal.nutriments.carbohydrates100, 0);
        expect(updated.isIncomplete, isTrue);
        expect(updated.meal.isQuickAdd, quick);
        expect((await repo.getIntakeById('other'))!.totalKcal, 150);
      },
    );
  }
  test(
    'catalogue refresh uses exact ID, preserves grams and bypasses search cache',
    () async {
      await log(food(source: MealSourceEntity.fdc, code: 'usda:1'));
      await log(
        food(source: MealSourceEntity.fdc, code: 'usda:1'),
        id: 'other',
      );
      catalogue.pending = Completer<MealEntity?>();
      final a = refresh.refresh('entry');
      final b = refresh.refresh('entry');
      await Future<void>.delayed(Duration.zero);
      await repo.updateIntake('entry', {'amount': 200.0});
      catalogue.pending!.complete(
        food(
          source: MealSourceEntity.fdc,
          code: 'usda:1',
          kcal: 250,
          carbs: null,
        ),
      );
      expect((await a)!.totalKcal, 500);
      expect((await b)!.amount, 200);
      expect(catalogue.ids, ['usda:1']);
      expect(products.calls, 0);
      expect(cache.values, isEmpty);
      expect((await repo.getIntakeById('other'))!.totalKcal, 150);
    },
  );

  for (final source in [MealSourceEntity.off]) {
    test(
      '$source refresh bypasses old snapshot, deduplicates and retains intervening weight',
      () async {
        await log(food(source: source));
        products.response = Completer<MealEntity>();
        final a = refresh.refresh('entry');
        final b = refresh.refresh('entry');
        await Future<void>.delayed(Duration.zero);
        await repo.updateIntake('entry', {'amount': 200.0});
        products.response!.complete(
          food(source: source, kcal: 250, carbs: null),
        );
        expect((await a)!.totalKcal, 500);
        expect((await b)!.amount, 200);
        expect(products.calls, 1);
        expect(cache.values.single.nutriments.carbohydrates100, isNull);
      },
    );
  }
  test('deleted source does not substitute another food', () async {
    await log(food());
    await custom.add(MealDBO.fromMealEntity(MealEntity.empty()));
    await expectLater(
      refresh.refresh('entry'),
      throwsA(isA<DiarySourceUnavailable>()),
    );
    expect((await repo.getIntakeById('entry'))!.totalKcal, 150);
  });
  test('deleted occurrence discards in-flight response', () async {
    await log(food(source: MealSourceEntity.off));
    products.response = Completer<MealEntity>();
    final run = refresh.refresh('entry');
    await Future<void>.delayed(Duration.zero);
    await intakes.clear();
    products.response!.complete(food(source: MealSourceEntity.off));
    expect(await run, isNull);
    expect(cache.isEmpty, isTrue);
  });
  test('profile change discards response', () async {
    await log(food(source: MealSourceEntity.off));
    products.response = Completer<MealEntity>();
    final run = refresh.refresh('entry');
    await Future<void>.delayed(Duration.zero);
    db.activeProfileId = 'different';
    products.response!.complete(food(source: MealSourceEntity.off, kcal: 200));
    expect(await run, isNull);
    expect((await repo.getIntakeById('entry'))!.totalKcal, 150);
  });
  test('unchanged weight reconciles known totals on the logical day', () async {
    final day = DateTime(2026, 10, 2);
    await days.put(
      day.toParsedDay(),
      TrackedDayDBO(day: day, calorieGoal: 2000, caloriesTracked: 999),
    );
    await days.put(
      DateTime(2026, 10, 3).toParsedDay(),
      TrackedDayDBO(
        day: DateTime(2026, 10, 3),
        calorieGoal: 2000,
        caloriesTracked: 777,
      ),
    );
    await log(food());
    await log(food(), id: 'other');
    await custom.add(MealDBO.fromMealEntity(food(kcal: null, carbs: 0)));
    await refresh.refresh('entry');
    expect(days.values.first.caloriesTracked, 150);
    expect(days.values.first.carbsTracked, 15);
    expect(days.values.last.caloriesTracked, 777);
  });
  test('failure preserves occurrence and allows retry', () async {
    await log(food(source: MealSourceEntity.off));
    products.failure = StateError('offline');
    await expectLater(refresh.refresh('entry'), throwsStateError);
    expect((await repo.getIntakeById('entry'))!.totalKcal, 150);
    products.failure = null;
    products.result = food(source: MealSourceEntity.off, kcal: 200);
    expect((await refresh.refresh('entry'))!.totalKcal, 300);
  });
  test(
    'older recipe refresh supplies latest ingredient snapshot at unchanged weight',
    () async {
      final recipe = RecipeEntity(
        id: 'food',
        name: 'Recipe',
        description: null,
        ingredients: [
          RecipeIngredientEntity(
            snapshotMeal: food(kcal: null),
            amount: 80,
            unit: 'g',
            convertedAmountG: 80,
          ),
        ],
        totalWeightG: 200,
        aggregatedNutrimentsPer100: food().nutriments,
        createdAt: moment,
        updatedAt: moment,
        servingsCount: 4,
      );
      await recipes.add(recipe.toDBO());
      await log(recipe.toMealEntity());
      final updated = (await refresh.refresh('entry'))!;
      expect(updated.amount, 150);
      expect(updated.recipeSnapshot, recipe);
      expect(updated.isIncomplete, isTrue);
      final ingredients = ExplodeRecipeIntakeUsecase.prepareIngredients(
        updated,
      );
      expect(ingredients.single.amount, 60);
      expect(ingredients.single.meal.nutriments.energyKcal100, isNull);
    },
  );
}
