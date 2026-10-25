import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_amount_row.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_group_header.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_builder.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailNutrimentsTable extends StatelessWidget {
  final MealEntity product;
  final double baseAmount;
  final bool reference;
  final Map<String, NutrientGoal> goals;
  const MealDetailNutrimentsTable({
    super.key,
    required this.product,
    required this.baseAmount,
    required this.reference,
    this.goals = const {},
  });
  @override
  Widget build(BuildContext context) => NutrientVisibilityBuilder(
    builder: (context, daily, info) {
      final s = S.of(context);
      final nutrients = Nutrients.all
          .where((n) => n.core || (info[n.key] ?? true))
          .toList();
      Widget row(NutrientDefinition n) => NutrientAmountRow(
        nutrient: n,
        amount: n
            .amount(product.nutriments)
            ?.scale(reference ? 1 : baseAmount / 100),
        goal: goals[n.key],
        showPercentage: true,
      );
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              (n) => n.amount(product.nutriments)?.isQualified ?? false,
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
