import 'package:opennutritracker/core/data/dbo/recipe_ingredient_dbo.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';
import '../search/food_search_engine_test.dart' show food;

const _portions = [
  MealPortionEntity(
    id: 'usda:survey:2',
    label: '1 Tasse, "gehackt"',
    englishLabel: '1 cup, chopped',
    gramWeight: 132.123456789,
    localized: true,
  ),
  MealPortionEntity(
    id: 'usda:survey:1',
    label: '1 nut',
    gramWeight: 2.5,
    localized: false,
  ),
];

MealEntity _meal() => MealEntity(
  code: 'usda:2707503',
  name: 'Macadamia nuts',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: 30.123456789,
  servingUnit: 'g',
  servingSize: '1 handful (30.123456789 g)',
  nutriments: food('x', 'Food').nutriments,
  source: MealSourceEntity.catalogue,
  portions: _portions,
);

void _expectServings(MealEntity actual) {
  expect(actual.portions, _portions);
  expect(actual.servingQuantity, _meal().servingQuantity);
  expect(actual.servingUnit, _meal().servingUnit);
  expect(actual.servingSize, _meal().servingSize);
}

void main() {
  test(
    'snapshots detach serving choices and include them in meal equality',
    () {
      final portions = _portions.toList();
      final original = _meal().withPortions(portions);
      final snapshot = MealDBO.fromMealEntity(original);
      portions.clear();
      final restored = MealEntity.fromMealDBO(snapshot);
      _expectServings(restored);
      expect(restored, isNot(original));
      expect(() => snapshot.portions.clear(), throwsUnsupportedError);
      expect(() => restored.portions.clear(), throwsUnsupportedError);
    },
  );

  test(
    'older JSON snapshots retain their serving without backfilling portions',
    () {
      final json =
          jsonDecode(jsonEncode(MealDBO.fromMealEntity(_meal())))
              as Map<String, dynamic>;
      json.remove('portions');
      final restored = MealEntity.fromMealDBO(MealDBO.fromJson(json));
      expect(restored.portions, isEmpty);
      expect(restored.servingQuantity, _meal().servingQuantity);
      expect(restored.servingSize, _meal().servingSize);
    },
  );

  test(
    'recipe ingredient Hive and JSON retain the original portion snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recipe-quantity',
      );
      Hive.init(directory.path);
      registerHiveAdaptersOnce();
      var box = await Hive.openBox<RecipeIngredientDBO>('ingredients');
      const quantity = FoodAmountSelection(
        2.123456789,
        FoodAmountOption(
          unit: 'portion:slice',
          baseUnit: 'g',
          factor: 38.123456789,
          label: '1 slice',
        ),
      );
      try {
        final ingredient = RecipeIngredientEntity(
          snapshotMeal: _meal(),
          quantity: quantity,
        );
        final dbo = ingredient.toDBO();
        await box.add(dbo);
        await box.close();
        box = await Hive.openBox<RecipeIngredientDBO>('ingredients');
        final restored = RecipeIngredientEntity.fromDBO(box.values.single);
        expect(restored.quantity, quantity);
        _expectServings(restored.snapshotMeal);
        final json = jsonDecode(jsonEncode(dbo)) as Map<String, dynamic>;
        expect(json, isNot(contains('convertedAmountG')));
        final fromJson = RecipeIngredientEntity.fromDBO(
          RecipeIngredientDBO.fromJson(json),
        );
        expect(fromJson.quantity, quantity);
        _expectServings(fromJson.snapshotMeal);
        json['quantityUnitFactor'] = 0;
        expect(() => RecipeIngredientDBO.fromJson(json), throwsFormatException);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'Hive, JSON and CSV retain all serving choices and the entered conversion',
    () async {
      final dir = await Directory.systemTemp.createTemp('quantity-snapshot');
      Hive.init(dir.path);
      registerHiveAdaptersOnce();
      var box = await Hive.openBox<IntakeDBO>('intakes');
      final config = await Hive.openBox<ConfigDBO>('config');
      final days = await Hive.openBox<TrackedDayDBO>('days');
      try {
        final entry = IntakeEntity(
          id: 'entry',
          quantity: const FoodAmountSelection(
            2,
            FoodAmountOption(
              unit: 'portion:foundation:1',
              baseUnit: 'g',
              factor: 53,
              label: 'slice',
            ),
          ),
          type: IntakeTypeEntity.snack,
          meal: _meal(),
          dateTime: DateTime(2026, 10, 1),
        );
        final dbo = IntakeDBO.fromIntakeEntity(entry);
        await box.add(dbo);
        await box.close();
        box = await Hive.openBox<IntakeDBO>('intakes');
        final fromHive = IntakeEntity.fromIntakeDBO(box.values.single);
        expect(fromHive.quantity, entry.quantity);
        expect(fromHive.baseAmount, 106);
        _expectServings(fromHive.meal);
        final encoded = jsonDecode(jsonEncode(dbo)) as Map<String, dynamic>;
        expect(encoded, isNot(contains('amount')));
        expect(encoded, isNot(contains('unit')));
        expect(encoded, isNot(contains('baseAmount')));
        final fromJson = IntakeEntity.fromIntakeDBO(
          IntakeDBO.fromJson(encoded),
        );
        expect(fromJson.quantity, entry.quantity);
        _expectServings(fromJson.meal);
        final csv = CsvDataExporter.parseIntakesFromCsv(
          CsvDataExporter.intakesToCsv([dbo]),
        ).single;
        expect(csv.quantity, entry.quantity);
        expect(csv.baseAmount, 106);
        _expectServings(MealEntity.fromMealDBO(csv.meal));
        final missing = Map<String, dynamic>.from(encoded)
          ..removeWhere((key, _) => key.startsWith('quantity'));
        expect(() => IntakeDBO.fromJson(missing), throwsFormatException);
        final partial = Map<String, dynamic>.from(encoded)
          ..remove('quantityUnitFactor');
        expect(() => IntakeDBO.fromJson(partial), throwsFormatException);
        final source = IntakeDataSource(
          FakeHiveDBProvider(
            intakeBox: box,
            configBox: config,
            trackedDayBox: days,
          ),
        );
        const selected = FoodAmountSelection(
          0.053,
          FoodAmountOption(unit: 'kg', baseUnit: 'g', factor: 1000),
        );
        await source.updateIntake('entry', {'quantity': selected});
        expect(box.values.single.quantity, selected);
        expect(box.values.single.baseAmount, 53);
        _expectServings(MealEntity.fromMealDBO(box.values.single.meal));
        await expectLater(
          source.updateIntake('entry', {
            'quantity': const FoodAmountSelection(
              2,
              FoodAmountOption(unit: 'serving', baseUnit: 'g', factor: 0),
            ),
          }),
          throwsFormatException,
        );
        expect(box.values.single.quantity, selected);
      } finally {
        await Hive.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
