import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailMacroNutrients extends StatelessWidget {
  final String typeString;
  final double? value;
  final double goal;
  final Color color;
  final String? amountLabel;
  const MealDetailMacroNutrients({
    super.key,
    required this.typeString,
    required this.value,
    required this.goal,
    required this.color,
    this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final known = value != null && value!.isFinite;
    final percentage = !known || !goal.isFinite || goal <= 0
        ? '—'
        : '${(value! / goal * 100).round()}%';
    final amount = known
        ? amountLabel ?? '${value!.toStringAsFixed(2)} g'
        : S.of(context).nutritionNoDataLabel;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AutoSizeText(
          typeString,
          textAlign: TextAlign.center,
          maxLines: 1,
          minFontSize: 10,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        AutoSizeText(
          amount,
          textAlign: TextAlign.center,
          maxLines: 1,
          minFontSize: 12,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          percentage,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}
