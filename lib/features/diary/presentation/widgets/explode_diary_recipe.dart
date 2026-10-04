import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/explode_recipe_intake_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<void> explodeDiaryRecipe(
  BuildContext context,
  IntakeEntity entry,
) async {
  try {
    ExplodeRecipeIntakeUsecase.prepareIngredients(entry);
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).explodeRecipeOldEntryMessage)),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final s = S.of(context);
      return AlertDialog(
        title: Text(s.explodeRecipeConfirmTitle),
        content: Text(s.explodeRecipeOneWayHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.dialogCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.explodeRecipeLabel),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await locator<ExplodeRecipeIntakeUsecase>().explode(entry.id);
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).explodeRecipeSuccessMessage)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).explodeRecipeFailedMessage)),
      );
    }
  }
}
