import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_activity_selection_entity.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_sex_selection_entity.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_goal_selection_entity.dart';

class UserDataMaskEntity {
  UserSexSelectionEntity? sex;
  DateTime? birthday;
  double? height;
  double? weight;
  UserActivitySelectionEntity? activity;
  UserGoalSelectionEntity? goal;

  /// Optional weight the user is working towards. Captured on the same
  /// onboarding screen as the current weight so new users don't have to
  /// dig into Profile after first-run to set it. Stored in kilograms
  /// regardless of the display unit the user picked.
  double? targetWeight;

  /// Whether the user chose to display and enter height in imperial feet.
  bool heightUsesImperial = false;

  /// The unit chosen for current weight and target weight display.
  BodyWeightUnit bodyWeightUnit = BodyWeightUnit.kg;

  /// Whether the user chose to measure food and drinks in imperial units.
  /// Chosen explicitly rather than inferred from the height toggle.
  bool foodUsesImperial = false;

  /// App theme picked on the "Other options" page. Defaults to following
  /// the system, matching ConfigDBO.empty().
  AppThemeEntity appTheme = AppThemeEntity.system;

  /// Whether the user opted into the daily logging reminder. The actual
  /// permission request and scheduling happen when onboarding finishes.
  bool dailyReminderEnabled = false;

  /// Accent-colour choice from the "Other options" page, mirroring the
  /// Settings semantics: [useMaterialYou] true + null [accentColor] is the
  /// platform default (wallpaper palette on Android 12+, static elsewhere);
  /// picking a preset stores its ARGB value and turns Material You off.
  bool useMaterialYou = true;
  int? accentColor;

  UserDataMaskEntity({
    this.sex,
    this.birthday,
    this.height,
    this.weight,
    this.activity,
    this.goal,
    this.targetWeight,
    this.heightUsesImperial = false,
    this.bodyWeightUnit = BodyWeightUnit.kg,
    this.foodUsesImperial = false,
  });

  bool checkDataProvided() {
    if (sex != null &&
        birthday != null &&
        height != null &&
        weight != null &&
        activity != null &&
        goal != null) {
      return true;
    } else {
      return false;
    }
  }

  UserEntity? toUserEntity() {
    if (!checkDataProvided()) {
      return null;
    }
    final userBirthday = birthday ?? DateTime.now(); // TODO
    final userHeight = height ?? 180;
    final userWeight = weight ?? 70;
    UserSexEntity userSex;
    switch (sex) {
      case UserSexSelectionEntity.sexMale:
        userSex = UserSexEntity.male;
        break;
      case UserSexSelectionEntity.sexFemale:
        userSex = UserSexEntity.female;
        break;
      case null:
        userSex = UserSexEntity.female;
        break;
    }
    UserWeightGoalEntity userGoal;
    switch (goal) {
      case UserGoalSelectionEntity.loseWeight:
        userGoal = UserWeightGoalEntity.loseWeight;
        break;
      case UserGoalSelectionEntity.maintainWeight:
        userGoal = UserWeightGoalEntity.maintainWeight;
        break;
      case UserGoalSelectionEntity.gainWeigh:
        userGoal = UserWeightGoalEntity.gainWeight;
        break;
      case null:
        userGoal = UserWeightGoalEntity.maintainWeight;
    }
    UserPALEntity userPal;
    switch (activity) {
      case UserActivitySelectionEntity.sedentary:
        userPal = UserPALEntity.sedentary;
        break;
      case UserActivitySelectionEntity.lowActive:
        userPal = UserPALEntity.lowActive;
        break;
      case UserActivitySelectionEntity.active:
        userPal = UserPALEntity.active;
        break;
      case UserActivitySelectionEntity.veryActive:
        userPal = UserPALEntity.veryActive;
        break;
      case null:
        userPal = UserPALEntity.lowActive;
    }

    return UserEntity(
      birthday: userBirthday,
      heightCM: userHeight,
      weightKG: userWeight,
      sex: userSex,
      goal: userGoal,
      pal: userPal,
      targetWeightKg: targetWeight,
    );
  }
}
