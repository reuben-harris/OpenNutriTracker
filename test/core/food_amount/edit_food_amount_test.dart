import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  testWidgets(
    'editing a gram snapshot offers every original household measure',
    (tester) async {
      final sourcePortions = [
        const MealPortionEntity(
          id: 'usda:survey:298354',
          label: '1 nut',
          gramWeight: 2.5,
          localized: false,
        ),
        const MealPortionEntity(
          id: 'usda:survey:298355',
          label: '1 cup',
          gramWeight: 132,
          localized: false,
        ),
        const MealPortionEntity(
          id: 'usda:survey:298356',
          label: '1 package',
          gramWeight: 50,
          localized: false,
        ),
        const MealPortionEntity(
          id: 'usda:survey:298357',
          label: '1 oz',
          gramWeight: 28.35,
          localized: false,
        ),
        const MealPortionEntity(
          id: 'usda:survey:298358',
          label: '1 Quantity not specified',
          gramWeight: 28,
          localized: false,
        ),
      ];
      final entry = IntakeEntity(
        id: 'macadamia',
        quantity: const FoodAmountSelection(
          100,
          FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
        ),
        type: IntakeTypeEntity.snack,
        meal: food(
          'usda:2707503',
          'Macadamia nuts',
          source: MealSourceEntity.catalogue,
        ).withPortions(sourcePortions),
        dateTime: DateTime(2026),
      );
      final snapshot = IntakeEntity.fromIntakeDBO(
        IntakeDBO.fromIntakeEntity(entry),
      );
      final expectedOptions = foodAmountOptions(snapshot.meal);
      // Removing the source's current portions cannot change the saved menu.
      sourcePortions.clear();
      FoodAmountSelection? saved;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: FoodAmountEditor(
              meal: snapshot.meal,
              initial: snapshot.quantity,
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
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      for (final label in [
        '1 nut',
        '1 cup',
        '1 package',
        '1 oz',
        '1 Quantity not specified',
        'g',
        'kg',
        'oz',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      await tester.tap(find.text('1 nut').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(saved!.baseAmount, 2.5);
      expect(saved!.option.unit, 'portion:usda:survey:298354');
      expect(foodAmountOptions(snapshot.meal), expectedOptions);
      expect(snapshot.quantity, entry.quantity);
    },
  );

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
            body: FoodAmountEditor(
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
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(saved, entry.quantity);
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(saved!.amount, 3);
      expect(saved!.option, entry.quantity!.option);
      expect(saved!.baseAmount, 159);
      expect(entry.baseAmount, 106);
    },
  );
}
