import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/goal_value_toggle.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/generated/l10n.dart';

class OverviewMacros extends StatelessWidget {
  final double carbs, fat, protein, carbsGoal, fatGoal, proteinGoal;
  final bool asPercent;
  final VoidCallback onToggle;
  const OverviewMacros({
    super.key,
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.carbsGoal,
    required this.fatGoal,
    required this.proteinGoal,
    required this.asPercent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AutoSizeText(
                    s.macronutrientsLabel,
                    maxLines: 1,
                    minFontSize: 12,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GoalValueToggle(
                  identifier: 'overview-macros-mode',
                  asPercent: asPercent,
                  onPressed: onToggle,
                ),
              ],
            ),
            _row(context, s.carbsLabel, carbs, carbsGoal, palette.carbs),
            _row(context, s.fatLabel, fat, fatGoal, palette.fat),
            _row(
              context,
              s.proteinLabel,
              protein,
              proteinGoal,
              palette.protein,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double value,
    double goal,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final amount = Text(
              asPercent
                  ? goalPercentage(value, goal)
                  : '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} g',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            );
            final title = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
            if (MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, amount],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                Expanded(child: amount),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: goalProgress(value, goal),
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    ),
  );
}
