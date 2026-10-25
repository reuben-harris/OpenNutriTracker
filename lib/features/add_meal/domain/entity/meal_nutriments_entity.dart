import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_nutriments_dto.dart';

class MealNutrimentsEntity extends Equatable {
  final NutrientAmount? energyKcal100;

  bool get isIncomplete =>
      energyKcal100 == null ||
      carbohydrates100 == null ||
      fat100 == null ||
      proteins100 == null;

  final NutrientAmount? carbohydrates100;
  final NutrientAmount? fat100;
  final NutrientAmount? proteins100;
  final NutrientAmount? sugars100;
  final NutrientAmount? saturatedFat100;
  final NutrientAmount? fiber100;
  // #237: Extended lipid profile
  final NutrientAmount? monounsaturatedFat100;
  final NutrientAmount? polyunsaturatedFat100;
  final NutrientAmount? transFat100;
  final NutrientAmount? cholesterol100;
  // #237: Minerals (mg per 100g)
  final NutrientAmount? sodium100;
  final NutrientAmount? potassium100;
  final NutrientAmount? magnesium100;
  final NutrientAmount? calcium100;
  final NutrientAmount? iron100;
  final NutrientAmount? zinc100;
  final NutrientAmount? phosphorus100;
  // #237: Vitamins
  final NutrientAmount? vitaminA100; // µg RAE
  final NutrientAmount? vitaminC100; // mg
  final NutrientAmount? vitaminD100; // µg
  final NutrientAmount? vitaminB6100; // mg
  final NutrientAmount? vitaminB12100; // µg
  final NutrientAmount? niacin100; // mg (B3)

  NutrientAmount? get energyPerUnit => _getValuePerUnit(energyKcal100);

  NutrientAmount? get carbohydratesPerUnit =>
      _getValuePerUnit(carbohydrates100);

  NutrientAmount? get fatPerUnit => _getValuePerUnit(fat100);

  NutrientAmount? get proteinsPerUnit => _getValuePerUnit(proteins100);

  /// Returns true when at least one of the extended micronutrient fields
  /// (lipid profile / minerals / vitamins from #237) has a value.
  bool get hasMicronutrientData =>
      monounsaturatedFat100 != null ||
      polyunsaturatedFat100 != null ||
      transFat100 != null ||
      cholesterol100 != null ||
      sodium100 != null ||
      potassium100 != null ||
      magnesium100 != null ||
      calcium100 != null ||
      iron100 != null ||
      zinc100 != null ||
      phosphorus100 != null ||
      vitaminA100 != null ||
      vitaminC100 != null ||
      vitaminD100 != null ||
      vitaminB6100 != null ||
      vitaminB12100 != null ||
      niacin100 != null;

  const MealNutrimentsEntity({
    required this.energyKcal100,
    required this.carbohydrates100,
    required this.fat100,
    required this.proteins100,
    required this.sugars100,
    required this.saturatedFat100,
    required this.fiber100,
    this.monounsaturatedFat100,
    this.polyunsaturatedFat100,
    this.transFat100,
    this.cholesterol100,
    this.sodium100,
    this.potassium100,
    this.magnesium100,
    this.calcium100,
    this.iron100,
    this.zinc100,
    this.phosphorus100,
    this.vitaminA100,
    this.vitaminC100,
    this.vitaminD100,
    this.vitaminB6100,
    this.vitaminB12100,
    this.niacin100,
  });

  factory MealNutrimentsEntity.empty() => const MealNutrimentsEntity(
    energyKcal100: null,
    carbohydrates100: null,
    fat100: null,
    proteins100: null,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  );

  /// Stored values that are NaN or infinite read back as null ("unknown").
  /// A custom meal saved with a base quantity of 0 was stored that way
  /// (#1254); read through unchanged, one such row turned every total it
  /// fed into NaN and threw in the widgets that round those totals.
  factory MealNutrimentsEntity.fromMealNutrimentsDBO(
    MealNutrimentsDBO nutriments,
  ) {
    NutrientAmount? finite(NutrientAmount? value) =>
        value != null && value.isFinite ? value : null;
    return MealNutrimentsEntity(
      energyKcal100: finite(nutriments.energyKcal100),
      carbohydrates100: finite(nutriments.carbohydrates100),
      fat100: finite(nutriments.fat100),
      proteins100: finite(nutriments.proteins100),
      sugars100: finite(nutriments.sugars100),
      saturatedFat100: finite(nutriments.saturatedFat100),
      fiber100: finite(nutriments.fiber100),
      monounsaturatedFat100: finite(nutriments.monounsaturatedFat100),
      polyunsaturatedFat100: finite(nutriments.polyunsaturatedFat100),
      transFat100: finite(nutriments.transFat100),
      cholesterol100: finite(nutriments.cholesterol100),
      sodium100: finite(nutriments.sodium100),
      potassium100: finite(nutriments.potassium100),
      magnesium100: finite(nutriments.magnesium100),
      calcium100: finite(nutriments.calcium100),
      iron100: finite(nutriments.iron100),
      zinc100: finite(nutriments.zinc100),
      phosphorus100: finite(nutriments.phosphorus100),
      vitaminA100: finite(nutriments.vitaminA100),
      vitaminC100: finite(nutriments.vitaminC100),
      vitaminD100: finite(nutriments.vitaminD100),
      vitaminB6100: finite(nutriments.vitaminB6100),
      vitaminB12100: finite(nutriments.vitaminB12100),
      niacin100: finite(nutriments.niacin100),
    );
  }

