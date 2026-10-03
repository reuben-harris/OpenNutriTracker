import 'dart:async';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/meal_section_actions.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/goal_value_toggle.dart';
import 'package:opennutritracker/core/presentation/widgets/selected_day_header.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/activity_detail/presentation/bloc/activity_detail_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/daily_nutrient_panel.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/day_info_widget.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_table_calendar.dart';
import 'package:opennutritracker/features/fasting/presentation/bloc/fasting_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/log_water_dialog.dart';
import 'package:opennutritracker/features/home/presentation/widgets/overview_macros.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import '../../helpers/overview_diary_harness.dart';

class QuietProfile extends Fake implements ProfileBloc {
  @override
  ProfileState get state => ProfileLoadingState();
  @override
  Stream<ProfileState> get stream => const Stream.empty();
  @override
  void add(ProfileEvent event) {}
}

class QuietTrends extends Fake implements TrendsBloc {
  @override
  TrendsState get state => const TrendsLoading();
  @override
  Stream<TrendsState> get stream => const Stream.empty();
  @override
  void add(TrendsEvent event) {}
}

class QuietFasting extends Fake implements FastingBloc {
  @override
  FastingState get state => const FastingIdle();
  @override
  Stream<FastingState> get stream => const Stream.empty();
  @override
  void add(FastingEvent event) {}
  @override
  Future<void> close() async {}
}

class NoWorkouts extends Fake implements ImportWorkoutsUsecase {
  int calls = 0;
  @override
  Future<int> importIfDue() async {
    calls++;
    return 0;
  }
}

class UnusedMealDetail extends Fake implements MealDetailBloc {}

class UnusedActivityDetail extends Fake implements ActivityDetailBloc {}

Widget app(
  Widget child, {
  double scale = 1,
  ThemeData? theme,
  RouteFactory? onGenerateRoute,
  Locale locale = const Locale('en'),
}) => ChangeNotifierProvider(
  create: (_) => EnergyUnitProvider(),
  child: MaterialApp(
    theme: theme,
    onGenerateRoute: onGenerateRoute,
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);
Finder id(String name) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == name,
);

