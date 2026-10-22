import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_dialog.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../helpers/test_l10n.dart';

void main() {
  testWidgets('shows the initialValue as the dropdown selection on open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: CopyDialog(
            initialValue: AddMealType.dinnerType,
            direction: CopyDirection.to,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<AddMealType>>(
      find.byType(DropdownButton<AddMealType>),
    );
    expect(dropdown.value, AddMealType.dinnerType);
  });

  testWidgets('OK returns the initial value when nothing is changed', (
    tester,
  ) async {
    AddMealType? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showDialog<AddMealType>(
      context: capturedContext,
      builder: (_) => const CopyDialog(
        initialValue: AddMealType.lunchType,
        direction: CopyDirection.to,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10nEn.dialogOKLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, AddMealType.lunchType);
  });

  testWidgets('Cancel returns null even when initialValue is set', (
    tester,
  ) async {
    AddMealType? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showDialog<AddMealType>(
      context: capturedContext,
      builder: (_) => const CopyDialog(
        initialValue: AddMealType.snackType,
        direction: CopyDirection.from,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10nEn.dialogCancelLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, isNull);
  });

  testWidgets('user can change the selection and OK returns the new value', (
    tester,
  ) async {
    AddMealType? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showDialog<AddMealType>(
      context: capturedContext,
      builder: (_) => const CopyDialog(
        initialValue: AddMealType.breakfastType,
        direction: CopyDirection.from,
      ),
    );
    await tester.pumpAndSettle();

    // Open the dropdown and pick "dinner".
    await tester.tap(find.byType(DropdownButton<AddMealType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.dinnerLabel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10nEn.dialogOKLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, AddMealType.dinnerType);
  });

  for (final brightness in Brightness.values) {
    for (final direction in CopyDirection.values) {
      testWidgets('emphasizes $direction in the $brightness theme', (
        tester,
      ) async {
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            localizationsDelegates: const [S.delegate],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: CopyDialog(
                initialValue: AddMealType.lunchType,
                direction: direction,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final word = direction == CopyDirection.from
            ? l10nEn.copyDialogFromDirection
            : l10nEn.copyDialogToDirection;
        expect(
          find.text(l10nEn.copyDialogTitle(word), findRichText: true),
          findsOneWidget,
        );
        final title =
            tester.widget<AlertDialog>(find.byType(AlertDialog)).title! as Text;
        final span = (title.textSpan! as TextSpan).children!
            .whereType<TextSpan>()
            .singleWhere((span) => span.text == word);
        expect(span.style!.fontWeight, FontWeight.bold);
        expect(span.style!.color, theme.colorScheme.primary);
        expect(
          find.bySemanticsIdentifier(
            direction == CopyDirection.from
                ? 'diary-copy-source-meal'
                : 'diary-copy-destination-meal',
          ),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets(
    'empty source options stay visible and explain without selecting',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: const Scaffold(
            body: CopyDialog(
              initialValue: AddMealType.dinnerType,
              direction: CopyDirection.from,
              availableSources: {AddMealType.dinnerType},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<AddMealType>));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(CopyDialog));
      for (final group in AddMealType.values) {
        expect(find.text(group.getTypeName(context)), findsWidgets);
      }
      final lunch = tester.widget<Text>(find.text(l10nEn.lunchLabel));
      expect(
        lunch.style!.color,
        Theme.of(tester.element(find.byType(CopyDialog))).disabledColor,
      );
      await tester.tap(find.text(l10nEn.lunchLabel));
      await tester.pumpAndSettle();
      expect(
        find.text(l10nEn.diaryYesterdayEmptyMessage(l10nEn.lunchLabel)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DropdownButton<AddMealType>>(
              find.byType(DropdownButton<AddMealType>),
            )
            .value,
        AddMealType.dinnerType,
      );
      expect(find.byType(CopyDialog), findsOneWidget);
    },
  );

  testWidgets('all-empty sources keep the dialog open when confirming', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: CopyDialog(
            initialValue: AddMealType.lunchType,
            direction: CopyDirection.from,
            availableSources: {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.dialogOKLabel));
    await tester.pumpAndSettle();
    expect(
      find.text(l10nEn.diaryYesterdayEmptyMessage(l10nEn.lunchLabel)),
      findsOneWidget,
    );
    expect(find.byType(CopyDialog), findsOneWidget);
  });
}
