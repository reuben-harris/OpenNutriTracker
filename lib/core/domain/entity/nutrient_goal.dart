import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'nutrient_goal.g.dart';

@HiveType(typeId: 26)
@JsonSerializable()
class NutrientGoal extends Equatable {
  @HiveField(0)
  final double amount;
  @HiveField(1)
  final bool isLimit;
  const NutrientGoal(this.amount, {this.isLimit = false});
  factory NutrientGoal.fromJson(Map<String, dynamic> json) =>
      _$NutrientGoalFromJson(json);
  Map<String, dynamic> toJson() => _$NutrientGoalToJson(this);
  @override
  List<Object?> get props => [amount, isLimit];
}
