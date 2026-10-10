import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

void refreshFoodDiary() {
  locator<HomeBloc>().add(const LoadItemsEvent());
  locator<DiaryBloc>().add(const LoadDiaryYearEvent());
  locator<CalendarDayBloc>().add(const RefreshCalendarDayEvent());
}

Future<bool> logFoodAmount(
  BuildContext context, {
  required MealEntity meal,
  required DateTime day,
  required IntakeTypeEntity type,
}) async {
  final logger = locator<MealDetailBloc>();
  final profiles = locator.isRegistered<HiveDBProvider>()
      ? locator<HiveDBProvider>()
      : null;
  final profile = profiles?.activeProfileId;
  try {
    final saved = await showFoodAmountSheet(
      context,
      meal: meal,
      onConfirm: (food, selection) async {
        final reader = locator<GetIntakeUsecase>();
        final entries = await switch (type) {
          IntakeTypeEntity.breakfast => reader.getBreakfastIntakeByDay(day),
          IntakeTypeEntity.lunch => reader.getLunchIntakeByDay(day),
          IntakeTypeEntity.dinner => reader.getDinnerIntakeByDay(day),
          IntakeTypeEntity.snack => reader.getSnackIntakeByDay(day),
        };
        final duplicate = entries.any(
          (entry) =>
              (food.code != null &&
                  entry.meal.code == food.code &&
                  entry.meal.source == food.source) ||
              (food.name != null && entry.meal.name == food.name),
        );
        if (!context.mounted) return false;
        if (duplicate) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(S.of(ctx).warningLabel),
              content: Text(S.of(ctx).duplicateMealDialogContent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(S.of(ctx).dialogCancelLabel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(S.of(ctx).addLabel),
                ),
              ],
            ),
          );
          if (proceed != true) return false;
        }
        if (!context.mounted) return false;
        if (profiles != null && profiles.activeProfileId != profile) {
          throw StateError('Profile changed');
        }
        await logger.addIntake(
          context,
          selection.option.baseUnit,
          selection.baseAmount.toString(),
          type,
          food,
          day,
          selection: selection,
        );
        refreshFoodDiary();
        return true;
      },
    );
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).infoAddedIntakeLabel)),
      );
    }
    return saved;
  } finally {
    await logger.close();
  }
}
