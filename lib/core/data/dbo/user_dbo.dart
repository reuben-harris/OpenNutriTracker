import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import 'package:opennutritracker/core/domain/entity/life_stage_period.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/height_reading.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/user_sex_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';

part 'user_dbo.g.dart';

@JsonSerializable(explicitToJson: true)
@HiveType(typeId: 5)
class UserDBO extends HiveObject {
  @HiveField(0)
  DateTime birthday;
  @HiveField(1)
  double heightCM;
  @HiveField(2)
  double weightKG;
  @HiveField(3)
  UserSexDBO sex;
  @HiveField(4)
  UserWeightGoalDBO goal;
  @HiveField(5)
  UserPALDBO pal;
  @HiveField(6)
  double? weeklyWeightGoalKg;
  // Field ID 7 and its former profile type ID 18 are retired.
  @HiveField(8)
  double? targetWeightKg;
  // Opt-in linear taper that scales the daily kcal deficit down as
  // current weight approaches the target. Sits next to targetWeightKg
  // because the toggle only has anything to act on once a target
  // weight is set; lives on the user, not on app config, since it's a
  // personal weight-goal preference rather than an app-wide setting.
  @HiveField(9)
  bool caloriesTaperEnabled;

  @HiveField(10)
  List<HeightReading>? heightHistory;

  @HiveField(11)
  List<LifeStagePeriod> lifeStagePeriods;

  @HiveField(12)
  Map<String, NutrientPolicy> nutrientPolicies;

  UserDBO({
    required this.birthday,
    required this.heightCM,
    required this.weightKG,
    required this.sex,
    required this.goal,
    required this.pal,
    this.nutrientPolicies = const {},
    this.heightHistory,
    this.lifeStagePeriods = const [],
    this.weeklyWeightGoalKg,
    this.targetWeightKg,
    this.caloriesTaperEnabled = false,
  });

  factory UserDBO.fromJson(Map<String, dynamic> json) =>
      _$UserDBOFromJson(json);
  Map<String, dynamic> toJson() => _$UserDBOToJson(this);

  factory UserDBO.fromUserEntity(UserEntity entity) {
    return UserDBO(
      lifeStagePeriods: entity.lifeStagePeriods,
      heightHistory: entity.heightHistory,
      nutrientPolicies: entity.nutrientPolicies,
      birthday: entity.birthday,
      heightCM: entity.heightCM,
      weightKG: entity.weightKG,
      sex: UserSexDBO.fromUserSexEntity(entity.sex),
      goal: UserWeightGoalDBO.fromUserWeightGoalEntity(entity.goal),
      pal: UserPALDBO.fromUserPALEntity(entity.pal),
      weeklyWeightGoalKg: entity.weeklyWeightGoalKg,
      targetWeightKg: entity.targetWeightKg,
      caloriesTaperEnabled: entity.caloriesTaperEnabled,
    );
  }
}
