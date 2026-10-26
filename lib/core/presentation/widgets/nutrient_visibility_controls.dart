import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The same immediate-save controls on the visibility and detailed goal pages.
class NutrientVisibilityControls extends StatefulWidget {
  final NutrientDefinition nutrient;
  final ConfigEntity config;
  const NutrientVisibilityControls({
    super.key,
    required this.nutrient,
    required this.config,
  });
  @override
  State<NutrientVisibilityControls> createState() =>
      _NutrientVisibilityControlsState();
}

class _NutrientVisibilityControlsState
    extends State<NutrientVisibilityControls> {
  bool _saving = false;
  Future<void> _save(bool value, bool info) async {
    setState(() => _saving = true);
    try {
      await locator<AddConfigUsecase>().setNutrientVisibility(
        [widget.nutrient.key],
        value,
        info: info,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).nutrientSettingsSaveFailedLabel),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nutrient;
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(n.label(s), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        for (final info in [false, true])
          SizedBox(
            width: 64,
            child: Semantics(
              identifier:
                  'nutrient-visibility-${n.key.replaceAll('_', '-')}-${info ? 'info' : 'daily'}',
              label:
                  '${n.label(s)}, ${info ? s.nutrientVisibilityInfoLabel : s.nutrientVisibilityDailyLabel}',
              child: Checkbox(
                value:
                    (info
                        ? widget.config.nutrientInfoVisibility
                        : widget.config.nutrientPanelVisibility)[n.key] ??
                    true,
                onChanged: _saving ? null : (value) => _save(value!, info),
              ),
            ),
          ),
      ],
    );
  }
}
