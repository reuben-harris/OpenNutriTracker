import 'package:opennutritracker/core/domain/entity/nutrient_view.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';

class AddConfigUsecase {
  final ConfigRepository _configRepository;

  AddConfigUsecase(this._configRepository);

  Future<void> setCatalogueSourceOverrides(Map<String, bool> overrides) =>
      _configRepository.setCatalogueSourceOverrides(overrides);

  Future<void> addConfig(ConfigEntity configEntity) async {
    await _configRepository.updateConfig(configEntity);
  }

  Future<void> setShowMissingNutrientsInInfo(bool value) =>
      _configRepository.setShowMissingNutrientsInInfo(value);

  Future<void> setOverviewMacrosAsPercent(bool value) =>
      _configRepository.setOverviewMacrosAsPercent(value);

  Future<void> setOverviewNutrientView(NutrientView value) =>
      _configRepository.setOverviewNutrientView(value);

  Future<void> setConfigAppTheme(AppThemeEntity appTheme) async {
    await _configRepository.setConfigAppTheme(appTheme);
  }

  Future<void> setConfigUsesImperialUnits(bool usesImperialUnits) async {
    await _configRepository.setConfigUsesImperialUnits(usesImperialUnits);
  }

  Future<void> setConfigUsesImperialFoodUnits(bool usesImperial) async {
    await _configRepository.setConfigUsesImperialFoodUnits(usesImperial);
  }

  Future<void> setConfigUsesImperialHeightUnits(bool usesImperial) async {
    await _configRepository.setConfigUsesImperialHeightUnits(usesImperial);
  }

  Future<void> setConfigBodyWeightUnit(BodyWeightUnit unit) async {
    await _configRepository.setConfigBodyWeightUnit(unit);
  }

  Future<void> setConfigKcalAdjustment(double kcalAdjustment) async {
    await _configRepository.setConfigKcalAdjustment(kcalAdjustment);
  }

  Future<void> setConfigMacroGoalPct(
    double carbGoalPct,
    double proteinGoalPct,
    double fatPctGoal,
  ) async {
    await _configRepository.setUserMacroPct(
      carbGoalPct,
      proteinGoalPct,
      fatPctGoal,
    );
  }

  Future<void> setConfigShowActivityTracking(bool show) async {
    await _configRepository.setConfigShowActivityTracking(show);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _configRepository.setNotificationsEnabled(enabled);
  }

  Future<void> setNotificationTime(int hour, int minute) async {
    await _configRepository.setNotificationTime(hour, minute);
  }

  Future<void> setConfigUsesKilojoules(bool usesKilojoules) async {
    await _configRepository.setConfigUsesKilojoules(usesKilojoules);
  }

  Future<void> setAmountArithmeticEnabled(bool value) async {
    await _configRepository.setAmountArithmeticEnabled(value);
  }

  Future<void> setConfigMealKcalSharesPct(Map<String, int> shares) async {
    await _configRepository.setConfigMealKcalSharesPct(shares);
  }

  Future<void> setDiarySortPreference(String mealKey, int sortIndex) async {
    await _configRepository.setDiarySortPreference(mealKey, sortIndex);
  }

  Future<void> setConfigDayStartOffsetHours(int hours) async {
    await _configRepository.setConfigDayStartOffsetHours(hours);
  }

  Future<void> setConfigDayStartOffsetMinutes(int minutes) async {
    await _configRepository.setConfigDayStartOffsetMinutes(minutes);
  }

  Future<void> setConfigDailyWaterGoalMl(int goalMl) async {
    await _configRepository.setConfigDailyWaterGoalMl(goalMl);
  }

  Future<void> setConfigUseMaterialYou(bool useMaterialYou) async {
    await _configRepository.setConfigUseMaterialYou(useMaterialYou);
  }

  Future<void> setConfigAccentColor(int? value) async {
    await _configRepository.setConfigAccentColor(value);
  }

  Future<void> setConfigHealthImportEnabled(bool enabled) async {
    await _configRepository.setConfigHealthImportEnabled(enabled);
  }

  Future<void> setConfigHealthWorkoutKcalMultiplier(double multiplier) async {
    await _configRepository.setConfigHealthWorkoutKcalMultiplier(multiplier);
  }

  Future<void> setNutrientVisibility(
    Iterable<String> keys,
    bool visible, {
    required bool info,
  }) => _configRepository.setNutrientVisibility(keys, visible, info: info);
}
