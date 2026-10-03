import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/water_intake_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_water_intake_usecase.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    registerHiveAdaptersOnce();
    directory = await Directory.systemTemp.createTemp('overview-preferences');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'old configs and JSON without fields default independently to units',
    () {
      final dbo = ConfigDBO.empty();
      final json = dbo.toJson()
        ..remove('overviewMacrosAsPercent')
        ..remove('overviewNutrientsAsPercent');
      final config = ConfigEntity.fromConfigDBO(ConfigDBO.fromJson(json));
      expect(config.overviewMacrosAsPercent, isFalse);
      expect(config.overviewNutrientsAsPercent, isFalse);
    },
  );

  test(
    'display modes survive reopening and stay independent across profiles',
    () async {
      var app = await Hive.openBox<ConfigDBO>('app');
      var first = await Hive.openBox<ConfigDBO>('first');
      var second = await Hive.openBox<ConfigDBO>('second');
      ConfigRepository repository(Box<ConfigDBO> profile) => ConfigRepository(
        ConfigDataSource(
          FakeHiveDBProvider(configBox: profile, appConfigBox: app),
        ),
      );
      var firstRepo = repository(first);
      var secondRepo = repository(second);
      await AddConfigUsecase(firstRepo).setOverviewMacrosAsPercent(true);
      expect((await firstRepo.getConfig()).overviewNutrientsAsPercent, isFalse);
      expect((await secondRepo.getConfig()).overviewMacrosAsPercent, isFalse);
      await AddConfigUsecase(secondRepo).setOverviewNutrientsAsPercent(true);
      await Hive.close();
      app = await Hive.openBox<ConfigDBO>('app');
      first = await Hive.openBox<ConfigDBO>('first');
      second = await Hive.openBox<ConfigDBO>('second');
      firstRepo = repository(first);
      secondRepo = repository(second);
      expect((await firstRepo.getConfig()).overviewMacrosAsPercent, isTrue);
      expect((await firstRepo.getConfig()).overviewNutrientsAsPercent, isFalse);
      expect((await secondRepo.getConfig()).overviewMacrosAsPercent, isFalse);
      expect((await secondRepo.getConfig()).overviewNutrientsAsPercent, isTrue);
      await AddConfigUsecase(firstRepo).setOverviewMacrosAsPercent(false);
      expect((await secondRepo.getConfig()).overviewNutrientsAsPercent, isTrue);
    },
  );

  test(
    'water correction persists at the same ID and time after reopening',
    () async {
      var box = await Hive.openBox<WaterIntakeDBO>('water');
      WaterIntakeRepository repository() => WaterIntakeRepository(
        WaterIntakeDataSource(FakeHiveDBProvider(waterIntakeBox: box)),
      );
      final entry = WaterIntakeEntity(
        id: 'sip',
        dateTime: DateTime(2026, 9, 20, 2, 15),
        amountMl: 250,
      );
      await repository().addEntry(entry);
      await UpdateWaterIntakeUsecase(repository()).updateAmount(entry, 337);
      await box.close();
      box = await Hive.openBox<WaterIntakeDBO>('water');
      final saved = (await repository().getAllEntries()).single;
      expect(saved.id, entry.id);
      expect(saved.dateTime, entry.dateTime);
      expect(saved.amountMl, 337);
    },
  );
}
