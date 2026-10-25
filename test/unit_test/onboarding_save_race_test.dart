import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/onboarding/presentation/bloc/onboarding_bloc.dart';

/// Fake repository whose every write returns a Future controlled by an
/// external Completer. Lets us assert that `OnboardingBloc.saveOnboardingData`
/// only resolves when the inner Hive writes have actually finished.
class _FakeUserRepository implements UserRepository {
  final Completer<void> writeCompleter = Completer<void>();
  bool writeStarted = false;

  @override
  Future<void> updateUserData(userEntity) async {
    writeStarted = true;
    await writeCompleter.future;
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeConfigRepository implements ConfigRepository {
  bool writeStarted = false;
  final Completer<void> unitsCompleter = Completer<void>();

  // The policy acceptance is written right after the user, before the unit
  // write; it's not part of the race under test, so it resolves immediately.
  @override
  Future<void> setConfigHasAcceptedPolicy(bool _) async {}

  // Hold the first unit write to verify that onboarding awaits configuration.
  @override
  Future<void> setConfigUsesImperialHeightUnits(bool _) async {
    writeStarted = true;
    await unitsCompleter.future;
  }

  @override
  Future<void> setConfigUsesImperialFoodUnits(bool _) async {}

  @override
  Future<void> setConfigBodyWeightUnit(BodyWeightUnit _) async {}

  // "Other options" writes (theme, food sources, reminder flag) follow the
  // same pattern — written after the race under test, resolve immediately.
  @override
  Future<void> setConfigAppTheme(AppThemeEntity _) async {}

  @override
  Future<void> setNotificationsEnabled(bool _) async {}

  @override
  Future<void> setConfigUseMaterialYou(bool _) async {}

  @override
  Future<void> setConfigAccentColor(int? _) async {}

  // Stamped alongside the policy acceptance, so someone onboarding now is
  // never told the document they just read has changed (#887). Written after
  // the race under test, resolves immediately.
  @override
  Future<void> setConfigPolicyNoticeRevisionSeen(int _) async {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('OnboardingBloc.saveOnboardingData await chain', () {
    late _FakeUserRepository userRepo;
    late _FakeConfigRepository configRepo;
    late OnboardingBloc bloc;

    void initialize() {
      userRepo = _FakeUserRepository();
      configRepo = _FakeConfigRepository();
      bloc = OnboardingBloc(
        AddUserUsecase(userRepo),
        AddConfigUsecase(configRepo),
        GetConfigUsecase(configRepo),
      );
    }

    tearDown(() => bloc.close());

    UserEntity makeUser() => UserEntity(
      birthday: DateTime(1990, 6, 15),
      heightCM: 165,
      weightKG: 70,
      sex: UserSexEntity.female,
      goal: UserWeightGoalEntity.loseWeight,
      pal: UserPALEntity.sedentary,
    );

    test(
      'saveOnboardingData does not resolve until the user write completes',
      () {
        fakeAsync((time) {
          initialize();
          final saveFuture = bloc.saveOnboardingData(
            makeUser(),
            false,
            BodyWeightUnit.kg,
            false,
            appTheme: AppThemeEntity.system,
            dailyReminderEnabled: false,
            useMaterialYou: true,
            accentColor: null,
          );

          var resolved = false;
          saveFuture.then((_) => resolved = true);
          time.flushMicrotasks();
          expect(userRepo.writeStarted, isTrue);
          expect(configRepo.writeStarted, isFalse);
          expect(resolved, isFalse);

          userRepo.writeCompleter.complete();
          time.flushMicrotasks();
          expect(configRepo.writeStarted, isTrue);
          expect(resolved, isFalse);

          configRepo.unitsCompleter.complete();
          time.flushMicrotasks();
          expect(resolved, isTrue);
        });
      },
    );
  });
}
