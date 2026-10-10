import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// A conversion snapshot. Named portions use their description and weight,
/// rather than a position in a catalogue's current list.
class FoodAmountOption {
  const FoodAmountOption({required this.unit, required this.baseUnit,
    required this.factor, this.label});
  final String unit;
  final String baseUnit;
  final double factor;
  final String? label;
  bool get isNamed => unit == 'serving' || unit.startsWith('portion:');
  bool get isValid => (baseUnit == 'g' || baseUnit == 'ml') && factor.isFinite && factor > 0;
  String get identity => '$unit:$baseUnit:$factor';
  String get displayLabel => label ?? unit;
  double toBase(double amount) => amount * factor;

  static FoodAmountOption standard(FoodAmountUnit unit) => FoodAmountOption(
    unit: unit.label, baseUnit: unit.baseUnit, factor: unit.factor);
}

class FoodAmountSelection {
  const FoodAmountSelection(this.amount, this.option);
  final double amount;
  final FoodAmountOption option;
  double get baseAmount => option.toBase(amount);
}

List<FoodAmountOption> foodAmountOptions(MealEntity meal) {
  final result = <FoodAmountOption>[];
  for (final portion in meal.portions) {
    final label = portion.englishLabel ?? portion.label;
    final option = FoodAmountOption(unit: 'portion:${Uri.encodeComponent(label)}:${portion.gramWeight}',
      baseUnit: 'g', factor: portion.gramWeight, label: portion.label);
    if (option.isValid && !result.any((o) => o.identity == option.identity)) result.add(option);
  }
  final serving = meal.scalableServingQuantity;
  if (serving != null && serving.isFinite && serving > 0) {
    result.add(FoodAmountOption(unit: 'serving',
      baseUnit: MealEntity.liquidUnits.contains(meal.servingUnit) ? 'ml' : meal.isLiquid ? 'ml' : 'g',
      factor: serving, label: meal.servingSize?.trim().isNotEmpty == true ? meal.servingSize : null));
  }
  if (!meal.isLiquid) {
    result.addAll([FoodAmountUnit.g, FoodAmountUnit.kg, FoodAmountUnit.oz].map(FoodAmountOption.standard));
  }
  if (!meal.isSolid && !meal.isCatalogueFood) {
    result.addAll([FoodAmountUnit.ml, FoodAmountUnit.l, FoodAmountUnit.flOz].map(FoodAmountOption.standard));
  }
  return result;
}

FoodAmountSelection defaultFoodAmount(MealEntity meal, {required bool imperial, required bool rawUnits}) {
  final options = foodAmountOptions(meal);
  if (meal.isQuickAdd && meal.hasQuickAddWeight) {
    final base = double.tryParse(meal.mealQuantity ?? '');
    final unit = meal.isLiquid ? 'ml' : 'g';
    if (base != null && base.isFinite && base > 0) return FoodAmountSelection(base, options.firstWhere((o) => o.unit == unit));
  }
  if (!rawUnits && !meal.isCatalogueFood) {
    final named = options.where((o) => o.isNamed).firstOrNull;
    if (named != null) return FoodAmountSelection(1, named);
  }
  final unit = meal.isLiquid ? (imperial ? 'fl oz' : 'ml') : (imperial && !meal.isCatalogueFood ? 'oz' : 'g');
  final option = options.firstWhere((o) => o.unit == unit, orElse: () => options.first);
  return FoodAmountSelection(option.unit == 'oz' || option.unit == 'fl oz' ? 1 : 100, option);
}

String formatFoodAmount(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
