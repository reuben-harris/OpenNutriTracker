import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailMacroNutrients extends StatelessWidget {
  final String typeString;
  final NutrientAmount? value;
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
    final s = S.of(context);
    final percentage = formatNutrientPercentage(value, goal);
    final amount = known
        ? amountLabel ?? formatNutrientAmount(value, s, unit: 'g')
        : s.nutritionNoDataLabel;
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
          semanticsLabel: '$amount. ${nutrientQualificationLabel(value, s)}',
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
