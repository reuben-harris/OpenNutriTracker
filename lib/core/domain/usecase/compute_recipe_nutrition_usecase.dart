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
    double? totalWeightOverride,
  }) {
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
        totalWeightOverride ??
        ingredients.fold<double>(0, (sum, i) => sum + i.quantity.baseAmount);

    if (totalWeightG <= 0) {
      return ComputeRecipeNutritionResult(
        perHundredG: MealNutrimentsEntity.empty(),
        totalWeightG: 0,
      );
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

/// Single-pass accumulator for the 24 nutrient fields tracked on
/// [MealNutrimentsEntity]. Each field has a running sum and a flag for
/// "did any ingredient ever carry a non-null value for this field?". The
/// flag drives the existing "hide unknown micros" UI behaviour: if every
/// ingredient was silent on, say, vitamin B6, the recipe stays silent
/// too rather than showing a misleading 0.
class _NutrientAccumulator {
  double _energyKcal = 0, _carbs = 0, _fat = 0, _protein = 0;
  double _sugars = 0, _satFat = 0, _fiber = 0;
  double _monoFat = 0, _polyFat = 0, _transFat = 0, _cholesterol = 0;
  double _sodium = 0, _potassium = 0, _magnesium = 0, _calcium = 0;
  double _iron = 0, _zinc = 0, _phosphorus = 0;
  double _vitA = 0, _vitC = 0, _vitD = 0, _vitB6 = 0, _vitB12 = 0, _niacin = 0;

  bool _hasEnergy = false,
      _hasCarbs = false,
      _hasFat = false,
      _hasProtein = false;
  bool _hasSugars = false, _hasSatFat = false, _hasFiber = false;
  bool _hasMonoFat = false,
      _hasPolyFat = false,
      _hasTransFat = false,
      _hasCholesterol = false;
  bool _hasSodium = false,
      _hasPotassium = false,
      _hasMagnesium = false,
      _hasCalcium = false;
  bool _hasIron = false, _hasZinc = false, _hasPhosphorus = false;
  bool _hasVitA = false, _hasVitC = false, _hasVitD = false;
  bool _hasVitB6 = false, _hasVitB12 = false, _hasNiacin = false;

  void addFrom(MealNutrimentsEntity n, double baseAmount) {
    final ratio = baseAmount / 100;

    if (n.energyKcal100 != null) _hasEnergy = true;
    _energyKcal += (n.energyKcal100 ?? 0) * ratio;

    if (n.carbohydrates100 != null) _hasCarbs = true;
    _carbs += (n.carbohydrates100 ?? 0) * ratio;

    if (n.fat100 != null) _hasFat = true;
    _fat += (n.fat100 ?? 0) * ratio;

    if (n.proteins100 != null) _hasProtein = true;
    _protein += (n.proteins100 ?? 0) * ratio;

    if (n.sugars100 != null) _hasSugars = true;
    _sugars += (n.sugars100 ?? 0) * ratio;

    if (n.saturatedFat100 != null) _hasSatFat = true;
    _satFat += (n.saturatedFat100 ?? 0) * ratio;

    if (n.fiber100 != null) _hasFiber = true;
    _fiber += (n.fiber100 ?? 0) * ratio;

    if (n.monounsaturatedFat100 != null) _hasMonoFat = true;
    _monoFat += (n.monounsaturatedFat100 ?? 0) * ratio;

    if (n.polyunsaturatedFat100 != null) _hasPolyFat = true;
    _polyFat += (n.polyunsaturatedFat100 ?? 0) * ratio;

    if (n.transFat100 != null) _hasTransFat = true;
    _transFat += (n.transFat100 ?? 0) * ratio;

    if (n.cholesterol100 != null) _hasCholesterol = true;
    _cholesterol += (n.cholesterol100 ?? 0) * ratio;

    if (n.sodium100 != null) _hasSodium = true;
    _sodium += (n.sodium100 ?? 0) * ratio;

    if (n.potassium100 != null) _hasPotassium = true;
    _potassium += (n.potassium100 ?? 0) * ratio;

    if (n.magnesium100 != null) _hasMagnesium = true;
    _magnesium += (n.magnesium100 ?? 0) * ratio;

    if (n.calcium100 != null) _hasCalcium = true;
    _calcium += (n.calcium100 ?? 0) * ratio;

    if (n.iron100 != null) _hasIron = true;
    _iron += (n.iron100 ?? 0) * ratio;

    if (n.zinc100 != null) _hasZinc = true;
    _zinc += (n.zinc100 ?? 0) * ratio;

    if (n.phosphorus100 != null) _hasPhosphorus = true;
    _phosphorus += (n.phosphorus100 ?? 0) * ratio;

    if (n.vitaminA100 != null) _hasVitA = true;
    _vitA += (n.vitaminA100 ?? 0) * ratio;

    if (n.vitaminC100 != null) _hasVitC = true;
    _vitC += (n.vitaminC100 ?? 0) * ratio;

    if (n.vitaminD100 != null) _hasVitD = true;
    _vitD += (n.vitaminD100 ?? 0) * ratio;

    if (n.vitaminB6100 != null) _hasVitB6 = true;
    _vitB6 += (n.vitaminB6100 ?? 0) * ratio;

    if (n.vitaminB12100 != null) _hasVitB12 = true;
    _vitB12 += (n.vitaminB12100 ?? 0) * ratio;

    if (n.niacin100 != null) _hasNiacin = true;
    _niacin += (n.niacin100 ?? 0) * ratio;
  }

  MealNutrimentsEntity toEntityPerHundredG(double totalWeightG) {
    double? norm(double sum, bool anyPresent) =>
        anyPresent ? sum * 100 / totalWeightG : null;

    return MealNutrimentsEntity(
      energyKcal100: norm(_energyKcal, _hasEnergy),
      carbohydrates100: norm(_carbs, _hasCarbs),
      fat100: norm(_fat, _hasFat),
      proteins100: norm(_protein, _hasProtein),
      sugars100: norm(_sugars, _hasSugars),
      saturatedFat100: norm(_satFat, _hasSatFat),
      fiber100: norm(_fiber, _hasFiber),
      monounsaturatedFat100: norm(_monoFat, _hasMonoFat),
      polyunsaturatedFat100: norm(_polyFat, _hasPolyFat),
      transFat100: norm(_transFat, _hasTransFat),
      cholesterol100: norm(_cholesterol, _hasCholesterol),
      sodium100: norm(_sodium, _hasSodium),
      potassium100: norm(_potassium, _hasPotassium),
      magnesium100: norm(_magnesium, _hasMagnesium),
      calcium100: norm(_calcium, _hasCalcium),
      iron100: norm(_iron, _hasIron),
      zinc100: norm(_zinc, _hasZinc),
      phosphorus100: norm(_phosphorus, _hasPhosphorus),
      vitaminA100: norm(_vitA, _hasVitA),
      vitaminC100: norm(_vitC, _hasVitC),
      vitaminD100: norm(_vitD, _hasVitD),
      vitaminB6100: norm(_vitB6, _hasVitB6),
      vitaminB12100: norm(_vitB12, _hasVitB12),
      niacin100: norm(_niacin, _hasNiacin),
    );
  }
}
