import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/height_reading.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/hive_registrar.g.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/memory_user_repository.dart';

void main() {
  test(
    'dated readings normalize, replace, and never use a later measurement',
    () {
      final user = UserEntity.fromUserDBO(MemoryUserRepository().body);
      user.recordHeight(
        HeightReading(date: DateTime(2025, 1, 2, 17), centimetres: 160),
      );
      user.recordHeight(
        HeightReading(date: DateTime(2025, 2), centimetres: 165),
      );
      expect(user.heightOnOrBefore(DateTime(2025)), isNull);
      expect(user.heightOnOrBefore(DateTime(2025, 1, 31))!.centimetres, 160);
      user.recordHeight(
        HeightReading(date: DateTime(2025, 1, 2), centimetres: 161),
      );
      expect(user.heightHistory.length, 2);
      expect(user.heightOnOrBefore(DateTime(2025, 1, 2))!.centimetres, 161);
      expect(user.heightCM, 170);
      user.recordHeight(
        HeightReading(date: DateTime(2026, 10, 26), centimetres: 171),
        today: DateTime(2026, 10, 26),
      );
      expect(user.heightCM, 171);
      final restored = UserDBO.fromJson(
        jsonDecode(jsonEncode(UserDBO.fromUserEntity(user).toJson()))
            as Map<String, dynamic>,
      );
      expect(restored.heightHistory!.map((e) => e.centimetres), [
        161,
        165,
        171,
      ]);
    },
  );
  test(
    'profile boxes persist independently; seeding happens only once',
    () async {
      final root = await Directory.systemTemp.createTemp('height-history-');
      Hive.init(root.path);
      Hive.registerAdapters();
      final a = await Hive.openBox<UserDBO>('a');
      final b = await Hive.openBox<UserDBO>('b');
      final ra = UserRepository(UserDataSource(FakeHiveDBProvider(userBox: a)));
      final rb = UserRepository(UserDataSource(FakeHiveDBProvider(userBox: b)));
      await ra.restoreUserData(MemoryUserRepository().body);
      await rb.restoreUserData(MemoryUserRepository().body);
      final user = await ra.getUserData();
      expect(
        user.heightHistory.single.date,
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      );
      user.heightHistory.clear();
      await ra.updateUserData(user);
      expect((await ra.getUserData()).heightHistory, isEmpty);
      expect((await rb.getUserData()).heightHistory, hasLength(1));
      await a.close();
      final reopened = await Hive.openBox<UserDBO>('a');
      expect(reopened.get('UserKey')!.heightHistory, isEmpty);
      await Hive.close();
      await root.delete(recursive: true);
    },
  );
  test('imperial conversion retains centimetres', () {
    expect(UnitCalc.feetInchesToCm(5, 9), 175);
    expect(UnitCalc.cmToFeetInches(175.26), (5, 9));
  });
  test('height values must be positive and finite', () {
    for (final cm in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => HeightReading(date: DateTime.now(), centimetres: cm),
        throwsArgumentError,
      );
    }
  });
}
