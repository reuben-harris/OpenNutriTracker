import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_geometry.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// Shared food names, details, and nutrition for search results and logged foods.
class FoodCardText extends StatelessWidget {
  const FoodCardText({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailingTitle,
    required this.trailingSubtitle,
  });

  final String title;
  final TextSpan subtitle;
  final String trailingTitle;
  final String trailingSubtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final titleStyle = text.titleSmall?.copyWith(color: palette.textStrong);
    final subtitleStyle = text.bodySmall?.copyWith(color: palette.textMuted);
    final scale = MediaQuery.textScalerOf(context);
    final singleTitleHeight =
        (scale.scale(titleStyle?.fontSize ?? 14) * (titleStyle?.height ?? 1.3) +
                2)
            .ceilToDouble();
    final subtitleHeight =
        (scale.scale(subtitleStyle?.fontSize ?? 12) *
                    (subtitleStyle?.height ?? 1.3) +
                2)
            .ceilToDouble();
    // Use the thumbnail's spare height for a second, smaller title line.
    final titleHeight =
        (scale.scale(FoodCardGeometry.thumbnailSize) - subtitleHeight - 2)
            .clamp(singleTitleHeight, double.infinity);

    Widget line(double height, Widget child) =>
        SizedBox(height: height, width: double.infinity, child: child);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(
                titleHeight,
                AutoSizeText(
                  title,
                  style: titleStyle,
                  maxLines: 2,
                  minFontSize: 11,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              line(
                subtitleHeight,
                AutoSizeText.rich(
                  subtitle,
                  style: subtitleStyle,
                  maxLines: 1,
                  minFontSize: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Dimens.spacing8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              line(
                titleHeight,
                AutoSizeText(
                  trailingTitle,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  minFontSize: 8,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: palette.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              line(
                subtitleHeight,
                AutoSizeText(
                  trailingSubtitle,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  minFontSize: 8,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
