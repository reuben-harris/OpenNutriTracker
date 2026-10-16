import 'package:opennutritracker/core/data/dbo/recipe_ingredient_dbo.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
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
          snapshotMeal: food('bread', 'Bread'),
          quantity: quantity,
        );
        final dbo = ingredient.toDBO();
        await box.add(dbo);
        await box.close();
        box = await Hive.openBox<RecipeIngredientDBO>('ingredients');
        final restored = RecipeIngredientEntity.fromDBO(box.values.single);
        expect(restored.quantity, quantity);
        expect(restored.snapshotMeal.portions, isEmpty);
        final json = jsonDecode(jsonEncode(dbo)) as Map<String, dynamic>;
        expect(json, isNot(contains('convertedAmountG')));
        expect(RecipeIngredientDBO.fromJson(json).quantity, quantity);
        json['quantityUnitFactor'] = 0;
        expect(() => RecipeIngredientDBO.fromJson(json), throwsFormatException);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'Hive, JSON and CSV retain only the quantity and conversion snapshot',
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
          meal: food('x', 'Food'),
          dateTime: DateTime(2026, 10, 1),
        );
        final dbo = IntakeDBO.fromIntakeEntity(entry);
        await box.add(dbo);
        await box.close();
        box = await Hive.openBox<IntakeDBO>('intakes');
        final fromHive = IntakeEntity.fromIntakeDBO(box.values.single);
        expect(fromHive.quantity, entry.quantity);
        expect(fromHive.baseAmount, 106);
        final encoded = jsonDecode(jsonEncode(dbo)) as Map<String, dynamic>;
        expect(encoded, isNot(contains('amount')));
        expect(encoded, isNot(contains('unit')));
        expect(encoded, isNot(contains('baseAmount')));
        expect(IntakeDBO.fromJson(encoded).quantity, entry.quantity);
        final csv = CsvDataExporter.parseIntakesFromCsv(
          CsvDataExporter.intakesToCsv([dbo]),
        ).single;
        expect(csv.quantity, entry.quantity);
        expect(csv.baseAmount, 106);
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
