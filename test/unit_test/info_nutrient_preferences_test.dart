import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTestHive();

  test('unset info preference hides missing nutrients', () {
    final json = ConfigDBO.empty().toJson()
      ..remove('showMissingNutrientsInInfo');
    expect(
      ConfigEntity.fromConfigDBO(
        ConfigDBO.fromJson(json),
      ).showMissingNutrientsInInfo,
      isFalse,
    );
  });

  for (final show in [true, false]) {
    test(
      'show missing = $show survives serialization and profile switches',
      () async {
        var app = await Hive.openBox<ConfigDBO>('app');
        var first = await Hive.openBox<ConfigDBO>('first');
        var second = await Hive.openBox<ConfigDBO>('second');
        ConfigRepository repository(Box<ConfigDBO> profile) => ConfigRepository(
          ConfigDataSource(
            FakeHiveDBProvider(appConfigBox: app, configBox: profile),
          ),
        );
        var firstRepo = repository(first);
        var secondRepo = repository(second);
        final original = await firstRepo.getConfig();
        // Exercise a real transition for each persisted choice.
        await AddConfigUsecase(firstRepo).setShowMissingNutrientsInInfo(!show);
        await AddConfigUsecase(firstRepo).setShowMissingNutrientsInInfo(show);
        expect((await secondRepo.getConfig()).showMissingNutrientsInInfo, show);
        final saved = await firstRepo.getConfig();
        final roundTripped = ConfigEntity.fromConfigDBO(
          ConfigDBO.fromJson(ConfigDBO.fromConfigEntity(saved).toJson()),
        );
        expect(roundTripped, saved);
        expect(roundTripped.showMissingNutrientsInInfo, show);
        expect(saved == original, !show);

        await Hive.close();
        app = await Hive.openBox<ConfigDBO>('app');
        first = await Hive.openBox<ConfigDBO>('first');
        second = await Hive.openBox<ConfigDBO>('second');
        firstRepo = repository(first);
        secondRepo = repository(second);
        expect((await firstRepo.getConfig()).showMissingNutrientsInInfo, show);
        expect((await secondRepo.getConfig()).showMissingNutrientsInInfo, show);
        await AddConfigUsecase(
          secondRepo,
        ).setNutrientVisibility(['sugar'], false, info: true);
        expect((await firstRepo.getConfig()).showMissingNutrientsInInfo, show);
        await AddConfigUsecase(secondRepo).setShowMissingNutrientsInInfo(!show);
        expect((await firstRepo.getConfig()).showMissingNutrientsInInfo, !show);
        expect(
          (await firstRepo.getConfig()).nutrientInfoVisibility['sugar'],
          isFalse,
        );
      },
    );
  }
}
