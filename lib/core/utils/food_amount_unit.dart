import 'package:opennutritracker/core/utils/calc/unit_calc.dart';

/// Mass and volume units that the app can convert to its g/ml storage basis.
enum FoodAmountUnit {
  g('g', 'g', 1),
  kg('kg', 'g', 1000),
  mg('mg', 'g', 0.001),
  microgram('µg', 'g', 0.000001),
  oz('oz', 'g', 28.3495),
  ml('ml', 'ml', 1),
  l('l', 'ml', 1000),
  dl('dl', 'ml', 100),
  cl('cl', 'ml', 10),
  flOz('fl oz', 'ml', 29.5735);

  const FoodAmountUnit(this.label, this.baseUnit, this.factor);
  final String label;
  final String baseUnit;
  final double factor;
  double toBase(double amount) => switch (this) {
    oz => UnitCalc.ozToG(amount),
    flOz => UnitCalc.flOzToMl(amount),
    _ => amount * factor,
  };
  double fromBase(double amount) => amount / factor;
  static FoodAmountUnit fromLabel(String? label) => values.firstWhere(
    (u) => u.label == label || (u == flOz && label == 'fl.oz'),
    orElse: () => g,
  );
}
