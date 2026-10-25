import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';

class ConfigEntity extends Equatable {
  // #150: keys for the per-meal kcal share map. Kept as plain strings rather
  // than tied to IntakeTypeEntity so the persisted value stays stable across
  // any future enum renames.
  static const mealKeyBreakfast = 'breakfast';
  static const mealKeyLunch = 'lunch';
  static const mealKeyDinner = 'dinner';
  static const mealKeySnack = 'snack';

  /// Default share across breakfast / lunch / dinner / snack used when the
  /// user has never tuned the values themselves. Sums to 100; sensible
  /// without claiming to be medically prescriptive.
  static const Map<String, int> defaultMealKcalSharesPct = {
    mealKeyBreakfast: 30,
    mealKeyLunch: 40,
    mealKeyDinner: 20,
    mealKeySnack: 10,
  };

  final AppThemeEntity appTheme;
  // Legacy single switch, kept as the fallback the three split preferences
  // derive from when the user has never touched them (see [fromConfigDBO]).
  final bool usesImperialUnits;
  // Three independent unit preferences. Food covers serving (g/oz) and volume
  // (ml/fl oz); height covers cm/ft; body weight is a three-way kg/lb/st.
  final bool usesImperialFoodUnits;
  final bool usesImperialHeightUnits;
  final BodyWeightUnit bodyWeightUnit;
  final double? userKcalAdjustment;
  final double? userCarbGoalPct;
  final double? userProteinGoalPct;
  final double? userFatGoalPct;
  final bool showActivityTracking;
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;
  final bool usesKilojoules; // #177
  final Map<String, int> mealKcalSharesPct; // #150
  final Map<String, int>? diarySortPreferences;
  final bool overviewMacrosAsPercent;
  final bool overviewNutrientsAsPercent;
  // #160 follow-up: per-nutrient show/hide overrides for the daily panel.
  // Keys are nutrient identifiers (see `DailyNutrientPanel.nutrientKeys`),
  // values are explicit user overrides. A nutrient not present in this map
  // falls back to the default, which is currently "visible" for every
  // nutrient — see [isNutrientVisible].
  final Map<String, bool> nutrientPanelVisibility;
  final int dayStartOffsetHours; // #139: 0-23, default 0 (wall-clock midnight)
  final int
  dayStartOffsetMinutes; // #139 follow-up: 0-59, composes additively with hours
  // #32: nullable so "I haven't picked yet" can fall back to a
  // sex-based default at read time. Once the user has touched the
  // setting, their override is persisted and survives a profile edit.
  final int? dailyWaterGoalMl;
  // #415: whether to harmonise the app palette with the user's system
  // wallpaper colours. Effective only on Android 12+ — every other
  // platform falls back to the static palette regardless of this value.
  final bool useMaterialYou;
  // #415 follow-up: custom accent colour packed as 32-bit ARGB. Overrides
  // Material You when set. Null means "use the platform default" — Material
  // You on Android 12+, the static palette elsewhere.
  final int? accentColor;
  // #165: explicit user override for the scanner's portrait lock. Null means
  // "follow the device" — the scanner falls back to locking portrait on
  // phone-sized screens and leaving rotation free on tablets. Once the user
  // taps the in-scanner toggle, their choice is stored here and sticks.
  final bool? scannerPortraitLock;

  /// Whether workouts are imported from Health Connect / Apple Health.
  /// Off until the user opts in, so no health data is read by default.
  final bool healthImportEnabled;

  /// Share of an imported workout's device-reported energy that counts
  /// toward the daily goal, as a fraction in [minHealthWorkoutKcalMultiplier]
  /// .. [maxHealthWorkoutKcalMultiplier]. Null means no override is stored;
  /// read it through
  /// [effectiveHealthWorkoutKcalMultiplier], never directly.
  final double? healthWorkoutKcalMultiplier;

  /// End of the window covered by the last successful import, or null if
  /// nothing has been imported yet (which backfills
  /// [healthImportBackfillDays] on the first run).
  final DateTime? healthLastImportAt;

  /// External record ids of imported workouts the user deleted, mapped to the
  /// workout's own start time. The importer skips them, so a deletion sticks
  /// instead of being undone by the next overlapping read. Empty when nothing
  /// has been deleted.
  ///
  /// The date is what bounds the list (#768): see
  /// [oldestUsefulTombstone] for the instant before which a tombstone can
  /// never match again.
  final Map<String, DateTime> healthDeletedWorkouts;

