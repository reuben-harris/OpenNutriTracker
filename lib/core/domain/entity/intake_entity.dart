import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class IntakeEntity extends Equatable {
  final String id;
  final FoodAmountSelection? quantity;
  final IntakeTypeEntity type;
  final DateTime dateTime;
  final MealEntity meal;

  /// The recipe as it existed when this occurrence was logged.
  final RecipeEntity? recipeSnapshot;

  /// Links pending replacement ingredients to their original intake.
  final String? conversionParentId;

  IntakeEntity({
    required this.id,
    required this.quantity,
    required this.type,
    required this.meal,
    required this.dateTime,
    this.recipeSnapshot,
    this.conversionParentId,
  }) {
    validateFoodQuantity(quantity, meal);
  }

  factory IntakeEntity.fromIntakeDBO(IntakeDBO dbo) => IntakeEntity(
    id: dbo.id,
    quantity: dbo.quantity,
    type: IntakeTypeEntity.fromIntakeTypeDBO(dbo.type),
    meal: MealEntity.fromMealDBO(dbo.meal),
    dateTime: dbo.dateTime,
    recipeSnapshot: dbo.recipeSnapshot == null
        ? null
        : RecipeEntity.fromDBO(dbo.recipeSnapshot!),
    conversionParentId: dbo.conversionParentId,
  );

  double? get baseAmount => quantity?.baseAmount;
  String? get baseUnit => quantity?.option.baseUnit;

  /// Unweighted Quick Add stores totals; weighted foods store per-100 nutrition.
  double get nutritionScale =>
      quantity == null ? 1 : quantity!.baseAmount / 100;

  bool get isIncomplete =>
      meal.nutriments.isIncomplete ||
      (recipeSnapshot?.ingredients.any(
            (i) => i.snapshotMeal.nutriments.isIncomplete,
          ) ??
          false);

  double get totalKcal =>
      nutritionScale * (meal.nutriments.energyKcal100?.calculationValue ?? 0);
  double get totalCarbsGram =>
      nutritionScale *
      (meal.nutriments.carbohydrates100?.calculationValue ?? 0);
  double get totalFatsGram =>
      nutritionScale * (meal.nutriments.fat100?.calculationValue ?? 0);
  double get totalProteinsGram =>
      nutritionScale * (meal.nutriments.proteins100?.calculationValue ?? 0);

  @override
  List<Object?> get props => [
    id,
    quantity,
    type,
    dateTime,
    meal,
    recipeSnapshot,
    conversionParentId,
  ];
}
