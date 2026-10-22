import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import '../helpers/hive_test_setup.dart';
import '../helpers/fake_hive_db_provider.dart';

void main() {
  useTestHive();
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'database overrides survive restart, profile switches and JSON round trips',
    () async {
      final app = await Hive.openBox<ConfigDBO>('catalogue_app');
      final first = await Hive.openBox<ConfigDBO>('catalogue_first');
      final second = await Hive.openBox<ConfigDBO>('catalogue_second');
      addTearDown(() async {
        await app.deleteFromDisk();
        await first.deleteFromDisk();
        await second.deleteFromDisk();
      });
      ConfigDataSource source(Box<ConfigDBO> profile) => ConfigDataSource(
        FakeHiveDBProvider(appConfigBox: app, configBox: profile),
      );
      await source(first).initializeConfig();
      await source(second).initializeConfig();
      await source(first).setCatalogueSourceOverrides({'usda': false});
      expect((await source(second).getConfig()).catalogueSourceOverrides, {
        'usda': false,
      });
      await source(
        second,
      ).setCatalogueSourceOverrides({'usda': false, 'other': false});
      final saved = await source(first).getConfig();
      final entity = ConfigEntity.fromConfigDBO(
        ConfigDBO.fromJson(saved.toJson()),
      );
      expect(entity.catalogueSourceOverrides, {'usda': false, 'other': false});
      expect(
        ConfigDBO.fromConfigEntity(entity).catalogueSourceOverrides,
        entity.catalogueSourceOverrides,
      );
      expect(
        ConfigEntity.fromConfigDBO(ConfigDBO.empty()).catalogueSourceOverrides,
        isEmpty,
      );
    },
  );
}
