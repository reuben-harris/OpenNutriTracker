import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';

/// Returns true after the selected portion is added, or false on cancellation.
Future<bool> showFoodInformation(
  BuildContext context, {
  required MealEntity meal,
  required DateTime day,
  required IntakeTypeEntity type,
  required bool imperial,
  Future<bool> Function(MealEntity, FoodAmountSelection)? onConfirm,
}) async {
  return await Navigator.of(context).pushNamed<dynamic>(
        NavigationOptions.mealDetailRoute,
        arguments: MealDetailScreenArguments(
          meal,
          type,
          day,
          imperial,
          onConfirm: onConfirm,
          returnAfterAdding: true,
        ),
      ) ==
      true;
}
