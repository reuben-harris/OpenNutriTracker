import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';

class TrackedDayEntity extends Equatable {
  static const maxKcalDifferenceOverGoal = 500;
  static const maxKcalDifferenceUnderGoal = 1000;

  final DateTime day;
  final double calorieGoal;
  final double caloriesTracked;
  final double? carbsGoal;
  final double? carbsTracked;
  final double? fatGoal;
  final double? fatTracked;
  final double? proteinGoal;
  final double? proteinTracked;

  final Map<String, NutrientGoal> nutrientGoals;

  const TrackedDayEntity({
    required this.day,
    required this.calorieGoal,
    required this.caloriesTracked,
    this.carbsGoal,
    this.carbsTracked,
    this.fatGoal,
    this.fatTracked,
    this.proteinGoal,
    this.proteinTracked,
    this.nutrientGoals = const {},
  });

  factory TrackedDayEntity.fromTrackedDayDBO(TrackedDayDBO trackedDayDBO) {
    // A running total that took in a NaN nutriment stays NaN on disk (#1254)
    // until `ensureTrackedDayTotalsFinite` rebuilds it on the next profile
    // open. NaN.toInt() throws in the Trends and Diary cards, so meanwhile a
    // non-finite total reads as nothing tracked rather than taking the card
    // down.
    double? finite(double? value) =>
        value != null && value.isFinite ? value : null;
    return TrackedDayEntity(
      day: trackedDayDBO.day,
      calorieGoal: trackedDayDBO.calorieGoal,
      caloriesTracked: finite(trackedDayDBO.caloriesTracked) ?? 0,
      carbsGoal: trackedDayDBO.carbsGoal,
      carbsTracked: finite(trackedDayDBO.carbsTracked),
      fatGoal: trackedDayDBO.fatGoal,
      fatTracked: finite(trackedDayDBO.fatTracked),
      proteinGoal: trackedDayDBO.proteinGoal,
      proteinTracked: finite(trackedDayDBO.proteinTracked),
      nutrientGoals: Map.unmodifiable(trackedDayDBO.nutrientGoals),
    );
  }

  // TODO: make enum class for rating
  Color getCalendarDayRatingColor(BuildContext context) {
    if (_hasExceededMaxKcalDifferenceGoal(calorieGoal, caloriesTracked)) {
      return Theme.of(context).colorScheme.primary;
    } else {
      return Theme.of(context).colorScheme.error;
    }
  }

  Color getRatingDayTextColor(BuildContext context) {
    if (_hasExceededMaxKcalDifferenceGoal(calorieGoal, caloriesTracked)) {
      return Theme.of(context).colorScheme.onSecondaryContainer;
    } else {
      return Theme.of(context).colorScheme.onErrorContainer;
    }
  }

  Color getRatingDayTextBackgroundColor(BuildContext context) {
    if (_hasExceededMaxKcalDifferenceGoal(calorieGoal, caloriesTracked)) {
      return Theme.of(context).colorScheme.secondaryContainer;
    } else {
      return Theme.of(context).colorScheme.errorContainer;
    }
  }

  bool _hasExceededMaxKcalDifferenceGoal(double calorieGoal, caloriesTracked) {
    double difference = calorieGoal - caloriesTracked;

    if (calorieGoal < caloriesTracked) {
      return difference.abs() < maxKcalDifferenceOverGoal;
    } else {
      return difference < maxKcalDifferenceUnderGoal;
    }
  }

  @override
  List<Object?> get props => [
    day,
    calorieGoal,
    caloriesTracked,
    carbsGoal,
    carbsTracked,
    fatGoal,
    fatTracked,
    proteinGoal,
    proteinTracked,
    nutrientGoals,
  ];
}
