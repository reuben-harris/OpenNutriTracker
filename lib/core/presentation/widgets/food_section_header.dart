import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_sort_type.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? summary;
  final List<Widget> actions;
  const FoodSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.summary,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: Dimens.borderRadiusS,
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AutoSizeText(
              title,
              maxLines: 1,
              minFontSize: 14,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                color: palette.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (summary != null)
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: textTheme.labelMedium?.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ...actions,
        ],
      ),
    );
  }
}

class FoodSectionSortMenu extends StatelessWidget {
  final String identifier;
  final DiarySortType value;
  final ValueChanged<DiarySortType> onChanged;
  const FoodSectionSortMenu({
    super.key,
    required this.identifier,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final current = value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return Semantics(
      identifier: identifier,
      child: PopupMenuButton<DiarySortType>(
        tooltip: S.of(context).diarySortByLabel,
        icon: Icon(Icons.sort_rounded, color: palette.textMuted),
        shape: Dimens.shapeM,
        initialValue: current,
        onSelected: onChanged,
        itemBuilder: (context) => <PopupMenuEntry<DiarySortType>>[
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.timeAdded,
            checked: current == DiarySortType.timeAdded,
            child: Text(S.of(context).diarySortByTime),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.kcal,
            checked: current == DiarySortType.kcal,
            child: Text(S.of(context).diarySortByKcal),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.protein,
            checked: current == DiarySortType.protein,
            child: Text(S.of(context).diarySortByProtein),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.carbs,
            checked: current == DiarySortType.carbs,
            child: Text(S.of(context).diarySortByCarbs),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.fat,
            checked: current == DiarySortType.fat,
            child: Text(S.of(context).diarySortByFat),
          ),
        ],
      ),
    );
  }
}
