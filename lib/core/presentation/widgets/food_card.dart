import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_geometry.dart';
import 'package:opennutritracker/core/presentation/widgets/food_thumbnail.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class FoodCard extends StatelessWidget {
  final MealEntity meal;
  final Widget content;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final bool isRefreshing;

  const FoodCard({
    super.key,
    required this.meal,
    required this.content,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: FoodCardGeometry.margin,
    child: Semantics(
      identifier: 'food-card',
      child: AppCard(
        borderRadius: FoodCardGeometry.radius,
        borderColor: borderColor,
        padding: FoodCardGeometry.padding,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: FoodCardGeometry.thumbnailSize,
          ),
          child: Row(
            children: [
              FoodThumbnail(meal: meal, isRefreshing: isRefreshing),
              const SizedBox(width: FoodCardGeometry.gap),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    ),
  );
}
