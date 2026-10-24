import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import '../../../../helpers/hive_test_setup.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';

class _FakeRecipeRepository implements RecipeRepository {
  final List<RecipeEntity> saved = [];
  Completer<void>? blockNextSave;

  @override
  Future<void> saveRecipe(RecipeEntity recipe) async {
    saved.add(recipe);
    final block = blockNextSave;
    blockNextSave = null;
    await block?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

MealEntity _meal(String code, {double kcal = 100}) {
  return MealEntity(
    code: code,
    name: code,
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: kcal,
      carbohydrates100: null,
      fat100: null,
      proteins100: null,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
    source: MealSourceEntity.off,
  );
}

void main() {
  late ComputeRecipeNutritionUseCase compute;
  late _FakeRecipeRepository repo;
  late SaveRecipeUseCase save;
  late RecipeBuilderBloc bloc;

  setUp(() {
    compute = ComputeRecipeNutritionUseCase();
    repo = _FakeRecipeRepository();
    save = SaveRecipeUseCase(repo, compute);
    bloc = RecipeBuilderBloc(compute, save);
  });

  tearDown(() => bloc.close());

  Future<void> dispatch(RecipeBuilderEvent event) async {
    final changed = bloc.stream
        .firstWhere(
          (state) =>
              event is! SaveRecipeEvent ||
              (!state.isSaving && (state.didSave || state.saveError != null)),
        )
        .timeout(const Duration(seconds: 5));
    bloc.add(event);
    await changed;
  }

  test(
    'live saves serialize writes and retain edits made during a pending save',
    () async {
      await dispatch(InitializeBuilderEvent());
      await dispatch(const UpdateNameEvent('First name'));
      await dispatch(
        AddIngredientEvent(
          meal: _meal('oats'),
          quantity: FoodAmountSelection(
            100,
            FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
          ),
        ),
      );
      final block = Completer<void>();
      repo.blockNextSave = block;
      final first = Completer<bool>();
      bloc.add(
        SaveRecipeEvent(closeAfterSave: false, onCompleted: first.complete),
      );
      await bloc.stream.firstWhere((state) => state.isSaving);
      await dispatch(const UpdateNameEvent('Second name'));
      final second = Completer<bool>();
      bloc.add(
        SaveRecipeEvent(closeAfterSave: false, onCompleted: second.complete),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.name, 'First name');
      block.complete();
      expect(await first.future, true);
      expect(await second.future, true);
      expect(repo.saved.last.name, 'Second name');
      expect(bloc.state.name, 'Second name');
      expect(bloc.state.didSave, false);
      expect(bloc.state.isSaving, false);
    },
  );

  test('live editing can persist removal of the last ingredient', () async {
    await dispatch(InitializeBuilderEvent());
    await dispatch(const UpdateNameEvent('Empty recipe'));
    final completed = Completer<bool>();
    bloc.add(
      SaveRecipeEvent(closeAfterSave: false, onCompleted: completed.complete),
    );
    expect(await completed.future, true);
    expect(repo.saved.single.ingredients, isEmpty);
    expect(repo.saved.single.totalWeightG, 0);
    expect(bloc.state.didSave, false);
  });

  test(
    'exploding a nested recipe scales its ingredients to the selected quantity',
    () async {
      await dispatch(InitializeBuilderEvent());
      await dispatch(const UpdateNameEvent('Nested'));
      await dispatch(
        AddIngredientEvent(
          meal: _meal('flour'),
          quantity: FoodAmountSelection(
            200,
            FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
          ),
        ),
      );
      await dispatch(const SaveRecipeEvent());
      final nested = repo.saved.single;
      await dispatch(InitializeBuilderEvent());
      await dispatch(
        AddIngredientEvent(
          meal: nested.toMealEntity(),
          quantity: FoodAmountSelection(
            50,
            FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
          ),
        ),
      );
      await dispatch(ExplodeIngredientEvent(index: 0, recipe: nested));
      expect(
        bloc.state.ingredients.single.snapshotMeal.source,
        isNot(MealSourceEntity.recipe),
      );
      expect(bloc.state.ingredients.single.quantity.baseAmount, 50);
      expect(bloc.state.totalWeightG, 50);
    },
  );

  test(
    'builder preserves portions through editing, saving and reopening',
    () async {
      const quantity = FoodAmountSelection(
        2,
        FoodAmountOption(
          unit: 'portion:slice',
          baseUnit: 'g',
          factor: 38,
          label: '1 slice',
        ),
      );
      await dispatch(
        AddIngredientEvent(meal: _meal('bread', kcal: 200), quantity: quantity),
      );

      expect(bloc.state.ingredients.single.quantity, quantity);
      expect(bloc.state.totalWeightG, 76);
      await dispatch(
        UpdateIngredientEvent(
          index: 0,
          meal: bloc.state.ingredients.single.snapshotMeal,
          quantity: FoodAmountSelection(3, quantity.option),
        ),
      );
      await dispatch(const UpdateNameEvent('Bread recipe'));

      expect(bloc.state.totalWeightG, 114);
      await dispatch(const SaveRecipeEvent());

      final saved = repo.saved.single;
      expect(saved.ingredients.single.quantity.amount, 3);
      expect(saved.ingredients.single.quantity.option, quantity.option);
      await dispatch(InitializeBuilderEvent(existing: saved));

      expect(bloc.state.ingredients.single.quantity.option, quantity.option);
      expect(bloc.state.totalWeightG, 114);
    },
  );

  for (final grams in [200.0, 250.0]) {
    test(
      'updated ingredient food and quantity survive saving and reopening at $grams g',
      () async {
        final original = _meal('yoghurt');
        final corrected = MealEntity(
          code: 'corrected-yoghurt',
          name: 'Corrected yoghurt',
          brands: 'Updated brand',
          url: null,
          mealQuantity: '100',
          mealUnit: 'g',
          servingQuantity: 40,
          servingUnit: 'g',
          servingSize: '40 g',
          nutriments: const MealNutrimentsEntity(
            energyKcal100: 150,
            carbohydrates100: 0,
            fat100: 5,
            proteins100: 12,
            sugars100: null,
            saturatedFat100: 1,
            fiber100: null,
            calcium100: 120,
          ),
          source: MealSourceEntity.custom,
        );
        final quantity = FoodAmountSelection(
          grams,
          FoodAmountOption.standard(FoodAmountUnit.g),
        );
        await dispatch(const UpdateNameEvent('Yoghurt recipe'));
        await dispatch(
          AddIngredientEvent(
            meal: original,
            quantity: FoodAmountSelection(200, quantity.option),
          ),
        );
        await dispatch(
          UpdateIngredientEvent(index: 0, meal: corrected, quantity: quantity),
        );
        expect(bloc.state.ingredients.single.snapshotMeal, same(corrected));
        expect(bloc.state.ingredients.single.quantity, quantity);
        expect(bloc.state.aggregatedNutrimentsPer100, corrected.nutriments);
        expect(bloc.state.totalWeightG, grams);
        await dispatch(const SaveRecipeEvent());

        final saved = repo.saved.single;
        expect(saved.ingredients.single.snapshotMeal, same(corrected));
        expect(
          saved.aggregatedNutrimentsPer100.energyKcal100! *
              saved.totalWeightG /
              100,
          grams == 200 ? 300 : 375,
        );

        final dir = await Directory.systemTemp.createTemp('recipe-ingredient');
        Hive.init(dir.path);
        registerHiveAdaptersOnce();
        var box = await Hive.openBox<RecipeDBO>('recipes');
        try {
          await box.put(saved.id, saved.toDBO());
          await box.close();
          box = await Hive.openBox<RecipeDBO>('recipes');
          final restored = RecipeEntity.fromDBO(box.get(saved.id)!);
          await dispatch(InitializeBuilderEvent(existing: restored));

          final ingredient = bloc.state.ingredients.single;
          expect(ingredient.snapshotMeal, corrected);
          expect(ingredient.snapshotMeal.brands, corrected.brands);
          expect(ingredient.snapshotMeal.source, corrected.source);
          expect(ingredient.quantity, quantity);
          expect(bloc.state.aggregatedNutrimentsPer100, corrected.nutriments);
          expect(bloc.state.totalWeightG, grams);
        } finally {
          await Hive.close();
          await dir.delete(recursive: true);
        }
      },
    );
  }

  Future<void> addFlour(double grams) => dispatch(
    AddIngredientEvent(
      meal: _meal('flour', kcal: 200),
      quantity: FoodAmountSelection(
        grams,
        FoodAmountOption.standard(FoodAmountUnit.g),
      ),
    ),
  );

  test(
    'custom weight survives persistence, reopening, edits and duplication',
    () async {
      await dispatch(const UpdateNameEvent('Bread'));
      await addFlour(800);
      await dispatch(const UpdateServingsCountEvent(4));
      await dispatch(const UpdateWeightModeEvent(RecipeWeightMode.custom));
      await dispatch(const UpdateCookedWeightEvent(720.123456789));
      await dispatch(const SaveRecipeEvent());
      final saved = repo.saved.single;
      expect(saved.cookedWeightG, 720.123456789);
      expect(saved.totalWeightG, 720.123456789);
      expect(saved.toMealEntity().scalableServingQuantity, 720.123456789 / 4);
      expect(
        saved.aggregatedNutrimentsPer100.energyKcal100! *
            saved.totalWeightG /
            100,
        closeTo(1600, 0.00001),
      );

      final dir = await Directory.systemTemp.createTemp('recipe-weight');
      Hive.init(dir.path);
      registerHiveAdaptersOnce();
      var box = await Hive.openBox<RecipeDBO>('recipes');
      try {
        await box.put(saved.id, saved.toDBO());
        await box.close();
        box = await Hive.openBox<RecipeDBO>('recipes');
        final restored = RecipeEntity.fromDBO(
          RecipeDBO.fromJson(
            jsonDecode(jsonEncode(box.get(saved.id)!.toJson()))
                as Map<String, dynamic>,
          ),
        );
        expect(restored.cookedWeightG, saved.cookedWeightG);
        await dispatch(InitializeBuilderEvent(existing: restored));
        expect(bloc.state.weightMode, RecipeWeightMode.custom);
        expect(bloc.state.totalWeightG, saved.totalWeightG);
        await dispatch(const UpdateNameEvent('Renamed bread'));
        await dispatch(const SaveRecipeEvent());
        expect(repo.saved.last.totalWeightG, saved.totalWeightG);
        await dispatch(
          InitializeBuilderEvent(existing: repo.saved.last.copyWith(id: '')),
        );
        expect(bloc.state.isExistingRecipe, isFalse);
        expect(bloc.state.weightMode, RecipeWeightMode.custom);
        await addFlour(100);
        expect(bloc.state.totalWeightG, saved.totalWeightG);
        expect(
          bloc.state.aggregatedNutrimentsPer100!.energyKcal100! *
              bloc.state.totalWeightG! /
              100,
          closeTo(1800, 0.00001),
        );
        await dispatch(const RemoveIngredientEvent(1));
        expect(bloc.state.totalWeightG, saved.totalWeightG);
      } finally {
        await Hive.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'automatic weight follows ingredient edits and remains automatic after reopening',
    () async {
      await dispatch(const UpdateNameEvent('Bread'));
      await addFlour(800);
      await addFlour(100);
      expect(bloc.state.totalWeightG, 900);
      await dispatch(
        UpdateIngredientEvent(
          index: 0,
          meal: bloc.state.ingredients.first.snapshotMeal,
          quantity: FoodAmountSelection(
            700,
            FoodAmountOption.standard(FoodAmountUnit.g),
          ),
        ),
      );
      expect(bloc.state.totalWeightG, 800);
      await dispatch(const RemoveIngredientEvent(1));
      expect(bloc.state.totalWeightG, 700);
      await dispatch(const SaveRecipeEvent());
      expect(repo.saved.single.cookedWeightG, isNull);
      await dispatch(InitializeBuilderEvent(existing: repo.saved.single));
      expect(bloc.state.weightMode, RecipeWeightMode.automatic);
      expect(bloc.state.totalWeightG, 700);
    },
  );

  test(
    'switching to automatic discards custom weight even when it equals the ingredient sum',
    () async {
      await dispatch(const UpdateNameEvent('Bread'));
      await addFlour(800);
      await dispatch(const UpdateWeightModeEvent(RecipeWeightMode.custom));
      expect(bloc.state.totalWeightG, isNull);
      expect(bloc.state.aggregatedNutrimentsPer100, isNull);
      await dispatch(const UpdateCookedWeightEvent(800));
      await dispatch(const SaveRecipeEvent());
      await dispatch(InitializeBuilderEvent(existing: repo.saved.single));
      expect(bloc.state.weightMode, RecipeWeightMode.custom);
      await dispatch(const UpdateWeightModeEvent(RecipeWeightMode.automatic));
      expect(bloc.state.cookedWeightG, isNull);
      expect(bloc.state.totalWeightG, 800);
      await dispatch(const SaveRecipeEvent());
      expect(repo.saved.last.cookedWeightG, isNull);
      await dispatch(const UpdateWeightModeEvent(RecipeWeightMode.custom));
      expect(bloc.state.cookedWeightG, isNull);
      expect(bloc.state.totalWeightG, isNull);
    },
  );

  for (final invalid in [null, 0.0, -1.0, double.nan, double.infinity]) {
    test(
      'invalid custom weight $invalid cannot reuse the previous valid weight',
      () async {
        await dispatch(const UpdateNameEvent('Bread'));
        await addFlour(800);
        await dispatch(const UpdateWeightModeEvent(RecipeWeightMode.custom));
        await dispatch(const UpdateCookedWeightEvent(720));
        await dispatch(UpdateCookedWeightEvent(invalid));
        expect(bloc.state.cookedWeightG, isNull);
        expect(bloc.state.totalWeightG, isNull);
        expect(bloc.state.aggregatedNutrimentsPer100, isNull);
        await dispatch(const SaveRecipeEvent());
        expect(bloc.state.saveError, SaveError.invalidTotalWeight);
        expect(repo.saved, isEmpty);
        await dispatch(const UpdateCookedWeightEvent(710));
        expect(bloc.state.hasValidWeight, isTrue);
        await dispatch(const SaveRecipeEvent());
        expect(repo.saved.single.totalWeightG, 710);
      },
    );
  }

  group('RecipeBuilderBloc', () {
    test('initial state has no id, empty name, empty ingredients', () {
      expect(bloc.state.id, isNull);
      expect(bloc.state.name, '');
      expect(bloc.state.ingredients, isEmpty);
      expect(bloc.state.isExistingRecipe, isFalse);
    });

    test(
      'AddIngredientEvent recomputes total weight + per-100g nutrition',
      () async {
        await dispatch(
          AddIngredientEvent(
            meal: _meal('flour', kcal: 340),
            quantity: resolveFoodAmount(100, 'g', _meal('flour', kcal: 340))!,
          ),
        );

        expect(bloc.state.ingredients, hasLength(1));
        expect(bloc.state.totalWeightG, 100);
        expect(
          bloc.state.aggregatedNutrimentsPer100!.energyKcal100,
          closeTo(340, 0.01),
        );
      },
    );

    test('save with empty name emits nameRequired error', () async {
      await dispatch(const SaveRecipeEvent());

      expect(bloc.state.saveError, SaveError.nameRequired);
      expect(repo.saved, isEmpty);
    });

    test('save with no ingredients emits needsIngredients error', () async {
      await dispatch(const UpdateNameEvent('Cake'));
      await dispatch(const SaveRecipeEvent());

      expect(bloc.state.saveError, SaveError.needsIngredients);
      expect(repo.saved, isEmpty);
    });

    test('successful save persists and emits didSave', () async {
      await dispatch(const UpdateNameEvent('Cake'));
      await dispatch(
        AddIngredientEvent(
          meal: _meal('flour', kcal: 340),
          quantity: resolveFoodAmount(100, 'g', _meal('flour', kcal: 340))!,
        ),
      );

      await dispatch(const SaveRecipeEvent());

      expect(bloc.state.didSave, isTrue);
      expect(bloc.state.saveError, isNull);
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.name, 'Cake');
      expect(repo.saved.single.id, isNotEmpty);
    });

    test('initialize with existing recipe sets isExistingRecipe', () async {
      final existing = RecipeEntity(
        id: 'existing-1',
        name: 'Original',
        description: null,
        ingredients: const [],
        totalWeightG: 100,
        aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
        servingsCount: null,
      );
      await dispatch(InitializeBuilderEvent(existing: existing));

      expect(bloc.state.isExistingRecipe, isTrue);
      expect(bloc.state.id, 'existing-1');
      expect(bloc.state.name, 'Original');
    });

    test(
      'initialize with empty-id recipe (duplicate sentinel) treats as create',
      () async {
        final duplicate = RecipeEntity(
          id: '',
          name: 'Cake (copy)',
          description: null,
          ingredients: const [],
          totalWeightG: 100,
          aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 1),
          servingsCount: null,
        );
        await dispatch(InitializeBuilderEvent(existing: duplicate));

        expect(bloc.state.isExistingRecipe, isFalse);
        expect(bloc.state.id, isNull);
        expect(bloc.state.name, 'Cake (copy)');
      },
    );
  });
}
