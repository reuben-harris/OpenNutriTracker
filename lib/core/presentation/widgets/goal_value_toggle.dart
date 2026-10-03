import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Percentages are relative to a daily goal, not shares of calories consumed.
String goalPercentage(double consumed, double goal) =>
    goal > 0 && goal.isFinite && consumed.isFinite
    ? '${(consumed / goal * 100).toStringAsFixed(0)}%'
    : '—';

double goalProgress(double consumed, double goal) =>
    goal > 0 && goal.isFinite && consumed.isFinite
    ? (consumed / goal).clamp(0.0, 1.0)
    : 0;

class GoalValueToggle extends StatelessWidget {
  final String identifier;
  final bool asPercent;
  final VoidCallback onPressed;
  const GoalValueToggle({
    super.key,
    required this.identifier,
    required this.asPercent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    child: IconButton(
      tooltip: asPercent
          ? S.of(context).showNutrientAmountsLabel
          : S.of(context).showNutrientPercentagesLabel,
      isSelected: asPercent,
      onPressed: onPressed,
      icon: const Icon(Icons.percent_rounded),
      selectedIcon: const Icon(Icons.percent_rounded),
    ),
  );
}
