import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import '../../../helpers/locator_test_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_profiles_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/profile/profile_page.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/workout_calorie_credit_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../fixture/user_entity_fixtures.dart';
import '../../../helpers/test_l10n.dart';
import '../../../helpers/pump_until.dart';

/// Real Bloc state/stream machinery, but [updateUser] just records the call
/// instead of touching AddUserUsecase / HomeBloc / DiaryBloc / CalendarDayBloc
/// — none of which are wired up in this test.
class _FakeProfileBloc extends Bloc<ProfileEvent, ProfileState>
    implements ProfileBloc {
  final List<UserEntity> updateUserCalls = [];
  double multiplier = 0.72;
  int reloads = 0;

  _FakeProfileBloc(super.initialState) {
    on<LoadProfileEvent>((event, emit) {
      reloads++;
      final current = state as ProfileLoadedState;
      emit(
        ProfileLoadedState(
          userEntity: current.userEntity,
          bodyWeightUnit: current.bodyWeightUnit,
          usesImperialHeightUnits: current.usesImperialHeightUnits,
          effectiveWaterGoalMl: current.effectiveWaterGoalMl,
          effectiveWorkoutKcalMultiplier: multiplier,
        ),
      );
    });
  }

  @override
  Future<UserEntity> getUser() async =>
      (state as ProfileLoadedState).userEntity;

  @override
  Future<void> setCaloriesTaperEnabled(bool enabled) async {}

  @override
  Future<void> setNutrientPolicies(
    Map<String, NutrientPolicy> policies,
  ) async {}

  @override
  Future<void> updateUser(UserEntity userEntity) async {
    updateUserCalls.add(userEntity);
  }
}

class _FakeSettingsBloc extends Fake implements SettingsBloc {
  final _FakeProfileBloc profileBloc;
  final List<double> savedCredits = [];

  _FakeSettingsBloc(this.profileBloc);

  @override
  Future<void> setHealthWorkoutKcalMultiplier(double multiplier) async {
    savedCredits.add(multiplier);
    profileBloc.multiplier = multiplier;
  }
}

class _FakeAddWeightLogUsecase extends Fake implements AddWeightLogUsecase {
  final List<WeightLogEntity> entries = [];

  @override
  Future<void> addEntry(WeightLogEntity entry) async {
    entries.add(entry);
  }
}

class _FakeGetUserUsecase extends Fake implements GetUserUsecase {
  final UserEntity user;

  _FakeGetUserUsecase(this.user);

  @override
  Future<UserEntity> getUserData() async => user;
}

/// Single-profile stub so ProfileSwitcherHeader (rendered unconditionally at
/// the top of ProfilePage) has something to show.
class _SingleProfileGetProfilesUsecase implements GetProfilesUsecase {
  static final _profile = ProfileEntity(
    id: 'p1',
    name: 'Me',
    createdAt: DateTime(2026, 1, 1),
    boxSuffix: '',
  );

  @override
  List<ProfileEntity> getProfiles() => [_profile];

  @override
  String get activeProfileId => 'p1';

  @override
  ProfileEntity? getActiveProfile() => _profile;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  useTestLocator();
  late _FakeProfileBloc fakeProfileBloc;
  late _FakeAddWeightLogUsecase fakeAddWeightLogUsecase;
  late _FakeSettingsBloc settingsBloc;
  late int profileLookups;
  final user = UserEntityFixtures.youngSedentaryMaleWantingToMaintainWeight;

  setUp(() {
    fakeProfileBloc = _FakeProfileBloc(
      ProfileLoadedState(
        effectiveWorkoutKcalMultiplier: 0.72,
        userEntity: user,
        bodyWeightUnit: BodyWeightUnit.kg,
        usesImperialHeightUnits: false,
        effectiveWaterGoalMl: 2000,
      ),
    );
    fakeAddWeightLogUsecase = _FakeAddWeightLogUsecase();

    profileLookups = 0;
    locator.registerFactory<ProfileBloc>(() {
      profileLookups++;
      return fakeProfileBloc;
    });
    settingsBloc = _FakeSettingsBloc(fakeProfileBloc);
    locator.registerSingleton<SettingsBloc>(settingsBloc);
    locator.registerSingleton<AddWeightLogUsecase>(fakeAddWeightLogUsecase);
    locator.registerSingleton<GetUserUsecase>(_FakeGetUserUsecase(user));
    locator.registerSingleton<GetProfilesUsecase>(
      _SingleProfileGetProfilesUsecase(),
    );
  });

  tearDown(() async {
    await fakeProfileBloc.close();
    await GetIt.instance.resetScope();
  });

  testWidgets(
    'You contains profile controls without library or settings entries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(const ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('profile-height'), findsOneWidget);
      expect(find.bySemanticsIdentifier('profile-water-goal'), findsOneWidget);
      expect(find.bySemanticsIdentifier('profile-recipes'), findsNothing);
      expect(find.text(l10nEn.recipesLabel), findsNothing);
      expect(find.text(l10nEn.settingsLabel), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
    },
  );

  testWidgets('tapping the profile weight tile logs a weight-history entry '
      '(regression #510: Profile weight edits used to skip WeightLogBox)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const ProfilePage()));
    await tester.pumpAndSettle();

    final weightTileFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'profile-weight',
    );
    expect(weightTileFinder, findsOneWidget);

    await tester.tap(weightTileFinder);
    await tester.pumpAndSettle();

    // Submit without moving the picker — the dialog defaults to the
    // current weight, which is enough to prove the write path fires.
    await tester.tap(find.text(l10nEn.dialogOKLabel));
    await tester.pumpAndSettle();

    expect(fakeAddWeightLogUsecase.entries, hasLength(1));
    final logged = fakeAddWeightLogUsecase.entries.single;
    expect(logged.weightKg, closeTo(user.weightKG, 0.5));
    // Use a two-day window to avoid a flaky failure when the test runs right
    // across a midnight boundary (the production code calls DateTime.now()
    // before we capture it here).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    expect({today, yesterday}, contains(logged.date));

    // Profile/home/diary refresh still happens via ProfileBloc.updateUser.
    expect(fakeProfileBloc.updateUserCalls, hasLength(1));
  });
  testWidgets('You edits workout credit and refreshes its mounted bloc', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProfilePage()));
    await tester.pumpAndSettle();

    final tile = find.bySemanticsIdentifier('profile-workout-calorie-credit');
    expect(find.text('BMI'), findsNothing);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10nEn.healthSyncKcalMultiplierValueLabel(72)),
      ),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutCalorieCreditDialog), findsOneWidget);
    final slider = find.byType(Slider);
    await tester.tapAt(tester.getRect(slider).centerRight - const Offset(1, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.buttonSaveLabel));
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () => find
          .descendant(
            of: tile,
            matching: find.text(l10nEn.healthSyncKcalMultiplierValueLabel(100)),
          )
          .evaluate()
          .isNotEmpty,
      reason: 'the mounted profile bloc to publish the saved workout credit',
    );

    expect(settingsBloc.savedCredits, [1.0]);
    expect(fakeProfileBloc.reloads, 1);
    expect(profileLookups, 1, reason: 'refresh the mounted factory instance');
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10nEn.healthSyncKcalMultiplierValueLabel(100)),
      ),
      findsOneWidget,
    );
  });
}