void main() {
  test(
    'percentages use daily goals, exceed 100, and handle undefined goals',
    () {
      expect(goalPercentage(150, 100), '150%');
      expect(goalProgress(150, 100), 1);
      expect(goalPercentage(0, 0), '—');
      expect(goalPercentage(20, double.nan), '—');
      expect(goalProgress(20, 0), 0);
    },
  );

  testWidgets(
    'water validates exact corrections, prevents duplicate saves and retains failures',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        app(
          LogWaterDialog(
            initialAmount: 337,
            onSave: (amount) async {
              expect(amount, 337);
              calls++;
              await pending.future;
            },
          ),
        ),
      );
      expect(find.text('337'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1.5');
      await tester.tap(id('log-water-save'));
      await tester.pump();
      expect(
        find.text('Enter a positive whole number of millilitres.'),
        findsOneWidget,
      );
      expect(calls, 0);
      await tester.enterText(find.byType(TextField), '337');
      await tester.tap(id('log-water-save'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.completeError(StateError('disk unavailable'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(LogWaterDialog), findsOneWidget);
      expect(
        find.text('Could not save water changes. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('337'), findsOneWidget);
    },
  );

  testWidgets(
    'stacked macros and permanently expanded nutrients fit compact large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Nunito')
        ..addFont(rootBundle.load('fonts/Nunito.ttf'));
      await font.load();
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: Column(
              children: [
                OverviewMacros(
                  carbs: 150,
                  fat: 20,
                  protein: 0,
                  carbsGoal: 100,
                  fatGoal: 0,
                  proteinGoal: 50,
                  asPercent: true,
                  onToggle: () {},
                ),
                DailyNutrientPanel(
                  intakes: const [],
                  asPercent: false,
                  onToggle: () {},
                ),
              ],
            ),
          ),
          theme: buildAppTheme(AppPalette.light),
          scale: 2,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('150%'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(13));
      final sodiumAmount = find.textContaining('/ 2300mg');
      expect(sodiumAmount, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(sodiumAmount).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'English date and two-digit calendar cells fit at 320dp and 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Nunito')
        ..addFont(rootBundle.load('fonts/Nunito.ttf'));
      await font.load();
      final h = OverviewDiaryHarness();
      DayBoundaryCalc.clock = () => DateTime(2026, 9, 29, 12);
      await tester.runAsync(h.initialize);
      locator.registerSingleton<SelectedDayCubit>(h.selection);
      addTearDown(() async {
        DayBoundaryCalc.clock = DateTime.now;
        await locator.reset();
        await h.dispose();
      });
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: Column(
              children: [
                const SelectedDayHeader(),
                DiaryTableCalendar(
                  onDateSelected: (_, _) {},
                  calendarDurationDays: const Duration(days: 365 * 5),
                  focusedDate: h.selection.state.day,
                  currentDate: h.selection.state.today,
                  selectedDate: h.selection.state.day,
                  trackedDaysMap: const {},
                ),
              ],
            ),
          ),
          theme: buildAppTheme(AppPalette.light),
          scale: 2,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      final paragraphs = tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      );
      var checkedDays = 0;
      for (final paragraph in paragraphs) {
        final text = paragraph.text.toPlainText();
        if (RegExp(r'^\d{1,2}$').hasMatch(text) ||
            text.contains('Sept.') ||
            text == 'September 2026') {
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + 1),
            reason: text,
          );
          checkedDays++;
        }
      }
      expect(checkedDays, greaterThan(28));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('calendar keeps the browsed month when its parent refreshes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget calendar() => app(
      DiaryTableCalendar(
        onDateSelected: (_, _) {},
        calendarDurationDays: const Duration(days: 365 * 5),
        focusedDate: DateTime(2026, 9, 29),
        currentDate: DateTime(2026, 9, 29),
        selectedDate: DateTime(2026, 9, 29),
        trackedDaysMap: const {},
      ),
    );
    await tester.pumpWidget(calendar());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    await tester.pumpWidget(calendar());
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets('meal shortcuts retain the selected day and meal group', (
    tester,
  ) async {
    for (final day in [DateTime(2026, 9, 20), DateTime(2026, 10, 3)]) {
      for (final type in AddMealType.values) {
        RouteSettings? destination;
        await tester.pumpWidget(
          app(
            MealSectionActions(day: day, mealType: type),
            onGenerateRoute: (settings) {
              destination = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('Destination')),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(id('diary-${type.getIntakeType().name}-scan'));
        await tester.pumpAndSettle();
        expect(destination!.name, NavigationOptions.scannerRoute);
        final scanner = destination!.arguments as ScannerScreenArguments;
        expect(scanner.day, day);
        expect(scanner.intakeTypeEntity, type.getIntakeType());
        expect(scanner.initialBarcode, isNull);
        Navigator.of(tester.element(find.text('Destination'))).pop();
        await tester.pumpAndSettle();

        await tester.tap(id('add-meal-placeholder'));
        await tester.pumpAndSettle();
        expect(destination!.name, NavigationOptions.addMealRoute);
        final search = destination!.arguments as AddMealScreenArguments;
        expect(search.day, day);
        expect(search.mealType, type);
        Navigator.of(tester.element(find.text('Destination'))).pop();
        await tester.pumpAndSettle();

        await tester.tap(id('diary-${type.getIntakeType().name}-quick-add'));
        await tester.pumpAndSettle();
        final quickAdd = tester.widget<QuickAddBottomSheet>(
          find.byType(QuickAddBottomSheet),
        );
        expect(quickAdd.day, day);
        expect(quickAdd.intakeType, type.getIntakeType());
        Navigator.of(tester.element(find.byType(QuickAddBottomSheet))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets(
    'entry macros show the logged portion below energy in the amount colour',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final meal = MealEntity(
        code: 'portion',
        name: 'A meal with a long name',
        url: null,
        mealQuantity: '100',
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: 'g',
        servingSize: null,
        source: MealSourceEntity.custom,
        nutriments: MealNutrimentsEntity(
          energyKcal100: 200,
          carbohydrates100: 40,
          fat100: 8,
          proteins100: 20,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
      );
      final intake = IntakeEntity(
        id: 'portion',
        unit: 'g',
        amount: 25,
        type: IntakeTypeEntity.lunch,
        meal: meal,
        dateTime: DateTime(2026, 9, 20),
      );
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          app(
            IntakeCard(
              key: const ValueKey('portion'),
              intake: intake,
              firstListElement: true,
              usesImperialUnits: false,
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final macros = find.text('10 c 2 f 5 p');
        final energy = find.text('50 kcal');
        expect(macros, findsOneWidget);
        expect(
          tester.getCenter(macros).dy,
          greaterThan(tester.getCenter(energy).dy),
        );
        final amount = tester.widget<MealValueUnitText>(
          find.byType(MealValueUnitText),
        );
        expect(
          tester.widget<Text>(macros).style!.color,
          amount.textStyle!.color,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Diary opens first; calendar and Overview share one date without a central add button',
    (tester) async {
      final h = OverviewDiaryHarness();
      late DiaryBloc diary;
      final importer = NoWorkouts();
      DayBoundaryCalc.clock = () => DateTime(2026, 9, 29, 12);
      await tester.runAsync(() async {
        await h.initialize();
        h.createHome();
        h.createCalendar();
      });
      diary = DiaryBloc(GetTrackedDayUsecase(h.tracked), h.getConfig);
      locator.registerSingleton<SelectedDayCubit>(h.selection);
      locator.registerSingleton<GetConfigUsecase>(h.getConfig);
      locator.registerSingleton<GetIntakeUsecase>(h.getIntakes);
      locator.registerSingleton<GetUserUsecase>(h.getUser);
      locator.registerSingleton<AddConfigUsecase>(AddConfigUsecase(h.config));
      locator.registerSingleton<HomeBloc>(h.home!);
      locator.registerSingleton<CalendarDayBloc>(h.calendar!);
      locator.registerSingleton<DiaryBloc>(diary);
      locator.registerSingleton<ImportWorkoutsUsecase>(importer);
      locator.registerSingleton<ProfileBloc>(QuietProfile());
      locator.registerSingleton<TrendsBloc>(QuietTrends());
      locator.registerFactory<FastingBloc>(QuietFasting.new);
      locator.registerFactory<MealDetailBloc>(UnusedMealDetail.new);
      locator.registerFactory<ActivityDetailBloc>(UnusedActivityDetail.new);
      addTearDown(() async {
        DayBoundaryCalc.clock = DateTime.now;
        await locator.reset();
        await diary.close();
        await h.dispose();
      });
      await tester.pumpWidget(app(const MainScreen()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DayInfoWidget), findsOneWidget);
      expect(find.byType(DashboardWidget), findsNothing);
      expect(find.byType(DailyNutrientPanel), findsNothing);
      expect(
        tester.getCenter(id('nav-diary')).dx,
        lessThan(tester.getCenter(id('nav-overview')).dx),
      );
      expect(importer.calls, 1);
      await tester.tap(id('selected-day-next'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      expect(h.selection.state.day, DateTime(2026, 9, 30));
      await tester.tap(id('selected-day-calendar'));
      await tester.pump(const Duration(milliseconds: 500));
      final calendar = tester.widget<DiaryTableCalendar>(
        find.byType(DiaryTableCalendar),
      );
      expect(calendar.selectedDate, h.selection.state.day);
      calendar.onDateSelected(DateTime.utc(2026, 9, 20), const {});
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(id('nav-overview'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      expect(h.selection.state.day, DateTime(2026, 9, 20));
      expect(find.byType(DayInfoWidget), findsNothing);
      expect(find.byType(DashboardWidget), findsOneWidget);
      expect(
        tester
            .widget<DashboardWidget>(find.byType(DashboardWidget))
            .allowGoalDetails,
        isFalse,
      );
      expect(id('diary-water-add'), findsNothing);
      expect(id('home-water-edit'), findsNothing);
      expect(id('home-weight-chip'), findsNothing);
      expect(id('fab-add-item'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(id('overview-nutrients-period'), findsNothing);
      // Logging flows replace MainScreen; they must retain the chosen day.
      await tester.pumpWidget(app(const MainScreen(key: ValueKey('reopened'))));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(h.selection.state.day, DateTime(2026, 9, 20));
      await tester.tap(id('selected-day-calendar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(id('selected-day-today'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: id('selected-day-today'),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      await tester.tap(id('selected-day-today'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      expect(h.selection.state.isToday, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
