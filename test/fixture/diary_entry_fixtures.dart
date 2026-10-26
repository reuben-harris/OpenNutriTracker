import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
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
      energyKcal100: NutrientAmount(380),
      carbohydrates100: NutrientAmount(60),
      fat100: NutrientAmount(8),
      proteins100: NutrientAmount(12),
      sugars100: NutrientAmount(1),
      saturatedFat100: NutrientAmount(2),
      fiber100: NutrientAmount(10),
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
              quantity: FoodAmountSelection.fromSnapshot(
                amount: 100,
                unit: 'g',
                baseUnit: 'g',
                factor: (100) / (100),
              ),
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
    quantity: FoodAmountSelection(
      amount,
      FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
    ),
    type: IntakeTypeEntity.breakfast,
    meal: saved?.toMealEntity() ?? food,
    dateTime: DateTime(2026, 9, 29, 8, 42),
    recipeSnapshot: saved,
  );
}

MealEntity nutrientFood(MealNutrimentsEntity amounts) => MealEntity(
  code: 'fixture',
  name: 'Food',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: null,
  servingSize: null,
  source: MealSourceEntity.custom,
  nutriments: amounts,
);
