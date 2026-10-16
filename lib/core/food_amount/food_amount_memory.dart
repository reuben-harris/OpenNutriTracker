import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// A convenience default, without a historical conversion snapshot.
class FoodAmountPreference {
  const FoodAmountPreference(this.amount, this.unit, this.baseUnit);
  final double amount;
  final String unit;
  final String baseUnit;
}

class FoodAmountMemory {
  FoodAmountMemory(this.box);
  final Box<Map> box;
  final _log = Logger('FoodAmountMemory');
  String? _key(MealEntity meal) => meal.code?.trim().isNotEmpty == true
      ? jsonEncode([meal.source.name, meal.code])
      : null;

  FoodAmountPreference? read(MealEntity meal) {
    try {
      final key = _key(meal);
      if (key == null || !box.isOpen) return null;
      final data = box.get(key);
      if (data == null) return null;
      final amount = (data['amount'] as num?)?.toDouble();
      final unit = data['unit'] as String?;
      final base = data['base'] as String?;
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          unit == null ||
          unit.isEmpty ||
          (base != 'g' && base != 'ml')) {
        return null;
      }
      return FoodAmountPreference(amount, unit, base!);
    } catch (error, stack) {
      _log.warning('Could not read amount preference', error, stack);
      return null;
    }
  }

  Future<void> remember(MealEntity meal, FoodAmountSelection selection) async {
    try {
      final key = _key(meal);
      if (key == null || !box.isOpen) return;
      await box.put(key, {
        'amount': selection.amount,
        'unit': selection.option.unit,
        'base': selection.option.baseUnit,
      });
    } catch (error, stack) {
      _log.warning('Could not save amount preference', error, stack);
    }
  }
}

FoodAmountSelection? supportedRememberedAmount(
  MealEntity meal,
  FoodAmountPreference? remembered,
) {
  if (remembered == null) return null;
  final option = resolveFoodAmountOption(
    meal,
    remembered.unit,
    baseUnit: remembered.baseUnit,
  );
  return option == null ? null : FoodAmountSelection(remembered.amount, option);
}
