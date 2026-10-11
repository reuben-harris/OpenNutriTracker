import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_memory.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  test('amount defaults persist separately per profile and source', () async {
    final dir = await Directory.systemTemp.createTemp('amount-memory');
    Hive.init(dir.path);
    try {
      var box = await Hive.openBox<Map>('profile-a');
      final meal = food('123', 'Food');
      const selection = FoodAmountSelection(
        53,
        FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
      );
      await FoodAmountMemory(box).remember(meal, selection);
      await box.close();
      box = await Hive.openBox<Map>('profile-a');
      expect(FoodAmountMemory(box).read(meal)!.amount, 53);
      expect(box.values.single, {'amount': 53.0, 'unit': 'g', 'base': 'g'});
      expect(
        FoodAmountMemory(
          box,
        ).read(food('123', 'Other', source: MealSourceEntity.recipe)),
        isNull,
      );
      final other = await Hive.openBox<Map>('profile-b');
      expect(FoodAmountMemory(other).read(meal), isNull);
      await box.clear();
      expect(FoodAmountMemory(box).read(meal), isNull);
      await box.close();
      await FoodAmountMemory(
        box,
      ).remember(meal, selection); // Best effort after close.
    } finally {
      await Hive.close();
      await dir.delete(recursive: true);
    }
  });
  test('an unsupported remembered pair is discarded together', () {
    const selection = FoodAmountPreference(53, 'serving', 'g');
    expect(supportedRememberedAmount(food('x', 'Food'), selection), isNull);
  });
  test('remembered servings use the current food conversion', () {
    final meal = MealEntity(
      code: 'food',
      name: 'Food',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: 35,
      servingUnit: 'g',
      servingSize: '35 g',
      nutriments: food('x', 'Food').nutriments,
      source: MealSourceEntity.custom,
    );
    final selected = supportedRememberedAmount(
      meal,
      const FoodAmountPreference(2, 'serving', 'g'),
    )!;
    expect(selected.amount, 2);
    expect(selected.option.factor, 35);
    expect(selected.baseAmount, 70);
    expect(
      supportedRememberedAmount(
        meal,
        const FoodAmountPreference(2, 'serving', 'ml'),
      ),
      isNull,
    );
  });
}
