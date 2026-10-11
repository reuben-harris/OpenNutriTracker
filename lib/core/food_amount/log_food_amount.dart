import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
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
  try {
    final saved = await showFoodAmountSheet(
      context,
      meal: meal,
      onConfirm: (food, selection) async {
        return saveFoodAmount(
          context,
          meal: food,
          selection: selection,
          day: day,
          type: type,
          logger: logger,
        );
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

Future<bool> saveFoodAmount(
  BuildContext context, {
  required MealEntity meal,
  required FoodAmountSelection selection,
  required DateTime day,
  required IntakeTypeEntity type,
  required MealDetailBloc logger,
}) async {
  final profiles = locator.isRegistered<HiveDBProvider>()
      ? locator<HiveDBProvider>()
      : null;
  final profile = profiles?.activeProfileId;
  final reader = locator<GetIntakeUsecase>();
  final entries = await switch (type) {
    IntakeTypeEntity.breakfast => reader.getBreakfastIntakeByDay(day),
    IntakeTypeEntity.lunch => reader.getLunchIntakeByDay(day),
    IntakeTypeEntity.dinner => reader.getDinnerIntakeByDay(day),
    IntakeTypeEntity.snack => reader.getSnackIntakeByDay(day),
  };
  final duplicate = entries.any(
    (entry) =>
        (meal.code != null &&
            entry.meal.code == meal.code &&
            entry.meal.source == meal.source) ||
        (meal.name != null && entry.meal.name == meal.name),
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
  await logger.addIntake(context, selection, type, meal, day);
  refreshFoodDiary();
  return true;
}
