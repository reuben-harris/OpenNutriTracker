import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/recipe_weight_editor.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    double? initialWeight,
    double width = 400,
    double textScale = 1,
  }) async {
    var mode = initialWeight == null
        ? RecipeWeightMode.automatic
        : RecipeWeightMode.custom;
    double? cookedWeight = initialWeight;
    var showError = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: StatefulBuilder(
                    builder: (context, setState) => Column(
                      children: [
                        RecipeWeightEditor(
                          mode: mode,
                          fieldBorder: const OutlineInputBorder(
                            borderRadius: Dimens.borderRadiusS,
                          ),
                          showError: showError,
                          totalWeightG: mode == RecipeWeightMode.automatic
                              ? 800
                              : cookedWeight,
                          cookedWeightG: cookedWeight,
                          onModeChanged: (value) => setState(() {
                            mode = value;
                            cookedWeight = null;
                            showError = false;
                          }),
                          onCookedWeightChanged: (value) => setState(() {
                            showError = false;
                            cookedWeight =
                                value != null && value.isFinite && value > 0
                                ? value
                                : null;
                          }),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            showError =
                                mode == RecipeWeightMode.custom &&
                                cookedWeight == null;
                          }),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'automatic is read-only; custom starts blank and switching clears it',
    (tester) async {
      await mount(tester);
      expect(find.text('800'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Cooked weight'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
      await tester.enterText(field, '720,25');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
      await tester.tap(find.text('Automatic'));
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(find.text('800'), findsOneWidget);
      await tester.tap(find.text('Cooked weight'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).decoration!.errorText, isNotNull);
    },
  );

  testWidgets(
    'restored decimals retain precision and invalid edits show validation',
    (tester) async {
      await mount(tester, initialWeight: 720.123456789);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, '720.123456789');
      for (final text in ['', '0', '-1', 'NaN', '720..5', '7,2.5']) {
        await tester.enterText(field, text);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        final decoration = tester.widget<TextField>(field).decoration!;
        expect(decoration.errorText, isNotNull);
        expect(decoration.errorBorder, decoration.enabledBorder);
        expect(decoration.focusedErrorBorder, decoration.enabledBorder);
      }
      await tester.enterText(field, '710.123456789');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
      expect(tester.widget<TextField>(field).controller!.text, '710.123456789');
    },
  );

  testWidgets(
    'narrow screens and large text retain labelled controls and semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await mount(tester, width: 280, textScale: 2);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<SegmentedButton<RecipeWeightMode>>(
                find.byType(SegmentedButton<RecipeWeightMode>),
              )
              .direction,
          Axis.vertical,
        );
        expect(
          find.bySemanticsIdentifier('recipe-weight-mode'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cooked weight'));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('recipe-cooked-weight-input'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );
}
