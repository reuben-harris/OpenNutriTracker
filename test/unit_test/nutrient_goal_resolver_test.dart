import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/domain/entity/life_stage_period.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import '../helpers/memory_user_repository.dart';

void main() {
  UserEntity user() =>
      UserEntity.fromUserDBO(MemoryUserRepository().body)
        ..birthday = DateTime(2000, 10, 26);
  test('calendar age and viewed-day life stage select exact rows', () {
    final u = user();
    u.lifeStagePeriods = [
      LifeStagePeriod(
        stage: LifeStage.pregnancy,
        start: DateTime(2018, 10, 25),
        end: DateTime(2018, 10, 26),
      ),
    ];
    final before = NutrientGoalResolver.resolve(
      user: u,
      day: DateTime(2018, 10, 24),
    );
    final during = NutrientGoalResolver.resolve(
      user: u,
      day: DateTime(2018, 10, 26),
    );
    final after = NutrientGoalResolver.resolve(
      user: u,
      day: DateTime(2018, 10, 27),
    );
    expect(u.ageOn(DateTime(2018, 10, 25)), 17);
    expect(u.ageOn(DateTime(2018, 10, 26)), 18);
    expect(before['iron']!.adequacy!.amount, 15);
    expect(during['iron']!.adequacy!.amount, 27);
    expect(after['iron']!.adequacy!.amount, 15);
  });
  test(
    'missing historical measurement is unavailable; no current or later substitute',
    () {
      final u = user();
      final weights = [
        WeightLogEntity(date: DateTime(2025), weightKg: 50),
        WeightLogEntity(date: DateTime(2026), weightKg: 60),
      ];
      final missing = NutrientGoalResolver.resolve(
        user: u,
        day: DateTime(2024),
        weights: weights,
      )['leucine']!;
      expect(missing.unavailable, 'weight');
      expect(missing.adequacy, isNull);
      final historical = NutrientGoalResolver.resolve(
        user: u,
        day: DateTime(2025, 6),
        weights: weights,
      )['leucine']!;
      expect(historical.adequacy!.amount, 2.1);
    },
  );
  test(
    'freezing retains today’s amounts, cohort and provenance for all dates',
    () {
      final u = user();
      final policy = NutrientGoalResolver.freeze(
        nutrient: 'leucine',
        policy: const NutrientPolicy(),
        user: u,
        today: DateTime(2026),
        weights: [WeightLogEntity(date: DateTime(2026), weightKg: 60)],
      );
      u.nutrientPolicies = {'leucine': policy};
      final restored = UserEntity.fromUserDBO(
        UserDBO.fromJson(
          jsonDecode(jsonEncode(UserDBO.fromUserEntity(u).toJson()))
              as Map<String, dynamic>,
        ),
      );
      restored.birthday = DateTime(2010);
      for (final day in [DateTime(2010), DateTime(2035)]) {
        final result = NutrientGoalResolver.resolve(
          user: restored,
          day: day,
        )['leucine']!;
        expect(result.adequacy!.amount, 2.52);
        expect(result.frozen, isTrue);
        expect(result.reference!.age, 25);
        expect(result.reference!.equation, contains('60.0'));
        expect(result.reference!.edition, contains('2006'));
      }
    },
  );
  test(
    'current policies reinterpret old dates with independent thresholds',
    () {
      final u = user();
      final day = DateTime(2018);
      final original = NutrientGoalResolver.resolve(
        user: u,
        day: day,
      )['calcium']!;
      expect(original.adequacy!.amount, 1300);
      expect(original.upper!.amount, 3000);
      u.nutrientPolicies = {
        'calcium': const NutrientPolicy(
          adequacyMode: ThresholdMode.custom,
          target: 900,
          upperMode: ThresholdMode.custom,
          upper: 2000,
        ),
      };
      final changed = NutrientGoalResolver.resolve(
        user: u,
        day: day,
      )['calcium']!;
      expect(changed.adequacy!.term, 'custom-target');
      expect(changed.upper!.amount, 2000);
      u.nutrientPolicies = {
        'calcium': const NutrientPolicy(
          adequacyMode: ThresholdMode.unset,
          upperMode: ThresholdMode.unset,
        ),
      };
      expect(
        NutrientGoalResolver.resolve(user: u, day: day)['calcium']!.hasGoal,
        isFalse,
      );
    },
  );
  test('no cross-source fallback; missing frozen result stays missing', () {
    final u = user()..birthday = DateTime(2013);
    u.lifeStagePeriods = [
      LifeStagePeriod(stage: LifeStage.pregnancy, start: DateTime(2026)),
    ];
    final policy = NutrientGoalResolver.freeze(
      nutrient: 'iron',
      policy: const NutrientPolicy(source: 'nzAustralia'),
      user: u,
      today: DateTime(2026, 10, 26),
    );
    expect(
      NutrientGoalResolver.resolveOne(
        nutrient: 'iron',
        policy: policy,
        user: u,
        day: DateTime(2028),
      ).unavailable,
      'cohort',
    );
  });
  test('zero upper is valid, zero adequacy and contradictions are invalid', () {
    expect(
      const NutrientPolicy(upperMode: ThresholdMode.custom, upper: 0).valid,
      isTrue,
    );
    expect(
      const NutrientPolicy(adequacyMode: ThresholdMode.custom, target: 0).valid,
      isFalse,
    );
    expect(
      const NutrientPolicy(
        adequacyMode: ThresholdMode.custom,
        target: 2,
        upperMode: ThresholdMode.custom,
        upper: 1,
      ).valid,
      isFalse,
    );
  });
}
