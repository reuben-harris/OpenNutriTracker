import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_brand_span.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/demo/unsplash_attribution.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class ItemInformationScaffold extends StatelessWidget {
  final MealEntity meal;
  final List<Widget> actions;
  final Widget child;
  final VoidCallback? onLog;
  final bool isRefreshing;
  final String logIdentifier;
  final EdgeInsets contentPadding;
  const ItemInformationScaffold({
    super.key,
    required this.meal,
    required this.actions,
    required this.child,
    required this.onLog,
    this.isRefreshing = false,
    this.logIdentifier = 'item-information-log',
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final subtitle = meal.source == MealSourceEntity.recipe
        ? TextSpan(text: s.additionalInfoLabelRecipe)
        : foodBrandSpan(context, meal);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.surface,
        leading: Semantics(
          identifier: 'meal-detail-back',
          child: const BackButton(),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      key: const ValueKey('meal-detail-header'),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Hero(
                          tag: ImageFullScreen.fullScreenHeroTag,
                          child: FoodImage(
                            meal: meal,
                            width: 64,
                            height: 64,
                            borderRadius: BorderRadius.circular(14),
                            isRefreshing: isRefreshing,
                            refreshIdentifier: 'meal-detail-image-refresh',
                            refreshLabel: s.refreshProductLabel,
                            tapLabel: s.foodImageEnlargeLabel,
                            onTap: () => Navigator.of(context).pushNamed(
                              NavigationOptions.imageFullScreenRoute,
                              arguments: ImageFullScreenArguments(meal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AutoSizeText(
                                meal.name ?? '',
                                maxLines: 2,
                                minFontSize: 16,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text.rich(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: palette.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    UnsplashCreditLine(imageUrl: meal.mainImageUrl),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Padding(padding: contentPadding, child: child),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Semantics(
            identifier: logIdentifier,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLog,
                icon: const Icon(Icons.add_rounded),
                label: Text(s.logThisItemLabel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
