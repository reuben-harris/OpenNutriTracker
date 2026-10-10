import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// Convenience defaults only; entries remain the source of truth for edits.
class FoodAmountMemory {
  FoodAmountMemory(this.box);
  final Box<Map> box;
  final _log = Logger('FoodAmountMemory');
  String? _key(MealEntity meal) => meal.code?.trim().isNotEmpty == true
      ? jsonEncode([meal.source.name, meal.code])
      : null;
  FoodAmountSelection? read(MealEntity meal) {
    try {
      final key = _key(meal);
      if (key == null || !box.isOpen) return null;
      final data = box.get(key);
      if (data == null) return null;
      final amount = (data['amount'] as num?)?.toDouble();
      final factor = (data['factor'] as num?)?.toDouble();
      final unit = data['unit'] as String?;
      final base = data['base'] as String?;
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          factor == null ||
          unit == null ||
          base == null) {
        return null;
      }
      final option = FoodAmountOption(
        unit: unit,
        baseUnit: base,
        factor: factor,
        label: data['label'] as String?,
      );
      return option.isValid ? FoodAmountSelection(amount, option) : null;
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
        'factor': selection.option.factor,
        'label': selection.option.label,
      });
    } catch (error, stack) {
      _log.warning('Could not save amount preference', error, stack);
    }
  }
}

FoodAmountSelection? supportedRememberedAmount(
  MealEntity meal,
  FoodAmountSelection? remembered,
) {
  if (remembered == null) return null;
  final option = foodAmountOptions(
    meal,
  ).where((o) => o.identity == remembered.option.identity).firstOrNull;
  return option == null ? null : FoodAmountSelection(remembered.amount, option);
}
