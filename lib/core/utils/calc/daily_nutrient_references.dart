import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/utils/calc/dri_reference.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';

class DailyNutrientReferences {
  DailyNutrientReferences._();
  // ---- Default daily references (#173) ----------------------------------
  // Published DRIs / FDA Daily Values used when the user hasn't set their
  // own target in Settings → Nutrient goals. Iron and magnesium default
  // to a sex-aware value; the rest are sex-neutral.
  static const double defaultFibreRefG = 30.0;
  static const double defaultSaturatedFatRefG = 20.0;
  static const double defaultSugarRefG = 50.0;
  static const double defaultSodiumRefMg = 2300.0;
  static const double defaultCalciumRefMg = 1000.0;
  static const double defaultPotassiumRefMg = 3500.0;
  static const double defaultVitaminDRefUg = 15.0;
  static const double defaultVitaminB12RefUg = 2.4;
  static const double defaultMagnesiumRefMg =
      355.0; // fallback when no user is available

  /// Pure helpers that prefer the user's [TrackedDayEntity] per-nutrient
  /// goal when set, falling back to the published default otherwise.
  /// Public because the unit test suite asserts each one in isolation.
  static double resolveFibreReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.fibreGoal ?? defaultFibreRefG;

  static double resolveSatFatReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.satFatGoal ?? defaultSaturatedFatRefG;

  static double resolveSugarsReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.sugarsGoal ?? defaultSugarRefG;

  static double resolveSodiumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.sodiumGoal ?? defaultSodiumRefMg;

  static double resolveCalciumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.calciumGoal ?? defaultCalciumRefMg;

  /// Iron uses a sex-aware default that the caller supplies, since the
  /// female / male DRIs (18 vs 8 mg) are far enough apart that a generic fallback
  /// number would mislead one group.
  static double resolveIronReference(
    TrackedDayEntity? trackedDay,
    double sexDefault,
  ) => trackedDay?.ironGoal ?? sexDefault;

  static double resolvePotassiumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.potassiumGoal ?? defaultPotassiumRefMg;

  static double resolveVitaminDReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.vitaminDGoal ?? defaultVitaminDRefUg;

  static double resolveVitaminB12Reference(TrackedDayEntity? trackedDay) =>
      trackedDay?.vitaminB12Goal ?? defaultVitaminB12RefUg;

  static double resolveMagnesiumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.magnesiumGoal ?? defaultMagnesiumRefMg;

  static Map<String, double> resolve({
    TrackedDayEntity? trackedDay,
    UserEntity? user,
  }) {
    final td = trackedDay;
    // Helper: prefer the per-day tracked override, then the IOM age-banded
    // DRI when a user record is available, then the sex-agnostic default
    // the panel has always used as a last resort. This keeps the existing
    // resolver helpers as the single source of truth for tests, but layers
    // the age-aware IOM lookup (#245) on top for users we know enough about.
    double resolveWithDri(
      double? Function() trackedOverride,
      String nutrientKey,
      double fallback,
    ) {
      final tracked = trackedOverride();
      if (tracked != null) return tracked;
      if (user != null) {
        final dri = getReferenceFor(nutrient: nutrientKey, user: user);
        if (dri != null) return dri.amount;
      }
      return fallback;
    }

    final fiberRefG = resolveWithDri(
      () => td?.fibreGoal,
      NutrientPanelKeys.fiber,
      defaultFibreRefG,
    );
    final sodiumRefMg = resolveWithDri(
      () => td?.sodiumGoal,
      NutrientPanelKeys.sodium,
      defaultSodiumRefMg,
    );
    // Saturated fat and sugars have no IOM RDA — the resolver helper still
    // returns the published FDA Daily Value as the fallback for both.
    final saturatedFatRefG = resolveSatFatReference(td);
    final sugarRefG = resolveSugarsReference(td);
    final calciumRefMg = resolveWithDri(
      () => td?.calciumGoal,
      NutrientPanelKeys.calcium,
      defaultCalciumRefMg,
    );
    final ironRefMg = resolveWithDri(
      () => td?.ironGoal,
      NutrientPanelKeys.iron,
      _ironRefForUser(user),
    );
    final potassiumRefMg = resolveWithDri(
      () => td?.potassiumGoal,
      NutrientPanelKeys.potassium,
      defaultPotassiumRefMg,
    );
    final vitaminDRefMcg = resolveWithDri(
      () => td?.vitaminDGoal,
      NutrientPanelKeys.vitaminD,
      defaultVitaminDRefUg,
    );
    final vitaminB12RefMcg = resolveWithDri(
      () => td?.vitaminB12Goal,
      NutrientPanelKeys.vitaminB12,
      defaultVitaminB12RefUg,
    );
    final magnesiumRefMg = resolveWithDri(
      () => td?.magnesiumGoal,
      NutrientPanelKeys.magnesium,
      _magnesiumRefForUser(user),
    );

    return {
      NutrientPanelKeys.fiber: fiberRefG,
      NutrientPanelKeys.sodium: sodiumRefMg,
      NutrientPanelKeys.saturatedFat: saturatedFatRefG,
      NutrientPanelKeys.sugar: sugarRefG,
      NutrientPanelKeys.calcium: calciumRefMg,
      NutrientPanelKeys.iron: ironRefMg,
      NutrientPanelKeys.potassium: potassiumRefMg,
      NutrientPanelKeys.vitaminD: vitaminDRefMcg,
      NutrientPanelKeys.vitaminB12: vitaminB12RefMcg,
      NutrientPanelKeys.magnesium: magnesiumRefMg,
    };
  }

  // Sex-specific defaults when a user is available.
  static double _ironRefForUser(UserEntity? user) {
    const female = 18.0;
    const male = 8.0;
    const fallback = 14.0;
    return _dispatchSexReference(
      user,
      female: female,
      male: male,
      fallback: fallback,
    );
  }

  static double _magnesiumRefForUser(UserEntity? user) {
    const female = 310.0;
    const male = 400.0;
    const fallback = 355.0;
    return _dispatchSexReference(
      user,
      female: female,
      male: male,
      fallback: fallback,
    );
  }

  static double _dispatchSexReference(
    UserEntity? user, {
    required double female,
    required double male,
    required double fallback,
  }) {
    if (user == null) return fallback;
    switch (user.sex) {
      case UserSexEntity.female:
        return female;
      case UserSexEntity.male:
        return male;
    }
  }
}
