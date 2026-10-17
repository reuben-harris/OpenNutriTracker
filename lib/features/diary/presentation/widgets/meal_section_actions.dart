import 'package:opennutritracker/core/presentation/widgets/food_section_actions.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';

/// Each shortcut logs to this meal group on the displayed diary day.
class MealSectionActions extends StatelessWidget {
  final DateTime day;
  final AddMealType mealType;

  const MealSectionActions({
    super.key,
    required this.day,
    required this.mealType,
  });

  @override
  Widget build(BuildContext context) {
    final intakeType = mealType.getIntakeType();
    return FoodSectionActions(
      scanIdentifier: 'diary-${intakeType.name}-scan',
      addIdentifier: 'add-meal-placeholder',
      quickAddIdentifier: 'diary-${intakeType.name}-quick-add',
      onScan: () async {
        final selected = await Navigator.of(context).pushNamed(
          NavigationOptions.scannerRoute,
          arguments: ScannerScreenArguments(day, intakeType),
        );
        if (selected is MealEntity && context.mounted) {
          await logFoodAmount(
            context,
            meal: selected,
            day: day,
            type: intakeType,
          );
        }
      },
      onAdd: () => Navigator.of(context).pushNamed(
        NavigationOptions.addMealRoute,
        arguments: AddMealScreenArguments(mealType, day),
      ),
      onQuickAdd: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => QuickAddBottomSheet(intakeType: intakeType, day: day),
      ),
    );
  }
}
