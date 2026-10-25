import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';

part 'meal_portion_dbo.g.dart';

@HiveType(typeId: 23)
@JsonSerializable()
class MealPortionDBO {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String label;
  @HiveField(2)
  final String? englishLabel;
  @HiveField(3)
  final double gramWeight;
  @HiveField(4)
  final bool localized;

  const MealPortionDBO({
    required this.id,
    required this.label,
    required this.gramWeight,
    required this.localized,
    this.englishLabel,
  });

  factory MealPortionDBO.fromEntity(MealPortionEntity portion) =>
      MealPortionDBO(
        id: portion.id,
        label: portion.label,
        englishLabel: portion.englishLabel,
        gramWeight: portion.gramWeight,
        localized: portion.localized,
      );

  factory MealPortionDBO.fromJson(Map<String, dynamic> json) =>
      _$MealPortionDBOFromJson(json);

  Map<String, dynamic> toJson() => _$MealPortionDBOToJson(this);
}
