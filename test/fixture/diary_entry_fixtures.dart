import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

IntakeEntity diaryEntry({
  String id = 'source',
  bool recipe = false,
  double amount = 125,
}) {
  const food = MealEntity(
    code: 'test-oats',
    name: 'Diary oats',
    url: null,
    mealQuantity: '100',
    mealUnit: 'g',
    servingQuantity: 50,
    servingUnit: 'g',
    servingSize: '50 g',
    source: MealSourceEntity.custom,
    nutriments: MealNutrimentsEntity(
      energyKcal100: 380,
      carbohydrates100: 60,
      fat100: 8,
      proteins100: 12,
      sugars100: 1,
      saturatedFat100: 2,
      fiber100: 10,
    ),
  );
  final saved = recipe
      ? RecipeEntity(
          id: 'saved-recipe',
          name: 'Saved recipe',
          description: 'Original version',
          ingredients: [
            RecipeIngredientEntity(
              snapshotMeal: food,
              amount: 100,
              unit: 'g',
              convertedAmountG: 100,
            ),
          ],
          totalWeightG: 200,
          aggregatedNutrimentsPer100: food.nutriments,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 2),
          servingsCount: 2,
          tags: ['Breakfast'],
        )
      : null;
  return IntakeEntity(
    id: id,
    unit: 'g',
    amount: amount,
    type: IntakeTypeEntity.breakfast,
    meal: saved?.toMealEntity() ?? food,
    dateTime: DateTime(2026, 9, 29, 8, 42),
    recipeSnapshot: saved,
  );
}
