import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/create_recipe_from_intakes_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import '../../helpers/pump_until.dart';
import '../../helpers/locator_test_setup.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/activity_detail/presentation/bloc/activity_detail_bloc.dart';
import 'package:opennutritracker/features/diary/diary_page.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_copy_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_sort_type.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/intake_vertical_list.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../fixture/diary_entry_fixtures.dart';
import '../../helpers/diary_workflow_harness.dart';

class _Activity extends Fake implements ActivityDetailBloc {}

Finder control(String id) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == id,
);
Finder section(IntakeTypeEntity type) => find.byWidgetPredicate(
  (widget) =>
      widget is IntakeVerticalList &&
      widget.addMealType.getIntakeType() == type,
);
Finder menu(IntakeTypeEntity type) => find.descendant(
  of: section(type),
  matching: find.byType(PopupMenuButton<DiaryMealAction>),
);

void main() {
  useTestLocator();
  late DateTime Function() originalClock;
  late DiaryWorkflowHarness h;
  late DiaryBloc diary;
  late DiaryClipboardCubit clipboard;
  var now = DateTime(2026, 9, 29, 12);
  setUp(() async {
    now = DateTime(2026, 9, 29, 12);
    originalClock = DayBoundaryCalc.clock;
    DayBoundaryCalc.clock = () => now;
    h = DiaryWorkflowHarness();
    await h.initialize();
    await h.configSource.setConfigShowActivityTracking(false);
    h.createHome();
    h.createCalendar();
    diary = DiaryBloc(GetTrackedDayUsecase(h.tracked), h.getConfig);
    clipboard = DiaryClipboardCubit();
    h.createCopier(
      refresh: () {
        h.home!.add(const LoadItemsEvent());
        diary.add(const LoadDiaryYearEvent());
        h.calendar!.add(RefreshCalendarDayEvent());
      },
    );
    locator.registerSingleton<DiaryClipboardCubit>(clipboard);
    locator.registerSingleton<DiaryCopyCubit>(h.copier);
    locator.registerSingleton<SelectedDayCubit>(h.selection);
    locator.registerSingleton<CalendarDayBloc>(h.calendar!);
    locator.registerSingleton<DiaryBloc>(diary);
    locator.registerSingleton<HomeBloc>(h.home!);
    locator.registerSingleton<ActivityDetailBloc>(_Activity());
    locator.registerSingleton<UpdateIntakeUsecase>(
      UpdateIntakeUsecase(h.intakes),
    );
    locator.registerSingleton<GetConfigUsecase>(h.getConfig);
    locator.registerSingleton<IntakeRepository>(h.intakes);
  });
  tearDown(() async {
    await locator.resetScope();
    await diary.close();
    await clipboard.close();
    await h.dispose();
    DayBoundaryCalc.clock = originalClock;
  });

  Future<void> mount(
    WidgetTester tester, {
    List<IntakeEntity>? entries,
    double scale = 1,
    RouteFactory? onGenerateRoute,
  }) async {
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final records = entries ?? [diaryEntry()];
    await tester.runAsync(() async {
      for (final entry in records) {
        await h.intakes.addIntake(entry);
      }
      final loaded = h.calendar!.stream.firstWhere(
        (state) => state is CalendarDayLoaded,
      );
      final loadedDiary = diary.stream.firstWhere(
        (state) => state is DiaryLoadedState,
      );
      h.calendar!.add(LoadCalendarDayEvent(h.selection.state.day));
      diary.add(const LoadDiaryYearEvent());
      await Future.wait([loaded, loadedDiary]);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          onGenerateRoute: onGenerateRoute,
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: const SwipeRevealScope(child: DiaryPage()),
            bottomNavigationBar: const SizedBox(
              height: 78,
              child: Center(child: Text('Navigation')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'meal menu creates a saved recipe and opens it without changing diary entries',
    (tester) async {
      final store = _RecipeStore();
      final compute = ComputeRecipeNutritionUseCase();
      locator.registerSingleton<CreateRecipeFromIntakesUsecase>(
        CreateRecipeFromIntakesUsecase(
          compute,
          SaveRecipeUseCase(store, compute),
        ),
      );
      RecipeDetailArguments? opened;
      final source = [diaryEntry(), diaryEntry(id: 'second', amount: 50)];
      await mount(
        tester,
        entries: source,
        onGenerateRoute: (settings) {
          expect(settings.name, NavigationOptions.recipeDetailRoute);
          opened = settings.arguments as RecipeDetailArguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Created recipe')),
          );
        },
      );
      await tester.ensureVisible(menu(IntakeTypeEntity.breakfast));
      await tester.tap(menu(IntakeTypeEntity.breakfast));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('diary-create-recipe'));
      await tester.pumpAndSettle();
      expect(find.text('Created recipe'), findsOneWidget);
      expect(store.saved, hasLength(1));
      final recipe = store.saved.single;
      expect(opened!.recipeId, recipe.id);
      expect(recipe.name, 'Breakfast recipe');
      expect(
        recipe.ingredients.map((i) => i.quantity),
        source.map((e) => e.quantity),
      );
      expect(recipe.totalWeightG, 175);
      final entries = await h.intakes.getIntakeByDateAndType(
        IntakeTypeEntity.breakfast,
        h.selection.state.day,
      );
      expect(entries.map((e) => e.id), source.map((e) => e.id));
      expect(entries.map((e) => e.quantity), source.map((e) => e.quantity));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'creating a recipe asks for missing weight and preserves Quick Add totals',
    (tester) async {
      final store = _RecipeStore();
      final compute = ComputeRecipeNutritionUseCase();
      locator.registerSingleton<CreateRecipeFromIntakesUsecase>(
        CreateRecipeFromIntakesUsecase(
          compute,
          SaveRecipeUseCase(store, compute),
        ),
      );
      final base = diaryEntry();
      final quick = IntakeEntity(
        id: 'quick',
        type: base.type,
        dateTime: base.dateTime,
        quantity: null,
        meal: MealEntity(
          code: 'quick',
          name: 'Sauce',
          url: null,
          mealQuantity: null,
          mealUnit: 'gml',
          servingQuantity: null,
          servingUnit: null,
          servingSize: null,
          nutriments: base.meal.nutriments,
          source: MealSourceEntity.custom,
          isQuickAdd: true,
        ),
      );
      await mount(
        tester,
        entries: [quick],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Created recipe')),
        ),
      );
      await tester.ensureVisible(menu(IntakeTypeEntity.breakfast));
      await tester.tap(menu(IntakeTypeEntity.breakfast));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('diary-create-recipe'));
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);
      await tester.enterText(
        find.descendant(
          of: find.bySemanticsIdentifier('quick-add-weight'),
          matching: find.byType(TextField),
        ),
        '20',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.bySemanticsIdentifier('quick-add-submit'),
      );
      await tester.tap(find.bySemanticsIdentifier('quick-add-submit'));
      await tester.pumpAndSettle();
      expect(find.text('Created recipe'), findsOneWidget);
      expect(store.saved.single.totalWeightG, 20);
      expect(
        store.saved.single.aggregatedNutrimentsPer100.energyKcal100! * .2,
        quick.totalKcal,
      );
      final original = await h.intakes.getIntakeByDateAndType(
        IntakeTypeEntity.breakfast,
        h.selection.state.day,
      );
      expect(original.single.quantity, isNull);
      expect(original.single.totalKcal, quick.totalKcal);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<void> settleStorage(WidgetTester tester) async {
    await tester.runAsync(() async {
      await h.copier.idle;
    });
    await tester.pump();
    await pumpUntil(
      tester,
      () =>
          h.calendar!.state is CalendarDayLoaded &&
          diary.state is DiaryLoadedState,
    );
    await tester.pumpAndSettle();
  }

  Future<TestGesture> hold(WidgetTester tester, {String id = 'source'}) async {
    final card = find.descendant(
      of: find.byKey(ValueKey(id)).first,
      matching: find.byType(IntakeCard),
    );
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
    return gesture;
  }

  testWidgets('hold starts drag, cancellation leaves data and day unchanged', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await hold(tester);
    expect(find.byKey(const ValueKey('fb-source')), findsOneWidget);
    expect(control('diary-copy-target'), findsNothing);
    expect(control('diary-delete-target'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(control('diary-copy-target'), findsNothing);
    expect(h.selection.state.day, DateTime(2026, 9, 29));
    expect(await h.intakes.getAllIntakesDBO(), hasLength(1));
  });

  testWidgets(
    'drag preserves group geometry and highlights destination groups',
    (tester) async {
      await mount(tester, scale: 1.8);
      final breakfast = tester.getRect(control('diary-breakfast-group'));
      final lunch = tester.getRect(control('diary-lunch-group'));
      final dinner = tester.getRect(control('diary-dinner-group'));
      expect(lunch.top - breakfast.bottom, 12);
      expect(dinner.top - lunch.bottom, 12);
      final header = find
          .ancestor(
            of: menu(IntakeTypeEntity.lunch),
            matching: find.byType(Row),
          )
          .first;
      final topPadding = tester.getTopLeft(header).dy - lunch.top;
      final bottomPadding =
          lunch.bottom - tester.getBottomLeft(control('diary-lunch-scan')).dy;
      expect(bottomPadding, topPadding);
      final sourceRect = tester.getRect(find.byType(IntakeCard).first);
      final drag = await hold(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('fb-source'))),
        sourceRect,
      );
      expect(tester.getRect(control('diary-breakfast-group')), breakfast);
      expect(tester.getRect(control('diary-lunch-group')), lunch);
      expect(tester.getRect(control('diary-dinner-group')), dinner);
      Color background(String id) =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: control(id),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final idleColor = background('diary-lunch-group');
      await drag.moveTo(tester.getCenter(find.text('Lunch')));
      await tester.pump();
      expect(background('diary-lunch-group'), isNot(idleColor));
      expect(tester.getRect(control('diary-lunch-group')), lunch);
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(await h.intakes.getAllIntakesDBO(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swipe Copy preserves source, pastes into empty groups repeatedly and clears',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      await tester.drag(find.byType(IntakeCard).first, const Offset(-140, 0));
      await tester.pumpAndSettle();
      await tester.tap(control('diary-intake-copy'));
      await tester.pumpAndSettle();
      expect(clipboard.state.single.id, 'source');
      expect(await h.intakes.getAllIntakesDBO(), hasLength(1));
      expect(control('diary-clear-clipboard'), findsOneWidget);
      expect(control('diary-lunch-paste'), findsOneWidget);
      final preview = control('diary-lunch-paste');
      for (final label in [
        'Diary oats',
        '125 g',
        '475 kcal',
        '75 c 10 f 15 p',
      ]) {
        expect(
          find.descendant(of: preview, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: preview, matching: find.byType(FoodImage)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.content_paste_rounded), findsNothing);
      await tester.runAsync(() => tester.tap(control('diary-lunch-paste')));
      await settleStorage(tester);
      await tester.runAsync(() => tester.tap(control('diary-lunch-paste')));
      await settleStorage(tester);
      expect(
        await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.lunch,
          h.selection.state.day,
        ),
        hasLength(2),
      );
      expect(clipboard.state, hasLength(1));
      await tester.runAsync(() => tester.tap(control('diary-clear-clipboard')));
      await tester.pumpAndSettle();
      expect(clipboard.state, isEmpty);
      expect(control('diary-lunch-paste'), findsNothing);
      expect(control('diary-clear-clipboard'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'swipe Delete confirms once, cancellation retains source, confirmation deletes',
    (tester) async {
      final entry = diaryEntry();
      final day = h.selection.state.day;
      await tester.runAsync(() async {
        await h.tracked.addNewTrackedDay(day, 2000, 250, 60, 100);
        await h.tracked.addDayTrackedCalories(day, entry.totalKcal);
        await h.tracked.addDayMacrosTracked(
          day,
          carbsTracked: entry.totalCarbsGram,
          fatTracked: entry.totalFatsGram,
          proteinTracked: entry.totalProteinsGram,
        );
      });
      await mount(tester);
      for (final confirm in [false, true]) {
        await tester.drag(find.byType(IntakeCard).first, const Offset(-140, 0));
        await tester.pumpAndSettle();
        await tester.runAsync(() => tester.tap(control('diary-intake-delete')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        var reloaded = !confirm;
        final loaded = confirm
            ? h.calendar!.stream
                  .firstWhere((s) => s is CalendarDayLoaded)
                  .then((_) => reloaded = true)
            : Future.value(true);
        await tester.runAsync(
          () => tester.tap(find.text(confirm ? 'OK' : 'CANCEL')),
        );
        await pumpUntil(tester, () => reloaded);
        await loaded;
        await settleStorage(tester);
        expect(await h.intakes.getAllIntakesDBO(), hasLength(confirm ? 0 : 1));
        final totals = (await h.tracked.getTrackedDay(day))!;
        expect(totals.caloriesTracked, confirm ? 0 : entry.totalKcal);
        expect(totals.carbsTracked, confirm ? 0 : entry.totalCarbsGram);
        expect(totals.fatTracked, confirm ? 0 : entry.totalFatsGram);
        expect(totals.proteinTracked, confirm ? 0 : entry.totalProteinsGram);
        expect(find.byType(AlertDialog), findsNothing);
        if (confirm) {
          expect(find.text('Item deleted'), findsOneWidget);
          expect(
            (h.calendar!.state as CalendarDayLoaded).breakfastIntakeList,
            isEmpty,
          );
        }
      }
    },
  );

  testWidgets(
    'meal drop keeps identity and selected sorting; same group does not write',
    (tester) async {
      await tester.runAsync(
        () => h.calendar!.setDiarySortPreference(
          'lunch',
          DiarySortType.kcal.index,
        ),
      );

      await mount(tester);

      final before = (await h.intakes.getAllIntakesDBO()).single.toJson()
        ..remove('type');
      var writes = 0;
      final watch = h.db.intakeBox.watch().listen((_) => writes++);
      var gesture = await hold(tester);
      await gesture.moveTo(tester.getCenter(find.text('Lunch')));
      await tester.pump();
      await tester.runAsync(gesture.up);

      await settleStorage(tester);

      expect(
        (await h.intakes.getAllIntakesDBO()).single.toJson()..remove('type'),
        before,
      );
      expect(
        (await h.intakes.getIntakeById('source'))!.type,
        IntakeTypeEntity.lunch,
      );
      expect(
        tester
            .widget<IntakeVerticalList>(section(IntakeTypeEntity.lunch))
            .sortType,
        DiarySortType.kcal,
      );
      expect(writes, 1);
      gesture = await hold(tester);
      await gesture.moveTo(tester.getCenter(find.text('Lunch')));
      await tester.pump();
      await tester.runAsync(gesture.up);

      await settleStorage(tester);

      expect(writes, 1);

      await tester.runAsync(watch.cancel);
    },
  );

  testWidgets('drag scrolls to offscreen groups and hides the clear button', (
    tester,
  ) async {
    clipboard.copy([diaryEntry()]);
    await mount(
      tester,
      entries: List.generate(
        7,
        (i) => diaryEntry(id: i == 0 ? 'source' : 'row-$i'),
      ),
    );
    final gesture = await hold(tester);
    expect(control('diary-clear-clipboard'), findsNothing);
    final viewport = tester.getRect(find.byType(ListView).first);
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 30));
    await tester.pump(const Duration(seconds: 2));
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(scroll.pixels, greaterThan(200));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(control('diary-clear-clipboard'), findsOneWidget);
  });

  testWidgets(
    'logical today menus copy yesterday across year boundary and append',
    (tester) async {
      now = DateTime(2027, 1, 2, 2, 15);
      await tester.runAsync(() async {
        await h.config.setConfigDayStartOffsetHours(6);
        await h.config.setConfigDayStartOffsetMinutes(30);
        await h.selection.initialize(reset: true);
      });
      expect(h.selection.state.today, DateTime(2027, 1, 1));
      final source = diaryEntry();
      final yesterday = IntakeEntity(
        id: 'yesterday',
        quantity: source.quantity,
        type: source.type,
        meal: source.meal,
        dateTime: DateTime(2026, 12, 31, 9),
      );
      await mount(tester, entries: [yesterday]);
      await tester.runAsync(() => tester.tap(menu(IntakeTypeEntity.breakfast)));
      await tester.pumpAndSettle();
      expect(find.text('Copy from yesterday'), findsOneWidget);
      expect(find.text('Copy to today'), findsNothing);
      await tester.runAsync(() => tester.tap(find.text('Copy from yesterday')));
      await pumpUntil(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.runAsync(() => tester.tap(find.text('OK')));
      await settleStorage(tester);
      expect(
        await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.breakfast,
          DateTime(2027, 1, 1),
          dayStartOffsetHours: 6,
          dayStartOffsetMinutes: 30,
        ),
        hasLength(1),
      );
      await tester.runAsync(() => tester.tap(menu(IntakeTypeEntity.lunch)));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Copy from yesterday')));
      await pumpUntil(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
        reason: 'copy source dialog after loading yesterday’s meal groups',
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.runAsync(() => tester.tap(find.text('OK')));
      await tester.pumpAndSettle();
      expect(find.text('No entries in Lunch yesterday.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.runAsync(() => tester.tap(find.text('CANCEL')));
      await settleStorage(tester);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  for (final hasYesterdayLunch in [false, true]) {
    testWidgets(
      'copy yesterday dinner into today lunch when yesterday lunch exists: $hasYesterdayLunch',
      (tester) async {
        final recipe = diaryEntry(recipe: true);
        final dinner = IntakeEntity(
          id: 'yesterday-dinner',
          quantity: recipe.quantity,
          type: IntakeTypeEntity.dinner,
          meal: recipe.meal,
          recipeSnapshot: recipe.recipeSnapshot,
          dateTime: DateTime(2026, 9, 28, 20),
        );
        final food = diaryEntry(amount: 50);
        final lunch = IntakeEntity(
          id: 'today-lunch',
          quantity: food.quantity,
          type: IntakeTypeEntity.lunch,
          meal: food.meal,
          dateTime: DateTime(2026, 9, 29, 12),
        );
        await mount(
          tester,
          entries: [
            dinner,
            lunch,
            if (hasYesterdayLunch)
              IntakeEntity(
                id: 'yesterday-lunch',
                quantity: food.quantity,
                type: IntakeTypeEntity.lunch,
                meal: food.meal,
                dateTime: DateTime(2026, 9, 28, 12),
              ),
          ],
        );
        await tester.ensureVisible(menu(IntakeTypeEntity.lunch));
        await tester.runAsync(() => tester.tap(menu(IntakeTypeEntity.lunch)));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => tester.tap(find.text('Copy from yesterday')),
        );
        await pumpUntil(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
          reason: 'copy source dialog after loading yesterday’s meal groups',
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Which meal group do you want to copy from?',
            findRichText: true,
          ),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButton<AddMealType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dinner').last);
        await tester.pumpAndSettle();
        await tester.runAsync(() => tester.tap(find.text('OK')));
        await settleStorage(tester);

        final entries = await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.lunch,
          h.selection.state.today,
        );
        expect(entries, hasLength(2));
        expect(entries, contains(lunch));
        final copied = entries.singleWhere((entry) => entry.id != lunch.id);
        expect(copied.id, isNot(dinner.id));
        expect(copied.quantity, dinner.quantity);
        expect(copied.recipeSnapshot, dinner.recipeSnapshot);
        expect(await h.intakes.getIntakeById(dinner.id), dinner);
        expect(
          await h.intakes.getIntakeByDateAndType(
            IntakeTypeEntity.dinner,
            h.selection.state.today,
          ),
          isEmpty,
        );
      },
    );
  }

  testWidgets(
    'copy to today keeps the menu source and chooses the destination',
    (tester) async {
      final source = diaryEntry(recipe: true);
      final dinner = IntakeEntity(
        id: 'past-dinner',
        quantity: source.quantity,
        type: IntakeTypeEntity.dinner,
        meal: source.meal,
        recipeSnapshot: source.recipeSnapshot,
        dateTime: DateTime(2026, 9, 28, 20),
      );
      await tester.runAsync(() async {
        h.selection.select(DateTime(2026, 9, 28));
      });
      await mount(tester, entries: [dinner]);
      await tester.ensureVisible(menu(IntakeTypeEntity.dinner));
      await tester.runAsync(() => tester.tap(menu(IntakeTypeEntity.dinner)));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Copy to today')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Which meal group do you want to copy to?',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButton<AddMealType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunch').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('OK')));
      await settleStorage(tester);

      final copied = (await h.intakes.getIntakeByDateAndType(
        IntakeTypeEntity.lunch,
        h.selection.state.today,
      )).single;
      expect(copied.id, isNot(dinner.id));
      expect(copied.quantity, dinner.quantity);
      expect(copied.recipeSnapshot, dinner.recipeSnapshot);
      expect(await h.intakes.getIntakeById(dinner.id), dinner);
      expect(
        await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.dinner,
          h.selection.state.today,
        ),
        isEmpty,
      );
      expect(h.selection.state.day, DateTime(2026, 9, 28));
    },
  );

  testWidgets(
    'group clipboard uses a collection preview and pastes every entry',
    (tester) async {
      await mount(
        tester,
        entries: [
          diaryEntry(),
          diaryEntry(id: 'second', recipe: true, amount: 50),
        ],
      );
      await tester.tap(menu(IntakeTypeEntity.breakfast));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy to clipboard'));
      await tester.pumpAndSettle();
      expect(clipboard.state, hasLength(2));
      expect(find.byIcon(Icons.collections_rounded), findsNWidgets(4));
      expect(find.text('2 entries'), findsNWidgets(4));
      final preview = control('diary-breakfast-paste');
      expect(
        find.descendant(of: preview, matching: find.byType(FoodImage)),
        findsNothing,
      );
      for (final hidden in ['Diary oats', 'Saved recipe', '125 g', '50 g']) {
        expect(
          find.descendant(of: preview, matching: find.text(hidden)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: preview, matching: find.text('665 kcal')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text('105 c 14 f 21 p')),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(preview).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(control('diary-breakfast-scan')).dy,
        ),
      );
      await tester.ensureVisible(control('diary-snack-paste'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(control('diary-snack-paste')));
      await settleStorage(tester);
      expect(
        await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.snack,
          h.selection.state.day,
        ),
        hasLength(2),
      );
      expect(clipboard.state, hasLength(2));
    },
  );

  testWidgets(
    'row left swipes reveal Refresh; header swipes change dates and close Info',
    (tester) async {
      await mount(tester);
      final card = find.byType(IntakeCard).first;
      await tester.drag(card, const Offset(140, 0));
      await tester.pumpAndSettle();
      expect(control('diary-intake-info'), findsOneWidget);
      await tester.runAsync(
        () => tester.drag(find.text('Breakfast'), const Offset(-140, 0)),
      );
      await settleStorage(tester);
      expect(h.selection.state.day, DateTime(2026, 9, 30));
      expect(control('diary-intake-info'), findsNothing);
      await tester.runAsync(() async {
        h.selection.select(DateTime(2026, 9, 29));
      });
      await tester.pump();
      await pumpUntil(
        tester,
        () =>
            h.calendar!.state is CalendarDayLoaded &&
            (h.calendar!.state as CalendarDayLoaded).day ==
                DateTime(2026, 9, 29),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.drag(find.byType(IntakeCard).first, const Offset(-140, 0)),
      );
      await settleStorage(tester);
      expect(h.selection.state.day, DateTime(2026, 9, 29));
      expect(control('diary-intake-refresh'), findsOneWidget);
    },
  );
}

class _RecipeStore extends Fake implements RecipeRepository {
  final saved = <RecipeEntity>[];
  @override
  Future<void> saveRecipe(RecipeEntity recipe) async {
    saved.add(recipe);
  }
}
