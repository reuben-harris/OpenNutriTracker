import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailNutrimentsTable extends StatelessWidget {
  final MealEntity product;
  final double baseAmount;
  final bool reference;
  final Map<String, double> goals;
  const MealDetailNutrimentsTable({
    super.key,
    required this.product,
    required this.baseAmount,
    required this.reference,
    this.goals = const {},
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final s = S.of(context);
    final n = product.nutriments;
    Widget row(
      String key,
      String label,
      NutrientAmount? value,
      String? unit, {
      String? parent,
    }) {
      final scaled = value == null || !value.isFinite
          ? null
          : value.scale(reference ? 1 : baseAmount / 100);
      final goal = goals[key];
      final hasGoal = goal != null && goal.isFinite && goal > 0;
      final ratio = scaled == null || !hasGoal
          ? null
          : scaled.calculationValue / goal;
      String number(double amount) =>
          (unit == null ? EnergyDisplay.convert(context, amount) : amount)
              .toStringAsFixed(2);
      final displayed = unit == null
          ? EnergyDisplay.convertAmount(context, scaled)
          : scaled;
      final amount = formatNutrientAmount(
        displayed,
        s,
        unit: displayed?.isQualified == true
            ? (unit ?? EnergyDisplay.unitLabel(context))
            : '',
      );
      final target = hasGoal ? number(goal) : '—';
      final percentage = formatNutrientPercentage(scaled, goal);
      final color = switch (parent ?? key) {
        'energy' => palette.textStrong,
        'fat' || NutrientPanelKeys.saturatedFat => palette.fat,
        'carbohydrates' ||
        NutrientPanelKeys.sugar ||
        NutrientPanelKeys.fiber => palette.carbs,
        'protein' => palette.protein,
        _ => palette.micronutrients,
      };
      return Padding(
        key: ValueKey('nutrition-row-$key'),
        padding: EdgeInsetsDirectional.only(
          start: parent == null ? 0 : 12,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$label - $amount / $target ${unit ?? EnergyDisplay.unitLabel(context)}',
                    semanticsLabel:
                        '$label. $amount. ${nutrientQualificationLabel(scaled, s)}. $percentage',
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          const {
                            'energy',
                            'fat',
                            'carbohydrates',
                            'protein',
                          }.contains(key)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  percentage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: ratio?.clamp(0.0, 1.0) ?? 0,
                minHeight: 5,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: palette.border,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      color: palette.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('energy', s.energyLabel, n.energyKcal100, null),
          row('fat', s.fatLabel, n.fat100, 'g'),
          row(
            NutrientPanelKeys.saturatedFat,
            s.saturatedFatLabel,
            n.saturatedFat100,
            'g',
            parent: 'fat',
          ),
          row(
            'monounsaturated-fat',
            s.monounsaturatedFatLabel,
            n.monounsaturatedFat100,
            'g',
            parent: 'fat',
          ),
          row(
            'polyunsaturated-fat',
            s.polyunsaturatedFatLabel,
            n.polyunsaturatedFat100,
            'g',
            parent: 'fat',
          ),
          row('trans-fat', s.transFatLabel, n.transFat100, 'g', parent: 'fat'),
          row(
            'cholesterol',
            s.cholesterolLabel,
            n.cholesterol100,
            'mg',
            parent: 'fat',
          ),
          row('carbohydrates', s.carbohydrateLabel, n.carbohydrates100, 'g'),
          row(
            NutrientPanelKeys.sugar,
            s.sugarLabel,
            n.sugars100,
            'g',
            parent: 'carbohydrates',
          ),
          row(
            NutrientPanelKeys.fiber,
            s.fiberLabel,
            n.fiber100,
            'g',
            parent: 'carbohydrates',
          ),
          row('protein', s.proteinLabel, n.proteins100, 'g'),
          row(NutrientPanelKeys.sodium, s.sodiumLabel, n.sodium100, 'mg'),
          row(
            NutrientPanelKeys.potassium,
            s.potassiumLabel,
            n.potassium100,
            'mg',
          ),
          row(
            NutrientPanelKeys.magnesium,
            s.magnesiumLabel,
            n.magnesium100,
            'mg',
          ),
          row(NutrientPanelKeys.calcium, s.calciumLabel, n.calcium100, 'mg'),
          row(NutrientPanelKeys.iron, s.ironLabel, n.iron100, 'mg'),
          row('zinc', s.zincLabel, n.zinc100, 'mg'),
          row('phosphorus', s.phosphorusLabel, n.phosphorus100, 'mg'),
          row('vitamin-a', s.vitaminALabel, n.vitaminA100, 'µg'),
          row('vitamin-c', s.vitaminCLabel, n.vitaminC100, 'mg'),
          row(NutrientPanelKeys.vitaminD, s.vitaminDLabel, n.vitaminD100, 'µg'),
          row('vitamin-b6', s.vitaminB6Label, n.vitaminB6100, 'mg'),
          row(
            NutrientPanelKeys.vitaminB12,
            s.vitaminB12Label,
            n.vitaminB12100,
            'µg',
          ),
          row('niacin', s.niacinLabel, n.niacin100, 'mg'),
          Text(
            s.nutrientQualificationLegend,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.nutritionTargetUnavailableLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
