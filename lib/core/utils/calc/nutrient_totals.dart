import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

/// One pass over intakes aggregates every supported nutrient without dropping
/// source qualifications or confusing missing measurements with zero.
class NutrientTotals {
  final Map<String, NutrientAmount?> amounts;
  const NutrientTotals(this.amounts);

  /// A day without logged food has known zero totals; absent values on foods
  /// remain unknown and must never use this as a replacement.
  static final zero = NutrientTotals(
    Map.unmodifiable({
      for (final n in Nutrients.all) n.field: const NutrientAmount(0),
    }),
  );

  NutrientAmount? get energyKcal => amounts['energyKcal100'];
  NutrientAmount? get carbsG => amounts['carbohydrates100'];
  NutrientAmount? get fatG => amounts['fat100'];
  NutrientAmount? get proteinG => amounts['proteins100'];

  factory NutrientTotals.fromIntakes(
    List<IntakeEntity> intakes, {
    bool weekly = false,
  }) {
    if (intakes.isEmpty) return zero;
    final accumulators = {
      for (final n in Nutrients.all) n.field: NutrientAccumulator(),
    };
    for (final intake in intakes) {
      final values = intake.meal.nutriments.amounts;
      for (final entry in accumulators.entries) {
        entry.value.add(values[entry.key], scale: intake.nutritionScale);
      }
    }
    return NutrientTotals(
      Map.unmodifiable({
        for (final entry in accumulators.entries)
          entry.key: entry.value.total?.scale(weekly ? 1 / 7 : 1),
      }),
    );
  }

  factory NutrientTotals.averageDays(Iterable<NutrientTotals> days) {
    final accumulators = {
      for (final n in Nutrients.all) n.field: NutrientAccumulator(),
    };
    var count = 0;
    for (final day in days) {
      count++;
      for (final entry in accumulators.entries) {
        entry.value.add(day.amounts[entry.key]);
      }
    }
    if (count == 0) return zero;
    return NutrientTotals(
      Map.unmodifiable({
        for (final entry in accumulators.entries)
          entry.key: entry.value.total?.scale(1 / count),
      }),
    );
  }
}

NutrientAmount? intakeNutrientTotal(
  Iterable<IntakeEntity> intakes,
  NutrientAmount? Function(MealNutrimentsEntity) pick,
) {
  final accumulator = NutrientAccumulator();
  var hasIntakes = false;
  for (final intake in intakes) {
    hasIntakes = true;
    accumulator.add(pick(intake.meal.nutriments), scale: intake.nutritionScale);
  }
  return hasIntakes ? accumulator.total : const NutrientAmount(0);
}
