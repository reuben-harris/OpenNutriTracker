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

    // Aggregate every supported field in one sweep, retaining qualifications
    // and marking a known sum as partial when an ingredient has no value.
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

  MealNutrimentsEntity toEntityPerHundredG(double totalWeightG) =>
      MealNutrimentsEntity.fromAmounts({
        for (final entry in _amounts.entries)
          entry.key: entry.value.total?.scale(100 / totalWeightG),
      });
}
