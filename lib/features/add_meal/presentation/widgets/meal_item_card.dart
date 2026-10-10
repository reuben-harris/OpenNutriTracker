import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_geometry.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_text.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealItemCard extends StatelessWidget {
  final MealEntity mealEntity;
  final ValueChanged<MealEntity> onSelected;
  final VoidCallback onInfo;
  const MealItemCard({
    super.key,
    required this.mealEntity,
    required this.onSelected,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final brand = mealEntity.brands?.trim();
    final hasBrand = brand != null && brand.isNotEmpty;
    final unknownBrand = mealEntity.source == MealSourceEntity.off && !hasBrand;
    final subtitle = switch (mealEntity.source) {
      MealSourceEntity.off => hasBrand ? brand : s.unknownBrandLabel,
      MealSourceEntity.fdc => s.foodSourceFdcLabel,
      MealSourceEntity.custom => hasBrand ? brand : s.foodSourceCustomLabel,
      MealSourceEntity.recipe => s.recipesLabel,
      MealSourceEntity.unknown => hasBrand ? brand : s.foodSourceUnknownLabel,
    };
    final energy = mealEntity.nutriments.energyKcal100;
    final reference = mealEntity.isLiquid ? '100 ml' : '100 g';
    return Semantics(
      identifier: 'meal-item-select',
      customSemanticsActions: {
        CustomSemanticsAction(label: S.of(context).diaryInfoLabel): onInfo,
      },
      child: SwipeReveal(
        resetKey: (mealEntity.source, mealEntity.code),
        actionInsets: FoodCardGeometry.margin,
        actionRadius: FoodCardGeometry.radius,
        leftAction: SwipeRevealAction(
          icon: Icons.info_outline_rounded,
          label: S.of(context).diaryInfoLabel,
          semanticsIdentifier: 'meal-item-info',
          revealThreshold: 32,
          onTap: onInfo,
        ),
        child: FoodCard(
          meal: mealEntity,
          onTap: () => onSelected(mealEntity),
          content: FoodCardText(
            title: mealEntity.name ?? '?',
            subtitle: TextSpan(
              text: subtitle,
              style: unknownBrand
                  ? const TextStyle(fontStyle: FontStyle.italic)
                  : null,
            ),
            trailingTitle: energy == null
                ? '—'
                : EnergyDisplay.formatWithUnit(context, energy),
            trailingSubtitle: '/ $reference',
          ),
        ),
      ),
    );
  }
}
