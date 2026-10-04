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
import 'package:opennutritracker/features/home/presentation/widgets/recipe_swipe_scope.dart';
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
  late DiaryWorkflowHarness h;
  late DiaryBloc diary;
  late DiaryClipboardCubit clipboard;
  var now = DateTime(2026, 9, 29, 12);
  setUp(() async {
    now = DateTime(2026, 9, 29, 12);
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
    await locator.reset();
    await diary.close();
    await clipboard.close();
    await h.dispose();
    DayBoundaryCalc.clock = DateTime.now;
  });

  Future<void> mount(
    WidgetTester tester, {
    List<IntakeEntity>? entries,
    double scale = 1,
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
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: const RecipeSwipeScope(child: DiaryPage()),
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

  Future<void> settleStorage(WidgetTester tester) async {
    await tester.runAsync(() async {
      await h.copier.idle;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
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
    expect(control('diary-copy-target'), findsOneWidget);
    expect(control('diary-delete-target'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(control('diary-copy-target'), findsNothing);
    expect(h.selection.state.day, DateTime(2026, 9, 29));
    expect(await h.intakes.getAllIntakesDBO(), hasLength(1));
  });

  testWidgets(
    'drag preserves group geometry and hover visibly changes each target',
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
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: control(id),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      for (final target in ['diary-copy-target', 'diary-delete-target']) {
        final idleColor = background(target);
        expect(idleColor.a, 1);
        await drag.moveTo(tester.getCenter(control(target)));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.getCenter(find.byKey(const ValueKey('fb-source'))),
          tester.getCenter(control(target)),
        );
        expect(background(target), isNot(idleColor));
        expect(background(target).a, 1);
      }
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(await h.intakes.getAllIntakesDBO(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'drop Copy preserves source, pastes into empty groups repeatedly and clears',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      final gesture = await hold(tester);
      final copy = tester.getRect(control('diary-copy-target'));
      final delete = tester.getRect(control('diary-delete-target'));
      expect(copy.width, delete.width);
      expect(copy.left, greaterThan(delete.right));
      expect(
        copy.bottom,
        lessThan(tester.getTopLeft(find.text('Navigation')).dy),
      );
      await gesture.moveTo(copy.center);
      await tester.pump();
      await tester.runAsync(gesture.up);
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
        find.descendant(of: preview, matching: find.byType(IntakeThumbnail)),
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
    'Delete drop confirms, cancellation retains source, confirmation deletes',
    (tester) async {
      await mount(tester);
      for (final confirm in [false, true]) {
        final gesture = await hold(tester);
        await gesture.moveTo(tester.getCenter(control('diary-delete-target')));
        await tester.pump();
        await tester.runAsync(gesture.up);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.runAsync(
          () => tester.tap(find.text(confirm ? 'OK' : 'CANCEL')),
        );
        await settleStorage(tester);
        expect(await h.intakes.getAllIntakesDBO(), hasLength(confirm ? 0 : 1));
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
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 110));
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
        unit: source.unit,
        amount: source.amount,
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
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
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
      await settleStorage(tester);
      expect(find.text('No entries in this group yesterday.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
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
        find.descendant(of: preview, matching: find.byType(IntakeThumbnail)),
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
    'ordinary left swipes and header swipes change dates and close Info',
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
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.drag(find.byType(IntakeCard).first, const Offset(-140, 0)),
      );
      await settleStorage(tester);
      expect(h.selection.state.day, DateTime(2026, 9, 30));
    },
  );
}
