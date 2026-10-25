import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_calc.dart';

import '../fixture/user_entity_fixtures.dart';

void main() {
  // Yesterday (not `day - 1`) so the date stays valid on the 1st of the
  // month; captured once so components can't straddle a midnight rollover.
  final yesterday = DateTime.now().subtract(const Duration(days: 1));

  test('IOM TDEE calculation for a male user', () {
    // Mock a male user
    UserEntity user = UserEntity(
      birthday: DateTime(yesterday.year - 25, yesterday.month, yesterday.day),
      heightCM: 180.0,
      weightKG: 80.0,
      sex: UserSexEntity.male,
      goal: UserWeightGoalEntity.maintainWeight,
      pal: UserPALEntity.sedentary,
    );

    // Call the TDEE calculation method
    double userTdee = TDEECalc.getTDEEKcalIOM2005(user);

    // IOM 2005 p. 204:
    //   TEE = 864 – (9.72 × age [y]) + PA × (14.2 × weight [kg]
    //         + 503 × height [m])
    //
    // 864 - (9.72 * 25) + 1.0 * (14.2 * 80 + 503 * 1.80)
    //   = 621 + 2041.4 = 2662.4
    //
    // Sedentary is the one category this is invariant for: PA = 1.0, so the
    // #987 bracket bug did not move it. That is exactly why a sedentary-only
    // pin could never have caught the bug — see the non-sedentary pins below.
    int expectedTdee = 2662;

    expect(userTdee.toInt(), expectedTdee);
  });

  test('IOM TDEE calculation for a female user', () {
    // Mock a female user
    UserEntity user =
        UserEntityFixtures.middleAgedActiveFemaleWantingToLoseWeight;

    // Call the TDEE calculation method
    double userTdee = TDEECalc.getTDEEKcalIOM2005(user);

    // IOM 2005 p. 204:
    //   TEE = 387 – (7.31 × age [y]) + PA × (10.9 × weight [kg]
    //         + 660.7 × height [m])
    //
    // 387 - (7.31 * 54) + 1.27 * (10.9 * 75 + 660.7 * 1.60)
    //   = -7.74 + 1.27 * 1874.62 = 2373.03
    //
    // Was pinned at 2087 before #987: the old code left the height term
    // outside the PA multiplier, costing this user 286 kcal/day.
    int expectedTdee = 2373;

    expect(userTdee.toInt(), expectedTdee);
  });

  group('Real-user kcal goal must differ from the old dummy fallback', () {
    // Regression for the onboarding race: when getUserData() returned the
    // hardcoded 80 kg / 180 cm / male / age 26 / active / maintain dummy,
    // the home screen showed ≈ 2959 kcal regardless of who the user was.
    // For a generic sedentary female with a lose-weight goal, the budget
    // must land far below that — otherwise we have regressed back to
    // pulling the dummy.
    test('female / sedentary / lose-weight produces a budget well below the '
        'old male / active / maintain dummy', () {
      final user = UserEntity(
        birthday: DateTime(yesterday.year - 35, yesterday.month, yesterday.day),
        heightCM: 165.0,
        weightKG: 70.0,
        sex: UserSexEntity.female,
        goal: UserWeightGoalEntity.loseWeight,
        pal: UserPALEntity.sedentary,
      );

      final totalGoal = CalorieGoalCalc.getTotalKcalGoal(user, 0);
      // TEE = 387 - 7.31*35 + 1.0*(10.9*70 + 660.7*1.65)
      //     = 131.15 + 1853.155 ≈ 1984.3
      // Total goal = 1984.3 - 500 ≈ 1484.3 — well below the dummy's 2959.
      expect(totalGoal, lessThan(1700));
      expect(totalGoal, greaterThan(1300));
    });
  });
}
