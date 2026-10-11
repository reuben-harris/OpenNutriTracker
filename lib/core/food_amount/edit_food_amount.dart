import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';

Future<bool> editFoodAmount(BuildContext context, IntakeEntity intake) async {
  final box = locator<HiveDBProvider>().intakeBox;
  return showFoodAmountSheet(
    context,
    meal: intake.meal,
    editing: true,
    hydrate: false,
    initial: intake.quantity!,
    onConfirm: (_, selected) async {
      if (!identical(box, locator<HiveDBProvider>().intakeBox)) {
        throw StateError('Profile changed');
      }
      final updated = await locator<UpdateIntakeUsecase>().updateIntake(
        intake.id,
        {'quantity': selected},
      );
      if (updated == null) throw StateError('Entry no longer exists');
      refreshFoodDiary();
      return true;
    },
  );
}
