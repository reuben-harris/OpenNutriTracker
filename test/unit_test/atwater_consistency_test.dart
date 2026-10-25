import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

MealNutrimentsEntity _n({
  double? energy,
  double? carbs,
  double? fat,
  double? protein,
}) => MealNutrimentsEntity(
  energyKcal100: NutrientAmount.fromNumber(energy),
  carbohydrates100: NutrientAmount.fromNumber(carbs),
  fat100: NutrientAmount.fromNumber(fat),
  proteins100: NutrientAmount.fromNumber(protein),
  sugars100: null,
  saturatedFat100: null,
  fiber100: null,
);

void main() {
  group('Atwater energy consistency', () {
    test('coherent product has a small relative error and is consistent', () {
      // 4*10 + 4*5 + 9*5 = 105 vs declared 100 -> 5% error.
      final n = _n(energy: 100, carbs: 10, fat: 5, protein: 5);
      expect(atwaterEnergyRelativeError(n), closeTo(0.05, 1e-12));
      expect(isAtwaterConsistent(n), isTrue);
    });

    test('declared kcal far above macro-implied energy is inconsistent', () {
      // macros imply 4*5 + 4*1 + 9*1 = 33 vs declared 100 -> 67% error.
      final n = _n(energy: 100, carbs: 5, fat: 1, protein: 1);
      expect(atwaterEnergyRelativeError(n), closeTo(0.67, 1e-12));
      expect(isAtwaterConsistent(n), isFalse);
    });

    test('a unit slip (kJ logged as kcal) is caught', () {
      // ~2252 kJ stored where kcal expected, against ~540 kcal of macros.
      final n = _n(energy: 2252, carbs: 57, fat: 31, protein: 6);
      expect(isAtwaterConsistent(n), isFalse);
    });

    test('no declared energy -> no opinion (treated as consistent)', () {
      final n = _n(energy: null, carbs: 10, fat: 5, protein: 5);
      expect(atwaterEnergyRelativeError(n), isNull);
      expect(isAtwaterConsistent(n), isTrue);
    });

    test('one missing macro gives no opinion rather than assuming zero', () {
      final n = _n(energy: 500, carbs: 1, fat: 0);
      expect(atwaterEnergyRelativeError(n), isNull);
      expect(isAtwaterConsistent(n), isTrue);
    });

    test('no macros at all -> no opinion (treated as consistent)', () {
      final n = _n(energy: 200);
      expect(atwaterEnergyRelativeError(n), isNull);
      expect(isAtwaterConsistent(n), isTrue);
    });

    for (final (name, carbs, error, consistent) in [
      ('below tolerance', 19.99, 0.2496, true),
      ('exact tolerance', 20.0, 0.25, true),
      ('above tolerance', 20.01, 0.2504, false),
    ]) {
      test(name, () {
        final nutrients = _n(energy: 100, carbs: carbs, fat: 5, protein: 0);
        expect(atwaterEnergyRelativeError(nutrients), closeTo(error, 1e-12));
        expect(isAtwaterConsistent(nutrients), consistent);
      });
    }
    for (final energy in [0.0, -1.0]) {
      test('unusable declared energy $energy gives no verdict', () {
        final nutrients = _n(energy: energy, carbs: 10, fat: 5, protein: 5);
        expect(atwaterEnergyRelativeError(nutrients), isNull);
        expect(isAtwaterConsistent(nutrients), isTrue);
      });
    }
  });
}
