import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  Future<void> mount(WidgetTester tester, {bool raw = false, bool imperial = false,
    Future<bool> Function(MealEntity, FoodAmountSelection)? confirm}) async {
    final meal = MealEntity(code: 'solid', name: 'Food', url: null, mealQuantity: null,
      mealUnit: 'g', servingQuantity: 30, servingUnit: 'g', servingSize: '30 g',
      nutriments: food('x', 'x').nutriments, source: MealSourceEntity.custom);
    await tester.pumpWidget(MaterialApp(localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales, home: Scaffold(body: FoodAmountSheet(
        meal: meal, rawUnits: raw, imperial: imperial, hydrate: false,
        onConfirm: confirm ?? (_, __) async => true))));
    await tester.pumpAndSettle();
  }
  testWidgets('autofocus selects the complete default amount', (tester) async {
    await mount(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, true);
    expect(field.controller!.text, '1');
    expect(field.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 1));
    expect(find.text('30 g'), findsOneWidget);
  });
  for (final imperial in [false, true]) {
    testWidgets('raw default respects imperial=$imperial', (tester) async {
      await mount(tester, raw: true, imperial: imperial);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, imperial ? '1' : '100');
      final dropdown = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
      expect(dropdown.initialValue, contains(imperial ? 'oz:g:' : 'g:g:'));
    });
  }
  testWidgets('invalid amount stays open; errors permit correction and retry', (tester) async {
    var calls = 0;
    await mount(tester, confirm: (_, __) async { calls++; throw StateError('save'); });
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
  testWidgets('pending save disables repeated confirmation and dismissal', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await mount(tester, confirm: (_, __) { calls++; return pending.future; });
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
  test('portions use stable identity and exact conversion, not list index', () {
    final option = const FoodAmountOption(unit: 'portion:cup:140', baseUnit: 'g', factor: 140, label: 'cup');
    expect(FoodAmountSelection(2, option).baseAmount, 280);
  });
}
