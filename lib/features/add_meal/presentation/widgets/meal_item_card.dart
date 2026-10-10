import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealItemCard extends StatelessWidget {
  final MealEntity mealEntity;
  final bool usesImperialUnits;
  final ValueChanged<MealEntity> onSelected;
  const MealItemCard({super.key, required this.mealEntity,
    required this.usesImperialUnits, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final isRecipe = mealEntity.source == MealSourceEntity.recipe;
    return FoodCard(
      meal: mealEntity,
      onTap: () => onSelected(mealEntity),
      content: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AutoSizeText.rich(
                  TextSpan(
                    text: mealEntity.name ?? "?",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                    children: [
                      TextSpan(
                        text: ' ${mealEntity.brands ?? ""}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Dimens.spacing4),
                _buildSubtitle(context, palette, accent, isRecipe),
              ],
            ),
          ),
          const SizedBox(width: Dimens.spacing8),
          Semantics(
            identifier: 'meal-item-add',
            child: IconButton(
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: accent,
                shape: const RoundedRectangleBorder(
                  borderRadius: Dimens.borderRadiusM,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 24),
              onPressed: () => onSelected(mealEntity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    AppPalette palette,
    Color accent,
    bool isRecipe,
  ) {
    final chip = _labelChip(
      context,
      _sourceLabel(context),
      background: isRecipe
          ? accent.withValues(alpha: 0.16)
          : palette.textMuted.withValues(alpha: 0.12),
      foreground: isRecipe ? accent : palette.textMuted,
    );
    final quantity =
        mealEntity.mealQuantity != null &&
            (!mealEntity.isQuickAdd || mealEntity.hasQuickAddWeight)
        ? MealValueUnitText(
            value: double.parse(mealEntity.mealQuantity ?? "0"),
            meal: mealEntity,
            usesImperialUnits: usesImperialUnits,
          )
        : null;

    if (quantity != null) {
      return Wrap(
        spacing: Dimens.spacing8,
        runSpacing: Dimens.spacing4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [chip, quantity],
      );
    }
    return chip;
  }

  String _sourceLabel(BuildContext context) => switch (mealEntity.source) {
    MealSourceEntity.off => OFFConst.offSourceName,
    MealSourceEntity.fdc => 'USDA FoodData Central',
    MealSourceEntity.custom => S.of(context).additionalInfoLabelCustom,
    MealSourceEntity.recipe => S.of(context).additionalInfoLabelRecipe,
    MealSourceEntity.unknown => S.of(context).additionalInfoLabelUnknown,
  };

  Widget _labelChip(
    BuildContext context,
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacing8,
        vertical: Dimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Dimens.borderRadiusS,
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

}
