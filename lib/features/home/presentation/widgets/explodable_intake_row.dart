import 'package:opennutritracker/core/domain/usecase/refresh_diary_intake_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_geometry.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Entry swipes reveal Info on the right and Refresh on the left.
class ExplodableIntakeRow extends StatefulWidget {
  final IntakeEntity intake;
  final bool usesImperialUnits;
  final Function(BuildContext, IntakeEntity)? onItemLongPressed;
  final Function(BuildContext, IntakeEntity, bool)? onItemTapped;

  const ExplodableIntakeRow({
    super.key,
    required this.intake,
    required this.usesImperialUnits,
    this.onItemLongPressed,
    this.onItemTapped,
  });

  @override
  State<ExplodableIntakeRow> createState() => _ExplodableIntakeRowState();
}

class _ExplodableIntakeRowState extends State<ExplodableIntakeRow> {
  bool _busy = false;
  bool get _isRecipe => widget.intake.meal.source == MealSourceEntity.recipe;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'diary-intake-swipe',
    child: SwipeReveal(
      enabled: !_busy,
      resetKey: (
        widget.intake.id,
        widget.intake.dateTime,
        widget.intake.meal.source,
      ),
      actionInsets: FoodCardGeometry.margin,
      actionRadius: FoodCardGeometry.radius,
      leftAction: SwipeRevealAction(
        icon: Icons.info_outline_rounded,
        label: S.of(context).diaryInfoLabel,
        semanticsIdentifier: 'diary-intake-info',
        onTap: _onInfo,
        // The recognizer consumes touch slop before reporting drag updates.
        revealThreshold: 32,
      ),
      rightAction: SwipeRevealAction(
        icon: Icons.refresh_rounded,
        label: S.of(context).diaryRefreshLabel,
        semanticsIdentifier: 'diary-intake-refresh',
        onTap: _onRefresh,
      ),
      child: IntakeCard(
        key: ValueKey('card-${widget.intake.id}'),
        intake: widget.intake,
        isRefreshing: _busy,
        onItemLongPressed: widget.onItemLongPressed,
        onItemTapped: (context, intake, imperial) {
          if (intake.meal.isQuickAdd) {
            _openQuickAdd();
          } else {
            widget.onItemTapped?.call(context, intake, imperial);
          }
        },
        usesImperialUnits: widget.usesImperialUnits,
      ),
    ),
  );

  void _onInfo() {
    final intake = widget.intake;
    if (_isRecipe) {
      final recipeId = intake.meal.code;
      if (recipeId == null ||
          locator<RecipeRepository>().getRecipeById(recipeId) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).diaryRecipeUnavailableMessage)),
        );
        return;
      }
      Navigator.of(context).pushNamed(
        NavigationOptions.recipeDetailRoute,
        arguments: RecipeDetailArguments(recipeId: recipeId),
      );
    } else {
      Navigator.of(context).pushNamed(
        NavigationOptions.mealDetailRoute,
        arguments: MealDetailScreenArguments(
          intake.meal,
          intake.type,
          locator<SelectedDayCubit>().state.day,
          widget.usesImperialUnits,
        ),
      );
    }
  }

  void _openQuickAdd() {
    final intake = widget.intake;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddBottomSheet(
        intakeType: intake.type,
        day: intake.dateTime,
        editingIntake: intake,
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_busy) return;
    if (widget.intake.meal.isQuickAdd) {
      _openQuickAdd();
      return;
    }
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        locator<RefreshDiaryIntakeUsecase>().refresh(widget.intake.id),
        Future<IntakeEntity?>.delayed(
          const Duration(milliseconds: 500),
          () => null,
        ),
      ]);
      final updated = results.first;
      if (updated == null) return;
      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).diaryRefreshSuccess)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is DiarySourceUnavailable
                  ? S.of(context).diaryRefreshUnavailable
                  : error is DiaryConversionUnavailable
                  ? S.of(context).diaryRefreshUnitUnavailable
                  : S.of(context).diaryRefreshFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
