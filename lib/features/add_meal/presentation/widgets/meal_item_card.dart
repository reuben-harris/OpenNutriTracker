import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_brand_span.dart';
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
    final brand = foodBrandSpan(context, mealEntity);
    final subtitle = switch (mealEntity.source) {
      MealSourceEntity.off => brand!,
      MealSourceEntity.catalogue => brand!,
      MealSourceEntity.custom =>
        brand ?? TextSpan(text: s.foodSourceCustomLabel),
      MealSourceEntity.recipe => TextSpan(text: s.recipesLabel),
      MealSourceEntity.unknown =>
        brand ?? TextSpan(text: s.foodSourceUnknownLabel),
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
          animateClose: false,
          revealThreshold: 32,
          onTap: onInfo,
        ),
        child: FoodCard(
          meal: mealEntity,
          onTap: () => onSelected(mealEntity),
          content: FoodCardText(
            title: mealEntity.name ?? '?',
            subtitle: subtitle,
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
