import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';

/// Water seeds are sex-specific when no override is stored.
void main() {
  group('ConfigEntity.seedWaterGoalForSex', () {
    test('female users seed at 1500 ml (EFSA-derived)', () {
      expect(ConfigEntity.seedWaterGoalForSex(UserSexEntity.female), 1500);
    });

    test('male users seed at 1900 ml (EFSA-derived)', () {
      expect(ConfigEntity.seedWaterGoalForSex(UserSexEntity.male), 1900);
    });
  });

  group('ConfigEntity.effectiveDailyWaterGoalMl', () {
    test('returns the user override when one is stored', () {
      const config = ConfigEntity(
        false,
        AppThemeEntity.system,
        dailyWaterGoalMl: 2400,
      );
      expect(config.effectiveDailyWaterGoalMl(UserSexEntity.female), 2400);
    });

    test('falls back to the sex-based seed when no override is stored', () {
      const config = ConfigEntity(false, AppThemeEntity.system);
      expect(config.effectiveDailyWaterGoalMl(UserSexEntity.male), 1900);
      expect(config.effectiveDailyWaterGoalMl(UserSexEntity.female), 1500);
    });
  });
}
