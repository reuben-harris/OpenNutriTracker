import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'dart:convert';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/features/home/domain/entity/shared_meal_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

// Issue #451 — Quick Add. The form stores values per 100 g on the
// nutriments entity, with the intake carrying amount=100 g, so the totals
// math in IntakeEntity returns the exact numbers the user typed. This
// test pins that invariant so a future refactor of the nutriments model
// can't silently break the Quick Add flow.

IntakeEntity _buildIntake({
  required double? kcal,
  double? carbs,
  double? fat,
  double? protein,
}) {
  final nutriments = MealNutrimentsEntity(
    energyKcal100: kcal,
    carbohydrates100: carbs,
    fat100: fat,
    proteins100: protein,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  );
  final meal = MealEntity(
    code: 'quick-add-test',
    name: 'Quick add',
    url: null,
    mealQuantity: '100',
    mealUnit: 'gml',
    servingQuantity: null,
    servingUnit: 'gml',
    servingSize: '',
    nutriments: nutriments,
    source: MealSourceEntity.custom,
    isQuickAdd: true,
  );
  return IntakeEntity(
    id: 'intake-test',
    unit: 'g',
    amount: 100,
    type: IntakeTypeEntity.breakfast,
    meal: meal,
    dateTime: DateTime(2026, 5, 23),
  );
}

void main() {
  test('historical Quick Add is recognized without changing known zeros', () {
    final dbo = MealDBO.fromMealEntity(_buildIntake(kcal: 0).meal);
    final json = jsonDecode(jsonEncode(dbo.toJson())) as Map<String, dynamic>;
    json.remove('isQuickAdd');
    final old = MealEntity.fromMealDBO(MealDBO.fromJson(json));
    expect(old.isQuickAdd, true);
    expect(old.nutriments.energyKcal100, 0);
    json['servingQuantity'] = 100;
    expect(MealEntity.fromMealDBO(MealDBO.fromJson(json)).isQuickAdd, false);
  });
  for (final kcal in [null, 0.0, 120.0]) {
    test(
      'Quick Add discriminator and unknowns survive sharing and exports: $kcal',
      () {
        final intake = _buildIntake(kcal: kcal);
        final shared = SharedMealItem.fromArray(
          SharedMealItem.fromIntakeEntity(intake).toArray(),
        ).toMealEntity();
        expect(shared.isQuickAdd, true);
        expect(shared.nutriments.energyKcal100, kcal);
        expect(shared.nutriments.fat100, isNull);
        final dbo = IntakeDBO.fromIntakeEntity(intake);
        final decoded = IntakeDBO.fromJson(
          jsonDecode(jsonEncode(dbo.toJson())),
        );
        expect(decoded.meal.isQuickAdd, true);
        expect(decoded.meal.nutriments.energyKcal100, kcal);
        final csv = CsvDataExporter.intakesToCsv([dbo]);
        final imported = CsvDataExporter.parseIntakesFromCsv(csv).single;
        expect(imported.meal.isQuickAdd, true);
        expect(imported.meal.nutriments.energyKcal100, kcal);
      },
    );
  }
  group('Quick Add — entered values round-trip through IntakeEntity', () {
    test('500 kcal entered returns 500 kcal total', () {
      final intake = _buildIntake(kcal: 500);
      expect(intake.totalKcal, closeTo(500, 0.0001));
    });

    test('macros round-trip exactly when entered alongside kcal', () {
      final intake = _buildIntake(kcal: 420, carbs: 30, fat: 12, protein: 25);
      expect(intake.totalKcal, closeTo(420, 0.0001));
      expect(intake.totalCarbsGram, closeTo(30, 0.0001));
      expect(intake.totalFatsGram, closeTo(12, 0.0001));
      expect(intake.totalProteinsGram, closeTo(25, 0.0001));
    });

    test('omitted macros stay at zero in totals', () {
      final intake = _buildIntake(kcal: 100);
      expect(intake.totalCarbsGram, 0);
      expect(intake.totalFatsGram, 0);
      expect(intake.totalProteinsGram, 0);
    });
  });
}
