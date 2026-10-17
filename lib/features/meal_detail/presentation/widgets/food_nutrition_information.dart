import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_macro_nutrients.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodNutritionInformation extends StatefulWidget {
  final MealEntity meal;
  final DateTime day;
  final MealDetailBloc? bloc;
  const FoodNutritionInformation({
    super.key,
    required this.meal,
    required this.day,
    this.bloc,
  });
  @override
  State<FoodNutritionInformation> createState() =>
      _FoodNutritionInformationState();
}

class _FoodNutritionInformationState extends State<FoodNutritionInformation> {
  late final MealDetailBloc _bloc;
  bool _reference = false, _basisChosen = false;
  FoodAmountSelection? _selection;
  MealEntity get _meal => widget.meal;
  FoodAmountOption? get _serving => foodAmountOptions(
    _meal,
  ).where((option) => option.unit == 'serving').firstOrNull;
  @override
  void initState() {
    super.initState();
    _bloc = widget.bloc ?? locator<MealDetailBloc>();
    _reference = _serving == null;
    _bloc.add(LoadDailyTotalsEvent(widget.day));
    _updatePreview();
  }

  @override
  void didUpdateWidget(FoodNutritionInformation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal != widget.meal) {
      if (!_basisChosen || _serving == null) _reference = _serving == null;
      _updatePreview();
    }
    if (oldWidget.day != widget.day) {
      _bloc.add(LoadDailyTotalsEvent(widget.day));
    }
  }

  void _updatePreview() {
    final serving = _serving;
    final selection = !_reference && serving != null
        ? FoodAmountSelection(1, serving)
        : defaultFoodAmount(_meal);
    _selection = selection;
    _bloc.add(UpdateKcalEvent(meal: _meal, selection: selection));
  }

  @override
  void dispose() {
    if (widget.bloc == null) _bloc.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MealDetailBloc, MealDetailState>(
    bloc: _bloc,
    builder: (context, state) {
      final s = S.of(context);
      final n = _meal.nutriments;
      final palette = Theme.of(context).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_serving == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s.servingWeightUnavailableLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Semantics(
            identifier: 'meal-detail-nutrition-basis',
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  enabled: _serving != null,
                  label: Text(
                    _serving == null
                        ? s.oneServingLabel
                        : s.oneServingWeightLabel(
                            '${formatFoodAmount(_serving!.factor)} ${_serving!.baseUnit}',
                          ),
                  ),
                ),
                ButtonSegment(value: true, label: Text(s.per100gmlLabel)),
              ],
              selected: {_reference},
              onSelectionChanged: (value) => setState(() {
                _basisChosen = true;
                _reference = value.single;
                _updatePreview();
              }),
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            key: const ValueKey('meal-detail-macro-summary'),
            color: palette.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth /
                            MediaQuery.textScalerOf(context).scale(1) >=
                        280
                    ? 4
                    : 2;
                final summaries = [
                  MealDetailMacroNutrients(
                    typeString: s.energyLabel,
                    value: n.energyKcal100 == null ? null : state.totalKcal,
                    goal: state.dayKcalGoal,
                    color: palette.textStrong,
                    amountLabel: EnergyDisplay.formatWithUnit(
                      context,
                      state.totalKcal,
                    ),
                  ),
                  MealDetailMacroNutrients(
                    typeString: s.carbsLabel,
                    value: n.carbohydrates100 == null ? null : state.totalCarbs,
                    goal: state.dayCarbsGoal,
                    color: palette.carbs,
                  ),
                  MealDetailMacroNutrients(
                    typeString: s.fatLabel,
                    value: n.fat100 == null ? null : state.totalFat,
                    goal: state.dayFatGoal,
                    color: palette.fat,
                  ),
                  MealDetailMacroNutrients(
                    typeString: s.proteinLabel,
                    value: n.proteins100 == null ? null : state.totalProtein,
                    goal: state.dayProteinGoal,
                    color: palette.protein,
                  ),
                ];
                return Wrap(
                  runSpacing: 12,
                  children: [
                    for (final summary in summaries)
                      SizedBox(
                        width: constraints.maxWidth / columns,
                        child: summary,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          DailyKcalOverview(
            dayKcalConsumed: state.dayKcalConsumed,
            dayKcalGoal: state.dayKcalGoal,
            currentSelectionKcal: n.energyKcal100 == null ? 0 : state.totalKcal,
          ),
          const SizedBox(height: 12),
          if (state.isHydrating) const LinearProgressIndicator(minHeight: 2),
          MealDetailNutrimentsTable(
            product: _meal,
            baseAmount: _selection?.baseAmount ?? 0,
            reference: _reference,
            goals: state.dayNutrientGoals,
          ),
          const SizedBox(height: 12),
        ],
      );
    },
  );
}
