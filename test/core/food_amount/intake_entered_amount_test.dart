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
    'Hive, JSON and CSV retain entered quantity and conversion snapshot',
    () async {
      final dir = await Directory.systemTemp.createTemp('entered-amount');
      Hive.init(dir.path);
      registerHiveAdaptersOnce();
      final box = await Hive.openBox<IntakeDBO>('intakes');
      final config = await Hive.openBox<ConfigDBO>('config');
      final days = await Hive.openBox<TrackedDayDBO>('days');
      try {
        final entry = IntakeEntity(
          id: 'entry',
          amount: 106,
          unit: 'g',
          type: IntakeTypeEntity.snack,
          meal: food('x', 'Food'),
          dateTime: DateTime(2026, 10, 1),
          enteredAmount: 2,
          enteredUnit: 'portion:slice:53',
          enteredBaseUnit: 'g',
          enteredUnitFactor: 53,
          enteredUnitLabel: 'slice',
        );
        final dbo = IntakeDBO.fromIntakeEntity(entry);
        await box.add(dbo);
        await box.close();
        final reopened = await Hive.openBox<IntakeDBO>('intakes');
        final fromHive = IntakeEntity.fromIntakeDBO(reopened.values.single);
        expect(fromHive.enteredSelection!.amount, 2);
        expect(fromHive.enteredSelection!.option.factor, 53);
        final encoded = jsonDecode(jsonEncode(dbo)) as Map<String, dynamic>;
        final json = IntakeDBO.fromJson(encoded);
        expect(json.enteredUnitLabel, 'slice');
        final csv = CsvDataExporter.parseIntakesFromCsv(
          CsvDataExporter.intakesToCsv([dbo]),
        ).single;
        expect(csv.enteredAmount, 2);
        expect(csv.enteredUnit, 'portion:slice:53');
        final legacy = Map<String, dynamic>.from(encoded)
          ..removeWhere((key, _) => key.startsWith('entered'));
        expect(IntakeDBO.fromJson(legacy).enteredAmount, isNull);
        final source = IntakeDataSource(
          FakeHiveDBProvider(
            intakeBox: reopened,
            configBox: config,
            trackedDayBox: days,
          ),
        );
        await source.updateIntake(
          'entry',
          FoodAmountSelection(
            53,
            const FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
          ).intakeFields,
        );
        expect(reopened.values.single.enteredAmount, 53);
        await source.updateIntake('entry', {'amount': 42.0});
        expect(reopened.values.single.enteredAmount, isNull);
        expect(reopened.values.single.enteredUnitFactor, isNull);
      } finally {
        await Hive.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
