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
        trailingTitle: meal.nutriments.energyKcal100 == null
            ? '—'
            : EnergyDisplay.formatWithUnit(
                context,
                (meal.nutriments.energyKcal100 ?? 0) * scale,
              ),
        trailingSubtitle:
            '${_known(meal.nutriments.carbohydrates100, (meal.nutriments.carbohydrates100 ?? 0) * scale)} ${s.carbsLabelShort} '
            '${_known(meal.nutriments.fat100, (meal.nutriments.fat100 ?? 0) * scale)} ${s.fatLabelShort} '
            '${_known(meal.nutriments.proteins100, (meal.nutriments.proteins100 ?? 0) * scale)} ${s.proteinLabelShort}',
      ),
    );
  }

  String _known(double? value, double total) =>
      value == null ? '—' : total.toStringAsFixed(0);
}