  /// Undated tombstones from before #768, which only a pre-release install can
  /// have. Kept separate rather than given an invented date, so that mapping a
  /// stored config into an entity stays a pure function of that config.
  ///
  /// They are folded into the dated map — and cleared — by the next write
  /// through `ConfigDataSource`. Until then they still have to be *visible*,
  /// which is what [healthDeletedExternalIds] is for: a read path that ignored
  /// them would re-import every workout the user had already deleted.
  final Set<String> legacyHealthDeletedExternalIds;

  /// Every id the importer must skip, dated or not. All its dedupe set needs.
  Set<String> get healthDeletedExternalIds => {
    ...healthDeletedWorkouts.keys,
    ...legacyHealthDeletedExternalIds,
  };

  /// The earliest instant any future import could ask the platform about, and
  /// therefore the point before which a tombstone is dead weight rather than
  /// protection.
  ///
  /// Two windows have to be survivable, so this is the earlier of them:
  ///
  ///  * the window the *next* run will use — [healthLastImportAt] pushed back
  ///    by the importer's overlap tolerance;
  ///  * a full backfill, which is what a run with no watermark asks for.
  ///
  /// The watermark only ever moves forward, so the first of those advances and
  /// the list drains. The second is the floor: if a watermark were ever lost
  /// without the tombstones going with it, the next run would reach back
  /// [healthImportBackfillDays] and needs its tombstones intact. Taking the
  /// earlier of the two costs a few stale entries and cannot prune one that is
  /// still doing work.
  static DateTime oldestUsefulTombstone({
    required DateTime now,
    required DateTime? lastImportAt,
    required Duration overlapTolerance,
  }) {
    final backfillFloor = now
        .subtract(const Duration(days: healthImportBackfillDays))
        .subtract(overlapTolerance);
    if (lastImportAt == null) return backfillFloor;
    final nextWindowStart = lastImportAt.subtract(overlapTolerance);
    return nextWindowStart.isBefore(backfillFloor)
        ? nextWindowStart
        : backfillFloor;
  }

  final bool amountArithmeticEnabled;

  final Map<String, bool> catalogueSourceOverrides;

  /// Population-average starting credit, rounded from the 27.7% mean
  /// compensation reported by Careau et al. (2021). This is a fixed default,
  /// independent of body measurements; each profile can override it.
  static const double defaultHealthWorkoutKcalMultiplier = 0.72;

  /// Bounds on the calorie-credit multiplier. The floor sits at 50% because
  /// even the most compensating decile in Careau et al. 2021 keeps roughly
  /// half of the exercise deficit; the ceiling credits every reported calorie.
  static const double minHealthWorkoutKcalMultiplier = 0.5;
  static const double maxHealthWorkoutKcalMultiplier = 1.0;

  /// How far back the very first import reaches when there is no watermark.
  static const int healthImportBackfillDays = 30;

  /// Default daily water goal in millilitres for the home chip when the
  /// user has not picked one yet.
  ///
  /// The popular "8 × 8 oz = 2 L of plain water" target has no
  /// scientific basis — Valtin (2002, AJP-Reg) traced it to a misreading
  /// of a 1945 US Food and Nutrition Board note that explicitly said
  /// "most of this quantity is contained in prepared foods". No major
  /// guideline body recommends a single "2 L of plain water" figure
  /// today.
  ///
  /// Picking 1500 ml lands inside the NHS Eatwell Guide's "6 to 8 cups
  /// or glasses of fluid a day" (≈ 1.2–1.5 L of drinks of any kind)
  /// and is consistent with the EFSA 2010 Adequate Intake of 2.0 L/day
  /// total water for women / 2.5 L/day for men once the ~20% EFSA
  /// attributes to food moisture is subtracted. The user can adjust it
  /// from 100 to 10000 ml in Settings → Calculations whenever a
  /// different target fits their own activity level, climate, or
  /// clinical advice.
  ///
  /// Sources:
  ///   * NHS, "Water, drinks and your health" —
  ///     https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/
  ///   * EFSA NDA Panel, "Scientific Opinion on Dietary Reference
  ///     Values for water", EFSA Journal 2010;8(3):1459.
  ///   * Valtin H., "Drink at least eight glasses of water a day.
  ///     Really?", AJP-Reg 2002;283(5):R993–R1004.
  static const int defaultDailyWaterGoalMl = 1500;

  /// Sex-specific drinking-water seeds, derived from EFSA 2010 total-water
  /// AI minus the food-moisture share.
  static const int waterGoalFemaleMl = 1500;
  static const int waterGoalMaleMl = 1900;

