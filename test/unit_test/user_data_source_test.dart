import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_sex_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';

import '../helpers/hive_test_setup.dart';
import '../helpers/fake_hive_db_provider.dart';

class _BlockedBox extends Fake implements Box<UserDBO> {
  final gate = Completer<void>();
  final records = <dynamic, UserDBO>{};
  bool started = false;

  @override
  Future<void> put(dynamic key, UserDBO value) async {
    started = true;
    await gate.future;
    records[key] = value;
  }

  @override
  UserDBO? get(dynamic key, {UserDBO? defaultValue}) =>
      records[key] ?? defaultValue;
}

void main() {
  useTestHive();
  group('UserDataSource race-condition guarantees', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    UserDBO buildUser({
      double weight = 70,
      UserSexDBO sex = UserSexDBO.female,
    }) => UserDBO(
      birthday: DateTime(1990, 6, 15),
      heightCM: 165,
      weightKG: weight,
      sex: sex,
      goal: UserWeightGoalDBO.loseWeight,
      pal: UserPALDBO.sedentary,
    );

    test(
      'getUserData throws StateError before any save (no dummy fallback)',
      () async {
        // Regression: the data source used to fall back to a hardcoded
        // 80 kg / 180 cm / male / active dummy when the box was empty. That
        // silently produced an inflated kcal budget for any caller that hit
        // the box during the onboarding race. The data source must now fail
        // loudly so callers can diagnose the race instead of corrupting calcs.
        final box = await Hive.openBox<UserDBO>('user_data_source_test_empty');
        final source = UserDataSource(FakeHiveDBProvider(userBox: box));

        expect(source.getUserData, throwsStateError);
      },
    );

    for (final sex in UserSexDBO.values) {
      test('${sex.name} user survives closing and reopening the box', () async {
        final box = await Hive.openBox<UserDBO>(
          'user_data_source_test_save_${sex.name}',
        );
        final source = UserDataSource(FakeHiveDBProvider(userBox: box));

        await source.saveUserData(buildUser(sex: sex));

        await box.close();
        final reopened = await Hive.openBox<UserDBO>(
          'user_data_source_test_save_${sex.name}',
        );
        final loaded = await UserDataSource(
          FakeHiveDBProvider(userBox: reopened),
        ).getUserData();
        expect(loaded.weightKG, 70);
        expect(loaded.sex, sex);
      });
    }
    test('save remains pending until the underlying write completes', () {
      fakeAsync((time) {
        final box = _BlockedBox();
        final source = UserDataSource(FakeHiveDBProvider(userBox: box));
        var completed = false;
        source.saveUserData(buildUser()).then((_) => completed = true);
        time.flushMicrotasks();
        expect(box.started, isTrue);
        expect(completed, isFalse);
        expect(box.records, isEmpty);
        box.gate.complete();
        time.flushMicrotasks();
        expect(completed, isTrue);
        expect(box.records.values.single.weightKG, 70);
      });
    });

    test('a failed write propagates and leaves the prior user unchanged', () {
      fakeAsync((time) {
        final box = _BlockedBox();
        final prior = buildUser(weight: 65);
        box.records['UserKey'] = prior;
        final source = UserDataSource(FakeHiveDBProvider(userBox: box));
        Object? failure;
        source.saveUserData(buildUser()).catchError((Object error) {
          failure = error;
        });
        time.flushMicrotasks();
        final error = StateError('disk full');
        box.gate.completeError(error);
        time.flushMicrotasks();
        expect(failure, same(error));
        expect(box.records, {'UserKey': same(prior)});
      });
    });
  });
}
