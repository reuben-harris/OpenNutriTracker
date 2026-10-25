import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/nutrient_goals_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../fixture/user_entity_fixtures.dart';
import '../../helpers/test_l10n.dart';

class _Settings extends Fake implements SettingsBloc {
  Map<String, NutrientGoal> goals = {};
  final writes = <Map<String, NutrientGoal>>[];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<TrackedDayEntity?> getTodayTrackedDay(DateTime day) async =>
      TrackedDayEntity(
        day: day,
        calorieGoal: 2000,
        caloriesTracked: 0,
        nutrientGoals: goals,
      );
  @override
  Future<void> setTodayNutrientGoals(
    DateTime day,
    Map<String, NutrientGoal> value,
  ) async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Save failed');
    goals = Map.of(value);
    writes.add(Map.of(value));
  }

  @override
  void add(SettingsEvent event) {}
}

class _Profile extends Fake implements ProfileBloc {
  @override
  Future<UserEntity> getUser() async =>
      UserEntityFixtures.youngSedentaryMaleWantingToMaintainWeight;
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
  (widget) => widget is Semantics && widget.properties.identifier == id,
);
Finder field(String key) => find.descendant(
  of: control('nutrient-goal-$key'),
  matching: find.byType(TextField),
);

void main() {
  late _Settings settings;
  setUp(() => settings = _Settings());

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 900);
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NutrientGoalsScreen(
                    settingsBloc: settings,
                    profileBloc: _Profile(),
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

  Future<void> back(WidgetTester tester) async {
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String text) async {
    await tester.tap(find.widgetWithText(TextButton, text));
    await tester.pumpAndSettle();
  }

  testWidgets('unchanged goals leave without a prompt or a write', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    expect(find.byType(NutrientGoalsScreen), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.writes, isEmpty);
  });

  testWidgets(
    'sources opens beside Reset all and retains unsaved goals on return',
    (tester) async {
      await open(tester);
      await tester.enterText(field('sugar'), '25');
      await tester.pump();
      final info = control('nutrient-goals-sources');
      expect(
        tester.getTopLeft(info).dx,
        lessThan(tester.getTopLeft(control('nutrient-goals-reset')).dx),
      );
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);
      expect(find.text(l10nEn.settingsSourcesLabel), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await back(tester);
      expect(tester.widget<TextField>(field('sugar')).controller!.text, '25');
      expect(settings.writes, isEmpty);
      await back(tester);
      expect(find.text(l10nEn.unsavedChangesTitle), findsOneWidget);
      await choose(tester, l10nEn.dialogCancelLabel);
    },
  );

  testWidgets('amount, kind and reset remain inline at enlarged text', (
    tester,
  ) async {
    settings.goals = {'sugar': const NutrientGoal(20, isLimit: true)};
    await open(tester, scale: 2);
    final input = field('sugar');
    final kind = find.byType(DropdownButtonFormField<bool>).first;
    expect(tester.getTopLeft(input).dy, tester.getTopLeft(kind).dy);
    expect(
      tester.getTopLeft(control('nutrient-goal-reset-sugar')).dy,
      tester.getTopLeft(kind).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel retains edits; discard leaves without saving', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('sugar'), '25');
    await tester.pump(const Duration(seconds: 1));
    expect(settings.writes, isEmpty);
    await back(tester);
    expect(find.text(l10nEn.unsavedChangesTitle), findsOneWidget);
    expect(find.text(l10nEn.saveAndLeaveLabel), findsOneWidget);
    await choose(tester, l10nEn.dialogCancelLabel);
    expect(tester.widget<TextField>(field('sugar')).controller!.text, '25');
    await back(tester);
    await choose(tester, l10nEn.discardAndLeaveLabel);
    expect(find.byType(NutrientGoalsScreen), findsNothing);
    expect(settings.writes, isEmpty);
  });

  testWidgets('save and leave persists both the amount and goal kind', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('sugar'), '25');
    await tester.pump();
    await tester.tap(control('nutrient-goal-kind-sugar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.nutrientGoalTargetLabel).last);
    await tester.pumpAndSettle();
    await back(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, l10nEn.saveAndLeaveLabel),
    );
    await tester.pumpAndSettle();
    expect(settings.writes.single, {'sugar': const NutrientGoal(25)});
    expect(find.byType(NutrientGoalsScreen), findsNothing);
  });

  testWidgets('a failed save keeps edits and the unsaved-change warning', (
    tester,
  ) async {
    settings.fail = true;
    await open(tester);
    await tester.enterText(field('sugar'), '25');
    await back(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, l10nEn.saveAndLeaveLabel),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NutrientGoalsScreen), findsOneWidget);
    expect(find.text(l10nEn.nutrientSettingsSaveFailedLabel), findsOneWidget);
    expect(tester.widget<TextField>(field('sugar')).controller!.text, '25');
    expect(settings.writes, isEmpty);
    await back(tester);
    expect(find.text(l10nEn.unsavedChangesTitle), findsOneWidget);
    await choose(tester, l10nEn.dialogCancelLabel);
    settings.fail = false;
    await tester.tap(control('nutrient-goals-save'));
    await tester.pumpAndSettle();
    expect(
      settings.writes.single['sugar'],
      const NutrientGoal(25, isLimit: true),
    );
    expect(find.byType(NutrientGoalsScreen), findsNothing);
  });

  testWidgets(
    'changing a default reference to a limit saves its displayed amount',
    (tester) async {
      await open(tester);
      expect(
        tester.widget<TextField>(field('fiber')).controller!.text,
        isEmpty,
      );
      await tester.tap(control('nutrient-goal-kind-fiber'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.nutrientGoalLimitLabel).last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('fiber')).controller!.text, '38');
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(
        settings.writes.single['fiber'],
        const NutrientGoal(38, isLimit: true),
      );
    },
  );

  testWidgets(
    'single and global reset require confirmation and remain unsaved',
    (tester) async {
      settings.goals = {
        'sugar': const NutrientGoal(20),
        'fiber': const NutrientGoal(30, isLimit: true),
      };
      await open(tester);
      await tester.tap(control('nutrient-goal-reset-sugar'));
      await tester.pumpAndSettle();
      await choose(tester, l10nEn.dialogCancelLabel);
      expect(tester.widget<TextField>(field('sugar')).controller!.text, '20');
      await tester.tap(control('nutrient-goal-reset-sugar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10nEn.buttonResetLabel),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('sugar')).controller!.text,
        isEmpty,
      );
      expect(tester.widget<TextField>(field('fiber')).controller!.text, '30');
      expect(settings.writes, isEmpty);
      await tester.tap(control('nutrient-goals-reset'));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.nutrientGoalsResetAllTitle), findsOneWidget);
      await choose(tester, l10nEn.dialogCancelLabel);
      expect(tester.widget<TextField>(field('fiber')).controller!.text, '30');
      await tester.tap(control('nutrient-goals-reset'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10nEn.buttonResetLabel),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('fiber')).controller!.text,
        isEmpty,
      );
      expect(settings.writes, isEmpty);
      await tester.tap(control('nutrient-goals-save'));
      await tester.pumpAndSettle();
      expect(settings.writes.single, isEmpty);
    },
  );

  testWidgets('invalid numbers cannot be saved by leaving', (tester) async {
    await open(tester);
    await tester.enterText(field('sugar'), '-1');
    await back(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, l10nEn.saveAndLeaveLabel),
    );
    await tester.pumpAndSettle();
    expect(settings.writes, isEmpty);
    expect(find.byType(NutrientGoalsScreen), findsOneWidget);
    expect(find.text(l10nEn.nutrientInvalidAmountLabel), findsWidgets);
  });

  testWidgets('back cannot interrupt an in-flight save', (tester) async {
    final pending = settings.pending = Completer<void>();
    await open(tester);
    await tester.enterText(field('sugar'), '25');
    await tester.tap(control('nutrient-goals-save'));
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    expect(find.byType(NutrientGoalsScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(settings.writes, hasLength(1));
    expect(find.byType(NutrientGoalsScreen), findsNothing);
  });
}