  const ConfigEntity(
    this.appTheme, {
    this.usesImperialUnits = false,
    this.usesImperialFoodUnits = false,
    this.usesImperialHeightUnits = false,
    this.bodyWeightUnit = BodyWeightUnit.kg,
    this.userKcalAdjustment,
    this.userCarbGoalPct,
    this.userProteinGoalPct,
    this.userFatGoalPct,
    this.showActivityTracking = true,
    this.notificationsEnabled = false,
    this.notificationHour = 8,
    this.notificationMinute = 0,
    this.usesKilojoules = false,
    this.mealKcalSharesPct = defaultMealKcalSharesPct,
    this.diarySortPreferences,
    this.overviewMacrosAsPercent = false,
    this.overviewNutrientsAsPercent = false,
    this.nutrientPanelVisibility = const <String, bool>{},
    this.dayStartOffsetHours = 0,
    this.dayStartOffsetMinutes = 0,
    this.dailyWaterGoalMl,
    this.useMaterialYou = true,
    this.accentColor,
    this.scannerPortraitLock,
    this.healthImportEnabled = false,
    this.healthWorkoutKcalMultiplier,
    this.healthLastImportAt,
    this.healthDeletedWorkouts = const <String, DateTime>{},
    this.legacyHealthDeletedExternalIds = const <String>{},
    this.amountArithmeticEnabled = false,
    this.catalogueSourceOverrides = const {},
  });

  /// The multiplier the importer applies, using the fixed default when
  /// this profile has no override.
  double get effectiveHealthWorkoutKcalMultiplier =>
      healthWorkoutKcalMultiplier ?? defaultHealthWorkoutKcalMultiplier;

  /// Returns the stored override, or the sex-specific seed.
  int effectiveDailyWaterGoalMl(UserSexEntity sex) =>
      dailyWaterGoalMl ?? seedWaterGoalForSex(sex);

  /// Seed used when no override is stored.
  static int seedWaterGoalForSex(UserSexEntity sex) => switch (sex) {
    UserSexEntity.male => waterGoalMaleMl,
    UserSexEntity.female => waterGoalFemaleMl,
  };

  /// Whether a particular nutrient on the daily panel should be rendered.
  /// All nutrients default to visible; the user can hide individual ones
  /// from Settings → Nutrients.
  bool isNutrientVisible(String key) => nutrientPanelVisibility[key] ?? true;

  /// The combined day-start offset in minutes — what callers actually need
  /// when comparing two `DateTime`s under the configured boundary. Hours and
  /// minutes compose additively, so 4 h + 30 m and 0 h + 270 m both resolve
  /// to the same 270-minute shift.
  int get dayStartOffsetTotalMinutes =>
      dayStartOffsetHours * 60 + dayStartOffsetMinutes;

  factory ConfigEntity.fromConfigDBO(ConfigDBO dbo) => ConfigEntity(
    AppThemeEntity.fromAppThemeDBO(dbo.selectedAppTheme),
    usesImperialUnits: dbo.usesImperialUnits ?? false,
    usesImperialFoodUnits:
        dbo.usesImperialFoodUnits ?? (dbo.usesImperialUnits ?? false),
    usesImperialHeightUnits:
        dbo.usesImperialHeightUnits ?? (dbo.usesImperialUnits ?? false),
    bodyWeightUnit: dbo.bodyWeightUnitIndex != null
        ? BodyWeightUnit.fromIndex(dbo.bodyWeightUnitIndex!)
        : ((dbo.usesImperialUnits ?? false)
              ? BodyWeightUnit.lb
              : BodyWeightUnit.kg),
    userKcalAdjustment: dbo.userKcalAdjustment,
    userCarbGoalPct: dbo.userCarbGoalPct,
    userProteinGoalPct: dbo.userProteinGoalPct,
    userFatGoalPct: dbo.userFatGoalPct,
    showActivityTracking: dbo.showActivityTracking ?? true,
    notificationsEnabled: dbo.notificationsEnabled ?? false,
    notificationHour: dbo.notificationHour ?? 8,
    notificationMinute: dbo.notificationMinute ?? 0,
    usesKilojoules: dbo.usesKilojoules ?? false,
    mealKcalSharesPct:
        _sanitiseShares(dbo.mealKcalSharesPct) ?? defaultMealKcalSharesPct,
    diarySortPreferences: dbo.diarySortPreferences,
    overviewMacrosAsPercent: dbo.overviewMacrosAsPercent ?? false,
    overviewNutrientsAsPercent: dbo.overviewNutrientsAsPercent ?? false,
    nutrientPanelVisibility:
        dbo.nutrientPanelVisibility ?? const <String, bool>{},
    dayStartOffsetHours: _normaliseOffsetHours(dbo.dayStartOffsetHours),
    dayStartOffsetMinutes: _normaliseOffsetMinutes(dbo.dayStartOffsetMinutes),
    dailyWaterGoalMl: _normaliseWaterGoal(dbo.dailyWaterGoalMl),
    useMaterialYou: dbo.useMaterialYou ?? true,
    accentColor: _normaliseAccentColor(dbo.accentColor),
    scannerPortraitLock: dbo.scannerPortraitLock,
    healthImportEnabled: dbo.healthImportEnabled ?? false,
    healthWorkoutKcalMultiplier: _normaliseHealthMultiplier(
      dbo.healthWorkoutKcalMultiplier,
    ),
    healthLastImportAt: dbo.healthLastImportAt,
    healthDeletedWorkouts: dbo.healthDeletedWorkouts != null
        ? Map<String, DateTime>.from(dbo.healthDeletedWorkouts!)
        : const <String, DateTime>{},
    legacyHealthDeletedExternalIds: dbo.healthDeletedExternalIds != null
        ? Set<String>.from(dbo.healthDeletedExternalIds!)
        : const <String>{},
    amountArithmeticEnabled: dbo.amountArithmeticEnabled ?? false,
    catalogueSourceOverrides: Map.unmodifiable(
      dbo.catalogueSourceOverrides ?? const <String, bool>{},
    ),
  );