  factory MealNutrimentsEntity.fromOffNutriments(
    OFFProductNutrimentsDTO? offNutriments,
  ) {
    if (offNutriments == null) return MealNutrimentsEntity.empty();

    return MealNutrimentsEntity(
      energyKcal100: NutrientAmount.fromSource(
        offNutriments.energy_kcal_100g,
        modifier: offNutriments.modifiers['energy-kcal'],
      )?.scale(1),
      carbohydrates100: NutrientAmount.fromSource(
        offNutriments.carbohydrates_100g,
        modifier: offNutriments.modifiers['carbohydrates'],
      )?.scale(1),
      fat100: NutrientAmount.fromSource(
        offNutriments.fat_100g,
        modifier: offNutriments.modifiers['fat'],
      )?.scale(1),
      proteins100: NutrientAmount.fromSource(
        offNutriments.proteins_100g,
        modifier: offNutriments.modifiers['proteins'],
      )?.scale(1),
      sugars100: NutrientAmount.fromSource(
        offNutriments.sugars_100g,
        modifier: offNutriments.modifiers['sugars'],
      )?.scale(1),
      saturatedFat100: NutrientAmount.fromSource(
        offNutriments.saturated_fat_100g,
        modifier: offNutriments.modifiers['saturated-fat'],
      )?.scale(1),
      fiber100: NutrientAmount.fromSource(
        offNutriments.fiber_100g,
        modifier: offNutriments.modifiers['fiber'],
      )?.scale(1),
      monounsaturatedFat100: NutrientAmount.fromSource(
        offNutriments.monounsaturated_fat_100g,
        modifier: offNutriments.modifiers['monounsaturated-fat'],
      )?.scale(1),
      polyunsaturatedFat100: NutrientAmount.fromSource(
        offNutriments.polyunsaturated_fat_100g,
        modifier: offNutriments.modifiers['polyunsaturated-fat'],
      )?.scale(1),
      transFat100: NutrientAmount.fromSource(
        offNutriments.trans_fat_100g,
        modifier: offNutriments.modifiers['trans-fat'],
      )?.scale(1),
      cholesterol100: NutrientAmount.fromSource(
        offNutriments.cholesterol_100g,
        modifier: offNutriments.modifiers['cholesterol'],
      )?.scale(1000),
      sodium100: NutrientAmount.fromSource(
        offNutriments.sodium_100g,
        modifier: offNutriments.modifiers['sodium'],
      )?.scale(1000),
      potassium100: NutrientAmount.fromSource(
        offNutriments.potassium_100g,
        modifier: offNutriments.modifiers['potassium'],
      )?.scale(1000),
      magnesium100: NutrientAmount.fromSource(
        offNutriments.magnesium_100g,
        modifier: offNutriments.modifiers['magnesium'],
      )?.scale(1000),
      calcium100: NutrientAmount.fromSource(
        offNutriments.calcium_100g,
        modifier: offNutriments.modifiers['calcium'],
      )?.scale(1000),
      iron100: NutrientAmount.fromSource(
        offNutriments.iron_100g,
        modifier: offNutriments.modifiers['iron'],
      )?.scale(1000),
      zinc100: NutrientAmount.fromSource(
        offNutriments.zinc_100g,
        modifier: offNutriments.modifiers['zinc'],
      )?.scale(1000),
      phosphorus100: NutrientAmount.fromSource(
        offNutriments.phosphorus_100g,
        modifier: offNutriments.modifiers['phosphorus'],
      )?.scale(1000),
      vitaminA100: NutrientAmount.fromSource(
        offNutriments.vitamin_a_100g,
        modifier: offNutriments.modifiers['vitamin-a'],
      )?.scale(1000000),
      vitaminC100: NutrientAmount.fromSource(
        offNutriments.vitamin_c_100g,
        modifier: offNutriments.modifiers['vitamin-c'],
      )?.scale(1000),
      vitaminD100: NutrientAmount.fromSource(
        offNutriments.vitamin_d_100g,
        modifier: offNutriments.modifiers['vitamin-d'],
      )?.scale(1000000),
      vitaminB6100: NutrientAmount.fromSource(
        offNutriments.vitamin_b6_100g,
        modifier: offNutriments.modifiers['vitamin-b6'],
      )?.scale(1000),
      vitaminB12100: NutrientAmount.fromSource(
        offNutriments.vitamin_b12_100g,
        modifier: offNutriments.modifiers['vitamin-b12'],
      )?.scale(1000000),
      niacin100: NutrientAmount.fromSource(
        offNutriments.niacin_100g,
        modifier: offNutriments.modifiers['vitamin-pp'],
      )?.scale(1000),
    );
  }

