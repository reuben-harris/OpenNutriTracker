import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';

MealEntity food({
  String? unit,
  double? serving,
  String? servingSize,
  List<MealPortionEntity> portions = const [],
}) => MealEntity(
  code: 'food',
  name: 'Food',
  url: null,
  mealQuantity: null,
  mealUnit: unit,
  servingQuantity: serving,
  servingUnit: unit,
  servingSize: servingSize,
  portions: portions,
  nutriments: MealNutrimentsEntity.empty(),
  source: MealSourceEntity.custom,
);

void main() {
  test('standard units resolve through a common mass/volume basis', () {
    final meal = food();
    for (final entry in {
      'g': 1.0,
      'kg': 1000.0,
      'mg': 0.001,
      'µg': 0.000001,
      'oz': 28.3495,
      'ml': 1.0,
      'l': 1000.0,
      'cl': 10.0,
      'dl': 100.0,
      'fl oz': 29.5735,
      'fl.oz': 29.5735,
      'gml': 1.0,
      'g/ml': 1.0,
    }.entries) {
      expect(
        resolveFoodAmount(2, entry.key, meal)!.baseAmount,
        closeTo(2 * entry.value, 1e-10),
        reason: entry.key,
      );
    }
    expect(
      resolveFoodAmount(2, 'g/ml', food(unit: 'ml'))!.option.baseUnit,
      'ml',
    );
    expect(resolveFoodAmount(2, 'ml', food(unit: 'g')), isNull);
    expect(resolveFoodAmount(2, 'g', food(unit: 'ml')), isNull);
  });
  test('unknown units and unresolved servings never become grams', () {
    for (final unit in [
      'unknown',
      'tablespoon',
      'serving',
      'portion:missing',
      'serving#0',
      '',
    ]) {
      expect(resolveFoodAmount(2, unit, food()), isNull, reason: unit);
    }
    expect(resolveFoodAmount(2, 'serving', food(servingSize: '1 egg')), isNull);
    expect(
      resolveFoodAmount(
        2,
        'serving',
        food(servingSize: '1 slice (25 g)'),
      )!.baseAmount,
      50,
    );
  });
  test('invalid quantities, factors and overflow cannot resolve', () {
    for (final amount in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      double.maxFinite,
    ]) {
      expect(resolveFoodAmount(amount, 'kg', food()), isNull);
    }
    for (final factor in [0.0, -1.0, double.nan, double.infinity]) {
      final meal = food(
        serving: factor,
        portions: [
          MealPortionEntity(
            id: 'bad',
            label: 'Bad',
            gramWeight: factor,
            localized: false,
          ),
        ],
      );
      expect(resolveFoodAmount(1, 'serving', meal), isNull);
      expect(resolveFoodAmount(1, 'portion:bad', meal), isNull);
    }
  });
  test('snapshot serialization preserves precision and portion identity', () {
    const original = FoodAmountSelection(
      2.123456789,
      FoodAmountOption(
        unit: 'portion:slice',
        baseUnit: 'g',
        factor: 38.123456789,
        label: '1 slice',
      ),
    );
    final restored = FoodAmountSelection.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.baseAmount, original.baseAmount);
    expect(
      () => FoodAmountSelection.fromJson({
        'amount': 1,
        'unit': 'serving',
        'baseUnit': 'g',
        'factor': 0,
      }),
      throwsFormatException,
    );
  });
}
