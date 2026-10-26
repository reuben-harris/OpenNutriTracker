import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/life_stage_period.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import '../helpers/memory_user_repository.dart';

void main() {
  test('inclusive boundaries, gaps, ongoing periods and sex', () {
    final user = UserEntity.fromUserDBO(MemoryUserRepository().body);
    user.lifeStagePeriods = [
      LifeStagePeriod(
        stage: LifeStage.pregnancy,
        start: DateTime(2025, 1, 1, 12),
        end: DateTime(2025, 9, 1),
      ),
      LifeStagePeriod(
        stage: LifeStage.breastfeeding,
        start: DateTime(2025, 9, 3),
      ),
    ];
    expect(user.lifeStageOn(DateTime(2024, 12, 31)), isNull);
    expect(user.lifeStageOn(DateTime(2025, 1, 1)), LifeStage.pregnancy);
    expect(user.lifeStageOn(DateTime(2025, 9, 1, 23)), LifeStage.pregnancy);
    expect(user.lifeStageOn(DateTime(2025, 9, 2)), isNull);
    expect(user.lifeStageOn(DateTime(2030)), LifeStage.breastfeeding);
    user.sex = UserSexEntity.male;
    expect(user.lifeStageOn(DateTime(2025, 2)), isNull);
  });
  test(
    'reject invalid and overlapping periods without replacing saved periods',
    () {
      final user = UserEntity.fromUserDBO(MemoryUserRepository().body);
      final period = LifeStagePeriod(
        stage: LifeStage.pregnancy,
        start: DateTime(2025),
        end: DateTime(2025, 9),
      );
      user.lifeStagePeriods = [period];
      expect(
        () => user.lifeStagePeriods = [
          period,
          LifeStagePeriod(
            stage: LifeStage.breastfeeding,
            start: DateTime(2025, 9),
          ),
        ],
        throwsArgumentError,
      );
      expect(user.lifeStagePeriods.single, period);
      expect(
        () => LifeStagePeriod(
          stage: LifeStage.pregnancy,
          start: DateTime(2025),
          end: DateTime(2024),
        ),
        throwsArgumentError,
      );
      expect(
        () => user.lifeStagePeriods = [
          LifeStagePeriod(stage: LifeStage.pregnancy, start: DateTime(2025)),
          LifeStagePeriod(
            stage: LifeStage.breastfeeding,
            start: DateTime(2026),
          ),
        ],
        throwsArgumentError,
      );
    },
  );
  test('backup retains periods and changes do not affect another profile', () {
    final a = UserEntity.fromUserDBO(MemoryUserRepository().body);
    final b = UserEntity.fromUserDBO(MemoryUserRepository().body);
    a.lifeStagePeriods = [
      LifeStagePeriod(stage: LifeStage.breastfeeding, start: DateTime(2025)),
    ];
    final restored = UserEntity.fromUserDBO(
      UserDBO.fromJson(
        jsonDecode(jsonEncode(UserDBO.fromUserEntity(a).toJson()))
            as Map<String, dynamic>,
      ),
    );
    expect(restored.lifeStageOn(DateTime(2026)), LifeStage.breastfeeding);
    a.lifeStagePeriods = [];
    expect(restored.lifeStagePeriods, hasLength(1));
    expect(b.lifeStagePeriods, isEmpty);
  });
}
