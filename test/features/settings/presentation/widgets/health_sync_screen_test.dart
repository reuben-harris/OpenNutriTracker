import '../../../../helpers/locator_test_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/repository/health_import_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/health_disclosure_dialog.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/health_sync_screen.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/workout_calorie_credit_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../../helpers/test_l10n.dart';

class _FakeSettingsBloc extends Fake implements SettingsBloc {
  final List<bool> importEnabledCalls = [];
  final List<double> multiplierCalls = [];

  @override
  Future<void> setHealthImportEnabled(bool enabled) async {
    importEnabledCalls.add(enabled);
  }

  @override
  Future<void> setHealthWorkoutKcalMultiplier(double multiplier) async {
    multiplierCalls.add(multiplier);
  }
}

class _FakeGetConfigUsecase extends Fake implements GetConfigUsecase {
  ConfigEntity config = const ConfigEntity(true, true, AppThemeEntity.system);

  @override
  Future<ConfigEntity> getConfig() async => config;
}

class _FakeHealthImportRepository extends Fake
    implements HealthImportRepository {
  bool available = true;
  bool granted = true;
  int requestPermissionsCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCalls++;
    return granted;
  }
}

class _FakeImportWorkoutsUsecase extends Fake implements ImportWorkoutsUsecase {
  int importedCount = 0;
  int importNowCalls = 0;

  @override
  Future<int> importNow() async {
    importNowCalls++;
    return importedCount;
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.supportedLocales,
    home: child,
  );
}

/// Finds the widget carrying an accessibility identifier, which is how the
/// screen's interactive rows are addressed.
Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
);

