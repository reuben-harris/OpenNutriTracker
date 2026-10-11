import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecipeListItem extends StatelessWidget {
  final RecipeEntity recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  static const double _thumbSize = 52;

  const RecipeListItem({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    final kcalPer100 = recipe.aggregatedNutrimentsPer100.energyKcal100;
    final totalKcal = (kcalPer100 ?? 0) * recipe.totalWeightG / 100;
    final ingredientCount = recipe.ingredients.length;

    // AppCard's own onTap is left null so the inner InkWell can carry both the
    // tap and the long-press (multi-select) gestures from a single hit target.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacing16,
        vertical: Dimens.spacing4,
      ),
      child: AppCard(
        color: isSelected ? accent.withValues(alpha: 0.12) : null,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: Dimens.borderRadiusL,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(Dimens.spacing12),
            child: Row(
              children: [
                FoodImage(
                  meal: recipe.toMealEntity(),
                  width: _thumbSize,
                  height: _thumbSize,
                  borderRadius: Dimens.borderRadiusS,
                  fallbackIcon: Icons.menu_book_rounded,
                ),
                const SizedBox(width: Dimens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        recipe.name,
                        maxLines: 1,
                        minFontSize: 12,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Dimens.spacing4),
                      Text(
                        '${S.of(context).recipeIngredientCountLabel(ingredientCount)} · '
                        '${EnergyDisplay.formatWithUnit(context, totalKcal)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimens.spacing8),
                isSelected
                    ? Icon(Icons.check_circle_rounded, color: accent, size: 24)
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textMuted,
                        size: 24,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
