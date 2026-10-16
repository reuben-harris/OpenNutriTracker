import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_ingredient_dbo.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class RecipeIngredientEntity extends Equatable {
  final MealEntity snapshotMeal;
  final FoodAmountSelection quantity;

  RecipeIngredientEntity({required this.snapshotMeal, required this.quantity}) {
    quantity.validate();
  }

  factory RecipeIngredientEntity.fromDBO(RecipeIngredientDBO dbo) =>
      RecipeIngredientEntity(
        snapshotMeal: MealEntity.fromMealDBO(dbo.snapshotMeal),
        quantity: dbo.quantity,
      );

  RecipeIngredientDBO toDBO() => RecipeIngredientDBO(
    snapshotMeal: MealDBO.fromMealEntity(snapshotMeal),
    quantityAmount: quantity.amount,
    quantityUnit: quantity.option.unit,
    quantityBaseUnit: quantity.option.baseUnit,
    quantityUnitFactor: quantity.option.factor,
    quantityUnitLabel: quantity.option.label,
  );

  RecipeIngredientEntity copyWith({
    MealEntity? snapshotMeal,
    FoodAmountSelection? quantity,
  }) => RecipeIngredientEntity(
    snapshotMeal: snapshotMeal ?? this.snapshotMeal,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [snapshotMeal, quantity];
}
