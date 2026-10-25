import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/utils/calc/daily_nutrient_references.dart';

/// #173 (+follow-up): the daily micronutrient panel uses ten nutrient
/// references the user can override per day. The original commit
/// covered fibre, saturated fat, and sugars; the follow-up extends the
/// same pattern to sodium, calcium, iron, potassium, vitamin D,
/// vitamin B12, and magnesium. When the per-day `TrackedDayEntity`
/// carries a non-null override the panel must respect it; when null
/// (or when no entity is present at all) it has to fall back to the
/// default reference values the panel exposes as static constants.
/// The test exercises the resolver helpers the panel actually uses
/// rather than rendering the widget tree, which keeps it both quick
/// and immune to layout churn.
void main() {
  TrackedDayEntity trackedDay({
    double? fibreGoal,
    double? satFatGoal,
    double? sugarsGoal,
    double? sodiumGoal,
    double? calciumGoal,
    double? ironGoal,
    double? potassiumGoal,
    double? vitaminDGoal,
    double? vitaminB12Goal,
    double? magnesiumGoal,
  }) {
    return TrackedDayEntity(
      day: DateTime.utc(2026, 5, 13),
      calorieGoal: 2000,
      caloriesTracked: 0,
      fibreGoal: fibreGoal,
      satFatGoal: satFatGoal,
      sugarsGoal: sugarsGoal,
      sodiumGoal: sodiumGoal,
      calciumGoal: calciumGoal,
      ironGoal: ironGoal,
      potassiumGoal: potassiumGoal,
      vitaminDGoal: vitaminDGoal,
      vitaminB12Goal: vitaminB12Goal,
      magnesiumGoal: magnesiumGoal,
    );
  }

  group('DailyNutrientPanel goal resolution', () {
    test('falls back to default fibre reference when no tracked day', () {
      expect(
        DailyNutrientReferences.resolveFibreReference(null),
        DailyNutrientReferences.defaultFibreRefG,
      );
    });

    test('falls back to default fibre reference when goal is null', () {
      expect(
        DailyNutrientReferences.resolveFibreReference(trackedDay()),
        DailyNutrientReferences.defaultFibreRefG,
      );
    });

    test('uses user fibre goal when set on the tracked day', () {
      // A fibre target set higher than the default — common for people
      // following plant-forward diets where 30g is the floor, not the
      // ceiling.
      const userFibreGoal = 45.0;
      expect(
        DailyNutrientReferences.resolveFibreReference(
          trackedDay(fibreGoal: userFibreGoal),
        ),
        userFibreGoal,
      );
    });

    test('falls back to default saturated fat reference when null', () {
      expect(
        DailyNutrientReferences.resolveSatFatReference(null),
        DailyNutrientReferences.defaultSaturatedFatRefG,
      );
      expect(
        DailyNutrientReferences.resolveSatFatReference(trackedDay()),
        DailyNutrientReferences.defaultSaturatedFatRefG,
      );
    });

    test('uses user saturated fat goal when set on the tracked day', () {
      // A tighter cap — e.g. a clinician-suggested 13g for someone
      // managing cardiovascular risk.
      const userSatFatGoal = 13.0;
      expect(
        DailyNutrientReferences.resolveSatFatReference(
          trackedDay(satFatGoal: userSatFatGoal),
        ),
        userSatFatGoal,
      );
    });

    test('falls back to default sugars reference when null', () {
      expect(
        DailyNutrientReferences.resolveSugarsReference(null),
        DailyNutrientReferences.defaultSugarRefG,
      );
      expect(
        DailyNutrientReferences.resolveSugarsReference(trackedDay()),
        DailyNutrientReferences.defaultSugarRefG,
      );
    });

    test('uses user sugars goal when set on the tracked day', () {
      const userSugarsGoal = 25.0;
      expect(
        DailyNutrientReferences.resolveSugarsReference(
          trackedDay(sugarsGoal: userSugarsGoal),
        ),
        userSugarsGoal,
      );
    });

    test('resolves each nutrient independently', () {
      // Only fibre is overridden; sat fat and sugars must still fall
      // back to defaults rather than getting tangled together.
      final day = trackedDay(fibreGoal: 40);
      expect(DailyNutrientReferences.resolveFibreReference(day), 40);
      expect(
        DailyNutrientReferences.resolveSatFatReference(day),
        DailyNutrientReferences.defaultSaturatedFatRefG,
      );
      expect(
        DailyNutrientReferences.resolveSugarsReference(day),
        DailyNutrientReferences.defaultSugarRefG,
      );
    });
  });

  // Follow-up to #173: same expectations, applied to the remaining
  // seven nutrients. Each one falls back to its default when the goal
  // field is null and uses the override otherwise.
  group('DailyNutrientPanel goal resolution (follow-up nutrients)', () {
    test('falls back to default sodium reference when null', () {
      expect(
        DailyNutrientReferences.resolveSodiumReference(null),
        DailyNutrientReferences.defaultSodiumRefMg,
      );
      expect(
        DailyNutrientReferences.resolveSodiumReference(trackedDay()),
        DailyNutrientReferences.defaultSodiumRefMg,
      );
    });

    test('uses user sodium goal when set on the tracked day', () {
      // A tighter cap — e.g. 1500mg as recommended for adults managing
      // blood pressure.
      const userSodiumGoal = 1500.0;
      expect(
        DailyNutrientReferences.resolveSodiumReference(
          trackedDay(sodiumGoal: userSodiumGoal),
        ),
        userSodiumGoal,
      );
    });

    test('falls back to default calcium reference when null', () {
      expect(
        DailyNutrientReferences.resolveCalciumReference(null),
        DailyNutrientReferences.defaultCalciumRefMg,
      );
      expect(
        DailyNutrientReferences.resolveCalciumReference(trackedDay()),
        DailyNutrientReferences.defaultCalciumRefMg,
      );
    });

    test('uses user calcium goal when set on the tracked day', () {
      const userCalciumGoal = 1200.0;
      expect(
        DailyNutrientReferences.resolveCalciumReference(
          trackedDay(calciumGoal: userCalciumGoal),
        ),
        userCalciumGoal,
      );
    });

    test('falls back to sex-aware iron default when goal is null', () {
      // The caller supplies the sex-based default so the helper
      // stays pure — passing 18 here simulates the female fallback.
      expect(DailyNutrientReferences.resolveIronReference(null, 18.0), 18.0);
      expect(
        DailyNutrientReferences.resolveIronReference(trackedDay(), 8.0),
        8.0,
      );
    });

    test('uses user iron goal when set on the tracked day', () {
      // Iron supplementation for someone managing anaemia — a value
      // well above the standard DRI.
      const userIronGoal = 27.0;
      expect(
        DailyNutrientReferences.resolveIronReference(
          trackedDay(ironGoal: userIronGoal),
          // Sex default is passed through but ignored when the
          // goal is non-null.
          8.0,
        ),
        userIronGoal,
      );
    });

    test('falls back to default potassium reference when null', () {
      expect(
        DailyNutrientReferences.resolvePotassiumReference(null),
        DailyNutrientReferences.defaultPotassiumRefMg,
      );
      expect(
        DailyNutrientReferences.resolvePotassiumReference(trackedDay()),
        DailyNutrientReferences.defaultPotassiumRefMg,
      );
    });

    test('uses user potassium goal when set on the tracked day', () {
      const userPotassiumGoal = 4700.0;
      expect(
        DailyNutrientReferences.resolvePotassiumReference(
          trackedDay(potassiumGoal: userPotassiumGoal),
        ),
        userPotassiumGoal,
      );
    });

    test('falls back to default vitamin D reference when null', () {
      expect(
        DailyNutrientReferences.resolveVitaminDReference(null),
        DailyNutrientReferences.defaultVitaminDRefUg,
      );
      expect(
        DailyNutrientReferences.resolveVitaminDReference(trackedDay()),
        DailyNutrientReferences.defaultVitaminDRefUg,
      );
    });

    test('uses user vitamin D goal when set on the tracked day', () {
      // A higher target — e.g. 25µg as sometimes prescribed for
      // people with low baseline vitamin D status.
      const userVitaminDGoal = 25.0;
      expect(
        DailyNutrientReferences.resolveVitaminDReference(
          trackedDay(vitaminDGoal: userVitaminDGoal),
        ),
        userVitaminDGoal,
      );
    });

    test('falls back to default vitamin B12 reference when null', () {
      expect(
        DailyNutrientReferences.resolveVitaminB12Reference(null),
        DailyNutrientReferences.defaultVitaminB12RefUg,
      );
      expect(
        DailyNutrientReferences.resolveVitaminB12Reference(trackedDay()),
        DailyNutrientReferences.defaultVitaminB12RefUg,
      );
    });

    test('uses user vitamin B12 goal when set on the tracked day', () {
      const userVitaminB12Goal = 5.0;
      expect(
        DailyNutrientReferences.resolveVitaminB12Reference(
          trackedDay(vitaminB12Goal: userVitaminB12Goal),
        ),
        userVitaminB12Goal,
      );
    });

    test('falls back to default magnesium reference when null', () {
      expect(
        DailyNutrientReferences.resolveMagnesiumReference(null),
        DailyNutrientReferences.defaultMagnesiumRefMg,
      );
      expect(
        DailyNutrientReferences.resolveMagnesiumReference(trackedDay()),
        DailyNutrientReferences.defaultMagnesiumRefMg,
      );
    });

    test('uses user magnesium goal when set on the tracked day', () {
      const userMagnesiumGoal = 500.0;
      expect(
        DailyNutrientReferences.resolveMagnesiumReference(
          trackedDay(magnesiumGoal: userMagnesiumGoal),
        ),
        userMagnesiumGoal,
      );
    });
  });
}
