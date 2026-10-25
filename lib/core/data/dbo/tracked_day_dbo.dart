import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';

part 'tracked_day_dbo.g.dart';

@HiveType(typeId: 9)
@JsonSerializable()
class TrackedDayDBO extends HiveObject {
  @HiveField(0)
  DateTime day;
  @HiveField(1)
  double calorieGoal;
  @HiveField(2)
  double caloriesTracked;
  @HiveField(3)
  double? carbsGoal;
  @HiveField(4)
  double? carbsTracked;
  @HiveField(5)
  double? fatGoal;
  @HiveField(6)
  double? fatTracked;
  @HiveField(7)
  double? proteinGoal;
  @HiveField(8)
  double? proteinTracked;

  // Fields 9–18 are retired individual nutrient goals.
  @HiveField(19)
  Map<String, NutrientGoal> nutrientGoals;

  TrackedDayDBO({
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

  factory TrackedDayDBO.fromTrackedDayEntity(TrackedDayEntity entity) {
    return TrackedDayDBO(
      day: entity.day,
      calorieGoal: entity.calorieGoal,
      caloriesTracked: entity.caloriesTracked,
      carbsGoal: entity.carbsGoal,
      carbsTracked: entity.carbsTracked,
      fatGoal: entity.fatGoal,
      fatTracked: entity.fatTracked,
      proteinGoal: entity.proteinGoal,
      proteinTracked: entity.proteinTracked,
      nutrientGoals: Map.of(entity.nutrientGoals),
    );
  }

  factory TrackedDayDBO.fromJson(Map<String, dynamic> json) =>
      _$TrackedDayDBOFromJson(json);

  Map<String, dynamic> toJson() => _$TrackedDayDBOToJson(this);
}
