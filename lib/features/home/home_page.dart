import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/presentation/widgets/low_kcal_warning_card.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/daily_nutrient_panel.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/fasting_home_chip.dart';
import 'package:opennutritracker/features/home/presentation/widgets/overview_macros.dart';
import 'package:opennutritracker/features/profile/presentation/utils/profile_display_format.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The Overview is a read-only account of the shared selected day.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SelectedDayCubit, SelectedDayState>(
    bloc: locator<SelectedDayCubit>(),
    builder: (context, selection) => BlocBuilder<HomeBloc, HomeState>(
      bloc: locator<HomeBloc>(),
      // Keep the current content mounted during refresh.
      buildWhen: (_, next) => next is! HomeLoadingState,
      builder: (context, state) {
        if (state is! HomeLoadedState || state.day != selection.day) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = S.of(context);
        final palette = Theme.of(context).brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light;
        final weight = state.weight;
        final weightText = weight == null
            ? s.overviewWeightUnavailableLabel
            : formatBodyWeight(
                weight.weightKg,
                state.bodyWeightUnit,
                kgLabel: s.kgLabel,
                lbLabel: s.lbsLabel,
                stLabel: s.stLabel,
              );
        return ListView(
          key: const PageStorageKey('overview-scroll'),
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            if (selection.isToday) FastingHomeChip(key: ObjectKey(state)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _informationChip(
                    context,
                    icon: Icons.water_drop_rounded,
                    color: palette.protein,
                    label: s.waterChipLabel(
                      state.waterMlToday,
                      state.waterGoalMl,
                    ),
                  ),
                  _informationChip(
                    context,
                    icon: Icons.monitor_weight_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    label: weightText,
                    detail: weight == null
                        ? null
                        : DateFormat.yMMMd(
                            Localizations.localeOf(context).toString(),
                          ).format(weight.date),
                  ),
                ],
              ),
            ),
            DashboardWidget(
              allowGoalDetails: selection.isToday,
              totalKcalDaily: state.totalKcalDaily,
              totalKcalLeft: state.totalKcalLeft,
              totalKcalSupplied: state.totalKcalSupplied,
              totalKcalBurned: state.totalKcalBurned,
              totalCarbsIntake: state.totalCarbsIntake,
              totalFatsIntake: state.totalFatsIntake,
              totalProteinsIntake: state.totalProteinsIntake,
              totalCarbsGoal: state.totalCarbsGoal,
              totalFatsGoal: state.totalFatsGoal,
              totalProteinsGoal: state.totalProteinsGoal,
            ),
            OverviewMacros(
              carbs: state.totalCarbsIntake,
              fat: state.totalFatsIntake,
              protein: state.totalProteinsIntake,
              carbsGoal: state.totalCarbsGoal,
              fatGoal: state.totalFatsGoal,
              proteinGoal: state.totalProteinsGoal,
              asPercent: state.overviewMacrosAsPercent,
              onToggle: () => _toggle(
                context,
                !state.overviewMacrosAsPercent,
                macros: true,
              ),
            ),
            DailyNutrientPanel(
              intakes: [
                ...state.breakfastIntakeList,
                ...state.lunchIntakeList,
                ...state.dinnerIntakeList,
                ...state.snackIntakeList,
              ],
              selectedDay: state.day,
              trackedDay: state.trackedDay,
              asPercent: state.overviewNutrientsAsPercent,
              onToggle: () => _toggle(
                context,
                !state.overviewNutrientsAsPercent,
                macros: false,
              ),
            ),
            if (CalorieGoalCalc.isBelowRecommendedDailyKcalFloor(
              goalKcal: state.totalKcalDaily,
              gender: state.userGender,
              caloriesProfile: state.userCaloriesProfile,
            ))
              LowKcalWarningCard(
                thresholdKcal: CalorieGoalCalc.recommendedDailyKcalFloor(
                  gender: state.userGender,
                  caloriesProfile: state.userCaloriesProfile,
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _informationChip(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    String? detail,
  }) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: Dimens.borderRadiusM,
        border: Border.all(color: palette.border, width: Dimens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: palette.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    bool value, {
    required bool macros,
  }) async {
    final config = locator<AddConfigUsecase>();
    try {
      if (macros) {
        await config.setOverviewMacrosAsPercent(value);
      } else {
        await config.setOverviewNutrientsAsPercent(value);
      }
      locator<HomeBloc>().add(const LoadItemsEvent());
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).displayPreferenceSaveErrorLabel),
          ),
        );
      }
    }
  }
}
