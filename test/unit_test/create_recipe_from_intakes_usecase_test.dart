import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/create_recipe_from_intakes_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import '../fixture/diary_entry_fixtures.dart';

class _Save implements SaveRecipeUseCase {
  RecipeEntity? saved;
  @override
  Future<RecipeEntity> save(RecipeEntity recipe) async => saved = recipe;
}

void main() {
  test(
    'copies exact foods and quantities into a new saved recipe without changing the diary',
    () async {
      final save = _Save();
      final create = CreateRecipeFromIntakesUsecase(
        ComputeRecipeNutritionUseCase(),
        save,
      );
      final source = [
        diaryEntry(amount: 75),
        diaryEntry(id: 'nested', recipe: true, amount: 50),
      ];
      final original = List<IntakeEntity>.of(source);
      final recipe = await create.create(
        name: ' Lunch recipe ',
        entries: source,
      );
      expect(recipe.id, isNotEmpty);
      expect(recipe.id, isNot('saved-recipe'));
      expect(recipe.name, 'Lunch recipe');
      expect(recipe.servingsCount, 1);
      expect(recipe.totalWeightG, 125);
      expect(
        recipe.ingredients.map((i) => i.quantity),
        source.map((i) => i.quantity),
      );
      expect(
        recipe.ingredients.last.snapshotMeal.source,
        MealSourceEntity.recipe,
      );
      expect(
        recipe.aggregatedNutrimentsPer100.energyKcal100! * 1.25,
        source.fold<double>(0, (sum, entry) => sum + entry.totalKcal),
      );
      expect(source, original);
      expect(save.saved, same(recipe));
    },
  );

  test(
    'empty groups and unweighted Quick Add entries cannot be silently omitted',
    () async {
      final save = _Save();
      final create = CreateRecipeFromIntakesUsecase(
        ComputeRecipeNutritionUseCase(),
        save,
      );
      await expectLater(
        create.create(name: 'Recipe', entries: []),
        throwsFormatException,
      );
      final entry = diaryEntry();
      final unweighted = IntakeEntity(
        id: 'quick',
        quantity: null,
        type: entry.type,
        dateTime: entry.dateTime,
        meal: MealEntity(
          code: 'quick',
          name: 'Quick add',
          url: null,
          mealQuantity: null,
          mealUnit: 'gml',
          servingQuantity: null,
          servingUnit: null,
          servingSize: null,
          nutriments: entry.meal.nutriments,
          source: MealSourceEntity.custom,
          isQuickAdd: true,
        ),
      );
      await expectLater(
        create.create(name: 'Recipe', entries: [unweighted]),
        throwsFormatException,
      );
      expect(save.saved, isNull);
    },
  );
}
