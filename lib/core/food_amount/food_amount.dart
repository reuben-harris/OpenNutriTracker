import 'package:opennutritracker/features/add_meal/util/portion_unit.dart';
import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// A conversion snapshot with a unit identity independent of its weight or label.
class FoodAmountOption extends Equatable {
  const FoodAmountOption({
    required this.unit,
    required this.baseUnit,
    required this.factor,
    this.label,
  });
  final String unit;
  final String baseUnit;
  final double factor;
  final String? label;
  bool get isNamed => unit == 'serving' || unit.startsWith('portion:');
  bool get isValid =>
      (baseUnit == 'g' || baseUnit == 'ml') && factor.isFinite && factor > 0;
  String get identity => '$unit:$baseUnit:$factor';
  String get displayLabel => label ?? unit;
  double toBase(double amount) => amount * factor;

  @override
  List<Object?> get props => [unit, baseUnit, factor, label];

  static FoodAmountOption standard(FoodAmountUnit unit) => FoodAmountOption(
    unit: unit.label,
    baseUnit: unit.baseUnit,
    factor: unit.factor,
  );
}

class FoodAmountSelection extends Equatable {
  const FoodAmountSelection(this.amount, this.option);
  final double amount;
  final FoodAmountOption option;
  double get baseAmount => option.toBase(amount);
  bool get isValid =>
      amount.isFinite &&
      amount > 0 &&
      option.isValid &&
      baseAmount.isFinite &&
      baseAmount > 0;

  @override
  List<Object?> get props => [amount, option];
}

void validateFoodQuantity(FoodAmountSelection? quantity, MealEntity meal) {
  if (quantity == null) {
    if (meal.isQuickAdd && !meal.hasQuickAddWeight) return;
    throw const FormatException('A weighted intake requires a quantity');
  }
  if (!quantity.isValid) {
    throw const FormatException('Invalid food quantity or conversion');
  }
}

/// Resolves a logical unit against current food data, without changing quantity.
FoodAmountOption? currentFoodAmountOption(
  MealEntity meal,
  String unit,
  String baseUnit,
) {
  final options = foodAmountOptions(meal);
  final standard = FoodAmountUnit.values
      .where((u) => u.label == unit)
      .firstOrNull;
  if (standard != null) {
    return standard.baseUnit == baseUnit &&
            options.any((o) => o.baseUnit == baseUnit)
        ? FoodAmountOption.standard(standard)
        : null;
  }
  return options
      .where((o) => o.unit == unit && o.baseUnit == baseUnit)
      .firstOrNull;
}

List<FoodAmountOption> foodAmountOptions(MealEntity meal) {
  final result = <FoodAmountOption>[];
  for (final portion in meal.portions) {
    final option = FoodAmountOption(
      unit: 'portion:${portion.id}',
      baseUnit: 'g',
      factor: portion.gramWeight,
      label: portion.label,
    );
    if (option.isValid && !result.any((o) => o.identity == option.identity)) {
      result.add(option);
    }
  }
  final serving = meal.scalableServingQuantity;
  if (serving != null && serving.isFinite && serving > 0) {
    result.add(
      FoodAmountOption(
        unit: 'serving',
        baseUnit: MealEntity.liquidUnits.contains(meal.servingUnit)
            ? 'ml'
            : meal.isLiquid
            ? 'ml'
            : 'g',
        factor: serving,
        label: meal.servingSize?.trim().isNotEmpty == true
            ? meal.servingSize
            : null,
      ),
    );
  }
  if (!meal.isLiquid) {
    result.addAll(
      [
        FoodAmountUnit.g,
        FoodAmountUnit.kg,
        FoodAmountUnit.oz,
      ].map(FoodAmountOption.standard),
    );
  }
  if (!meal.isSolid && !meal.isCatalogueFood) {
    result.addAll(
      [
        FoodAmountUnit.ml,
        FoodAmountUnit.l,
        FoodAmountUnit.flOz,
      ].map(FoodAmountOption.standard),
    );
  }
  return result;
}

FoodAmountSelection defaultFoodAmount(
  MealEntity meal, {
  required bool imperial,
  required bool rawUnits,
}) {
  final options = foodAmountOptions(meal);
  if (meal.isQuickAdd && meal.hasQuickAddWeight) {
    final base = double.tryParse(meal.mealQuantity ?? '');
    final unit = meal.isLiquid ? 'ml' : 'g';
    if (base != null && base.isFinite && base > 0) {
      return FoodAmountSelection(
        base,
        options.firstWhere((o) => o.unit == unit),
      );
    }
  }
  if (!rawUnits && !meal.isCatalogueFood) {
    final named = options.where((o) => o.isNamed).firstOrNull;
    if (named != null) return FoodAmountSelection(1, named);
  }
  final unit = meal.isLiquid
      ? (imperial ? 'fl oz' : 'ml')
      : (imperial && !meal.isCatalogueFood ? 'oz' : 'g');
  final option = options.firstWhere(
    (o) => o.unit == unit,
    orElse: () => options.first,
  );
  return FoodAmountSelection(
    option.unit == 'oz' || option.unit == 'fl oz' ? 1 : 100,
    option,
  );
}

String formatFoodAmount(double value) {
  final text = value.toString();
  if (!text.contains('e')) {
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
  // Keep resolved expressions editable by the decimal-only amount field.
  final parts = text.split('e');
  final negative = parts.first.startsWith('-');
  final mantissa = negative ? parts.first.substring(1) : parts.first;
  final digits = mantissa.replaceAll('.', '');
  final decimalAt = mantissa.indexOf('.');
  final point =
      (decimalAt < 0 ? mantissa.length : decimalAt) + int.parse(parts.last);
  final decimal = point <= 0
      ? '0.${'0' * -point}$digits'
      : point >= digits.length
      ? '$digits${'0' * (point - digits.length)}'
      : '${digits.substring(0, point)}.${digits.substring(point)}';
  return negative ? '-$decimal' : decimal;
}

FoodAmountSelection selectionForFoodUnit(
  double amount,
  String unit,
  MealEntity meal,
) {
  final options = foodAmountOptions(meal);
  final canonical = unit == 'fl.oz' ? 'fl oz' : unit;
  final direct = currentFoodAmountOption(
    meal,
    canonical,
    MealEntity.liquidUnits.contains(canonical) ? 'ml' : 'g',
  );
  if (direct != null) return FoodAmountSelection(amount, direct);
  if (isPortionUnit(unit) && meal.portions.isNotEmpty) {
    final index = effectivePortionIndex(unit);
    if (index >= 0 && index < meal.portions.length) {
      final portion = meal.portions[index];
      return FoodAmountSelection(
        amount,
        options.firstWhere((o) => o.unit == 'portion:${portion.id}'),
      );
    }
  }
  final option = options.where((o) => o.unit == canonical).firstOrNull;
  return FoodAmountSelection(
    amount,
    option ??
        FoodAmountOption(
          unit: meal.isLiquid ? 'ml' : 'g',
          baseUnit: meal.isLiquid ? 'ml' : 'g',
          factor: 1,
        ),
  );
}
