import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';

class AddTrackedDayUsecase {
  final TrackedDayRepository _trackedDayRepository;

  AddTrackedDayUsecase(this._trackedDayRepository);

  Future<void> updateDayCalorieGoal(DateTime day, double calorieGoal) async {
    await _trackedDayRepository.updateDayCalorieGoal(day, calorieGoal);
  }

  Future<void> increaseDayCalorieGoal(DateTime day, double amount) async {
    await _trackedDayRepository.increaseDayCalorieGoal(day, amount);
  }

  Future<void> reduceDayCalorieGoal(DateTime day, double amount) async {
    await _trackedDayRepository.reduceDayCalorieGoal(day, amount);
  }

  Future<bool> hasTrackedDay(DateTime day) async {
    return await _trackedDayRepository.hasTrackedDay(day);
  }

  Future<void> addNewTrackedDay(
    DateTime day,
    double totalKcalGoal,
    double totalCarbsGoal,
    double totalFatGoal,
    double totalProteinGoal,
  ) async {
    return await _trackedDayRepository.addNewTrackedDay(
      day,
      totalKcalGoal,
      totalCarbsGoal,
      totalFatGoal,
      totalProteinGoal,
    );
  }

  Future<void> addDayCaloriesTracked(
    DateTime day,
    double caloriesTracked,
  ) async {
    await _trackedDayRepository.addDayTrackedCalories(day, caloriesTracked);
  }

  Future<void> removeDayCaloriesTracked(
    DateTime day,
    double caloriesTracked,
  ) async {
    await _trackedDayRepository.removeDayTrackedCalories(day, caloriesTracked);
  }

  Future<void> updateDayMacroGoals(
    DateTime day, {
    double? carbsGoal,
    double? fatGoal,
    double? proteinGoal,
  }) async {
    await _trackedDayRepository.updateDayMacroGoal(
      day,
      carbGoal: carbsGoal,
      fatGoal: fatGoal,
      proteinGoal: proteinGoal,
    );
  }

  Future<void> increaseDayMacroGoals(
    DateTime day, {
    double? carbsAmount,
    double? fatAmount,
    double? proteinAmount,
  }) async {
    await _trackedDayRepository.increaseDayMacroGoal(
      day,
      carbGoal: carbsAmount,
      fatGoal: fatAmount,
      proteinGoal: proteinAmount,
    );
  }

  Future<void> reduceDayMacroGoals(
    DateTime day, {
    double? carbsAmount,
    double? fatAmount,
    double? proteinAmount,
  }) async {
    await _trackedDayRepository.reduceDayMacroGoal(
      day,
      carbGoal: carbsAmount,
      fatGoal: fatAmount,
      proteinGoal: proteinAmount,
    );
  }

  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {
    await _trackedDayRepository.addDayMacrosTracked(
      day,
      carbsTracked: carbsTracked,
      fatTracked: fatTracked,
      proteinTracked: proteinTracked,
    );
  }

  Future<void> removeDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {
    await _trackedDayRepository.removeDayMacrosTracked(
      day,
      carbsTracked: carbsTracked,
      fatTracked: fatTracked,
      proteinTracked: proteinTracked,
    );
  }

  /// Replace today's personal nutrient goals. Omitted keys use their default reference.
  Future<void> updateDayNutrientGoals(
    DateTime day,
    Map<String, NutrientGoal> goals,
  ) async {
    await _trackedDayRepository.updateDayNutrientGoals(day, goals);
  }

  /// Overwrite cached tracked values with actual sums to fix stale data (#182)
  Future<void> reconcileDayTracked(
    DateTime day,
    double calories,
    double carbs,
    double fat,
    double protein,
  ) async {
    await _trackedDayRepository.reconcileDayTracked(
      day,
      calories,
      carbs,
      fat,
      protein,
    );
  }
}
