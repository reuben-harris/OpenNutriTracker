import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/features/onboarding/presentation/widgets/onboarding_body_measurements_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../../helpers/test_l10n.dart';

/// Plausibility checks question typos without blocking intentional outliers.
void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: OnboardingBodyMeasurementsPageBody(
            setButtonContent: (_, _, _, _, _, _, _) {},
          ),
        ),
      ),
    );
  }

  Future<void> enterHeightAndWeight(
    WidgetTester tester, {
    required String height,
    required String weight,
  }) async {
    await tester.enterText(find.byType(TextFormField).first, height);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), weight);
    await tester.pump();
  }

  testWidgets('an implausible weight asks for confirmation on blur', (
    tester,
  ) async {
    await pumpPage(tester);
    await enterHeightAndWeight(tester, height: '180', weight: '5');

    expect(
      find.text(l10nEn.onboardingImplausibleTitle),
      findsNothing,
      reason: 'not while the field still has focus',
    );

    // Move focus to the target field.
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    expect(find.text(l10nEn.onboardingImplausibleTitle), findsOneWidget);
  });

  testWidgets('keeping an implausible value accepts it and does not re-ask', (
    tester,
  ) async {
    bool? lastActive;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: OnboardingBodyMeasurementsPageBody(
            setButtonContent: (active, _, _, _, _, _, _) => lastActive = active,
          ),
        ),
      ),
    );
    await enterHeightAndWeight(tester, height: '180', weight: '5');

    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.onboardingImplausibleKeep));
    await tester.pumpAndSettle();

    expect(
      lastActive,
      isTrue,
      reason: '5 kg clears the hard bounds, so the page can still proceed',
    );

    // Refocus the confirmed weight and leave it again without changing it.
    final weight = find.byType(TextField).at(1);
    await tester.ensureVisible(weight);
    await tester.pumpAndSettle();
    await tester.tap(weight);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(weight).focusNode!.hasFocus, isTrue);

    final height = find.byType(TextField).first;
    await tester.ensureVisible(height);
    await tester.pumpAndSettle();
    await tester.tap(height);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(weight).focusNode!.hasFocus, isFalse);
    expect(find.text(l10nEn.onboardingImplausibleTitle), findsNothing);
  });

  testWidgets('a plausible weight is never questioned', (tester) async {
    await pumpPage(tester);
    await enterHeightAndWeight(tester, height: '180', weight: '75');

    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    expect(find.text(l10nEn.onboardingImplausibleTitle), findsNothing);
  });

  group('imperial units get the same checks as metric', () {
    testWidgets('an incomplete ft/in height reports its error on blur', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: OnboardingBodyMeasurementsPageBody(
              initialHeightImperial: true,
              setButtonContent: (_, _, _, _, _, _, _) {},
            ),
          ),
        ),
      );

      // Feet without inches parses to null, the same way an out-of-range cm
      // value does, but FeetInchesInput has no validator of its own, so the
      // page has to supply the message.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '2');
      await tester.pump();
      expect(
        find.text(l10nEn.onboardingWrongHeightLabel),
        findsNothing,
        reason: 'still typing',
      );

      await tester.tap(fields.at(2));
      await tester.pumpAndSettle();

      expect(find.text(l10nEn.onboardingWrongHeightLabel), findsOneWidget);
    });

    testWidgets('an incomplete stones weight reports its error on blur', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: OnboardingBodyMeasurementsPageBody(
              initialBodyWeightUnit: BodyWeightUnit.st,
              setButtonContent: (_, _, _, _, _, _, _) {},
            ),
          ),
        ),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '11');
      await tester.pump();
      expect(find.text(l10nEn.onboardingWrongWeightLabel), findsNothing);

      await tester.tap(fields.at(0));
      await tester.pumpAndSettle();

      expect(find.text(l10nEn.onboardingWrongWeightLabel), findsOneWidget);
    });

    testWidgets(
      'an incomplete stones target blocks progress and reports its error',
      (tester) async {
        bool? lastActive;
        final showErrors = ValueNotifier<int>(0);
        addTearDown(showErrors.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [S.delegate],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: OnboardingBodyMeasurementsPageBody(
                initialBodyWeightUnit: BodyWeightUnit.st,
                showErrorsSignal: showErrors,
                setButtonContent: (active, _, _, _, _, _, _) =>
                    lastActive = active,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField).first, '180');
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(1), '11');
        await tester.enterText(fields.at(2), '0');
        await tester.pump();
        expect(lastActive, isTrue);

        await tester.enterText(fields.at(3), '10');
        await tester.pumpAndSettle();
        expect(lastActive, isFalse);

        showErrors.value++;
        await tester.pump();
        expect(find.text(l10nEn.onboardingWrongWeightLabel), findsOneWidget);
      },
    );

    testWidgets('an implausible ft/in height asks for confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: OnboardingBodyMeasurementsPageBody(
              initialHeightImperial: true,
              setButtonContent: (_, _, _, _, _, _, _) {},
            ),
          ),
        ),
      );

      // 2 ft 0 in is 61 cm: inside the hard bounds, outside the plausible band.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '2');
      await tester.pump();
      await tester.enterText(fields.at(1), '0');
      await tester.pump();
      await tester.tap(fields.at(2));
      await tester.pumpAndSettle();

      expect(find.text(l10nEn.onboardingImplausibleTitle), findsOneWidget);
    });

    testWidgets('an implausible stones weight asks for confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: OnboardingBodyMeasurementsPageBody(
              initialBodyWeightUnit: BodyWeightUnit.st,
              setButtonContent: (_, _, _, _, _, _, _) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '180');
      await tester.pump();
      // 1 st 0 lb is 6.35 kg.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '1');
      await tester.pump();
      await tester.enterText(fields.at(2), '0');
      await tester.pump();
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      expect(find.text(l10nEn.onboardingImplausibleTitle), findsOneWidget);
    });
  });
}
