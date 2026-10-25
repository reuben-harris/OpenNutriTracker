import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_text.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodAmountCard extends StatelessWidget {
  final MealEntity meal;
  final FoodAmountSelection? quantity;
  final bool usesImperialUnits;
  final bool isRefreshing;
  final bool isIncomplete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const FoodAmountCard({
    super.key,
    required this.meal,
    required this.quantity,
    required this.usesImperialUnits,
    this.isRefreshing = false,
    this.isIncomplete = false,
    this.onTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scale = quantity == null ? 1.0 : quantity!.baseAmount / 100;
    return FoodCard(
      meal: meal,
      isRefreshing: isRefreshing,
      borderColor: isIncomplete ? Colors.orange : null,
      onTap: onTap,
      onLongPress: onLongPress,
      content: FoodCardText(
        nutritionSemantics: meal.nutriments.hasQualifications
            ? '${EnergyDisplay.formatAmount(context, meal.nutriments.energyKcal100?.scale(scale))}. ${meal.nutriments.amounts.entries.where((e) => e.value?.isQualified ?? false).map((e) => nutrientQualificationLabel(e.value, s)).join('. ')}'
            : null,
        title: meal.name ?? '?',
        subtitle: TextSpan(
          children: [
            TextSpan(
              text: quantity == null
                  ? '—'
                  : MealValueUnitText.format(
                      context,
                      quantity!.baseAmount,
                      meal,
                      sourceUnit: quantity?.option.baseUnit,
                      usesImperialUnits: usesImperialUnits,
                    ),
            ),
            if (isIncomplete)
              TextSpan(
                text: ' · ${s.missingNutritionLabel}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailingTitle: EnergyDisplay.formatAmount(
          context,
          meal.nutriments.energyKcal100?.scale(scale),
        ),
        trailingSubtitle:
            '${formatNutrientAmount(meal.nutriments.carbohydrates100?.scale(scale), s, decimals: 0)} ${s.carbsLabelShort} '
            '${formatNutrientAmount(meal.nutriments.fat100?.scale(scale), s, decimals: 0)} ${s.fatLabelShort} '
            '${formatNutrientAmount(meal.nutriments.proteins100?.scale(scale), s, decimals: 0)} ${s.proteinLabelShort}',
      ),
    );
  }
}
