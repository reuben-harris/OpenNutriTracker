import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';

/// Convenience builder for a `MealEntity` carrying a specific micronutrient
/// profile. All fields default to zero so each test only has to spell out
/// the nutrients it cares about.
MealEntity _meal({
  double? fiber,
  double? sodium,
  double? saturatedFat,
  double? sugars,
  double? calcium,
  double? iron,
  double? potassium,
  double? vitaminD,
  double? vitaminB12,
  double? magnesium,
}) {
  return MealEntity(
    code: 'test',
    name: 'test meal',
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    source: MealSourceEntity.custom,
    nutriments: MealNutrimentsEntity(
      energyKcal100: NutrientAmount(100),
      carbohydrates100: NutrientAmount(0),
      fat100: NutrientAmount(0),
      proteins100: NutrientAmount(0),
      sugars100: NutrientAmount.fromNumber(sugars),
      saturatedFat100: NutrientAmount.fromNumber(saturatedFat),
      fiber100: NutrientAmount.fromNumber(fiber),
      sodium100: NutrientAmount.fromNumber(sodium),
      potassium100: NutrientAmount.fromNumber(potassium),
      magnesium100: NutrientAmount.fromNumber(magnesium),
      calcium100: NutrientAmount.fromNumber(calcium),
      iron100: NutrientAmount.fromNumber(iron),
      vitaminD100: NutrientAmount.fromNumber(vitaminD),
      vitaminB12100: NutrientAmount.fromNumber(vitaminB12),
    ),
  );
}

IntakeEntity _intake({
  required double amountGrams,
  required MealEntity meal,
  DateTime? at,
}) {
  return IntakeEntity(
    id: 'i-${meal.code}-${amountGrams.toString()}',
    quantity: FoodAmountSelection(
      amountGrams,
      FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
    ),
    type: IntakeTypeEntity.breakfast,
    meal: meal,
    dateTime: at ?? DateTime(2026, 1, 1),
  );
}

