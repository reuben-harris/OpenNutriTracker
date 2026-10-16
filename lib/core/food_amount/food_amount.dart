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
      unit.trim().isNotEmpty &&
      (baseUnit == 'g' || baseUnit == 'ml') &&
      factor.isFinite &&
      factor > 0;
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

  factory FoodAmountSelection.fromSnapshot({
    required double amount,
    required String unit,
    required String baseUnit,
    required double factor,
    String? label,
  }) {
    final selection = FoodAmountSelection(
      amount,
      FoodAmountOption(
        unit: unit,
        baseUnit: baseUnit,
        factor: factor,
        label: label,
      ),
    );
    selection.validate();
    return selection;
  }

  void validate() {
    if (!isValid) {
      throw const FormatException('Invalid food quantity or conversion');
    }
  }

  factory FoodAmountSelection.fromJson(Map<String, dynamic> json) =>
      FoodAmountSelection.fromSnapshot(
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        baseUnit: json['baseUnit'] as String,
        factor: (json['factor'] as num).toDouble(),
        label: json['label'] as String?,
      );

  Map<String, dynamic> toJson() {
    validate();
    return {
      'amount': amount,
      'unit': option.unit,
      'baseUnit': option.baseUnit,
      'factor': option.factor,
      if (option.label != null) 'label': option.label,
    };
  }

  @override
  List<Object?> get props => [amount, option];
}

void validateFoodQuantity(FoodAmountSelection? quantity, MealEntity meal) {
  if (quantity == null) {
    if (meal.isQuickAdd && !meal.hasQuickAddWeight) return;
    throw const FormatException('A weighted intake requires a quantity');
  }
  quantity.validate();
}

/// UI choices and named conversions available for this food.
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

FoodAmountSelection defaultFoodAmount(MealEntity meal) => FoodAmountSelection(
  100,
  FoodAmountOption.standard(
    meal.isLiquid ? FoodAmountUnit.ml : FoodAmountUnit.g,
  ),
);

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

/// Resolves an explicit request. Failure never changes the requested unit.
FoodAmountOption? resolveFoodAmountOption(
  MealEntity meal,
  String unit, {
  String? baseUnit,
}) {
  final canonical = switch (unit.trim()) {
    'fl.oz' => 'fl oz',
    'gml' || 'g/ml' => meal.isLiquid ? 'ml' : 'g',
    final unit => unit,
  };
  final options = foodAmountOptions(meal);
  final direct = options
      .where(
        (o) =>
            o.unit == canonical && (baseUnit == null || o.baseUnit == baseUnit),
      )
      .firstOrNull;
  if (direct != null) return direct;
  // Small metric units share the same availability rules as the displayed
  // mass/volume choices; their factors come from the standard unit registry.
  final standard = FoodAmountUnit.values
      .where((u) => u.label == canonical)
      .firstOrNull;
  if (standard == null ||
      (baseUnit != null && standard.baseUnit != baseUnit) ||
      !options.any((o) => o.baseUnit == standard.baseUnit)) {
    return null;
  }
  return FoodAmountOption.standard(standard);
}

FoodAmountSelection? resolveFoodAmount(
  double amount,
  String unit,
  MealEntity meal,
) {
  final option = resolveFoodAmountOption(meal, unit);
  if (option == null) return null;
  final selection = FoodAmountSelection(amount, option);
  return selection.isValid ? selection : null;
}
