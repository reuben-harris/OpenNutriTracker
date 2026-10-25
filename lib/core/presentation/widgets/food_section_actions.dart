import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/custom_icons.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodSectionActions extends StatelessWidget {
  final String scanIdentifier, addIdentifier, quickAddIdentifier;
  final VoidCallback onScan, onAdd, onQuickAdd;
  final IconData addIcon;
  const FoodSectionActions({
    super.key,
    required this.scanIdentifier,
    required this.addIdentifier,
    required this.quickAddIdentifier,
    required this.onScan,
    required this.onAdd,
    required this.onQuickAdd,
    this.addIcon = Icons.add_rounded,
  });
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final s = S.of(context);
    Widget button(
      String identifier,
      String label,
      IconData icon,
      VoidCallback onPressed,
    ) => Expanded(
      child: Semantics(
        identifier: identifier,
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: palette.surfaceMuted,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: Dimens.borderRadiusM,
              side: BorderSide(color: palette.border),
            ),
          ),
          tooltip: label,
          icon: Icon(icon, color: palette.textMuted),
          onPressed: onPressed,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          button(
            scanIdentifier,
            s.scanProductLabel,
            CustomIcons.barcode_scan,
            onScan,
          ),
          const SizedBox(width: 8),
          button(addIdentifier, s.addLabel, addIcon, onAdd),
          const SizedBox(width: 8),
          button(
            quickAddIdentifier,
            s.quickAddCardLabel,
            Icons.bolt_rounded,
            onQuickAdd,
          ),
        ],
      ),
    );
  }
}
