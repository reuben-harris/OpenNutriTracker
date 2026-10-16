part of 'meal_detail_bloc.dart';

abstract class MealDetailEvent extends Equatable {
  const MealDetailEvent();
}

class UpdateKcalEvent extends MealDetailEvent {
  final MealEntity meal;
  final FoodAmountSelection selection;
  const UpdateKcalEvent({required this.meal, required this.selection});
  @override
  List<Object?> get props => [meal, selection];
}

class LoadDailyTotalsEvent extends MealDetailEvent {
  final DateTime day;

  const LoadDailyTotalsEvent(this.day);

  @override
  List<Object?> get props => [day];
}

/// Fetch the full product record for a thin Open Food Facts search result so
/// the detail view can show serving options and micronutrients. A no-op for
/// non-OFF meals, already-detailed meals, or meals without a code.
class HydrateMealEvent extends MealDetailEvent {
  final MealEntity meal;

  const HydrateMealEvent(this.meal);

  @override
  List<Object?> get props => [meal];
}

/// Explicitly bypass the local cache for one Open Food Facts product.
class RefreshMealEvent extends MealDetailEvent {
  final MealEntity meal;

  const RefreshMealEvent(this.meal);

  @override
  List<Object?> get props => [meal];
}
