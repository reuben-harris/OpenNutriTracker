import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

/// Pure-function helper that aggregates a list of intakes into per-nutrient
/// totals. Pulled out of the widget so unit tests can exercise it directly
/// without spinning up a Flutter binding. `weekly: true` divides every total
/// by 7 to convert a seven-day window into an average daily intake.
class NutrientPanelTotals {
  final double fiberG;
  final double sodiumMg;
  final double saturatedFatG;
  final double sugarG;
  final double calciumMg;
  final double ironMg;
  final double potassiumMg;
  final double vitaminDMcg;
  final double vitaminB12Mcg;
  final double magnesiumMg;

  const NutrientPanelTotals({
    required this.fiberG,
    required this.sodiumMg,
    required this.saturatedFatG,
    required this.sugarG,
    required this.calciumMg,
    required this.ironMg,
    required this.potassiumMg,
    required this.vitaminDMcg,
    required this.vitaminB12Mcg,
    required this.magnesiumMg,
  });

  factory NutrientPanelTotals.fromIntakes(
    List<IntakeEntity> intakes, {
    bool weekly = false,
  }) {
    final divisor = weekly ? 7.0 : 1.0;
    double sum(double? Function(MealNutrimentsEntity n) pick) {
      return intakes.fold<double>(0, (running, intake) {
            final per100 = pick(intake.meal.nutriments);
            if (per100 == null) return running;
            return running + intake.amount * per100 / 100.0;
          }) /
          divisor;
    }

    return NutrientPanelTotals(
      fiberG: sum((n) => n.fiber100),
      sodiumMg: sum((n) => n.sodium100),
      saturatedFatG: sum((n) => n.saturatedFat100),
      sugarG: sum((n) => n.sugars100),
      calciumMg: sum((n) => n.calcium100),
      ironMg: sum((n) => n.iron100),
      potassiumMg: sum((n) => n.potassium100),
      vitaminDMcg: sum((n) => n.vitaminD100),
      vitaminB12Mcg: sum((n) => n.vitaminB12100),
      magnesiumMg: sum((n) => n.magnesium100),
    );
  }
}

/// Stable identifiers for the panel's nutrient rows. These are the keys the
/// per-nutrient visibility map uses on [ConfigEntity], so renaming any of
/// them is a backward-incompatible change: existing visibility overrides
/// would silently lose their associations.
class NutrientPanelKeys {
  NutrientPanelKeys._();

  static const String fiber = 'fiber';
  static const String sodium = 'sodium';
  static const String saturatedFat = 'saturated_fat';
  static const String sugar = 'sugar';
  static const String calcium = 'calcium';
  static const String iron = 'iron';
  static const String potassium = 'potassium';
  static const String vitaminD = 'vitamin_d';
  static const String vitaminB12 = 'vitamin_b12';
  static const String magnesium = 'magnesium';

  static const List<String> all = <String>[
    fiber,
    sodium,
    saturatedFat,
    sugar,
    calcium,
    iron,
    potassium,
    vitaminD,
    vitaminB12,
    magnesium,
  ];
}
