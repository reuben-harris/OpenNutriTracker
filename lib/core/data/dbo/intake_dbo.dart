import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';

part 'intake_dbo.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class IntakeDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String unit;
  @HiveField(2)
  double amount;
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
  double? enteredAmount;

  @HiveField(9)
  String? enteredUnit;

  @HiveField(10)
  String? enteredBaseUnit;

  @HiveField(11)
  double? enteredUnitFactor;

  @HiveField(12)
  String? enteredUnitLabel;

  IntakeDBO({
    required this.id,
    required this.unit,
    required this.amount,
    required this.type,
    required this.meal,
    required this.dateTime,
    this.recipeSnapshot,
    this.conversionParentId,
    this.enteredAmount,
    this.enteredUnit,
    this.enteredBaseUnit,
    this.enteredUnitFactor,
    this.enteredUnitLabel,
  });

  factory IntakeDBO.fromIntakeEntity(IntakeEntity entity) {
    return IntakeDBO(
      id: entity.id,
      unit: entity.unit,
      amount: entity.amount,
      type: IntakeTypeDBO.fromIntakeTypeEntity(entity.type),
      meal: MealDBO.fromMealEntity(entity.meal),
      dateTime: entity.dateTime,
      recipeSnapshot: entity.recipeSnapshot?.toDBO(),
      conversionParentId: entity.conversionParentId,
      enteredAmount: entity.enteredAmount,
      enteredUnit: entity.enteredUnit,
      enteredBaseUnit: entity.enteredBaseUnit,
      enteredUnitFactor: entity.enteredUnitFactor,
      enteredUnitLabel: entity.enteredUnitLabel,
    );
  }

  factory IntakeDBO.fromJson(Map<String, dynamic> json) =>
      _$IntakeDBOFromJson(json);

  Map<String, dynamic> toJson() => _$IntakeDBOToJson(this);
}
