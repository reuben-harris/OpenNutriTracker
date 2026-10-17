import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/create_recipe_from_intakes_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<void> createRecipeFromDiary(
  BuildContext context, {
  required String groupName,
  required List<IntakeEntity> entries,
}) async {
  final ingredients = <IntakeEntity>[];
  for (final entry in entries) {
    if (!context.mounted) return;
    if (entry.quantity != null) {
      ingredients.add(entry);
      continue;
    }
    // Quick Add totals need a weight to contribute to per-100 recipe nutrition.
    IntakeEntity? weighted;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => QuickAddBottomSheet(
        intakeType: entry.type,
        day: entry.dateTime,
        editingIntake: entry,
        onConfirm: (meal, quantity) async {
          weighted = IntakeEntity(
            id: entry.id,
            quantity: quantity,
            type: entry.type,
            meal: meal,
            dateTime: entry.dateTime,
          );
          return true;
        },
      ),
    );
    if (weighted == null) return;
    ingredients.add(weighted!);
  }
  if (!context.mounted) return;
  try {
    final recipe = await locator<CreateRecipeFromIntakesUsecase>().create(
      name: S.of(context).diaryRecipeName(groupName),
      entries: ingredients,
    );
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(
      NavigationOptions.recipeDetailRoute,
      arguments: RecipeDetailArguments(recipeId: recipe.id),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).recipeSaveErrorLabel)),
      );
    }
  }
}
