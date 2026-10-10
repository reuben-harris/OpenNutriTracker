import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';

/// Returns a food only when the information page's logging action is used.
Future<MealEntity?> showFoodInformation(
  BuildContext context, {
  required MealEntity meal,
  required DateTime day,
  required IntakeTypeEntity type,
  required bool imperial,
}) async {
  final navigator = Navigator.of(context);
  final selected = await navigator.pushNamed<dynamic>(
    NavigationOptions.mealDetailRoute,
    arguments: MealDetailScreenArguments(
      meal,
      type,
      day,
      imperial,
      onSelected: (food) => navigator.pop(food),
    ),
  );
  return selected is MealEntity ? selected : null;
}
