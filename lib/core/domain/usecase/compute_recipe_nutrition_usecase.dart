import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

class ComputeRecipeNutritionResult {
  final MealNutrimentsEntity perHundredG;
  final double totalWeightG;

  const ComputeRecipeNutritionResult({
    required this.perHundredG,
    required this.totalWeightG,
  });
}

class ComputeRecipeNutritionUseCase {
  ComputeRecipeNutritionResult compute(
    List<RecipeIngredientEntity> ingredients, {
    double? cookedWeightG,
  }) {
    if (cookedWeightG != null &&
        (!cookedWeightG.isFinite || cookedWeightG <= 0)) {
      throw const FormatException('Cooked weight must be positive and finite');
    }
    if (ingredients.isEmpty) {
      return ComputeRecipeNutritionResult(
        perHundredG: MealNutrimentsEntity.empty(),
        totalWeightG: 0,
      );
    }

    for (final ingredient in ingredients) {
      ingredient.quantity.validate();
    }
    // Recipe weight retains the explicit approximation 1 ml ≈ 1 g.
    final totalWeightG =
        cookedWeightG ??
        ingredients.fold<double>(0, (sum, i) => sum + i.quantity.baseAmount);

    if (!totalWeightG.isFinite || totalWeightG <= 0) {
      throw const FormatException('Recipe weight must be positive and finite');
    }

    // For every nutrient field: sum (value100 ?? 0) × baseAmount / 100
    // across ingredients, but track whether *any* ingredient had a non-null
    // value for that field. If none did, the recipe field stays null too —
    // that preserves the existing UI behaviour of hiding unknown micros.
    //
    // The previous shape called a per-nutrient helper 24 times, each doing
    // its own anyNonNull() + total() pass. Restructuring to a single sweep
    // over the ingredient list keeps the same null-stays-null semantics
    // while collapsing 48 traversals into 1.
    final acc = _NutrientAccumulator();
    for (final ingredient in ingredients) {
      acc.addFrom(
        ingredient.snapshotMeal.nutriments,
        ingredient.quantity.baseAmount,
      );
    }

    final per = acc.toEntityPerHundredG(totalWeightG);

    return ComputeRecipeNutritionResult(
      perHundredG: per,
      totalWeightG: totalWeightG,
    );
  }
}

class _NutrientAccumulator {
  final _amounts = <String, NutrientAccumulator>{};
  void addFrom(MealNutrimentsEntity n, double baseAmount) {
    for (final entry in n.amounts.entries) {
      (_amounts[entry.key] ??= NutrientAccumulator()).add(
        entry.value,
        scale: baseAmount / 100,
      );
    }
  }

  MealNutrimentsEntity toEntityPerHundredG(
    double totalWeightG,
  ) => MealNutrimentsEntity(
    energyKcal100: _amounts['energyKcal100']?.total?.scale(100 / totalWeightG),
    carbohydrates100: _amounts['carbohydrates100']?.total?.scale(
      100 / totalWeightG,
    ),
    fat100: _amounts['fat100']?.total?.scale(100 / totalWeightG),
    proteins100: _amounts['proteins100']?.total?.scale(100 / totalWeightG),
    sugars100: _amounts['sugars100']?.total?.scale(100 / totalWeightG),
    saturatedFat100: _amounts['saturatedFat100']?.total?.scale(
      100 / totalWeightG,
    ),
    fiber100: _amounts['fiber100']?.total?.scale(100 / totalWeightG),
    monounsaturatedFat100: _amounts['monounsaturatedFat100']?.total?.scale(
      100 / totalWeightG,
    ),
    polyunsaturatedFat100: _amounts['polyunsaturatedFat100']?.total?.scale(
      100 / totalWeightG,
    ),
    transFat100: _amounts['transFat100']?.total?.scale(100 / totalWeightG),
    cholesterol100: _amounts['cholesterol100']?.total?.scale(
      100 / totalWeightG,
    ),
    sodium100: _amounts['sodium100']?.total?.scale(100 / totalWeightG),
    potassium100: _amounts['potassium100']?.total?.scale(100 / totalWeightG),
    magnesium100: _amounts['magnesium100']?.total?.scale(100 / totalWeightG),
    calcium100: _amounts['calcium100']?.total?.scale(100 / totalWeightG),
    iron100: _amounts['iron100']?.total?.scale(100 / totalWeightG),
    zinc100: _amounts['zinc100']?.total?.scale(100 / totalWeightG),
    phosphorus100: _amounts['phosphorus100']?.total?.scale(100 / totalWeightG),
    vitaminA100: _amounts['vitaminA100']?.total?.scale(100 / totalWeightG),
    vitaminC100: _amounts['vitaminC100']?.total?.scale(100 / totalWeightG),
    vitaminD100: _amounts['vitaminD100']?.total?.scale(100 / totalWeightG),
    vitaminB6100: _amounts['vitaminB6100']?.total?.scale(100 / totalWeightG),
    vitaminB12100: _amounts['vitaminB12100']?.total?.scale(100 / totalWeightG),
    niacin100: _amounts['niacin100']?.total?.scale(100 / totalWeightG),
  );
}
