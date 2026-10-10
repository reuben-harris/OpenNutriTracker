import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/edit_food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  IntakeEntity entry({bool entered = true}) => IntakeEntity(
    id: 'x',
    unit: 'g',
    amount: 106.00000000000001,
    type: IntakeTypeEntity.snack,
    meal: food('usda:123', 'Food'),
    dateTime: DateTime(2026),
    enteredAmount: entered ? 2 : null,
    enteredUnit: entered ? 'portion:slice:53' : null,
    enteredBaseUnit: entered ? 'g' : null,
    enteredUnitFactor: entered ? 53 : null,
    enteredUnitLabel: entered ? 'slice' : null,
  );
  test(
    'saved serving snapshot wins over current preferences and catalogue',
    () {
      final initial = initialIntakeAmount(entry(), imperial: true);
      expect(initial.amount, 2);
      expect(initial.option.displayLabel, 'slice');
      expect(initial.baseAmount, 106);
      expect(
        editedIntakeAmountFields(entry(), initial, initial)['amount'],
        entry().amount,
      );
      final changed = editedIntakeAmountFields(
        entry(),
        initial,
        FoodAmountSelection(3, initial.option),
      );
      expect(changed['amount'], 159);
      expect(changed['enteredAmount'], 3);
    },
  );
  test(
    'legacy entries use base amounts with no serving guess and retain precision',
    () {
      final intake = entry(entered: false);
      final initial = initialIntakeAmount(intake, imperial: true);
      expect(initial.option.unit, 'oz');
      expect(
        editedIntakeAmountFields(intake, initial, initial)['amount'],
        intake.amount,
      );
    },
  );
}
