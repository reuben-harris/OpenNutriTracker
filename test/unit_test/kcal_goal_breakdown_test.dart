import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/kcal_goal_breakdown_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_calc.dart';

void main() {
  // Yesterday (not `day - 1`) so the date stays valid on the 1st of the
  // month; captured once so components can't straddle a midnight rollover.
  final yesterday = DateTime.now().subtract(const Duration(days: 1));

  UserEntity buildUser({
    UserSexEntity sex = UserSexEntity.male,
    UserWeightGoalEntity goal = UserWeightGoalEntity.loseWeight,
    UserPALEntity pal = UserPALEntity.active,
    double? weeklyWeightGoalKg,
    double? targetWeightKg,
    bool taperEnabled = false,
    double weightKG = 80.0,
  }) {
    return UserEntity(
      birthday: DateTime(yesterday.year - 30, yesterday.month, yesterday.day),
      heightCM: 180.0,
      weightKG: weightKG,
      sex: sex,
      goal: goal,
      pal: pal,
      weeklyWeightGoalKg: weeklyWeightGoalKg,
      targetWeightKg: targetWeightKg,
      caloriesTaperEnabled: taperEnabled,
    );
  }

  test('breakdown components always sum to the total goal', () {
    final user = buildUser(
      weeklyWeightGoalKg: -0.5,
      targetWeightKg: 75.0,
      taperEnabled: true,
    );
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: user,
      userKcalAdjustment: 150,
      totalKcalActivities: 320,
    );

    expect(
      breakdown.tdeeKcal +
          breakdown.effectiveAdjustmentKcal +
          breakdown.manualKcalAdjustment +
          breakdown.activityKcal,
      closeTo(breakdown.totalKcalGoal, 0.0001),
    );
  });

  test('breakdown total matches the production goal calculation', () {
    final user = buildUser();
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: user,
      userKcalAdjustment: -100,
      totalKcalActivities: 250,
    );

    expect(
      breakdown.totalKcalGoal,
      CalorieGoalCalc.getTotalKcalGoal(
        user,
        250,
        kcalUserAdjustment: -100,
        caloriesTaperEnabled: user.caloriesTaperEnabled,
      ),
    );
    expect(breakdown.tdeeKcal, TDEECalc.getTDEEKcalIOM2005(user));
  });

  for (final sex in UserSexEntity.values) {
    for (final pal in UserPALEntity.values) {
      test('${sex.name} ${pal.name} uses the selected formula and PA', () {
        final user = buildUser(sex: sex, pal: pal);
        final breakdown = KcalGoalBreakdownEntity.compute(
          user: user,
          userKcalAdjustment: 125,
          totalKcalActivities: 250,
        );
        final expectedPa = switch (pal) {
          UserPALEntity.sedentary => 1.0,
          UserPALEntity.lowActive => sex == UserSexEntity.male ? 1.12 : 1.14,
          UserPALEntity.active => 1.27,
          UserPALEntity.veryActive => sex == UserSexEntity.male ? 1.54 : 1.45,
        };
        expect(breakdown.sex, sex);
        expect(breakdown.paValue, expectedPa);
        expect(breakdown.tdeeKcal, TDEECalc.getTDEEKcalIOM2005(user));
        expect(
          breakdown.totalKcalGoal,
          CalorieGoalCalc.getTotalKcalGoal(user, 250, kcalUserAdjustment: 125),
        );
      });
    }
  }

  test('weekly rate replaces the flat adjustment', () {
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: buildUser(weeklyWeightGoalKg: -0.5),
      totalKcalActivities: 0,
    );

    expect(breakdown.baseAdjustmentKcal, -550);
    expect(breakdown.effectiveAdjustmentKcal, -550);
    expect(breakdown.taperChangedAdjustment, isFalse);
  });

  test('taper scales the adjustment and the flag reports it', () {
    // 3 kg from target with the taper on → factor (3 − 1) / 4 = 0.5.
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: buildUser(weightKG: 78.0, targetWeightKg: 75.0, taperEnabled: true),
      totalKcalActivities: 0,
    );

    expect(breakdown.baseAdjustmentKcal, -500);
    expect(breakdown.effectiveAdjustmentKcal, -250);
    expect(breakdown.taperChangedAdjustment, isTrue);
  });

  test('unset manual adjustment is reported as zero', () {
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: buildUser(),
      totalKcalActivities: 0,
    );

    expect(breakdown.manualKcalAdjustment, 0);
  });

  test('macro grams match the production MacroCalc results', () {
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: buildUser(),
      totalKcalActivities: 200,
    );

    expect(
      breakdown.carbsGoalGrams,
      MacroCalc.getTotalCarbsGoal(breakdown.totalKcalGoal),
    );
    expect(
      breakdown.fatsGoalGrams,
      MacroCalc.getTotalFatsGoal(breakdown.totalKcalGoal),
    );
    expect(
      breakdown.proteinsGoalGrams,
      MacroCalc.getTotalProteinsGoal(breakdown.totalKcalGoal),
    );
    // Default split when the user has not customised it.
    expect(breakdown.carbsFractionGoal, 0.6);
    expect(breakdown.fatsFractionGoal, 0.25);
    expect(breakdown.proteinsFractionGoal, 0.15);
  });

  test('custom macro split replaces the defaults', () {
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: buildUser(),
      totalKcalActivities: 0,
      userCarbsGoalPct: 0.4,
      userFatsGoalPct: 0.3,
      userProteinsGoalPct: 0.3,
    );

    expect(breakdown.carbsFractionGoal, 0.4);
    expect(breakdown.fatsFractionGoal, 0.3);
    expect(breakdown.proteinsFractionGoal, 0.3);
    expect(
      breakdown.carbsGoalGrams,
      MacroCalc.getTotalCarbsGoal(breakdown.totalKcalGoal, userCarbsGoal: 0.4),
    );
  });

  test('macro gram energies sum back to the calorie goal', () {
    final breakdown = KcalGoalBreakdownEntity.compute(
      user: buildUser(),
      totalKcalActivities: 150,
    );

    // 60/25/15 sums to 100 %, so grams × densities must rebuild the goal.
    expect(
      breakdown.carbsGoalGrams * MacroCalc.carbsKcalPerGram +
          breakdown.fatsGoalGrams * MacroCalc.fatKcalPerGram +
          breakdown.proteinsGoalGrams * MacroCalc.proteinKcalPerGram,
      closeTo(breakdown.totalKcalGoal, 0.0001),
    );
  });
}
