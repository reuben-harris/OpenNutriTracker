import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:collection/collection.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/util/food_emoji_resolver.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealItemCard extends StatefulWidget {
  final DateTime day;
  final AddMealType addMealType;
  final MealEntity mealEntity;
  final bool usesImperialUnits;

  const MealItemCard({
    super.key,
    required this.day,
    required this.mealEntity,
    required this.addMealType,
    required this.usesImperialUnits,
  });

  @override
  State<MealItemCard> createState() => _MealItemCardState();
}

class _MealItemCardState extends State<MealItemCard> {
  bool _adding = false;
  DateTime get day => widget.day;
  AddMealType get addMealType => widget.addMealType;
  MealEntity get mealEntity => widget.mealEntity;
  bool get usesImperialUnits => widget.usesImperialUnits;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final isRecipe = mealEntity.source == MealSourceEntity.recipe;
    // Colored emoji is reserved for FDC base-food items where the head
    // noun reliably identifies the food ("Milk, fluid, nonfat..." → milk).
    // OFF products are branded, so a head-noun match would often be
    // misleading; they keep the outline icon as a placeholder.
    final emoji =
        (mealEntity.thumbnailImageUrl == null &&
            mealEntity.source == MealSourceEntity.fdc)
        ? resolveFoodEmoji(mealEntity.name)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.spacing8),
      child: AppCard(
        onTap: () => _onItemPressed(context),
        padding: const EdgeInsets.all(Dimens.spacing12),
        child: Row(
          children: [
            _buildThumbnail(context, palette, accent, isRecipe, emoji),
            const SizedBox(width: Dimens.spacing16),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.textMuted),
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
                onPressed: () => _onItemPressed(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    AppPalette palette,
    Color accent,
    bool isRecipe,
    String? emoji,
  ) {
    final radius = BorderRadius.circular(Dimens.radiusM);
    final background = isRecipe
        ? accent.withValues(alpha: 0.16)
        : palette.surfaceMuted;
    if (mealEntity.thumbnailImageUrl != null) {
      return Container(
        width: Dimens.mealThumb,
        height: Dimens.mealThumb,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: radius, color: background),
        child: CachedNetworkImage(
          cacheManager: locator<CacheManager>(),
          fit: BoxFit.cover,
          width: Dimens.mealThumb,
          height: Dimens.mealThumb,
          imageUrl: mealEntity.thumbnailImageUrl ?? "",
          placeholder: (context, url) => Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.textMuted,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Icon(
            Icons.restaurant_rounded,
            size: 26,
            color: palette.textMuted,
          ),
        ),
      );
    }
    return Container(
      width: Dimens.mealThumb,
      height: Dimens.mealThumb,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: radius, color: background),
      child: emoji != null
          ? ExcludeSemantics(
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            )
          : Icon(
              isRecipe ? Icons.menu_book_rounded : Icons.restaurant_rounded,
              size: 26,
              color: isRecipe ? accent : palette.textMuted,
            ),
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    AppPalette palette,
    Color accent,
    bool isRecipe,
  ) {
    if (isRecipe) {
      return _labelChip(
        context,
        S.of(context).additionalInfoLabelRecipe,
        background: accent.withValues(alpha: 0.16),
        foreground: accent,
      );
    }

    // Remote foods carry their database of origin; show it as a muted chip
    // (Open Food Facts, BLS, FDC SR Legacy...) so users can tell sources
    // apart. OFF products may additionally have a package quantity — keep
    // it visible next to the chip.
    if (mealEntity.isQuickAdd) {
      return mealEntity.hasQuickAddWeight
          ? MealValueUnitText(
              value: double.parse(mealEntity.mealQuantity!),
              meal: mealEntity,
              usesImperialUnits: usesImperialUnits,
            )
          : const Text('—');
    }
    final sourceLabel = _sourceLabel();
    final chip = sourceLabel != null
        ? _labelChip(
            context,
            sourceLabel,
            background: palette.textMuted.withValues(alpha: 0.12),
            foreground: palette.textMuted,
          )
        : null;
    final quantity = mealEntity.mealQuantity != null
        ? MealValueUnitText(
            value: double.parse(mealEntity.mealQuantity ?? "0"),
            meal: mealEntity,
            usesImperialUnits: usesImperialUnits,
          )
        : null;

    if (chip != null && quantity != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip,
          const SizedBox(width: Dimens.spacing8),
          Flexible(child: quantity),
        ],
      );
    }
    return chip ?? quantity ?? const SizedBox();
  }

  String? _sourceLabel() {
    if (mealEntity.source == MealSourceEntity.off) {
      return OFFConst.offSourceName;
    }
    return null;
  }

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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _onItemPressed(BuildContext context) async {
    if (_adding) return;
    if (mealEntity.isQuickAdd) {
      setState(() => _adding = true);
      final meal =
          locator<CustomMealDataSource>()
              .getAllCustomMeals()
              .where((m) => m.code == mealEntity.code)
              .map(MealEntity.fromMealDBO)
              .firstOrNull ??
          mealEntity;
      try {
        await locator<MealDetailBloc>().addIntake(
          context,
          meal.hasQuickAddWeight ? meal.mealUnit! : 'g',
          meal.hasQuickAddWeight ? meal.mealQuantity! : '100',
          addMealType.getIntakeType(),
          meal,
          day,
        );
        locator<HomeBloc>().add(const LoadItemsEvent());
        locator<DiaryBloc>().add(const LoadDiaryYearEvent());
        locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          NavigationOptions.mainRoute,
          (route) => false,
        );
      } catch (_) {
        if (mounted) {
          setState(() => _adding = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).quickAddReuseFailed)),
          );
        }
      }
      return;
    }
    Navigator.of(context).pushNamed(
      NavigationOptions.mealDetailRoute,
      arguments: MealDetailScreenArguments(
        mealEntity,
        addMealType.getIntakeType(),
        day,
        usesImperialUnits,
      ),
    );
  }
}
