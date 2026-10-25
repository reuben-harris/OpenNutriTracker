import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/pal_calc.dart';

UserEntity _user(UserSexEntity sex, UserPALEntity pal) {
  return UserEntity(
    birthday: DateTime(1995, 1, 1),
    heightCM: 170,
    weightKG: 70,
    sex: sex,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: pal,
  );
}

void main() {
  group('PalCalc.getPALValueFromActivityCategory', () {
    test('maps each category to its IOM PAL band', () {
      expect(
        PalCalc.getPALValueFromActivityCategory(
          _user(UserSexEntity.male, UserPALEntity.sedentary),
        ),
        1.25,
      );
      expect(
        PalCalc.getPALValueFromActivityCategory(
          _user(UserSexEntity.male, UserPALEntity.lowActive),
        ),
        1.5,
      );
      expect(
        PalCalc.getPALValueFromActivityCategory(
          _user(UserSexEntity.male, UserPALEntity.active),
        ),
        1.75,
      );
      expect(
        PalCalc.getPALValueFromActivityCategory(
          _user(UserSexEntity.male, UserPALEntity.veryActive),
        ),
        2.2,
      );
    });
  });

  group('PalCalc.getPAValueForFormula', () {
    test('sedentary: PA = 1.0 regardless of formula sex', () {
      expect(
        PalCalc.getPAValueForFormula(palValue: 1.25, isMaleFormula: true),
        1.0,
      );
      expect(
        PalCalc.getPAValueForFormula(palValue: 1.25, isMaleFormula: false),
        1.0,
      );
    });

    test('lowActive: male PA 1.12, female PA 1.14', () {
      expect(
        PalCalc.getPAValueForFormula(palValue: 1.5, isMaleFormula: true),
        1.12,
      );
      expect(
        PalCalc.getPAValueForFormula(palValue: 1.5, isMaleFormula: false),
        1.14,
      );
    });

    test('active: PA = 1.27 regardless of formula sex', () {
      expect(
        PalCalc.getPAValueForFormula(palValue: 1.75, isMaleFormula: true),
        1.27,
      );
      expect(
        PalCalc.getPAValueForFormula(palValue: 1.75, isMaleFormula: false),
        1.27,
      );
    });

    test('veryActive: male PA 1.54, female PA 1.45', () {
      expect(
        PalCalc.getPAValueForFormula(palValue: 2.2, isMaleFormula: true),
        1.54,
      );
      expect(
        PalCalc.getPAValueForFormula(palValue: 2.2, isMaleFormula: false),
        1.45,
      );
    });
  });

  group('PalCalc.getPAValueFromPALValue (sex-keyed wrapper)', () {
    test('male user gets male PA at lowActive and veryActive', () {
      final user = _user(UserSexEntity.male, UserPALEntity.lowActive);
      expect(PalCalc.getPAValueFromPALValue(user, 1.5), 1.12);
      expect(PalCalc.getPAValueFromPALValue(user, 2.2), 1.54);
    });

    test('female user gets female PA at lowActive and veryActive', () {
      final user = _user(UserSexEntity.female, UserPALEntity.lowActive);
      expect(PalCalc.getPAValueFromPALValue(user, 1.5), 1.14);
      expect(PalCalc.getPAValueFromPALValue(user, 2.2), 1.45);
    });
  });
}
