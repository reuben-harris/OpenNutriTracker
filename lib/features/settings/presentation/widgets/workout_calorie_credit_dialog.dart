import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Returns the chosen credit on Save, or null when dismissed. Both You and
/// Health sync use this editor and persist through the same settings API.
class WorkoutCalorieCreditDialog extends StatefulWidget {
  final double initialMultiplier;

  const WorkoutCalorieCreditDialog({
    super.key,
    required this.initialMultiplier,
  });

  @override
  State<WorkoutCalorieCreditDialog> createState() =>
      _WorkoutCalorieCreditDialogState();
}

class _WorkoutCalorieCreditDialogState
    extends State<WorkoutCalorieCreditDialog> {
  late double _multiplier = widget.initialMultiplier;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      // AutoSizeText uses LayoutBuilder, so give the dialog a tight width
      // instead of asking its title for intrinsic dimensions. Dialog clamps
      // this width to the available viewport on smaller screens.
      constraints: const BoxConstraints.tightFor(width: 560),
      scrollable: true,
      title: AutoSizeText(
        s.healthSyncKcalMultiplierLabel,
        maxLines: 2,
        minFontSize: 16,
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.healthSyncKcalMultiplierValueLabel((_multiplier * 100).round()),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Semantics(
            identifier: 'workout-calorie-credit-slider',
            child: Slider(
              min: ConfigEntity.minHealthWorkoutKcalMultiplier,
              max: ConfigEntity.maxHealthWorkoutKcalMultiplier,
              divisions:
                  ((ConfigEntity.maxHealthWorkoutKcalMultiplier -
                              ConfigEntity.minHealthWorkoutKcalMultiplier) *
                          100)
                      .round(),
              value: _multiplier,
              label: s.healthSyncKcalMultiplierValueLabel(
                (_multiplier * 100).round(),
              ),
              onChanged: (value) => setState(() => _multiplier = value),
            ),
          ),
          Text(s.healthSyncKcalMultiplierSubtitle),
          const SizedBox(height: Dimens.spacing8),
          Wrap(
            spacing: Dimens.spacing8,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _multiplier = ConfigEntity.defaultHealthWorkoutKcalMultiplier;
                }),
                child: Text(s.healthSyncKcalMultiplierDefaultLabel),
              ),
              Semantics(
                identifier: 'workout-calorie-credit-sources',
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SourcesScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(s.settingsSourcesLabel),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.dialogCancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_multiplier),
          child: Text(s.buttonSaveLabel),
        ),
      ],
    );
  }
}