void main() {
  useTestLocator();
  late _FakeSettingsBloc settingsBloc;
  late _FakeGetConfigUsecase getConfigUsecase;
  late _FakeHealthImportRepository healthImportRepository;
  late _FakeImportWorkoutsUsecase importWorkoutsUsecase;

  setUp(() {
    settingsBloc = _FakeSettingsBloc();
    getConfigUsecase = _FakeGetConfigUsecase();
    healthImportRepository = _FakeHealthImportRepository();
    importWorkoutsUsecase = _FakeImportWorkoutsUsecase();

    locator.registerSingleton<SettingsBloc>(settingsBloc);
    locator.registerSingleton<GetConfigUsecase>(getConfigUsecase);
    locator.registerSingleton<HealthImportRepository>(healthImportRepository);
    locator.registerSingleton<ImportWorkoutsUsecase>(importWorkoutsUsecase);
  });

  tearDown(() async {
    await GetIt.instance.resetScope();
  });

  /// Rewrites the stored config the screen loads from. Positional arguments
  /// mirror ConfigEntity's disclaimer / policy / theme head.
  void storeConfig({
    required bool healthImportEnabled,
    double? healthWorkoutKcalMultiplier,
  }) {
    getConfigUsecase.config = ConfigEntity(
      true,
      true,
      AppThemeEntity.system,
      healthImportEnabled: healthImportEnabled,
      healthWorkoutKcalMultiplier: healthWorkoutKcalMultiplier,
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(const HealthSyncScreen()));
    await tester.pumpAndSettle();
  }

  /// Taps the opt-in switch and confirms the disclosure that #926 put in front
  /// of the permission request. Every opt-in goes through it, so the tests that
  /// exercise opting in have to as well.
  Future<void> optIn(WidgetTester tester) async {
    await tester.tap(_byIdentifier('health-sync-auto-import'));
    await tester.pumpAndSettle();
    expect(
      find.byType(HealthDisclosureDialog),
      findsOneWidget,
      reason: 'the platform must not be asked before the user is told',
    );
    await tester.tap(find.text(l10nEn.healthSyncDisclosureContinueAction));
    await tester.pumpAndSettle();
  }

  testWidgets('credit can be configured before opting into import', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: false);
    await pumpScreen(tester);

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(
      find.text(l10nEn.healthSyncKcalMultiplierValueLabel(72)),
      findsOneWidget,
    );
    await tester.tap(_byIdentifier('health-sync-kcal-multiplier'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutCalorieCreditDialog), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.72);
    expect(healthImportRepository.requestPermissionsCalls, 0);
    expect(settingsBloc.importEnabledCalls, isEmpty);
  });

  testWidgets('opting in keeps the default without writing a suggestion', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: false);
    await pumpScreen(tester);
    await optIn(tester);

    expect(healthImportRepository.requestPermissionsCalls, 1);
    expect(settingsBloc.importEnabledCalls, [true]);
    expect(settingsBloc.multiplierCalls, isEmpty);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(
      find.text(l10nEn.healthSyncKcalMultiplierValueLabel(72)),
      findsOneWidget,
    );
    expect(importWorkoutsUsecase.importNowCalls, 1);
  });

  testWidgets('opting in preserves a configured credit', (tester) async {
    storeConfig(healthImportEnabled: false, healthWorkoutKcalMultiplier: 0.85);
    await pumpScreen(tester);
    await optIn(tester);

    expect(settingsBloc.multiplierCalls, isEmpty);
    expect(
      find.text(l10nEn.healthSyncKcalMultiplierValueLabel(85)),
      findsOneWidget,
    );
  });

  testWidgets('a denied permission leaves import off and says so', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: false);
    healthImportRepository.granted = false;

    await pumpScreen(tester);
    await optIn(tester);

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(settingsBloc.importEnabledCalls, isEmpty);
    expect(importWorkoutsUsecase.importNowCalls, 0);
    expect(
      find.text(l10nEn.healthSyncPermissionDeniedLabel(healthPlatformName)),
      findsOneWidget,
    );
  });

  testWidgets(
    'the shared editor saves credit and updates the displayed value',
    (tester) async {
      storeConfig(healthImportEnabled: true, healthWorkoutKcalMultiplier: 0.85);
      await pumpScreen(tester);
      await tester.tap(_byIdentifier('health-sync-kcal-multiplier'));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      await tester.tapAt(
        tester.getRect(slider).centerLeft + const Offset(24, 0),
      );
      await tester.pumpAndSettle();
      final selected = tester.widget<Slider>(slider).value;
      expect(selected, isNot(0.85));
      await tester.tap(find.text(l10nEn.buttonSaveLabel));
      await tester.pumpAndSettle();

      expect(settingsBloc.multiplierCalls, [selected]);
      expect(
        find.text(
          l10nEn.healthSyncKcalMultiplierValueLabel((selected * 100).round()),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('cancelling the shared editor leaves the override alone', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: true, healthWorkoutKcalMultiplier: 0.85);
    await pumpScreen(tester);
    await tester.tap(_byIdentifier('health-sync-kcal-multiplier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.healthSyncKcalMultiplierDefaultLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.dialogCancelLabel));
    await tester.pumpAndSettle();

    expect(settingsBloc.multiplierCalls, isEmpty);
    expect(
      find.text(l10nEn.healthSyncKcalMultiplierValueLabel(85)),
      findsOneWidget,
    );
  });

  testWidgets('every interactive widget carries an accessibility identifier', (
    tester,
  ) async {
    storeConfig(
      healthImportEnabled: true,
      healthWorkoutKcalMultiplier: ConfigEntity.maxHealthWorkoutKcalMultiplier,
    );

    await pumpScreen(tester);

    expect(_byIdentifier('health-sync-auto-import'), findsOneWidget);
    expect(_byIdentifier('health-sync-import-now'), findsOneWidget);
    expect(_byIdentifier('health-sync-kcal-multiplier'), findsOneWidget);
    expect(_byIdentifier('health-sync-privacy-policy'), findsOneWidget);
  });

  testWidgets('the credit section title cannot overflow its row', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: true);

    // Exercise the credit row on a narrow viewport.
    await tester.binding.setSurfaceSize(const Size(320, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(const HealthSyncScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // #926: Play's User Data policy wants the disclosure in front of the
  // permission request, resolved by an affirmative action. These pin the part
  // that matters — that a refusal really does ask the platform for nothing.

  testWidgets('cancelling the disclosure asks the platform for nothing', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: false);
    // Granted, so a wrongly-proceeding implementation would succeed loudly
    // rather than be masked by a denial.
    healthImportRepository.granted = true;

    await pumpScreen(tester);
    await tester.tap(_byIdentifier('health-sync-auto-import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.dialogCancelLabel));
    await tester.pumpAndSettle();

    expect(healthImportRepository.requestPermissionsCalls, 0);
    expect(settingsBloc.importEnabledCalls, isEmpty);
    expect(importWorkoutsUsecase.importNowCalls, 0);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  // A dialog that a stray tap could dismiss into a permission prompt would not
  // be consent, so the barrier has to hold.
  testWidgets('the disclosure ignores a tap outside it', (tester) async {
    storeConfig(healthImportEnabled: false);
    healthImportRepository.granted = true;

    await pumpScreen(tester);
    await tester.tap(_byIdentifier('health-sync-auto-import'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(HealthDisclosureDialog), findsOneWidget);
    expect(healthImportRepository.requestPermissionsCalls, 0);
  });

  testWidgets('turning import off discloses nothing', (tester) async {
    storeConfig(healthImportEnabled: true);

    await pumpScreen(tester);
    await tester.tap(_byIdentifier('health-sync-auto-import'));
    await tester.pumpAndSettle();

    expect(find.byType(HealthDisclosureDialog), findsNothing);
    expect(settingsBloc.importEnabledCalls, [false]);
  });

  testWidgets('the rendered disclosure describes only workout access', (
    tester,
  ) async {
    storeConfig(healthImportEnabled: false);
    await pumpScreen(tester);
    await tester.tap(_byIdentifier('health-sync-auto-import'));
    await tester.pumpAndSettle();

    final body = [
      l10nEn.healthSyncDisclosureBody(healthPlatformName),
      l10nEn.healthSyncDisclosureFooter(healthPlatformName),
    ].join('\n\n');
    expect(find.text(body), findsOneWidget);
    expect(body, contains(healthPlatformName));
    expect(body, contains('written back'));
    expect(body, contains('stays on this device'));
    expect(body, isNot(contains('body fat')));
  });
}
