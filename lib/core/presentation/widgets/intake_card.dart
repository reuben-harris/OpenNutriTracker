import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_text.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// A logged intake, rendered as a full-width row: a rounded thumbnail, the meal
/// name and amount, and the energy on the trailing edge. Replaces the old
/// 120x120 tile so a day's meals read as a clean scannable list.
class IntakeCard extends StatelessWidget {
  final IntakeEntity intake;
  final Function(BuildContext, IntakeEntity)? onItemLongPressed;
  final Function(BuildContext, IntakeEntity, bool)? onItemTapped;
  final bool usesImperialUnits;
  final bool isRefreshing;

  const IntakeCard({
    required super.key,
    required this.intake,
    this.onItemLongPressed,
    this.onItemTapped,
    required this.usesImperialUnits,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FoodCard(
      meal: intake.meal,
      isRefreshing: isRefreshing,
      borderColor: intake.isIncomplete ? Colors.orange : null,
      onTap: onItemTapped != null
          ? () => onTappedItem(context, usesImperialUnits)
          : null,
      onLongPress: onItemLongPressed != null
          ? () => onLongPressedItem(context)
          : null,
      content: FoodCardText(
        title: intake.meal.name ?? '?',
        subtitle: TextSpan(
          children: [
            TextSpan(
              text: intake.meal.isQuickAdd && !intake.meal.hasQuickAddWeight
                  ? '—'
                  : MealValueUnitText.format(
                      context,
                      intake.amount,
                      intake.meal,
                      usesImperialUnits: usesImperialUnits,
                    ),
            ),
            if (intake.isIncomplete)
              TextSpan(
                text: ' · ${s.missingNutritionLabel}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailingTitle: intake.meal.nutriments.energyKcal100 == null
            ? '—'
            : EnergyDisplay.formatWithUnit(context, intake.totalKcal),
        trailingSubtitle:
            '${_known(intake.meal.nutriments.carbohydrates100, intake.totalCarbsGram)} ${s.carbsLabelShort} '
            '${_known(intake.meal.nutriments.fat100, intake.totalFatsGram)} ${s.fatLabelShort} '
            '${_known(intake.meal.nutriments.proteins100, intake.totalProteinsGram)} ${s.proteinLabelShort}',
      ),
    );
  }

  String _known(double? value, double total) =>
      value == null ? '—' : total.toStringAsFixed(0);

  void onLongPressedItem(BuildContext context) {
    onItemLongPressed?.call(context, intake);
  }

  void onTappedItem(BuildContext context, bool usesImperialUnits) {
    onItemTapped?.call(context, intake, usesImperialUnits);
  }
}
