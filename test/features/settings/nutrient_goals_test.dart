import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/nutrient_goals_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../fixture/user_entity_fixtures.dart';
import '../../helpers/locator_test_setup.dart';
import '../../helpers/overview_diary_harness.dart';
import '../../helpers/pump_until.dart';
import '../../helpers/test_l10n.dart';

class _Settings extends Fake implements SettingsBloc {
  @override
  void add(SettingsEvent event) {}
}

class _Profile extends Fake implements ProfileBloc {
  final UserEntity user =
      UserEntityFixtures.youngSedentaryMaleWantingToMaintainWeight;
  final writes = <Map<String, NutrientPolicy>>[];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<UserEntity> getUser() async => user;
  @override
  Future<void> setNutrientPolicies(Map<String, NutrientPolicy> policies) async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Save failed');
    user.nutrientPolicies = Map.of(policies);
    writes.add(Map.of(policies));
  }
}

class _Home extends Fake implements HomeBloc {
  @override
  void add(HomeEvent event) {}
}

class _Diary extends Fake implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}
}

class _Calendar extends Fake implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}
}

Finder control(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);
Finder amount(String id) => find.descendant(
  of: control('nutrient-$id-amount'),
  matching: find.byType(TextField),
);
void main() {
  useTestLocator();
  late _Profile profile;
  setUp(() => profile = _Profile());
  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    double width = 600,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NutrientGoalsScreen(
                    settingsBloc: _Settings(),
                    profileBloc: profile,
                    homeBloc: _Home(),
                    diaryBloc: _Diary(),
                    calendarDayBloc: _Calendar(),
                  ),
                ),
              ),
              child: const Text('Open goals'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open goals'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseMode(WidgetTester tester, String id, String label) async {
    await tester.ensureVisible(control('nutrient-$id-mode'));
    await tester.tap(control('nutrient-$id-mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tester.ensureVisible(control('nutrient-selector'));
    final input = find.descendant(
      of: control('nutrient-selector'),
      matching: find.byType(TextField),
    );
    await tester.tap(input);
    await tester.enterText(input, name);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('drafts persist across nutrient switches; both thresholds save', (
    tester,
  ) async {
    await open(tester);
    await chooseMode(tester, 'adequacy', l10nEn.nutrientCustomTarget);
    await tester.enterText(amount('adequacy'), '35.125');
    await select(tester, l10nEn.ironLabel);
    await chooseMode(tester, 'upper', l10nEn.nutrientCustomUpper);
    await tester.enterText(amount('upper'), '40');
    await select(tester, l10nEn.fiberLabel);
    expect(
      tester.widget<TextField>(amount('adequacy')).controller!.text,
      '35.125',
    );
    expect(profile.writes, isEmpty);
    await tester.tap(control('nutrient-goals-save'));
    await tester.pumpAndSettle();
    expect(profile.writes.single['fiber']!.target, 35.125);
    expect(profile.writes.single['iron']!.upper, 40);
    expect(find.byType(NutrientGoalsScreen), findsNothing);
  });
  testWidgets(
    'source reset always opens for unavailable references and confirms replacement',
    (tester) async {
      await open(tester);
      await select(tester, l10nEn.caffeineLabel);
      await chooseMode(tester, 'upper', l10nEn.nutrientCustomUpper);
      await tester.enterText(amount('upper'), '100');
      await tester.ensureVisible(control('nutrient-goal-reset'));
      await tester.tap(control('nutrient-goal-reset'));
      await tester.pumpAndSettle();
      expect(find.text('NZ/Australia'), findsOneWidget);
      expect(find.text(l10nEn.referenceNotEstablished), findsWidgets);
      await tester.tap(control('nutrient-source-nz-australia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.dialogCancelLabel));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amount('upper')).controller!.text, '100');
      await tester.tap(control('nutrient-goal-reset'));
      await tester.pumpAndSettle();
      await tester.tap(control('nutrient-source-nz-australia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.buttonResetLabel));
      await tester.pumpAndSettle();
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(
        profile.writes.single['caffeine']!.region,
        ReferenceRegion.nzAustralia,
      );
      expect(
        profile.writes.single['caffeine']!.upperMode,
        ThresholdMode.reference,
      );
    },
  );
  testWidgets(
    'reset all retains each selected source and requires confirmation',
    (tester) async {
      profile.user.nutrientPolicies = {
        'fiber': const NutrientPolicy(
          source: 'nzAustralia',
          adequacyMode: ThresholdMode.custom,
          target: 42,
        ),
      };
      await open(tester);
      await tester.tap(control('nutrient-goals-reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.dialogCancelLabel));
      await tester.pumpAndSettle();
      expect(amount('adequacy'), findsOneWidget);
      await tester.tap(control('nutrient-goals-reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.buttonResetLabel));
      await tester.pumpAndSettle();
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(profile.writes.single['fiber']!.source, 'nzAustralia');
      expect(
        profile.writes.single['fiber']!.adequacyMode,
        ThresholdMode.reference,
      );
      expect(profile.writes.single['iron']!.source, 'usCanada');
    },
  );
  testWidgets(
    'unsaved navigation offers cancel, discard and save; failure keeps drafts',
    (tester) async {
      await open(tester);
      await chooseMode(tester, 'adequacy', l10nEn.nutrientCustomTarget);
      await tester.enterText(amount('adequacy'), '45');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.discardAndLeaveLabel), findsOneWidget);
      await tester.tap(find.text(l10nEn.dialogCancelLabel));
      await tester.pumpAndSettle();
      profile.fail = true;
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.saveAndLeaveLabel));
      await tester.pumpAndSettle();
      expect(find.byType(NutrientGoalsScreen), findsOneWidget);
      expect(profile.writes, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.discardAndLeaveLabel));
      await tester.pumpAndSettle();
      expect(find.byType(NutrientGoalsScreen), findsNothing);
    },
  );
  testWidgets(
    'positive targets and comparable contradictions validate across all drafts',
    (tester) async {
      await open(tester);
      await chooseMode(tester, 'adequacy', l10nEn.nutrientCustomTarget);
      await tester.enterText(amount('adequacy'), '0');
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(profile.writes, isEmpty);
      await tester.enterText(amount('adequacy'), '50');
      await chooseMode(tester, 'upper', l10nEn.nutrientCustomUpper);
      await tester.enterText(amount('upper'), '40');
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(profile.writes, isEmpty);
      await tester.enterText(amount('upper'), '60');
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(profile.writes, hasLength(1));
    },
  );
  testWidgets('visibility saves immediately and does not dirty the goal form', (
    tester,
  ) async {
    final h = OverviewDiaryHarness();
    await tester.runAsync(h.initialize);
    locator.registerSingleton<GetConfigUsecase>(h.getConfig);
    locator.registerSingleton<AddConfigUsecase>(AddConfigUsecase(h.config));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await locator.resetScope();
      await pumpUntilComplete(
        tester,
        h.dispose(),
        reason: 'closing settings storage',
      );
    });
    await open(tester);
    await tester.ensureVisible(control('nutrient-visibility-fiber-daily'));
    await tester.tap(control('nutrient-visibility-fiber-daily'));
    await pumpUntil(
      tester,
      () =>
          tester
              .widget<Checkbox>(
                find.descendant(
                  of: control('nutrient-visibility-fiber-daily'),
                  matching: find.byType(Checkbox),
                ),
              )
              .value ==
          false,
    );
    expect(profile.writes, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(l10nEn.unsavedChangesTitle), findsNothing);
  });
  testWidgets(
    'auto-adjust off freezes reference amounts and zero upper saves with adequacy unset',
    (tester) async {
      await open(tester);
      await tester.tap(control('nutrient-auto-adjust'));
      await tester.pumpAndSettle();
      await chooseMode(tester, 'adequacy', l10nEn.nutrientUnset);
      await chooseMode(tester, 'upper', l10nEn.nutrientCustomUpper);
      await tester.enterText(amount('upper'), '0');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.saveAndLeaveLabel));
      await tester.pumpAndSettle();
      final policy = profile.writes.single['fiber']!;
      expect(policy.autoAdjust, isFalse);
      expect(policy.frozenReference, isNotNull);
      expect(policy.frozenOn, isNotNull);
      expect(policy.upper, 0);
      expect(find.byType(NutrientGoalsScreen), findsNothing);
    },
  );
  testWidgets('detailed references fit enlarged text on narrow screens', (
    tester,
  ) async {
    await open(tester, scale: 2, width: 320);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
