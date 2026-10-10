import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';

FoodAmountSelection initialIntakeAmount(
  IntakeEntity intake, {
  required bool imperial,
}) {
  final entered = intake.enteredSelection;
  if (entered != null) return entered;
  final liquid = intake.meal.isLiquid;
  final unit = liquid
      ? (imperial ? FoodAmountUnit.flOz : FoodAmountUnit.ml)
      : (imperial ? FoodAmountUnit.oz : FoodAmountUnit.g);
  return FoodAmountSelection(
    unit.fromBase(intake.amount),
    FoodAmountOption.standard(unit),
  );
}

Map<String, dynamic> editedIntakeAmountFields(
  IntakeEntity intake,
  FoodAmountSelection initial,
  FoodAmountSelection selected,
) {
  final fields = selected.intakeFields;
  if (initial.amount == selected.amount &&
      initial.option.identity == selected.option.identity) {
    fields['amount'] = intake.amount;
  }
  return fields;
}

Future<bool> editFoodAmount(BuildContext context, IntakeEntity intake) async {
  final config = await locator<GetConfigUsecase>().getConfig();
  if (!context.mounted) return false;
  final box = locator<HiveDBProvider>().intakeBox;
  final initial = initialIntakeAmount(
    intake,
    imperial: config.usesImperialFoodUnits,
  );
  return showFoodAmountSheet(
    context,
    meal: intake.meal,
    editing: true,
    hydrate: false,
    initial: initial,
    onConfirm: (_, selected) async {
      if (!identical(box, locator<HiveDBProvider>().intakeBox)) {
        throw StateError('Profile changed');
      }
      final updated = await locator<UpdateIntakeUsecase>().updateIntake(
        intake.id,
        editedIntakeAmountFields(intake, initial, selected),
      );
      if (updated == null) throw StateError('Entry no longer exists');
      refreshFoodDiary();
      return true;
    },
  );
}
