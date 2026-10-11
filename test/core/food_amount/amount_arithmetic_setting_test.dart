import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';

void main() {
  test(
    'arithmetic defaults off and persists across profiles as a device setting',
    () async {
      final dir = await Directory.systemTemp.createTemp('amount-setting');
      Hive.init(dir.path);
      registerHiveAdaptersOnce();
      try {
        final app = await Hive.openBox<ConfigDBO>('app');
        final a = await Hive.openBox<ConfigDBO>('a');
        final b = await Hive.openBox<ConfigDBO>('b');
        final first = ConfigDataSource(
          FakeHiveDBProvider(configBox: a, appConfigBox: app),
        );
        expect(
          ConfigEntity.fromConfigDBO(
            await first.getConfig(),
          ).amountArithmeticEnabled,
          false,
        );
        await first.setAmountArithmeticEnabled(true);
        final second = ConfigDataSource(
          FakeHiveDBProvider(configBox: b, appConfigBox: app),
        );
        expect(
          ConfigEntity.fromConfigDBO(
            await second.getConfig(),
          ).amountArithmeticEnabled,
          true,
        );
        await app.close();
        final reopened = await Hive.openBox<ConfigDBO>('app');
        final source = ConfigDataSource(
          FakeHiveDBProvider(configBox: b, appConfigBox: reopened),
        );
        expect(
          ConfigEntity.fromConfigDBO(
            await source.getConfig(),
          ).amountArithmeticEnabled,
          true,
        );
        await source.setAmountArithmeticEnabled(false);
        expect(
          ConfigEntity.fromConfigDBO(
            await source.getConfig(),
          ).amountArithmeticEnabled,
          false,
        );
      } finally {
        await Hive.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
