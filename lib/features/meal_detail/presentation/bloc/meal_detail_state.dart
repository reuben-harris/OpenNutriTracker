part of 'meal_detail_bloc.dart';

enum ProductRefreshStatus { idle, loading, success, failure }

abstract class MealDetailState extends Equatable {
  final String totalQuantityConverted;
  final double totalKcal;
  final double totalCarbs;
  final double totalFat;
  final double totalProtein;

  final String selectedUnit;

  final double dayKcalConsumed;
  final double dayKcalGoal;
  final double dayCarbsGoal, dayFatGoal, dayProteinGoal;
  final Map<String, double> dayNutrientGoals;

  /// Latest full product from hydration or an explicit refresh; null until
  /// either succeeds. The screen uses it for nutrition and serving options.
  final MealEntity? hydratedMeal;

  /// True while the hydration network call is in flight.
  final bool isHydrating;

  final ProductRefreshStatus refreshStatus;

  /// MealEntity equality only compares code/name, so nutrition-only updates
  /// need their own revision to reach the screen (including repeated refreshes).
  final int mealRevision;

  bool get isRefreshing => refreshStatus == ProductRefreshStatus.loading;

  const MealDetailState({
    required this.totalQuantityConverted,
    this.totalKcal = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.totalProtein = 0,
    required this.selectedUnit,
    this.dayKcalConsumed = 0,
    this.dayKcalGoal = 0,
    this.dayCarbsGoal = 0,
    this.dayFatGoal = 0,
    this.dayProteinGoal = 0,
    this.dayNutrientGoals = const {},
    this.hydratedMeal,
    this.isHydrating = false,
    this.refreshStatus = ProductRefreshStatus.idle,
    this.mealRevision = 0,
  });

  @override
  List<Object?> get props => [
    totalQuantityConverted,
    totalKcal,
    totalCarbs,
    totalFat,
    totalProtein,
    selectedUnit,
    dayKcalConsumed,
    dayKcalGoal,
    dayCarbsGoal,
    dayFatGoal,
    dayProteinGoal,
    dayNutrientGoals,
    hydratedMeal,
    isHydrating,
    refreshStatus,
    mealRevision,
  ];

  MealDetailInitial copyWith({
    String? totalQuantityConverted,
    double? totalKcal,
    double? totalCarbs,
    double? totalFat,
    double? totalProtein,
    String? selectedUnit,
    double? dayKcalConsumed,
    double? dayKcalGoal,
    double? dayCarbsGoal,
    double? dayFatGoal,
    double? dayProteinGoal,
    Map<String, double>? dayNutrientGoals,
    MealEntity? hydratedMeal,
    bool? isHydrating,
    ProductRefreshStatus? refreshStatus,
    int? mealRevision,
  }) {
    return MealDetailInitial(
      totalQuantityConverted:
          totalQuantityConverted ?? this.totalQuantityConverted,
      totalKcal: totalKcal ?? this.totalKcal,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      totalProtein: totalProtein ?? this.totalProtein,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      dayKcalConsumed: dayKcalConsumed ?? this.dayKcalConsumed,
      dayKcalGoal: dayKcalGoal ?? this.dayKcalGoal,
      dayCarbsGoal: dayCarbsGoal ?? this.dayCarbsGoal,
      dayFatGoal: dayFatGoal ?? this.dayFatGoal,
      dayProteinGoal: dayProteinGoal ?? this.dayProteinGoal,
      dayNutrientGoals: dayNutrientGoals ?? this.dayNutrientGoals,
      hydratedMeal: hydratedMeal ?? this.hydratedMeal,
      isHydrating: isHydrating ?? this.isHydrating,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      mealRevision: mealRevision ?? this.mealRevision,
    );
  }
}

class MealDetailInitial extends MealDetailState {
  const MealDetailInitial({
    required super.totalQuantityConverted,
    super.totalKcal,
    super.totalCarbs,
    super.totalFat,
    super.totalProtein,
    required super.selectedUnit,
    super.dayKcalConsumed,
    super.dayKcalGoal,
    super.dayCarbsGoal,
    super.dayFatGoal,
    super.dayProteinGoal,
    super.dayNutrientGoals,
    super.hydratedMeal,
    super.isHydrating,
    super.refreshStatus,
    super.mealRevision,
  });
}
