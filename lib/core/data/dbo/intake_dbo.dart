import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

part 'intake_dbo.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class IntakeDBO extends HiveObject {
  @HiveField(0)
  String id;
  // Fields 1 and 2 (the duplicated base unit and amount) are retired.
  @HiveField(3)
  IntakeTypeDBO type;
  @HiveField(4)
  MealDBO meal;
  @HiveField(5)
  DateTime dateTime;
  @HiveField(6)
  RecipeDBO? recipeSnapshot;
  @HiveField(7)
  String? conversionParentId;
  @HiveField(8)
  double? quantityAmount;
  @HiveField(9)
  String? quantityUnit;
  @HiveField(10)
  String? quantityBaseUnit;
  @HiveField(11)
  double? quantityUnitFactor;
  @HiveField(12)
  String? quantityUnitLabel;

  IntakeDBO({
    required this.id,
    required this.type,
    required this.meal,
    required this.dateTime,
    required this.quantityAmount,
    required this.quantityUnit,
    required this.quantityBaseUnit,
    required this.quantityUnitFactor,
    this.quantityUnitLabel,
    this.recipeSnapshot,
    this.conversionParentId,
  }) {
    validateFoodQuantity(quantity, MealEntity.fromMealDBO(meal));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  FoodAmountSelection? get quantity {
    if (quantityAmount == null &&
        quantityUnit == null &&
        quantityBaseUnit == null &&
        quantityUnitFactor == null &&
        quantityUnitLabel == null) {
      return null;
    }
    if (quantityAmount == null ||
        quantityUnit == null ||
        quantityBaseUnit == null ||
        quantityUnitFactor == null) {
      throw const FormatException('Incomplete food quantity snapshot');
    }
    return FoodAmountSelection.fromSnapshot(
      amount: quantityAmount!,
      unit: quantityUnit!,
      baseUnit: quantityBaseUnit!,
      factor: quantityUnitFactor!,
      label: quantityUnitLabel,
    );
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  double? get baseAmount => quantity?.baseAmount;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get baseUnit => quantity?.option.baseUnit;

  factory IntakeDBO.fromIntakeEntity(IntakeEntity entity) => IntakeDBO(
    id: entity.id,
    type: IntakeTypeDBO.fromIntakeTypeEntity(entity.type),
    meal: MealDBO.fromMealEntity(entity.meal),
    dateTime: entity.dateTime,
    recipeSnapshot: entity.recipeSnapshot?.toDBO(),
    conversionParentId: entity.conversionParentId,
    quantityAmount: entity.quantity?.amount,
    quantityUnit: entity.quantity?.option.unit,
    quantityBaseUnit: entity.quantity?.option.baseUnit,
    quantityUnitFactor: entity.quantity?.option.factor,
    quantityUnitLabel: entity.quantity?.option.label,
  );

  factory IntakeDBO.fromJson(Map<String, dynamic> json) =>
      _$IntakeDBOFromJson(json);
  Map<String, dynamic> toJson() => _$IntakeDBOToJson(this);
}
