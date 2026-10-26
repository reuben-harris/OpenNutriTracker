import 'package:opennutritracker/core/domain/entity/height_reading.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';

class UserEntity {
  List<HeightReading> heightHistory;
  DateTime birthday;
  double heightCM;
  double weightKG;
  UserSexEntity sex;
  UserWeightGoalEntity goal;
  UserPALEntity pal;
  double? weeklyWeightGoalKg;

  /// #119: Optional concrete target weight in kg. Stored alongside the
  /// existing [weeklyWeightGoalKg] rate so the Profile screen can surface
  /// a "X kg to your target" line. Calorie computation deliberately does
  /// not consume this field yet — a tapering adjustment as the target
  /// nears is a separate scope question.
  double? targetWeightKg;

  /// Opt-in linear taper that scales the daily kcal deficit down as
  /// current weight approaches [targetWeightKg]. The toggle only has
  /// anything to act on when a target weight is set, so Profile gates
  /// the surfacing behind that condition.
  bool caloriesTaperEnabled;

  UserEntity({
    required this.birthday,
    required this.heightCM,
    required this.weightKG,
    required this.sex,
    required this.goal,
    required this.pal,
    List<HeightReading>? heightHistory,
    this.weeklyWeightGoalKg,
    this.targetWeightKg,
    this.caloriesTaperEnabled = false,
  }) : heightHistory = List.of(heightHistory ?? []);

  factory UserEntity.fromUserDBO(UserDBO userDBO) {
    return UserEntity(
      heightHistory: userDBO.heightHistory,
      birthday: userDBO.birthday,
      heightCM: userDBO.heightCM,
      weightKG: userDBO.weightKG,
      sex: UserSexEntity.fromUserSexDBO(userDBO.sex),
      goal: UserWeightGoalEntity.fromUserWeightGoalDBO(userDBO.goal),
      pal: UserPALEntity.fromUserPALDBO(userDBO.pal),
      weeklyWeightGoalKg: userDBO.weeklyWeightGoalKg,
      targetWeightKg: userDBO.targetWeightKg,
      caloriesTaperEnabled: userDBO.caloriesTaperEnabled,
    );
  }

  void recordHeight(HeightReading reading, {DateTime? today}) {
    heightHistory.removeWhere((e) => e.date == reading.date);
    heightHistory.add(reading);
    heightHistory.sort((a, b) => a.date.compareTo(b.date));
    final now = today ?? DateTime.now();
    if (reading.date == DateTime(now.year, now.month, now.day)) {
      heightCM = reading.centimetres;
    }
  }

  HeightReading? heightOnOrBefore(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final eligible = heightHistory.where((e) => !e.date.isAfter(date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return eligible.firstOrNull;
  }

  int get age => DateTime.now().difference(birthday).inDays ~/ 365;
}
