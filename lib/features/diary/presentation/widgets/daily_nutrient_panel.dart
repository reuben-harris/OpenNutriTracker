import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/goal_value_toggle.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/daily_nutrient_references.dart';
import 'package:opennutritracker/core/utils/calc/dri_reference.dart'
    show driSourceUrl;
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';

export 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';

/// Daily micronutrient summary that aggregates the nutrients reporters keep
/// asking for — fibre, sodium, saturated fat, sugar, calcium, iron, potassium,
/// vitamin D, vitamin B12, and magnesium — across the day's intake list and
/// renders each as a "value / reference" row with a small progress bar.
///
/// The references are sensible DRIs for an average adult (FDA Daily Values
/// where applicable). Iron and magnesium are gender-aware because the gap
/// between female and male DRIs is large enough that a single number would
/// mislead one group or the other.
///
/// Sums the selected day's records and respects per-nutrient visibility
/// settings. History is shown in the micronutrients chart on Trends.
class DailyNutrientPanel extends StatefulWidget {
  final List<IntakeEntity> intakes;
  final bool asPercent;
  final VoidCallback? onToggle;

  /// The day the panel is summarising.
  final DateTime? selectedDay;

  /// Forwarded from the diary day view so the panel can prefer the user's
  /// per-nutrient goals (set in Settings → Nutrient goals, #173) over
  /// the published daily references. Null on days the user hasn't tracked
  /// yet — in which case the panel falls back to the default DRIs.
  final TrackedDayEntity? trackedDay;

  const DailyNutrientPanel({
    super.key,
    required this.intakes,
    this.selectedDay,
    this.trackedDay,
    this.asPercent = false,
    this.onToggle,
  });

  @override
  State<DailyNutrientPanel> createState() => _DailyNutrientPanelState();
}

class _DailyNutrientPanelState extends State<DailyNutrientPanel> {
  Future<_PanelData>? _panelDataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _panelDataFuture ??= _loadPanelData();
  }

  @override
  void didUpdateWidget(covariant DailyNutrientPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent passes a fresh intake list whenever the day changes or an
    // intake is added/removed. Refetch the visibility map for Settings edits.
    if (oldWidget.intakes != widget.intakes ||
        oldWidget.selectedDay != widget.selectedDay) {
      _panelDataFuture = _loadPanelData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PanelData>(
      future: _panelDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        // Keep daily totals visible while loading the display settings.
        return _buildPanel(context, data);
      },
    );
  }

  Future<_PanelData> _loadPanelData() async {
    UserEntity? user;
    try {
      user = await locator<GetUserUsecase>().getUserData();
    } catch (_) {
      // Pre-onboarding / tests: fall back to gender-neutral defaults.
      user = null;
    }

    Map<String, bool> visibility = const <String, bool>{};
    try {
      final config = await locator<GetConfigUsecase>().getConfig();
      visibility = config.nutrientPanelVisibility;
    } catch (_) {
      // Tests without the locator wired up — default to "all visible".
    }

    return _PanelData(user: user, visibility: visibility);
  }

  Widget _buildPanel(BuildContext context, _PanelData? data) {
    final user = data?.user;
    final visibility = data?.visibility ?? const <String, bool>{};
    final totals = NutrientPanelTotals.fromIntakes(widget.intakes);
    final fiberG = totals.fiberG;
    final sodiumMg = totals.sodiumMg;
    final saturatedFatG = totals.saturatedFatG;
    final sugarG = totals.sugarG;
    final calciumMg = totals.calciumMg;
    final ironMg = totals.ironMg;
    final potassiumMg = totals.potassiumMg;
    final vitaminDMcg = totals.vitaminDMcg;
    final vitaminB12Mcg = totals.vitaminB12Mcg;
    final magnesiumMg = totals.magnesiumMg;

    final references = DailyNutrientReferences.resolve(
      trackedDay: widget.trackedDay,
      user: user,
    );

    final s = S.of(context);
    final allRows = <_PanelRow>[
      _PanelRow(
        key: NutrientPanelKeys.fiber,
        label: s.fiberLabel,
        value: fiberG,
        reference: references[NutrientPanelKeys.fiber]!,
        unit: 'g',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.sodium,
        label: s.sodiumLabel,
        value: sodiumMg,
        reference: references[NutrientPanelKeys.sodium]!,
        unit: 'mg',
        excessMatters: true,
      ),
      _PanelRow(
        key: NutrientPanelKeys.saturatedFat,
        label: s.saturatedFatLabel,
        value: saturatedFatG,
        reference: references[NutrientPanelKeys.saturatedFat]!,
        unit: 'g',
        excessMatters: true,
      ),
      _PanelRow(
        key: NutrientPanelKeys.sugar,
        label: s.sugarLabel,
        value: sugarG,
        reference: references[NutrientPanelKeys.sugar]!,
        unit: 'g',
        excessMatters: true,
      ),
      _PanelRow(
        key: NutrientPanelKeys.calcium,
        label: s.calciumLabel,
        value: calciumMg,
        reference: references[NutrientPanelKeys.calcium]!,
        unit: 'mg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.iron,
        label: s.ironLabel,
        value: ironMg,
        reference: references[NutrientPanelKeys.iron]!,
        unit: 'mg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.potassium,
        label: s.potassiumLabel,
        value: potassiumMg,
        reference: references[NutrientPanelKeys.potassium]!,
        unit: 'mg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.vitaminD,
        label: s.vitaminDLabel,
        value: vitaminDMcg,
        reference: references[NutrientPanelKeys.vitaminD]!,
        unit: 'µg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.vitaminB12,
        label: s.vitaminB12Label,
        value: vitaminB12Mcg,
        reference: references[NutrientPanelKeys.vitaminB12]!,
        unit: 'µg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.magnesium,
        label: s.magnesiumLabel,
        value: magnesiumMg,
        reference: references[NutrientPanelKeys.magnesium]!,
        unit: 'mg',
        excessMatters: false,
      ),
    ];

    // Filter by the user's per-nutrient visibility setting. Anything not
    // mentioned in the map defaults to visible.
    final visibleRows = allRows
        .where((row) => visibility[row.key] ?? true)
        .map(
          (row) => _NutrientRow(
            label: row.label,
            value: row.value,
            reference: row.reference,
            unit: row.unit,
            excessMatters: row.excessMatters,
            asPercent: widget.asPercent,
          ),
        )
        .toList();

    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AutoSizeText(
                    s.totalNutrientsLabel,
                    maxLines: 1,
                    minFontSize: 10,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Semantics(
                  identifier: 'dri-panel-info',
                  child: IconButton(
                    tooltip: s.driPanelInfoTitle,
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () => _showDataDisclaimer(context, s),
                  ),
                ),
                if (widget.onToggle != null)
                  GoalValueToggle(
                    identifier: 'overview-nutrients-mode',
                    asPercent: widget.asPercent,
                    onPressed: widget.onToggle!,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleRows.isEmpty)
              Text(s.nutrientPanelAllHiddenLabel, style: textTheme.bodySmall)
            else
              ...visibleRows,
          ],
        ),
      ),
    );
  }

  void _showDataDisclaimer(BuildContext context, S s) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.info_outline),
          title: Text(s.driPanelInfoTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.driPanelInfoBody),
                const SizedBox(height: 12.0),
                Text(s.diaryNutrientPanelDataDisclaimer),
                const SizedBox(height: 16.0),
                Semantics(
                  identifier: 'dri-panel-info-link',
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.parse(driSourceUrl);
                      // Best-effort link launch — silently no-ops if the
                      // platform reports it cannot handle the URL, which is
                      // friendlier than throwing in front of the user.
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        s.driPanelInfoLinkLabel,
                        style: Theme.of(dialogContext).textTheme.bodyMedium
                            ?.copyWith(
                              color: Theme.of(
                                dialogContext,
                              ).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.dialogOKLabel),
            ),
          ],
        );
      },
    );
  }
}

