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
    final selection = FoodAmountSelection(
      53,
      const FoodAmountOption(unit: 'serving', baseUnit: 'g', factor: 30),
    );
    expect(supportedRememberedAmount(food('x', 'Food'), selection), isNull);
  });
}
