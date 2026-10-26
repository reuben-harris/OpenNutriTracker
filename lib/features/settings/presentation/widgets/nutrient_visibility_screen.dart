import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_builder.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_group_header.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

class NutrientVisibilityScreen extends StatefulWidget {
  const NutrientVisibilityScreen({super.key});
  @override
  State<NutrientVisibilityScreen> createState() =>
      _NutrientVisibilityScreenState();
}

class _NutrientVisibilityScreenState extends State<NutrientVisibilityScreen> {
  bool _saving = false;
  Future<void> _toggle(Iterable<String> keys, bool value, bool info) async {
    setState(() => _saving = true);
    try {
      await locator<AddConfigUsecase>().setNutrientVisibility(
        keys,
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
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsNutrientsLabel)),
      body: NutrientVisibilityBuilder(
        builder: (context, config) => Semantics(
          identifier: 'nutrient-visibility-list',
          label: s.settingsNutrientsLabel,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s.settingsNutrientsHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  SizedBox(
                    width: 64,
                    child: Text(
                      s.nutrientVisibilityDailyLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      s.nutrientVisibilityInfoLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              for (final group in Nutrients.additionalGroups) ...[
                NutrientGroupHeader(
                  group: group,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final isInfo in [false, true])
                        _groupCheckbox(
                          group,
                          isInfo
                              ? config.nutrientInfoVisibility
                              : config.nutrientPanelVisibility,
                          isInfo,
                        ),
                    ],
                  ),
                ),
                for (final n in Nutrients.additional.where(
                  (n) => n.group == group,
                ))
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.label(s),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final isInfo in [false, true])
                        SizedBox(
                          width: 64,
                          child: Semantics(
                            identifier:
                                'nutrient-visibility-${n.key.replaceAll('_', '-')}-${isInfo ? 'info' : 'daily'}',
                            label:
                                '${n.label(s)}, ${isInfo ? s.nutrientVisibilityInfoLabel : s.nutrientVisibilityDailyLabel}',
                            child: Checkbox(
                              value:
                                  (isInfo
                                      ? config.nutrientInfoVisibility
                                      : config.nutrientPanelVisibility)[n
                                      .key] ??
                                  true,
                              onChanged: _saving
                                  ? null
                                  : (value) => _toggle([n.key], value!, isInfo),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupCheckbox(
    NutrientGroup group,
    Map<String, bool> visibility,
    bool info,
  ) {
    final s = S.of(context);
    final nutrients = Nutrients.additional
        .where((n) => n.group == group)
        .toList();
    final count = nutrients.where((n) => visibility[n.key] ?? true).length;
    final allVisible = count == nutrients.length;
    final bool? value = allVisible
        ? true
        : count == 0
        ? false
        : null;
    return SizedBox(
      width: 64,
      child: Semantics(
        identifier:
            'nutrient-visibility-group-${group.name}-${info ? 'info' : 'daily'}',
        label:
            '${group.label(s)}, ${info ? s.nutrientVisibilityInfoLabel : s.nutrientVisibilityDailyLabel}',
        child: Checkbox(
          tristate: true,
          value: value,
          onChanged: _saving
              ? null
              : (_) => _toggle(nutrients.map((n) => n.key), !allVisible, info),
        ),
      ),
    );
  }
}
