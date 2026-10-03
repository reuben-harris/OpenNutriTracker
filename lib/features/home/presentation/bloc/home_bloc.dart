import 'dart:async';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
part 'home_event.dart';

part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetConfigUsecase _getConfigUsecase;
  final GetIntakeUsecase _getIntakeUsecase;
  final GetUserActivityUsecase _getUserActivityUsecase;
  final GetKcalGoalUsecase _getKcalGoalUsecase;
  final GetMacroGoalUsecase _getMacroGoalUsecase;
  final GetUserUsecase _getUserUsecase;
  final GetWaterIntakeUsecase _getWaterIntakeUsecase;
  final GetTrackedDayUsecase _getTrackedDayUsecase;
  final GetWeightLogUsecase _getWeightLogUsecase;
  final SelectedDayCubit _selection;
  late final StreamSubscription<SelectedDayState> _selectionSubscription;
  int _loadVersion = 0;

  HomeBloc(
    this._getConfigUsecase,
    this._getIntakeUsecase,
    this._getUserActivityUsecase,
    this._getKcalGoalUsecase,
    this._getMacroGoalUsecase,
    this._getUserUsecase,
    this._getWaterIntakeUsecase,
    this._getTrackedDayUsecase,
    this._getWeightLogUsecase,
    this._selection,
  ) : super(HomeInitial()) {
    _selectionSubscription = _selection.stream.listen((_) {
      ++_loadVersion;
      add(const LoadItemsEvent());
    });
    on<LoadItemsEvent>((event, emit) async {
      final version = ++_loadVersion;
      if (!_selection.state.initialized) await _selection.initialize();
      final day = _selection.state.day;
      emit(HomeLoadingState());

      final configData = await _getConfigUsecase.getConfig();
      final dayStartOffsetHours = configData.dayStartOffsetHours;
      final dayStartOffsetMinutes = configData.dayStartOffsetMinutes;
      final usesImperialUnits = configData.usesImperialFoodUnits;
      final bodyWeightUnit = configData.bodyWeightUnit;
      final showDisclaimerDialog = !configData.hasAcceptedDisclaimer;
      final showMealMacros = configData.showMealMacros;
      final showActivityTracking = configData.showActivityTracking;

      final breakfastIntakeList = await _getIntakeUsecase
          .getBreakfastIntakeByDay(
            day,
            dayStartOffsetHours: dayStartOffsetHours,
            dayStartOffsetMinutes: dayStartOffsetMinutes,
          );
      final totalBreakfastKcal = getTotalKcal(breakfastIntakeList);
      final totalBreakfastCarbs = getTotalCarbs(breakfastIntakeList);
      final totalBreakfastFats = getTotalFats(breakfastIntakeList);
      final totalBreakfastProteins = getTotalProteins(breakfastIntakeList);

      final lunchIntakeList = await _getIntakeUsecase.getLunchIntakeByDay(
        day,
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalLunchKcal = getTotalKcal(lunchIntakeList);
      final totalLunchCarbs = getTotalCarbs(lunchIntakeList);
      final totalLunchFats = getTotalFats(lunchIntakeList);
      final totalLunchProteins = getTotalProteins(lunchIntakeList);

      final dinnerIntakeList = await _getIntakeUsecase.getDinnerIntakeByDay(
        day,
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalDinnerKcal = getTotalKcal(dinnerIntakeList);
      final totalDinnerCarbs = getTotalCarbs(dinnerIntakeList);
      final totalDinnerFats = getTotalFats(dinnerIntakeList);
      final totalDinnerProteins = getTotalProteins(dinnerIntakeList);

      final snackIntakeList = await _getIntakeUsecase.getSnackIntakeByDay(
        day,
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalSnackKcal = getTotalKcal(snackIntakeList);
      final totalSnackCarbs = getTotalCarbs(snackIntakeList);
      final totalSnackFats = getTotalFats(snackIntakeList);
      final totalSnackProteins = getTotalProteins(snackIntakeList);

      final totalKcalIntake =
          totalBreakfastKcal +
          totalLunchKcal +
          totalDinnerKcal +
          totalSnackKcal;
      final totalCarbsIntake =
          totalBreakfastCarbs +
          totalLunchCarbs +
          totalDinnerCarbs +
          totalSnackCarbs;
      final totalFatsIntake =
          totalBreakfastFats +
          totalLunchFats +
          totalDinnerFats +
          totalSnackFats;
      final totalProteinsIntake =
          totalBreakfastProteins +
          totalLunchProteins +
          totalDinnerProteins +
          totalSnackProteins;

      final userActivities = await _getUserActivityUsecase.getUserActivityByDay(
        day,
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalKcalActivities = userActivities
          .map((activity) => activity.burnedKcal)
          .toList()
          .sum;

      final waterIntakes = await _getWaterIntakeUsecase.getEntriesForDay(
        day,
        dayStartOffsetTotalMinutes: configData.dayStartOffsetTotalMinutes,
      );
      final totalWaterMl = waterIntakes
          .map((entry) => entry.amountMl)
          .fold<int>(0, (sum, ml) => sum + ml);

      final user = await _getUserUsecase.getUserData();
      final trackedDay = await _getTrackedDayUsecase.getTrackedDay(day);
      final weight = await _getWeightLogUsecase.latestOnOrBefore(day);
      final totalKcalGoal =
          trackedDay?.calorieGoal ??
          await _getKcalGoalUsecase.getKcalGoal(
            userEntity: user,
            totalKcalActivitiesParam: totalKcalActivities,
          );
      final totalCarbsGoal =
          trackedDay?.carbsGoal ??
          await _getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
      final totalFatsGoal =
          trackedDay?.fatGoal ??
          await _getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
      final totalProteinsGoal =
          trackedDay?.proteinGoal ??
          await _getMacroGoalUsecase.getProteinsGoal(totalKcalGoal);

      final totalKcalLeft = CalorieGoalCalc.getDailyKcalLeft(
        totalKcalGoal,
        totalKcalIntake,
      );

      // #150: derive recommended per-meal kcal targets from the saved share.
      final breakfastKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeyBreakfast,
        totalKcalGoal,
      );
      final lunchKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeyLunch,
        totalKcalGoal,
      );
      final dinnerKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeyDinner,
        totalKcalGoal,
      );
      final snackKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeySnack,
        totalKcalGoal,
      );

      if (emit.isDone ||
          version != _loadVersion ||
          day != _selection.state.day) {
        return;
      }
      emit(
        HomeLoadedState(
          day: day,
          trackedDay: trackedDay,
          weight: weight,
          overviewMacrosAsPercent: configData.overviewMacrosAsPercent,
          overviewNutrientsAsPercent: configData.overviewNutrientsAsPercent,
          showDisclaimerDialog: showDisclaimerDialog,
          totalKcalDaily: totalKcalGoal,
          totalKcalLeft: totalKcalLeft,
          totalKcalSupplied: totalKcalIntake,
          totalKcalBurned: totalKcalActivities,
          totalCarbsIntake: totalCarbsIntake,
          totalFatsIntake: totalFatsIntake,
          totalCarbsGoal: totalCarbsGoal,
          totalFatsGoal: totalFatsGoal,
          totalProteinsGoal: totalProteinsGoal,
          totalProteinsIntake: totalProteinsIntake,
          breakfastIntakeList: breakfastIntakeList,
          lunchIntakeList: lunchIntakeList,
          dinnerIntakeList: dinnerIntakeList,
          snackIntakeList: snackIntakeList,
          userActivityList: userActivities,
          usesImperialUnits: usesImperialUnits,
          bodyWeightUnit: bodyWeightUnit,
          showActivityTracking: showActivityTracking,
          showMealMacros: showMealMacros,
          userWeightKg: user.weightKG,
          breakfastKcalTarget: breakfastKcalTarget,
          lunchKcalTarget: lunchKcalTarget,
          dinnerKcalTarget: dinnerKcalTarget,
          snackKcalTarget: snackKcalTarget,
          breakfastSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeyBreakfast] ?? 0,
          lunchSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeyLunch] ?? 0,
          dinnerSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeyDinner] ?? 0,
          snackSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeySnack] ?? 0,
          userGender: user.gender,
          userCaloriesProfile: user.caloriesProfile,
          waterMlToday: totalWaterMl,
          waterGoalMl: configData.effectiveDailyWaterGoalMl(
            user.gender,
            caloriesProfile: user.caloriesProfile,
          ),
          waterIntakes: waterIntakes,
        ),
      );
    });
  }

  double getTotalKcal(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalKcal).toList().sum;

  double getTotalCarbs(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalCarbsGram).toList().sum;

  double getTotalFats(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalFatsGram).toList().sum;

  double getTotalProteins(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalProteinsGram).toList().sum;

  @override
  Future<void> close() async {
    await _selectionSubscription.cancel();
    return super.close();
  }
}
