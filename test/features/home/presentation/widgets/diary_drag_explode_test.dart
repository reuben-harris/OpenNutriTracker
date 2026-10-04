import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/explode_recipe_intake_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_drag_targets.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/explode_diary_recipe.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'explodable_intake_row_test.dart' as fixtures;

class _Explode extends Fake implements ExplodeRecipeIntakeUsecase {
  final ids = <String>[];
  @override
  Future<void> explode(String id) async {
    ids.add(id);
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

void main() {
  tearDown(() => locator.reset());
  Future<void> mount(
    WidgetTester tester,
    IntakeEntity entry, {
    ValueChanged<IntakeEntity>? copy,
    ValueChanged<IntakeEntity>? delete,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              LongPressDraggable<IntakeEntity>(
                data: entry,
                feedback: const Text('Dragging'),
                child: const Text('Recipe'),
              ),
              const SizedBox(height: 100),
              DiaryDragTargets(
                onDelete: delete ?? (_) {},
                onCopy: copy ?? (_) {},
                onExplode: (e) => explodeDiaryRecipe(context, e),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> drop(WidgetTester tester, String label) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Recipe')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text(label)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('drag Explode confirms and cancels without converting', (
    tester,
  ) async {
    final explode = _Explode();
    locator.registerSingleton<ExplodeRecipeIntakeUsecase>(explode);
    await mount(tester, fixtures.recipeIntake());
    await tester.pumpAndSettle();
    await drop(tester, 'Explode');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(explode.ids, isEmpty);
    locator.registerSingleton<HomeBloc>(_Home());
    locator.registerSingleton<DiaryBloc>(_Diary());
    locator.registerSingleton<CalendarDayBloc>(_Calendar());
    await drop(tester, 'Explode');
    await tester.tap(find.widgetWithText(FilledButton, 'Explode'));
    await tester.pumpAndSettle();
    expect(explode.ids, ['intake-1']);
  });
  testWidgets('unusable snapshot explains refresh without confirmation', (
    tester,
  ) async {
    await mount(tester, fixtures.recipeIntake(old: true));
    await tester.pumpAndSettle();
    await drop(tester, 'Explode');
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.textContaining('Refresh it from a saved recipe'),
      findsOneWidget,
    );
  });
  testWidgets('Copy and Delete retain their independent drop actions', (
    tester,
  ) async {
    var copied = 0, deleted = 0;
    await mount(
      tester,
      fixtures.recipeIntake(),
      copy: (_) => copied++,
      delete: (_) => deleted++,
    );
    await tester.pumpAndSettle();
    await drop(tester, 'Copy');
    expect(copied, 1);
    expect(deleted, 0);
    await drop(tester, 'DELETE');
    expect(deleted, 1);
    expect(copied, 1);
  });
}