  /// The catalogue build has already selected nutrients and converted units.
  factory MealNutrimentsEntity.fromCatalogue(Map<String, dynamic> values) {
    NutrientAmount? amount(String key) =>
        NutrientAmount.fromSource(values[key]);

    return MealNutrimentsEntity(
      energyKcal100: amount('energyKcal100'),
      carbohydrates100: amount('carbohydrates100'),
      fat100: amount('fat100'),
      proteins100: amount('proteins100'),
      sugars100: amount('sugars100'),
      saturatedFat100: amount('saturatedFat100'),
      fiber100: amount('fiber100'),
      monounsaturatedFat100: amount('monounsaturatedFat100'),
      polyunsaturatedFat100: amount('polyunsaturatedFat100'),
      transFat100: amount('transFat100'),
      cholesterol100: amount('cholesterol100'),
      sodium100: amount('sodium100'),
      potassium100: amount('potassium100'),
      magnesium100: amount('magnesium100'),
      calcium100: amount('calcium100'),
      iron100: amount('iron100'),
      zinc100: amount('zinc100'),
      phosphorus100: amount('phosphorus100'),
      vitaminA100: amount('vitaminA100'),
      vitaminC100: amount('vitaminC100'),
      vitaminD100: amount('vitaminD100'),
      vitaminB6100: amount('vitaminB6100'),
      vitaminB12100: amount('vitaminB12100'),
      niacin100: amount('niacin100'),
    );
  }

  static NutrientAmount? _getValuePerUnit(NutrientAmount? valuePer100) {
    if (valuePer100 != null) {
      return valuePer100.scale(0.01);
    } else {
      return null;
    }
  }

  bool get hasQualifications =>
      amounts.values.any((a) => a?.isQualified ?? false);

  Map<String, NutrientAmount?> get amounts => {
    'energyKcal100': energyKcal100,
    'carbohydrates100': carbohydrates100,
    'fat100': fat100,
    'proteins100': proteins100,
    'sugars100': sugars100,
    'saturatedFat100': saturatedFat100,
    'fiber100': fiber100,
    'monounsaturatedFat100': monounsaturatedFat100,
    'polyunsaturatedFat100': polyunsaturatedFat100,
    'transFat100': transFat100,
    'cholesterol100': cholesterol100,
    'sodium100': sodium100,
    'potassium100': potassium100,
    'magnesium100': magnesium100,
    'calcium100': calcium100,
    'iron100': iron100,
    'zinc100': zinc100,
    'phosphorus100': phosphorus100,
    'vitaminA100': vitaminA100,
    'vitaminC100': vitaminC100,
    'vitaminD100': vitaminD100,
    'vitaminB6100': vitaminB6100,
    'vitaminB12100': vitaminB12100,
    'niacin100': niacin100,
  };

  @override
  List<Object?> get props => [
    energyKcal100,
    carbohydrates100,
    fat100,
    proteins100,
    sugars100,
    saturatedFat100,
    fiber100,
    monounsaturatedFat100,
    polyunsaturatedFat100,
    transFat100,
    cholesterol100,
    sodium100,
    potassium100,
    magnesium100,
    calcium100,
    iron100,
    zinc100,
    phosphorus100,
    vitaminA100,
    vitaminC100,
    vitaminD100,
    vitaminB6100,
    vitaminB12100,
    niacin100,
  ];
}

class NutrimentsValidationResult {
  final bool isConsistent;
  final String? failureReason;

  const NutrimentsValidationResult.ok()
    : isConsistent = true,
      failureReason = null;

  const NutrimentsValidationResult.failed(this.failureReason)
    : isConsistent = false;
}

/// Tolerance applied to weight-summation and subset-of comparisons. Source
/// data is typically rounded to 0.1g or 1g, and the per-nutrient values do
/// not always sum exactly; a small slack keeps us from dropping items that
/// are merely noisy rather than corrupt.
const double _nutrimentsValidationToleranceG = 1.0;

