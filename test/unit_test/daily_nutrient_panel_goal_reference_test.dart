import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/utils/calc/daily_nutrient_references.dart';

void main() {
  test(
    'total sugars and unmatched bases do not receive a default reference',
    () {
      final references = DailyNutrientReferences.resolve();
      for (final key in [
        NutrientKeys.sugar,
        NutrientKeys.niacin,
        NutrientKeys.omega3,
        NutrientKeys.omega6,
        NutrientKeys.vitaminK1,
        NutrientKeys.alcohol,
        NutrientKeys.caffeine,
      ]) {
        expect(references.containsKey(key), isFalse, reason: key);
      }
      expect(
        references[NutrientKeys.addedSugars],
        const NutrientGoal(50, isLimit: true),
      );
      expect(references[NutrientKeys.folateDfe], const NutrientGoal(400));
      expect(references[NutrientKeys.vitaminE], const NutrientGoal(15));
    },
  );
  test(
    'personal amount and kind override a default or supply an absent reference',
    () {
      for (final nutrient in Nutrients.additional) {
        final overrides = {
          nutrient.key: const NutrientGoal(12.345, isLimit: true),
        };
        final day = TrackedDayEntity(
          day: DateTime(2026),
          calorieGoal: 2000,
          caloriesTracked: 0,
          nutrientGoals: overrides,
        );
        final references = DailyNutrientReferences.resolve(trackedDay: day);
        expect(references[nutrient.key], overrides[nutrient.key]);
      }
    },
  );
  test('cleared overrides return to the same default resolver', () {
    final day = TrackedDayEntity(
      day: DateTime(2026),
      calorieGoal: 2000,
      caloriesTracked: 0,
    );
    expect(
      DailyNutrientReferences.resolve(trackedDay: day),
      DailyNutrientReferences.resolve(),
    );
  });
}
