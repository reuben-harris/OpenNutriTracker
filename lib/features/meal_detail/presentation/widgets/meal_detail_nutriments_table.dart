import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_amount_row.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_group_header.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_builder.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailNutrimentsTable extends StatefulWidget {
  final MealEntity product;
  final double baseAmount;
  final DateTime? viewedDay;
  final bool reference;
  final Map<String, NutrientGoal> goals;
  final Map<String, NutrientReferenceRange> nutrientReferences;
  const MealDetailNutrimentsTable({
    super.key,
    required this.product,
    required this.baseAmount,
    required this.reference,
    this.goals = const {},
    this.viewedDay,
    this.nutrientReferences = const {},
  });
  @override
  State<MealDetailNutrimentsTable> createState() =>
      _MealDetailNutrimentsTableState();
}

class _MealDetailNutrimentsTableState extends State<MealDetailNutrimentsTable> {
  bool _saving = false;

  Future<void> _toggleMissing(bool show) async {
    setState(() => _saving = true);
    try {
      await locator<AddConfigUsecase>().setShowMissingNutrientsInInfo(show);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).nutrientSettingsSaveFailedLabel),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => NutrientVisibilityBuilder(
    builder: (context, config) {
      final showMissing = config.showMissingNutrientsInInfo;
      final s = S.of(context);
      final nutrients = Nutrients.all
          .where(
            (n) => n.core || (config.nutrientInfoVisibility[n.key] ?? true),
          )
          .where(
            (n) =>
                showMissing ||
                (n.amount(widget.product.nutriments)?.isFinite ?? false),
          )
          .toList();
      Widget row(NutrientDefinition n) => NutrientAmountRow(
        nutrient: n,
        amount: n
            .amount(widget.product.nutriments)
            ?.scale(widget.reference ? 1 : widget.baseAmount / 100),
        goal: widget.goals[n.key],
        referenceRange: widget.nutrientReferences[n.key],
        viewedDay: widget.viewedDay,
        showPercentage: true,
      );
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.nutrientsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  identifier: 'meal-detail-toggle-missing-nutrients',
                  child: IconButton(
                    tooltip: showMissing
                        ? s.hideMissingNutrientsLabel
                        : s.showMissingNutrientsLabel,
                    isSelected: !showMissing,
                    icon: const Icon(Icons.visibility_outlined),
                    selectedIcon: const Icon(Icons.visibility_off_outlined),
                    onPressed: _saving
                        ? null
                        : () => _toggleMissing(!showMissing),
                  ),
                ),
              ],
            ),
            if (nutrients.isEmpty) Text(s.nutritionNoReportedValuesLabel),
            if (nutrients.any((n) => n.key == NutrientKeys.energy))
              row(Nutrients.byKey[NutrientKeys.energy]!),
            for (final group in NutrientGroup.values)
              if (nutrients.any(
                (n) => n.key != NutrientKeys.energy && n.group == group,
              )) ...[
                NutrientGroupHeader(group: group),
                for (final n in nutrients.where(
                  (n) => n.key != NutrientKeys.energy && n.group == group,
                ))
                  row(n),
              ],
            if (nutrients.any(
              (n) => n.amount(widget.product.nutriments)?.isQualified ?? false,
            ))
              Text(
                s.nutrientQualificationLegend,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
    },
  );
}