/// Returns true when [nutriments] passes the three physical-plausibility
/// rules from issue #222:
///
///   1. `sugars100 <= carbohydrates100` (sugars are a subset of carbs)
///   2. `saturatedFat100 <= fat100` (sat fat is a subset of total fat)
///   3. `carbohydrates100 + fat100 + proteins100 <= 100g` (per-100g basis)
///
/// A null on either side of a comparison skips the rule (we cannot prove a
/// violation without both values). A small tolerance absorbs rounding from
/// the source.
///
/// Convenience wrapper around [validateNutriments] for callers that only
/// need the pass/fail bit.
bool isNutrimentsConsistent(MealNutrimentsEntity nutriments) =>
    validateNutriments(nutriments).isConsistent;

/// Full validation result. Use this when you need the failing rule name —
/// for example, to log a Sentry breadcrumb at the call site that dropped the
/// item from search results.
NutrimentsValidationResult validateNutriments(MealNutrimentsEntity nutriments) {
  final sugars = nutriments.sugars100?.isQualified == false
      ? nutriments.sugars100!.value
      : null;
  final carbs = nutriments.carbohydrates100?.isQualified == false
      ? nutriments.carbohydrates100!.value
      : null;
  if (sugars != null &&
      carbs != null &&
      sugars > carbs + _nutrimentsValidationToleranceG) {
    return const NutrimentsValidationResult.failed('sugars_exceed_carbs');
  }

  final satFat = nutriments.saturatedFat100?.isQualified == false
      ? nutriments.saturatedFat100!.value
      : null;
  final fat = nutriments.fat100?.isQualified == false
      ? nutriments.fat100!.value
      : null;
  if (satFat != null &&
      fat != null &&
      satFat > fat + _nutrimentsValidationToleranceG) {
    return const NutrimentsValidationResult.failed(
      'saturated_fat_exceeds_total_fat',
    );
  }

  // Per-100g basis: the weight-bearing macros (carbs + fat + protein) cannot
  // sum to more than 100g. Fibre is intentionally excluded because it is
  // typically already inside the carbohydrate total in both FDC and OFF
  // accounting, so adding it would double-count. Micronutrients are in
  // mg/µg so they do not enter the sum.
  final protein = nutriments.proteins100?.isQualified == false
      ? nutriments.proteins100!.value
      : null;
  final macroSum = (carbs ?? 0) + (fat ?? 0) + (protein ?? 0);
  if (macroSum > 100 + _nutrimentsValidationToleranceG) {
    return const NutrimentsValidationResult.failed('macros_exceed_100g');
  }

  return const NutrimentsValidationResult.ok();
}

/// Maximum relative gap between declared and Atwater-computed energy before a
/// product is treated as data-incoherent for ranking. Deliberately generous:
/// across a sample of ~700 Open Food Facts products the legitimate noise floor
/// (energy/macro rounding, food-specific Atwater factors, the EU/US fibre-in-
/// carbs convention) reaches ~10-15%, while genuine data errors are gross
/// (77% to >20000%). 25% sits in the empty gap between the two, so it demotes
/// real errors without penalising correctly-entered data.
const double atwaterEnergyTolerance = 0.25;

/// Relative difference between the declared energy and the energy implied by
/// the macros via the general Atwater factors (carbs 4, protein 4, fat 9
/// kcal/g). Fibre is not added separately for the same reason the macro-sum
/// check omits it — it is already inside the carbohydrate total here.
///
/// Returns null when there is nothing to judge (no declared kcal, or none of
/// the three macros present); callers should treat null as "no opinion" rather
/// than as inconsistent, so products with sparse data are ranked on the other
/// signals instead of being penalised.
double? atwaterEnergyRelativeError(MealNutrimentsEntity nutriments) {
  final energy = nutriments.energyKcal100?.isQualified == false
      ? nutriments.energyKcal100!.value
      : null;
  if (energy == null || energy <= 0) return null;
  final carbs = nutriments.carbohydrates100?.isQualified == false
      ? nutriments.carbohydrates100!.value
      : null;
  final fat = nutriments.fat100?.isQualified == false
      ? nutriments.fat100!.value
      : null;
  final protein = nutriments.proteins100?.isQualified == false
      ? nutriments.proteins100!.value
      : null;
  if (carbs == null || fat == null || protein == null) return null;

  final computed = 4 * carbs + 4 * protein + 9 * fat;
  return (energy - computed).abs() / energy;
}

/// True when a product's declared energy is coherent with its macros (within
/// [atwaterEnergyTolerance]) or cannot be judged. False only for products that
/// are computable AND diverge beyond the tolerance — the gross-error outliers.
bool isAtwaterConsistent(MealNutrimentsEntity nutriments) {
  final error = atwaterEnergyRelativeError(nutriments);
  return error == null || error <= atwaterEnergyTolerance;
}
