import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  testWidgets(
    'editing retains a saved portion absent from the current catalogue',
    (tester) async {
      final entry = IntakeEntity(
        id: 'entry',
        quantity: const FoodAmountSelection(
          2,
          FoodAmountOption(
            unit: 'portion:foundation:1',
            baseUnit: 'g',
            factor: 53,
            label: '1 slice',
          ),
        ),
        type: IntakeTypeEntity.snack,
        meal: food('usda:123', 'Food'),
        dateTime: DateTime(2026),
      );
      FoodAmountSelection? saved;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: FoodAmountSheet(
              meal: entry.meal,
              initial: entry.quantity,
              editing: true,
              hydrate: false,
              onConfirm: (_, quantity) async {
                saved = quantity;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '2');
      expect(field.focusNode!.hasFocus, true);
      expect(find.text('1 slice'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(saved, entry.quantity);
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(saved!.amount, 3);
      expect(saved!.option, entry.quantity!.option);
      expect(saved!.baseAmount, 159);
      expect(entry.baseAmount, 106);
    },
  );
}
