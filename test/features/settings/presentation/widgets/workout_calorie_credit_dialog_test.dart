import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/workout_calorie_credit_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../../helpers/test_l10n.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    double initialMultiplier = 0.72,
    ValueChanged<double?>? onClosed,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<double>(
                  context: context,
                  builder: (_) => WorkoutCalorieCreditDialog(
                    initialMultiplier: initialMultiplier,
                  ),
                );
                onClosed?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text(l10nEn.healthSyncKcalMultiplierLabel).hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(Slider).hitTestable(), findsOneWidget);
  }

  testWidgets('shows the saved value and supports every whole percentage', (
    tester,
  ) async {
    await pumpDialog(tester, initialMultiplier: 0.83);

    expect(
      find.text(l10nEn.healthSyncKcalMultiplierValueLabel(83)),
      findsOneWidget,
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.5);
    expect(slider.max, 1);
    expect(slider.divisions, 50);
    expect(slider.value, 0.83);
    expect(
      find.bySemanticsIdentifier('workout-calorie-credit-slider'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('workout-calorie-credit-sources'),
      findsOneWidget,
    );
  });

  for (final (offset, expected) in [(0.0, 0.5), (1.0, 1.0)]) {
    testWidgets('can save the ${expected * 100}% boundary', (tester) async {
      double? saved;
      await pumpDialog(tester, onClosed: (value) => saved = value);
      final rect = tester.getRect(find.byType(Slider));
      await tester.tapAt(
        Offset(rect.left + 1 + (rect.width - 2) * offset, rect.center.dy),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEn.buttonSaveLabel));
      await tester.pumpAndSettle();

      expect(saved, expected);
    });
  }

  testWidgets('default changes the draft and Save returns 72%', (tester) async {
    double? saved;
    var closed = false;
    await pumpDialog(
      tester,
      initialMultiplier: 1,
      onClosed: (value) {
        saved = value;
        closed = true;
      },
    );
    await tester.tap(find.text(l10nEn.healthSyncKcalMultiplierDefaultLabel));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.72);
    await tester.tap(find.text(l10nEn.buttonSaveLabel));
    await tester.pumpAndSettle();
    expect(saved, 0.72);
  });

  testWidgets('Cancel discards changes', (tester) async {
    double? saved = 1;
    await pumpDialog(
      tester,
      initialMultiplier: 0.85,
      onClosed: (value) => saved = value,
    );
    await tester.tap(find.text(l10nEn.healthSyncKcalMultiplierDefaultLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.dialogCancelLabel));
    await tester.pumpAndSettle();

    expect(saved, isNull);
  });

  for (final (size, textScale) in [
    (const Size(400, 800), 1.0),
    (const Size(320, 600), 2.0),
    (const Size(800, 400), 1.0),
  ]) {
    testWidgets(
      'dialog and actions render at $size with text scale $textScale',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        double? saved;
        await pumpDialog(
          tester,
          initialMultiplier: 0.85,
          textScale: textScale,
          onClosed: (value) => saved = value,
        );

        final sliderRect = tester.getRect(find.byType(Slider));
        expect(sliderRect.width, greaterThan(0));
        expect(sliderRect.height, greaterThan(0));
        expect((Offset.zero & size).contains(sliderRect.topLeft), isTrue);
        expect((Offset.zero & size).contains(sliderRect.bottomRight), isTrue);

        await tester.ensureVisible(
          find.text(l10nEn.healthSyncKcalMultiplierDefaultLabel),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(l10nEn.healthSyncKcalMultiplierDefaultLabel),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l10nEn.buttonSaveLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10nEn.buttonSaveLabel));
        await tester.pumpAndSettle();

        expect(saved, 0.72);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
