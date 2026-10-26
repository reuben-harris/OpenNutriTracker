import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// A shared section band separates nutrient groups from editable or value rows.
class NutrientGroupHeader extends StatelessWidget {
  final NutrientGroup group;
  final Widget? trailing;

  const NutrientGroupHeader({super.key, required this.group, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Container(
        width: double.infinity,
        padding: trailing == null
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
            : const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  group.label(S.of(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
