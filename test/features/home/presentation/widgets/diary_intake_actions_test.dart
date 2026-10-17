import '../../../../helpers/locator_test_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/explode_recipe_intake_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/widgets/diary_intake_row.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'diary_intake_row_test.dart' as fixtures;

class _Explode extends Fake implements ExplodeRecipeIntakeUsecase {
  final ids = <String>[];
  bool fail = false;
  @override
  Future<void> explode(String id) async {
    if (fail) throw StateError('failed conversion');
    ids.add(id);
  }
}

class _Home extends Fake implements HomeBloc {
  final events = <HomeEvent>[];
  @override
  void add(HomeEvent event) => events.add(event);
}

class _Diary extends Fake implements DiaryBloc {
  final events = <DiaryEvent>[];
  @override
  void add(DiaryEvent event) => events.add(event);
}

class _Calendar extends Fake implements CalendarDayBloc {
  final events = <CalendarDayEvent>[];
  @override
  void add(CalendarDayEvent event) => events.add(event);
}

void main() {
  useTestLocator();
  tearDown(() => locator.resetScope());
  Future<void> mount(WidgetTester tester, IntakeEntity entry) =>
      tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EnergyUnitProvider(),
          child: MaterialApp(
            localizationsDelegates: const [S.delegate],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: DiaryIntakeRow(
                intake: entry,
                usesImperialUnits: false,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
  Future<void> selectExplode(WidgetTester tester) async {
    await tester.drag(find.byType(IntakeCard), const Offset(-140, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explode'));
    await tester.pumpAndSettle();
  }

  testWidgets('swipe Explode cancels without converting and confirms once', (
    tester,
  ) async {
    final explode = _Explode();
    locator.registerSingleton<ExplodeRecipeIntakeUsecase>(explode);
    await mount(tester, fixtures.recipeIntake());
    await tester.pumpAndSettle();
    await selectExplode(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(explode.ids, isEmpty);
    final home = _Home();
    final diary = _Diary();
    final calendar = _Calendar();
    locator.registerSingleton<HomeBloc>(home);
    locator.registerSingleton<DiaryBloc>(diary);
    locator.registerSingleton<CalendarDayBloc>(calendar);
    await selectExplode(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Explode'));
    await tester.pumpAndSettle();
    expect(explode.ids, ['intake-1']);
    expect(home.events.single, isA<LoadItemsEvent>());
    expect(diary.events.single, isA<LoadDiaryYearEvent>());
    expect(calendar.events.single, isA<RefreshCalendarDayEvent>());
    expect(find.text('Recipe replaced with ingredients.'), findsOneWidget);
  });
  testWidgets('unusable snapshot explains refresh without confirmation', (
    tester,
  ) async {
    await mount(tester, fixtures.recipeIntake(old: true));
    await tester.pumpAndSettle();
    await selectExplode(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.textContaining('Refresh it from a saved recipe'),
      findsOneWidget,
    );
  });
  testWidgets(
    'an empty ingredient snapshot explains refresh without confirmation',
    (tester) async {
      final entry = fixtures.recipeIntake();
      entry.recipeSnapshot!.ingredients.clear();
      await mount(tester, entry);
      await selectExplode(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining('Refresh it from a saved recipe'),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed Explode leaves the row closed and reports failure', (
    tester,
  ) async {
    locator.registerSingleton<ExplodeRecipeIntakeUsecase>(
      _Explode()..fail = true,
    );
    await mount(tester, fixtures.recipeIntake());
    await selectExplode(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Explode'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not finish exploding the recipe. Reload the diary to check the result.',
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.byType(IntakeCard)).dx, 0);
  });
}
