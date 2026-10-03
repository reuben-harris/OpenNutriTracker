import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/custom_icons.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Each shortcut logs to this meal group on the displayed diary day.
class MealSectionActions extends StatelessWidget {
  final DateTime day;
  final AddMealType mealType;

  const MealSectionActions({
    super.key,
    required this.day,
    required this.mealType,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final s = S.of(context);
    final intakeType = mealType.getIntakeType();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              identifier: 'diary-${intakeType.name}-scan',
              container: true,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: palette.surfaceMuted,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: Dimens.borderRadiusM,
                    side: BorderSide(color: palette.border),
                  ),
                ),
                tooltip: s.scanProductLabel,
                icon: Icon(CustomIcons.barcode_scan, color: palette.textMuted),
                onPressed: () => Navigator.of(context).pushNamed(
                  NavigationOptions.scannerRoute,
                  arguments: ScannerScreenArguments(day, intakeType),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              identifier: 'add-meal-placeholder',
              container: true,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: palette.surfaceMuted,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: Dimens.borderRadiusM,
                    side: BorderSide(color: palette.border),
                  ),
                ),
                tooltip: s.addLabel,
                icon: Icon(
                  Icons.add_rounded,
                  size: 26,
                  color: palette.textMuted,
                ),
                onPressed: () => Navigator.of(context).pushNamed(
                  NavigationOptions.addMealRoute,
                  arguments: AddMealScreenArguments(mealType, day),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              identifier: 'diary-${intakeType.name}-quick-add',
              container: true,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: palette.surfaceMuted,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: Dimens.borderRadiusM,
                    side: BorderSide(color: palette.border),
                  ),
                ),
                tooltip: s.quickAddCardLabel,
                icon: Icon(Icons.bolt_rounded, color: palette.textMuted),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) =>
                      QuickAddBottomSheet(intakeType: intakeType, day: day),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
