import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_amount_row.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_group_header.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_builder.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DailyNutrientPanel extends StatefulWidget {
  final List<IntakeEntity> intakes;
  final bool withoutGoal;
  final ValueChanged<bool>? onViewChanged;
  final DateTime? selectedDay;
  final TrackedDayEntity? trackedDay;
  const DailyNutrientPanel({
    super.key,
    required this.intakes,
    this.selectedDay,
    this.trackedDay,
    this.withoutGoal = false,
    this.onViewChanged,
  });
  @override
  State<DailyNutrientPanel> createState() => _DailyNutrientPanelState();
}

class _DailyNutrientPanelState extends State<DailyNutrientPanel> {
  late Future<Map<String, NutrientReferenceRange>> _goals = _loadGoals();
  late bool _withoutGoal = widget.withoutGoal;
  Future<Map<String, NutrientReferenceRange>> _loadGoals() async {
    final user = locator.isRegistered<GetUserUsecase>()
        ? await locator<GetUserUsecase>().getUserData()
        : null;
    final weights = locator.isRegistered<GetWeightLogUsecase>()
        ? await locator<GetWeightLogUsecase>().getAllEntries()
        : const <Never>[];
    return NutrientGoalResolver.resolve(
      user: user,
      day: widget.selectedDay ?? widget.trackedDay?.day ?? DateTime.now(),
      weights: weights,
    );
  }

  @override
  void didUpdateWidget(covariant DailyNutrientPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.withoutGoal != widget.withoutGoal) {
      _withoutGoal = widget.withoutGoal;
    }
    if (oldWidget.intakes != widget.intakes ||
        oldWidget.selectedDay != widget.selectedDay) {
      _goals = _loadGoals();
    }
  }

  @override
  Widget build(BuildContext context) => NutrientVisibilityBuilder(
    builder: (context, config) =>
        FutureBuilder<Map<String, NutrientReferenceRange>>(
          future: _goals,
          builder: (context, snapshot) {
            final s = S.of(context);
            final totals = NutrientTotals.fromIntakes(widget.intakes);
            final goals = snapshot.data ?? <String, NutrientReferenceRange>{};
            final enabled = Nutrients.additional
                .where((n) => config.nutrientPanelVisibility[n.key] ?? true)
                .toList();
            bool hasGoal(NutrientDefinition n) {
              final goal = goals[n.key];
              return goal?.hasGoal ?? false;
            }

            final nutrients = enabled
                .where((n) => hasGoal(n) != _withoutGoal)
                .toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AutoSizeText(
                      s.totalNutrientsLabel,
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      identifier: 'overview-nutrients-view',
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(s.nutrientGoalsViewLabel),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text(s.nutrientNoGoalViewLabel),
                          ),
                        ],
                        selected: {_withoutGoal},
                        onSelectionChanged: (selection) {
                          final value = selection.single;
                          setState(() => _withoutGoal = value);
                          widget.onViewChanged?.call(value);
                        },
                      ),
                    ),
                    if (nutrients.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          enabled.isEmpty
                              ? s.nutrientPanelAllHiddenLabel
                              : _withoutGoal
                              ? s.nutrientNoGoalViewEmptyLabel
                              : s.nutrientGoalsViewEmptyLabel,
                        ),
                      ),
                    for (final group in NutrientGroup.values)
                      if (nutrients.any((n) => n.group == group)) ...[
                        NutrientGroupHeader(group: group),
                        for (final n in nutrients.where(
                          (n) => n.group == group,
                        ))
                          NutrientAmountRow(
                            nutrient: n,
                            amount: totals.amounts[n.field],
                            referenceRange: _withoutGoal ? null : goals[n.key],
                            asPercent: !_withoutGoal,
                            showProgress: !_withoutGoal,
                          ),
                      ],
                    if (nutrients.any(
                      (n) => totals.amounts[n.field]?.isQualified ?? false,
                    ))
                      Text(
                        s.nutrientQualificationLegend,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}