  /// Returns the recommended kcal target for [mealKey] given a daily goal.
  double targetKcalForMeal(String mealKey, double dailyKcalGoal) {
    final pct = mealKcalSharesPct[mealKey] ?? 0;
    return (dailyKcalGoal * pct) / 100;
  }

  /// Drops any keys outside the known set and only returns a map if all four
  /// expected meals are present. Defensive in case the stored map was written
  /// by an older or partially-broken build.
  static Map<String, int>? _sanitiseShares(Map<String, int>? raw) {
    if (raw == null) return null;
    final keys = [mealKeyBreakfast, mealKeyLunch, mealKeyDinner, mealKeySnack];
    if (!keys.every(raw.containsKey)) return null;
    return {for (final k in keys) k: raw[k] ?? 0};
  }

  static int _normaliseOffsetHours(int? raw) {
    if (raw == null) return 0;
    if (raw < 0 || raw > 23) return 0;
    return raw;
  }

  // Defensive clamp so a corrupt or hand-edited Hive value can't push the
  // total offset past the next wall-clock day. 0-59 is the supported range.
  static int _normaliseOffsetMinutes(int? raw) {
    if (raw == null) return 0;
    if (raw < 0) return 0;
    if (raw > 59) return 59;
    return raw;
  }

  // Defensive clamp on the persisted water goal. null means "no
  // override stored" — caller falls back to the sex-based seed in
  // [seedWaterGoalForSex]. A non-null value outside 100–10000 ml is
  // treated as corrupt and dropped to null so the seed kicks in.
  static int? _normaliseWaterGoal(int? raw) {
    if (raw == null) return null;
    if (raw < 100 || raw > 10000) return null;
    return raw;
  }

  // Defensive clamp on the persisted calorie-credit multiplier. Null means
  // "no override stored" — [effectiveHealthWorkoutKcalMultiplier] then
  // uses the fixed default. A stored value outside the supported
  // range is treated as corrupt and dropped to null rather than silently
  // scaling every future import by a nonsense factor.
  static double? _normaliseHealthMultiplier(double? raw) {
    if (raw == null) return null;
    if (raw < minHealthWorkoutKcalMultiplier ||
        raw > maxHealthWorkoutKcalMultiplier) {
      return null;
    }
    return raw;
  }

  // Defensive clamp on the persisted accent colour. Null means "no custom
  // colour stored" — the platform default kicks in. Anything else is
  // accepted as a 32-bit ARGB int (negative values come from packing the
  // top byte's alpha=0xFF, so don't try to reject them on range).
  static int? _normaliseAccentColor(int? raw) {
    return raw;
  }

  @override
  List<Object?> get props => [
    usesImperialUnits,
    usesImperialFoodUnits,
    usesImperialHeightUnits,
    bodyWeightUnit,
    userKcalAdjustment,
    userCarbGoalPct,
    userProteinGoalPct,
    userFatGoalPct,
    showActivityTracking,
    notificationsEnabled,
    notificationHour,
    notificationMinute,
    usesKilojoules,
    mealKcalSharesPct,
    diarySortPreferences,
    overviewMacrosAsPercent,
    overviewNutrientsAsPercent,
    nutrientPanelVisibility,
    dayStartOffsetHours,
    dayStartOffsetMinutes,
    dailyWaterGoalMl,
    useMaterialYou,
    accentColor,
    scannerPortraitLock,
    healthImportEnabled,
    healthWorkoutKcalMultiplier,
    healthLastImportAt,
    healthDeletedWorkouts,
    legacyHealthDeletedExternalIds,
    amountArithmeticEnabled,
    catalogueSourceOverrides,
  ];
}
