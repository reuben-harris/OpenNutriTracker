import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_expression.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool raw = false,
    bool imperial = false,
    bool arithmetic = false,
    Future<bool> Function(MealEntity, FoodAmountSelection)? confirm,
    FoodAmountSelection? initial,
    FoodAmountSelection? remembered,
    Future<void> Function(MealEntity, FoodAmountSelection)? remember,
  }) async {
    final meal = MealEntity(
      code: 'solid',
      name: 'Food',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: 30,
      servingUnit: 'g',
      servingSize: '30 g',
      nutriments: food('x', 'x').nutriments,
      source: MealSourceEntity.custom,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FoodAmountSheet(
            meal: meal,
            arithmetic: arithmetic,
            rawUnits: raw,
            imperial: imperial,
            hydrate: false,
            initial: initial,
            remembered: remembered,
            onRemember: remember,
            onConfirm: confirm ?? (_, _) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('autofocus selects the complete default amount', (tester) async {
    await mount(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, true);
    expect(field.controller!.text, '1');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    expect(find.text('30 g'), findsOneWidget);
  });
  testWidgets('remembered grams override a serving default', (tester) async {
    await mount(
      tester,
      remembered: const FoodAmountSelection(
        53,
        FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '53',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'g:g:1.0',
    );
  });
  testWidgets(
    'entry snapshot takes priority even when its serving has changed',
    (tester) async {
      await mount(
        tester,
        initial: const FoodAmountSelection(
          2,
          FoodAmountOption(
            unit: 'serving',
            baseUnit: 'g',
            factor: 25,
            label: '25 g',
          ),
        ),
        remembered: const FoodAmountSelection(
          53,
          FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2',
      );
      expect(find.text('25 g'), findsOneWidget);
    },
  );
  testWidgets('unsupported remembered units fall back to the current default', (
    tester,
  ) async {
    await mount(
      tester,
      remembered: const FoodAmountSelection(
        2,
        FoodAmountOption(unit: 'serving', baseUnit: 'g', factor: 25),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1',
    );
    expect(find.text('30 g'), findsOneWidget);
  });
  for (final imperial in [false, true]) {
    testWidgets('raw default respects imperial=$imperial', (tester) async {
      await mount(tester, raw: true, imperial: imperial);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        imperial ? '1' : '100',
      );
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, contains(imperial ? 'oz:g:' : 'g:g:'));
    });
  }
  testWidgets('invalid amount stays open; errors permit correction and retry', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      confirm: (_, _) async {
        calls++;
        throw StateError('save');
      },
    );
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(FoodAmountSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), '53');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(FoodAmountSheet), findsOneWidget);
    expect(find.text('Could not add this entry. Try again.'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
  testWidgets('pending save disables repeated confirmation', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await mount(
      tester,
      confirm: (_, _) {
        calls++;
        return pending.future;
      },
    );
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'arithmetic keeps expression until Done, then confirms its result',
    (tester) async {
      FoodAmountSelection? selected;
      await mount(
        tester,
        arithmetic: true,
        confirm: (_, selection) async {
          selected = selection;
          return false;
        },
      );
      await tester.enterText(find.byType(TextField), '10+20');
      await tester.pump();
      expect(find.text('= 30'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '10+20',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '30',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(selected!.amount, 30);
    },
  );
  testWidgets('operator buttons replace a selection without stealing focus', (
    tester,
  ) async {
    await mount(tester, arithmetic: true);
    await tester.enterText(find.byType(TextField), '1020');
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 3,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '+'));
    await tester.pump();
    expect(field.controller!.text, '10+0');
    expect(field.controller!.selection.baseOffset, 3);
    expect(field.focusNode!.hasFocus, true);
  });
  testWidgets(
    'disabled arithmetic has no operator row and rejects pasted expressions',
    (tester) async {
      await mount(tester);
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.enterText(find.byType(TextField), '10+20');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1',
      );
    },
  );
  testWidgets('invalid arithmetic does not call persistence', (tester) async {
    var calls = 0;
    await mount(
      tester,
      arithmetic: true,
      confirm: (_, _) async {
        calls++;
        return false;
      },
    );
    for (final text in ['10+', '1/0', '10-20']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(FoodAmountSheet), findsOneWidget);
    }
  });
  testWidgets('only a successful save remembers the evaluated numeric amount', (
    tester,
  ) async {
    final saved = Completer<bool>();
    FoodAmountSelection? remembered;
    var calls = 0;
    await mount(
      tester,
      arithmetic: true,
      confirm: (_, _) async => ++calls == 1 ? false : saved.future,
      remember: (_, selection) async => remembered = selection,
    );
    await tester.enterText(find.byType(TextField), '10+20');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(remembered, isNull);
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(remembered, isNull);
    saved.complete(true);
    await tester.pumpAndSettle();
    expect(remembered!.amount, 30);
    expect(remembered!.option.unit, 'serving');
  });
  testWidgets('cancellation does not remember an edited amount', (
    tester,
  ) async {
    var remembered = false;
    var saved = false;
    await mount(
      tester,
      confirm: (_, _) async {
        saved = true;
        return true;
      },
      remember: (_, _) async {
        remembered = true;
      },
    );
    await tester.enterText(find.byType(TextField), '53');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier == 'food-amount-cancel',
      ),
    );
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(remembered, false);
  });
  test(
    'resolved decimals remain parseable without scientific notation or truncation',
    () {
      for (final value in [1e-8, 1e20, 1.25e25, 53.0, 0.123456789]) {
        final text = formatFoodAmount(value);
        expect(text, isNot(contains('e')));
        expect(evaluateFoodAmount(text), value);
      }
    },
  );
  test('portions use stable identity and exact conversion, not list index', () {
    final option = const FoodAmountOption(
      unit: 'portion:cup:140',
      baseUnit: 'g',
      factor: 140,
      label: 'cup',
    );
    expect(FoodAmountSelection(2, option).baseAmount, 280);
  });
}
