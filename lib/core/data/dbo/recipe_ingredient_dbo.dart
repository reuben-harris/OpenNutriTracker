import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';

part 'recipe_ingredient_dbo.g.dart';

@HiveType(typeId: 17)
@JsonSerializable()
class RecipeIngredientDBO extends HiveObject {
  @HiveField(0)
  final MealDBO snapshotMeal;
  // Fields 1–3 (amount, unit, converted weight) are retired.
  @HiveField(4)
  final double quantityAmount;
  @HiveField(5)
  final String quantityUnit;
  @HiveField(6)
  final String quantityBaseUnit;
  @HiveField(7)
  final double quantityUnitFactor;
  @HiveField(8)
  final String? quantityUnitLabel;

  RecipeIngredientDBO({
    required this.snapshotMeal,
    required this.quantityAmount,
    required this.quantityUnit,
    required this.quantityBaseUnit,
    required this.quantityUnitFactor,
    this.quantityUnitLabel,
  }) {
    quantity.validate();
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  FoodAmountSelection get quantity => FoodAmountSelection.fromSnapshot(
    amount: quantityAmount,
    unit: quantityUnit,
    baseUnit: quantityBaseUnit,
    factor: quantityUnitFactor,
    label: quantityUnitLabel,
  );

  factory RecipeIngredientDBO.fromJson(Map<String, dynamic> json) =>
      _$RecipeIngredientDBOFromJson(json);
  Map<String, dynamic> toJson() => _$RecipeIngredientDBOToJson(this);
}