class _PanelData {
  final UserEntity? user;
  final Map<String, bool> visibility;

  _PanelData({required this.user, required this.visibility});
}

class _PanelRow {
  final String key;
  final String label;
  final double value;
  final double reference;
  final String unit;
  final bool excessMatters;

  _PanelRow({
    required this.key,
    required this.label,
    required this.value,
    required this.reference,
    required this.unit,
    required this.excessMatters,
  });
}

class _NutrientRow extends StatelessWidget {
  final bool asPercent;
  final String label;
  final double value;
  final double reference;
  final String unit;

  /// Whether going over the reference is a problem (sodium, saturated fat,
  /// sugar) versus simply not meeting a target (fibre, calcium, iron,
  /// potassium, vitamin D, vitamin B12, magnesium). Affects the colour the
  /// bar turns when the user goes over.
  final bool excessMatters;

  const _NutrientRow({
    required this.asPercent,
    required this.label,
    required this.value,
    required this.reference,
    required this.unit,
    required this.excessMatters,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;
    final ratio = reference > 0 ? value / reference : 0.0;
    final clamped = goalProgress(value, reference);
    final color = _colorForRatio(context, ratio);
    final valueLabel = asPercent
        ? goalPercentage(value, reference)
        : '${value.toStringAsFixed(value >= 10 ? 0 : 1)}'
              ' / ${reference.toStringAsFixed(reference >= 10 ? 0 : 1)}$unit';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  label,
                  maxLines: 1,
                  minFontSize: 10,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.textStrong,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AutoSizeText(
                  '${excessMatters ? '${s.nutrientPanelLimitLabel} · ' : ''}$valueLabel',
                  maxLines: 2,
                  minFontSize: 9,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacing8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8.0,
              backgroundColor: palette.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForRatio(BuildContext context, double ratio) {
    final scheme = Theme.of(context).colorScheme;
    if (excessMatters) {
      // Sodium / saturated fat / sugar: amber as you approach the reference,
      // red once you cross it, green while comfortably below.
      if (ratio >= 1.0) return scheme.error;
      if (ratio >= 0.8) return Colors.amber.shade700;
      return scheme.primary;
    } else {
      // Fibre / calcium / iron / potassium / vitamin D / B12 / magnesium:
      // amber while still well short of the reference, primary green once
      // you reach it. Going over isn't a concern at these values from food
      // alone.
      if (ratio >= 1.0) return scheme.primary;
      if (ratio >= 0.5) return Colors.amber.shade700;
      return scheme.primary.withValues(alpha: 0.6);
    }
  }
}
