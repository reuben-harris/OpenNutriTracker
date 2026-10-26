import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:opennutritracker/generated/l10n.dart';

Color nutrientProgressColor(BuildContext context, double? ratio, bool isLimit) {
  final palette = Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  if (ratio != null && ratio >= 1) {
    return isLimit
        ? palette.nutrientLimitReached
        : palette.nutrientTargetReached;
  }
  return palette.nutrientProgressNeutral;
}

/// Shared amounts, qualifications and goal progress for daily and item views.
class NutrientAmountRow extends StatelessWidget {
  final NutrientDefinition nutrient;
  final NutrientAmount? amount;
  final NutrientGoal? goal;
  final NutrientReferenceRange? referenceRange;
  final bool asPercent, showPercentage, showProgress;
  const NutrientAmountRow({
    super.key,
    required this.nutrient,
    required this.amount,
    this.goal,
    this.referenceRange,
    this.asPercent = false,
    this.showPercentage = false,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final reference = referenceRange?.primary;
    final goal = referenceRange == null
        ? this.goal
        : reference?.comparable == true
        ? NutrientGoal(reference!.amount, isLimit: reference.upper)
        : null;
    final s = S.of(context);
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final finiteAmount = amount?.isFinite == true ? amount : null;
    final energy = nutrient.key == NutrientKeys.energy;
    final unit = energy ? EnergyDisplay.unitLabel(context) : nutrient.unit;
    final displayed = energy
        ? EnergyDisplay.convertAmount(context, finiteAmount)
        : finiteAmount;
    final target = goal == null || !goal.amount.isFinite
        ? null
        : energy
        ? EnergyDisplay.convert(context, goal.amount)
        : goal.amount;
    final ratio =
        finiteAmount == null ||
            goal == null ||
            !goal.amount.isFinite ||
            goal.amount <= 0
        ? null
        : finiteAmount.calculationValue / goal.amount;
    final amountText = formatNutrientAmount(
      displayed,
      s,
      unit: unit,
      trimTrailingZeros: true,
    );
    final valueText = asPercent && ratio != null
        ? formatNutrientPercentage(finiteAmount, goal!.amount)
        : amountText;
    final targetText = target == null
        ? ''
        : ' / ${nutrientNumber(target)} $unit';
    final limitText = goal?.isLimit == true
        ? '${s.nutrientPanelLimitLabel} · '
        : '';
    final detail =
        '$limitText$valueText${asPercent && ratio != null ? '' : targetText}'
        '${showPercentage ? ' · ${formatNutrientPercentage(finiteAmount, goal?.amount)}' : ''}';
    final amountDetail = '$limitText$amountText$targetText';
    final color = nutrientProgressColor(context, ratio, goal?.isLimit ?? false);
    final qualification = nutrientQualificationLabel(finiteAmount, s);
    final row = Padding(
      key: ValueKey('nutrition-row-${nutrient.key}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                '${nutrient.label(s)}: $detail${asPercent && ratio != null ? '. $amountDetail' : ''}${qualification.isEmpty ? '' : '. $qualification'}',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AutoSizeText(
                      nutrient.label(s),
                      maxLines: 2,
                      minFontSize: 11,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: nutrient.core ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      detail,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: ratio?.clamp(0.0, 1.0) ?? 0,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: palette.border,
              ),
            ),
          ],
        ],
      ),
    );
    return asPercent
        ? Semantics(
            identifier:
                'nutrition-progress-${nutrient.key.replaceAll('_', '-')}',
            child: Tooltip(
              message: amountDetail,
              triggerMode: TooltipTriggerMode.tap,
              excludeFromSemantics: true,
              child: row,
            ),
          )
        : row;
  }
}