void main() {
  test(
    'empty recorded totals are zero; missing nutrients on logged foods remain unknown',
    () {
      final empty = NutrientTotals.fromIntakes([]);
      for (final n in Nutrients.all) {
        expect(empty.amounts[n.field], const NutrientAmount(0), reason: n.key);
      }
      expect(
        intakeNutrientTotal([], (n) => n.energyKcal100),
        const NutrientAmount(0),
      );
      final unknown = [_intake(amountGrams: 100, meal: _meal())];
      expect(NutrientTotals.fromIntakes(unknown).amounts['fiber100'], isNull);
      expect(intakeNutrientTotal(unknown, (n) => n.fiber100), isNull);
      final mixed = NutrientTotals.fromIntakes([
        ...unknown,
        _intake(amountGrams: 100, meal: _meal(fiber: 4)),
      ]).amounts['fiber100']!;
      expect(mixed.value, 4);
      expect(mixed.isPartial, isTrue);
    },
  );
  test(
    'daily averages include empty days as zero and retain unknown contributions',
    () {
      final known = NutrientTotals.fromIntakes([
        _intake(amountGrams: 100, meal: _meal(fiber: 14)),
      ]);
      final average = NutrientTotals.averageDays([known, NutrientTotals.zero]);
      expect(average.amounts['fiber100'], const NutrientAmount(7));
      final unknown = NutrientTotals.fromIntakes([
        _intake(amountGrams: 100, meal: _meal()),
      ]);
      final partial = NutrientTotals.averageDays([
        known,
        unknown,
        NutrientTotals.zero,
      ]);
      expect(partial.amounts['fiber100']!.value, closeTo(14 / 3, 1e-12));
      expect(partial.amounts['fiber100']!.isPartial, isTrue);
      expect(
        NutrientTotals.averageDays([]).amounts['fiber100'],
        const NutrientAmount(0),
      );
    },
  );
  group('NutrientTotals.fromIntakes — day view', () {
    test('aggregates three sample intakes for every surfaced nutrient', () {
      // Three foods, each carrying a slice of the nutrients we surface. The
      // expected totals are amount × (value100 / 100) summed across foods.
      final intakes = <IntakeEntity>[
        _intake(
          amountGrams: 200,
          meal: _meal(
            fiber: 5,
            sodium: 400,
            saturatedFat: 1.0,
            sugars: 6,
            calcium: 120,
            iron: 1.5,
            potassium: 350,
            vitaminD: 2.5,
            vitaminB12: 0.8,
            magnesium: 40,
          ),
        ),
        _intake(
          amountGrams: 150,
          meal: _meal(
            fiber: 8,
            sodium: 200,
            saturatedFat: 4.0,
            sugars: 10,
            calcium: 80,
            iron: 2.0,
            potassium: 600,
            vitaminD: 5.0,
            vitaminB12: 1.2,
            magnesium: 60,
          ),
        ),
        _intake(
          amountGrams: 100,
          meal: _meal(
            fiber: 2,
            sodium: 50,
            saturatedFat: 0.5,
            sugars: 1,
            calcium: 200,
            iron: 0.5,
            potassium: 100,
            vitaminD: 1.0,
            vitaminB12: 0.4,
            magnesium: 20,
          ),
        ),
      ];

      final totals = NutrientTotals.fromIntakes(intakes);

      // fiber: 200×5/100 + 150×8/100 + 100×2/100 = 10 + 12 + 2 = 24
      expect(totals.amounts['fiber100']?.value, closeTo(24.0, 1e-9));
      // sodium: 200×400/100 + 150×200/100 + 100×50/100 = 800 + 300 + 50 = 1150
      expect(totals.amounts['sodium100']?.value, closeTo(1150.0, 1e-9));
      // saturated fat: 200×1.0/100 + 150×4.0/100 + 100×0.5/100 = 2 + 6 + 0.5 = 8.5
      expect(totals.amounts['saturatedFat100']?.value, closeTo(8.5, 1e-9));
      // sugars: 200×6/100 + 150×10/100 + 100×1/100 = 12 + 15 + 1 = 28
      expect(totals.amounts['sugars100']?.value, closeTo(28.0, 1e-9));
      // calcium: 200×120/100 + 150×80/100 + 100×200/100 = 240 + 120 + 200 = 560
      expect(totals.amounts['calcium100']?.value, closeTo(560.0, 1e-9));
      // iron: 200×1.5/100 + 150×2.0/100 + 100×0.5/100 = 3 + 3 + 0.5 = 6.5
      expect(totals.amounts['iron100']?.value, closeTo(6.5, 1e-9));
      // potassium: 200×350/100 + 150×600/100 + 100×100/100 = 700 + 900 + 100 = 1700
      expect(totals.amounts['potassium100']?.value, closeTo(1700.0, 1e-9));
      // vitamin D: 200×2.5/100 + 150×5.0/100 + 100×1.0/100 = 5 + 7.5 + 1 = 13.5
      expect(totals.amounts['vitaminD100']?.value, closeTo(13.5, 1e-9));
      // vitamin B12: 200×0.8/100 + 150×1.2/100 + 100×0.4/100 = 1.6 + 1.8 + 0.4 = 3.8
      expect(totals.amounts['vitaminB12100']?.value, closeTo(3.8, 1e-9));
      // magnesium: 200×40/100 + 150×60/100 + 100×20/100 = 80 + 90 + 20 = 190
      expect(totals.amounts['magnesium100']?.value, closeTo(190.0, 1e-9));
    });

    test('sums known values and keeps wholly missing nutrients unknown', () {
      final intakes = [
        _intake(amountGrams: 100, meal: _meal(fiber: 4)),
        _intake(amountGrams: 100, meal: _meal()),
      ];

      final totals = NutrientTotals.fromIntakes(intakes);

      expect(totals.amounts['fiber100']?.value, closeTo(4.0, 1e-9));
      expect(totals.amounts['sodium100']?.value, isNull);
      expect(totals.amounts['vitaminD100']?.value, isNull);
    });
  });

  group('NutrientTotals.fromIntakes — week view', () {
    test('divides every total by 7 to land on a daily average', () {
      // Three days' worth of sample intakes, lumped into a single list (the
      // panel does the same — it pre-fetches the 7-day window and hands the
      // flattened list to the totals helper).
      final intakes = <IntakeEntity>[
        // Day 1
        _intake(
          amountGrams: 200,
          meal: _meal(fiber: 7, iron: 2.0, magnesium: 50, vitaminD: 4.0),
          at: DateTime(2026, 1, 1),
        ),
        // Day 2
        _intake(
          amountGrams: 100,
          meal: _meal(fiber: 5, iron: 3.0, magnesium: 80, vitaminD: 7.0),
          at: DateTime(2026, 1, 2),
        ),
        // Day 3
        _intake(
          amountGrams: 50,
          meal: _meal(fiber: 8, iron: 4.0, magnesium: 60, vitaminD: 10.0),
          at: DateTime(2026, 1, 3),
        ),
      ];

      final totals = NutrientTotals.fromIntakes(intakes, weekly: true);

      // fiber sum: 200×7/100 + 100×5/100 + 50×8/100 = 14 + 5 + 4 = 23
      // weekly average: 23 / 7 ≈ 3.2857
      expect(totals.amounts['fiber100']?.value, closeTo(23.0 / 7.0, 1e-9));
      // iron sum: 200×2.0/100 + 100×3.0/100 + 50×4.0/100 = 4 + 3 + 2 = 9
      expect(totals.amounts['iron100']?.value, closeTo(9.0 / 7.0, 1e-9));
      // magnesium sum: 200×50/100 + 100×80/100 + 50×60/100 = 100 + 80 + 30 = 210
      expect(totals.amounts['magnesium100']?.value, closeTo(210.0 / 7.0, 1e-9));
      // vitamin D sum: 200×4.0/100 + 100×7.0/100 + 50×10.0/100 = 8 + 7 + 5 = 20
      expect(totals.amounts['vitaminD100']?.value, closeTo(20.0 / 7.0, 1e-9));
    });

    test('empty week window starts with zero recorded amounts', () {
      final totals = NutrientTotals.fromIntakes(<IntakeEntity>[], weekly: true);
      expect(totals.amounts['fiber100']?.value, 0);
      expect(totals.amounts['iron100']?.value, 0);
      expect(totals.amounts['vitaminB12100']?.value, 0);
    });
  });

  group('ConfigEntity.isNutrientVisible', () {
    /// A minimal config — most fields don't matter for visibility behaviour.
    ConfigEntity withVisibility(Map<String, bool> v) =>
        ConfigEntity(AppThemeEntity.system, nutrientPanelVisibility: v);

    test('defaults to visible when the map is empty', () {
      final config = withVisibility(const {});
      for (final key in NutrientKeys.all) {
        expect(config.isNutrientVisible(key), isTrue, reason: 'key=$key');
      }
    });

    test('honours explicit false overrides', () {
      final config = withVisibility(const {
        NutrientKeys.vitaminD: false,
        NutrientKeys.magnesium: false,
      });
      expect(config.isNutrientVisible(NutrientKeys.vitaminD), isFalse);
      expect(config.isNutrientVisible(NutrientKeys.magnesium), isFalse);
      // Unrelated keys still default to visible.
      expect(config.isNutrientVisible(NutrientKeys.iron), isTrue);
      expect(config.isNutrientVisible(NutrientKeys.fiber), isTrue);
    });

    test('honours explicit true overrides as a no-op', () {
      final config = withVisibility(const {NutrientKeys.iron: true});
      expect(config.isNutrientVisible(NutrientKeys.iron), isTrue);
    });
  });

  group('NutrientKeys', () {
    test('every additional registry entry has a unique visibility key', () {
      expect(NutrientKeys.all, hasLength(Nutrients.additional.length));
      expect(NutrientKeys.all.toSet(), hasLength(Nutrients.additional.length));
      expect(
        NutrientKeys.all.toSet(),
        Nutrients.additional.map((n) => n.key).toSet(),
      );
    });
  });
}
