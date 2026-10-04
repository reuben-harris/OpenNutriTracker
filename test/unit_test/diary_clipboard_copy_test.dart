import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_copy_cubit.dart';
import '../fixture/diary_entry_fixtures.dart';
import '../helpers/diary_workflow_harness.dart';

class _FailSecondMacros extends AddTrackedDayUsecase {
  int calls = 0;
  _FailSecondMacros(super.repository);
  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {
    if (++calls == 2) throw StateError('storage failure after intake saved');
    await super.addDayMacrosTracked(
      day,
      carbsTracked: carbsTracked,
      fatTracked: fatTracked,
      proteinTracked: proteinTracked,
    );
  }
}

void main() {
  test(
    'clipboard replaces, deeply detaches, clears and starts empty',
    () async {
      final clipboard = DiaryClipboardCubit();
      final entry = diaryEntry(recipe: true);
      clipboard.copy([entry]);
      entry.recipeSnapshot!.tags.clear();
      entry.recipeSnapshot!.ingredients.clear();
      expect(clipboard.state.single.recipeSnapshot!.tags, ['Breakfast']);
      expect(clipboard.state.single.recipeSnapshot!.ingredients, hasLength(1));
      expect(clipboard.state.single.amount, 125);
      expect(clipboard.state.single.unit, 'g');
      clipboard.copy([diaryEntry(id: 'replacement')]);
      expect(clipboard.state.single.id, 'replacement');
      clipboard.clear();
      expect(clipboard.state, isEmpty);
      final restarted = DiaryClipboardCubit();
      expect(restarted.state, isEmpty);
      await clipboard.close();
      await restarted.close();
    },
  );

  late DiaryWorkflowHarness h;
  final destination = DateTime(2026, 9, 30);
  setUp(() async {
    h = DiaryWorkflowHarness();
    await h.initialize();
  });
  tearDown(() async => h.dispose());

  Future<BuildContext> contextFor(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('repeated batch pastes append fresh IDs and accurate totals', (
    tester,
  ) async {
    h.createCopier();
    final context = await contextFor(tester);
    await tester.runAsync(() async {
      final clipboard = DiaryClipboardCubit()
        ..copy([diaryEntry(), diaryEntry(id: 'recipe', recipe: true)]);
      h.recipes.recipe = diaryEntry(
        recipe: true,
      ).recipeSnapshot!.copyWith(name: 'Edited later');
      final source = clipboard.state;
      for (var i = 0; i < 2; i++) {
        expect(
          await h.copier.copy(
            context,
            source,
            destination,
            IntakeTypeEntity.lunch,
          ),
          DiaryCopyResult.copied,
        );
      }
      final entries = await h.intakes.getIntakeByDateAndType(
        IntakeTypeEntity.lunch,
        destination,
      );
      expect(entries, hasLength(4));
      expect(entries.map((e) => e.id).toSet(), hasLength(4));
      expect(entries.map((e) => e.id), isNot(contains('source')));
      expect(
        entries.every(
          (e) => e.dateTime == destination && e.amount == 125 && e.unit == 'g',
        ),
        isTrue,
      );
      expect(
        entries
            .where((e) => e.recipeSnapshot != null)
            .every((e) => e.recipeSnapshot!.name == 'Saved recipe'),
        isTrue,
      );
      final tracked = (await h.tracked.getTrackedDay(destination))!;
      expect(
        tracked.caloriesTracked,
        source.fold<double>(0, (sum, e) => sum + e.totalKcal) * 2,
      );
      expect(
        tracked.carbsTracked,
        source.fold<double>(0, (sum, e) => sum + e.totalCarbsGram) * 2,
      );
      expect(
        tracked.fatTracked,
        source.fold<double>(0, (sum, e) => sum + e.totalFatsGram) * 2,
      );
      expect(
        tracked.proteinTracked,
        source.fold<double>(0, (sum, e) => sum + e.totalProteinsGram) * 2,
      );
      expect(clipboard.state, same(source));
      expect(h.refreshes, 2);
      await clipboard.close();
    });
  });

  testWidgets('batch captures input before dialog and rejects overlap', (
    tester,
  ) async {
    h.createCopier();
    final context = await contextFor(tester);
    await tester.runAsync(() async {
      final source = [diaryEntry()];
      final dialog = Completer<IntakeTypeEntity?>();
      final batch = h.copier.copy(
        context,
        source,
        destination,
        IntakeTypeEntity.breakfast,
        selectDestination: () => dialog.future,
      );
      source.clear();
      expect(
        await h.copier.copy(
          context,
          [diaryEntry()],
          destination,
          IntakeTypeEntity.dinner,
        ),
        DiaryCopyResult.busy,
      );
      dialog.complete(IntakeTypeEntity.snack);
      expect(await batch, DiaryCopyResult.copied);
      expect(
        await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.snack,
          destination,
        ),
        hasLength(1),
      );
      expect(h.copier.state, isFalse);
    });
  });

  testWidgets(
    'partial failure stops, retains copies and clipboard, repairs totals',
    (tester) async {
      h.createCopier(trackedWriter: _FailSecondMacros(h.tracked));
      final context = await contextFor(tester);
      await tester.runAsync(() async {
        final clipboard = DiaryClipboardCubit()
          ..copy([
            diaryEntry(),
            diaryEntry(id: 'second', recipe: true),
            diaryEntry(id: 'third'),
          ]);
        final source = clipboard.state;
        expect(
          await h.copier.copy(
            context,
            source,
            destination,
            IntakeTypeEntity.dinner,
          ),
          DiaryCopyResult.failed,
        );
        final entries = await h.intakes.getIntakeByDateAndType(
          IntakeTypeEntity.dinner,
          destination,
        );
        expect(entries, hasLength(2));
        final tracked = (await h.tracked.getTrackedDay(destination))!;
        expect(
          tracked.caloriesTracked,
          entries.fold<double>(0, (sum, e) => sum + e.totalKcal),
        );
        expect(
          tracked.carbsTracked,
          entries.fold<double>(0, (sum, e) => sum + e.totalCarbsGram),
        );
        expect(
          tracked.fatTracked,
          entries.fold<double>(0, (sum, e) => sum + e.totalFatsGram),
        );
        expect(
          tracked.proteinTracked,
          entries.fold<double>(0, (sum, e) => sum + e.totalProteinsGram),
        );
        expect(clipboard.state, same(source));
        expect(h.refreshes, 1);
        expect(h.copier.state, isFalse);
        await clipboard.close();
      });
    },
  );

  testWidgets('cancelling a pending dialog releases batch without writes', (
    tester,
  ) async {
    h.createCopier();
    final context = await contextFor(tester);
    await tester.runAsync(() async {
      final dialog = Completer<IntakeTypeEntity?>();
      final batch = h.copier.copy(
        context,
        [diaryEntry()],
        destination,
        IntakeTypeEntity.lunch,
        selectDestination: () => dialog.future,
      );
      await h.copier.cancelAndWait();
      expect(await batch, DiaryCopyResult.cancelled);
      expect(await h.intakes.getAllIntakesDBO(), isEmpty);
      expect(h.refreshes, 0);
      dialog.complete(IntakeTypeEntity.lunch);
    });
  });

  testWidgets('move preserves snapshot, timestamp, identity and daily totals', (
    tester,
  ) async {
    h.createCopier();
    final context = await contextFor(tester);
    await tester.runAsync(() async {
      await h.copier.copy(
        context,
        [diaryEntry(recipe: true)],
        destination,
        IntakeTypeEntity.breakfast,
      );
      final before = (await h.intakes.getAllIntakesDBO()).single;
      final id = before.id;
      final json = before.toJson()..remove('type');
      final totals = (await h.tracked.getTrackedDay(destination))!;
      await UpdateIntakeUsecase(
        h.intakes,
      ).moveIntakeToType(id, IntakeTypeEntity.snack);
      final after = (await h.intakes.getAllIntakesDBO()).single;
      expect(after.id, id);
      expect(after.toJson()..remove('type'), json);
      expect(await h.tracked.getTrackedDay(destination), totals);
    });
  });
}
