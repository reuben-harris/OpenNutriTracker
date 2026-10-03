import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/goal_value_toggle.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/dri_reference.dart';
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

  // ---- Default daily references (#173) ----------------------------------
  // Published DRIs / FDA Daily Values used when the user hasn't set their
  // own target in Settings → Nutrient goals. Iron and magnesium default
  // to a gender-aware value; the rest are gender-neutral.
  static const double defaultFibreRefG = 30.0;
  static const double defaultSaturatedFatRefG = 20.0;
  static const double defaultSugarRefG = 50.0;
  static const double defaultSodiumRefMg = 2300.0;
  static const double defaultCalciumRefMg = 1000.0;
  static const double defaultPotassiumRefMg = 3500.0;
  static const double defaultVitaminDRefUg = 15.0;
  static const double defaultVitaminB12RefUg = 2.4;
  static const double defaultMagnesiumRefMg = 355.0; // non-binary midpoint

  /// Pure helpers that prefer the user's [TrackedDayEntity] per-nutrient
  /// goal when set, falling back to the published default otherwise.
  /// Public because the unit test suite asserts each one in isolation.
  static double resolveFibreReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.fibreGoal ?? defaultFibreRefG;

  static double resolveSatFatReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.satFatGoal ?? defaultSaturatedFatRefG;

  static double resolveSugarsReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.sugarsGoal ?? defaultSugarRefG;

  static double resolveSodiumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.sodiumGoal ?? defaultSodiumRefMg;

  static double resolveCalciumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.calciumGoal ?? defaultCalciumRefMg;

  /// Iron uses a gender-aware default that the caller supplies, since the
  /// female / male DRIs (18 vs 8 mg) are far enough apart that an averaged
  /// number would mislead one group.
  static double resolveIronReference(
    TrackedDayEntity? trackedDay,
    double genderDefault,
  ) => trackedDay?.ironGoal ?? genderDefault;

  static double resolvePotassiumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.potassiumGoal ?? defaultPotassiumRefMg;

  static double resolveVitaminDReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.vitaminDGoal ?? defaultVitaminDRefUg;

  static double resolveVitaminB12Reference(TrackedDayEntity? trackedDay) =>
      trackedDay?.vitaminB12Goal ?? defaultVitaminB12RefUg;

  static double resolveMagnesiumReference(TrackedDayEntity? trackedDay) =>
      trackedDay?.magnesiumGoal ?? defaultMagnesiumRefMg;

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

    // Reference values are sensible adult DRIs / FDA Daily Values. Iron's
    // reference uses UserEntity.gender so women see 18mg and men see 8mg;
    // magnesium follows the same gender-aware pattern (400/310). Non-binary
    // users get a midpoint, in line with the app's existing averaged-
    // reference convention for non-binary calculations.
    // Per-nutrient targets — route through the public resolver helpers so
    // the unit tests and the build method share a single source of truth.
    final td = widget.trackedDay;
    // Helper: prefer the per-day tracked override, then the IOM age-banded
    // DRI when a user record is available, then the gender-agnostic default
    // the panel has always used as a last resort. This keeps the existing
    // resolver helpers as the single source of truth for tests, but layers
    // the age-aware IOM lookup (#245) on top for users we know enough about.
    double resolveWithDri(
      double? Function() trackedOverride,
      String nutrientKey,
      double fallback,
    ) {
      final tracked = trackedOverride();
      if (tracked != null) return tracked;
      if (user != null) {
        final dri = getReferenceFor(nutrient: nutrientKey, user: user);
        if (dri != null) return dri.amount;
      }
      return fallback;
    }

    final fiberRefG = resolveWithDri(
      () => td?.fibreGoal,
      NutrientPanelKeys.fiber,
      DailyNutrientPanel.defaultFibreRefG,
    );
    final sodiumRefMg = resolveWithDri(
      () => td?.sodiumGoal,
      NutrientPanelKeys.sodium,
      DailyNutrientPanel.defaultSodiumRefMg,
    );
    // Saturated fat and sugars have no IOM RDA — the resolver helper still
    // returns the published FDA Daily Value as the fallback for both.
    final saturatedFatRefG = DailyNutrientPanel.resolveSatFatReference(td);
    final sugarRefG = DailyNutrientPanel.resolveSugarsReference(td);
    final calciumRefMg = resolveWithDri(
      () => td?.calciumGoal,
      NutrientPanelKeys.calcium,
      DailyNutrientPanel.defaultCalciumRefMg,
    );
    final ironRefMg = resolveWithDri(
      () => td?.ironGoal,
      NutrientPanelKeys.iron,
      _ironRefForUser(user),
    );
    final potassiumRefMg = resolveWithDri(
      () => td?.potassiumGoal,
      NutrientPanelKeys.potassium,
      DailyNutrientPanel.defaultPotassiumRefMg,
    );
    final vitaminDRefMcg = resolveWithDri(
      () => td?.vitaminDGoal,
      NutrientPanelKeys.vitaminD,
      DailyNutrientPanel.defaultVitaminDRefUg,
    );
    final vitaminB12RefMcg = resolveWithDri(
      () => td?.vitaminB12Goal,
      NutrientPanelKeys.vitaminB12,
      DailyNutrientPanel.defaultVitaminB12RefUg,
    );
    final magnesiumRefMg = resolveWithDri(
      () => td?.magnesiumGoal,
      NutrientPanelKeys.magnesium,
      _magnesiumRefForUser(user),
    );

    final s = S.of(context);
    final allRows = <_PanelRow>[
      _PanelRow(
        key: NutrientPanelKeys.fiber,
        label: s.fiberLabel,
        value: fiberG,
        reference: fiberRefG,
        unit: 'g',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.sodium,
        label: s.sodiumLabel,
        value: sodiumMg,
        reference: sodiumRefMg,
        unit: 'mg',
        excessMatters: true,
      ),
      _PanelRow(
        key: NutrientPanelKeys.saturatedFat,
        label: s.saturatedFatLabel,
        value: saturatedFatG,
        reference: saturatedFatRefG,
        unit: 'g',
        excessMatters: true,
      ),
      _PanelRow(
        key: NutrientPanelKeys.sugar,
        label: s.sugarLabel,
        value: sugarG,
        reference: sugarRefG,
        unit: 'g',
        excessMatters: true,
      ),
      _PanelRow(
        key: NutrientPanelKeys.calcium,
        label: s.calciumLabel,
        value: calciumMg,
        reference: calciumRefMg,
        unit: 'mg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.iron,
        label: s.ironLabel,
        value: ironMg,
        reference: ironRefMg,
        unit: 'mg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.potassium,
        label: s.potassiumLabel,
        value: potassiumMg,
        reference: potassiumRefMg,
        unit: 'mg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.vitaminD,
        label: s.vitaminDLabel,
        value: vitaminDMcg,
        reference: vitaminDRefMcg,
        unit: 'µg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.vitaminB12,
        label: s.vitaminB12Label,
        value: vitaminB12Mcg,
        reference: vitaminB12RefMcg,
        unit: 'µg',
        excessMatters: false,
      ),
      _PanelRow(
        key: NutrientPanelKeys.magnesium,
        label: s.magnesiumLabel,
        value: magnesiumMg,
        reference: magnesiumRefMg,
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

  // Gender-aware defaults for the two nutrients where female / male DRIs
  // disagree substantively. Non-binary users route through their chosen
  // [CaloriesProfileEntity] just like the calorie calculation does
  // (see [TDEECalc.getTDEEKcalIOM2005]): Estrogen-typical → female value,
  // Testosterone-typical → male value, Averaged (default) → midpoint.
  // This keeps a single source of truth for what "non-binary → which
  // reference" means across the app, rather than the nutrient panel
  // silently disagreeing with the calorie panel a few sections above.
  static double _ironRefForUser(UserEntity? user) {
    const female = 18.0;
    const male = 8.0;
    const averaged = 14.0;
    return _dispatchGenderReference(
      user,
      female: female,
      male: male,
      averaged: averaged,
    );
  }

  static double _magnesiumRefForUser(UserEntity? user) {
    const female = 310.0;
    const male = 400.0;
    const averaged = 355.0;
    return _dispatchGenderReference(
      user,
      female: female,
      male: male,
      averaged: averaged,
    );
  }

  static double _dispatchGenderReference(
    UserEntity? user, {
    required double female,
    required double male,
    required double averaged,
  }) {
    if (user == null) return averaged;
    switch (user.gender) {
      case UserGenderEntity.female:
        return female;
      case UserGenderEntity.male:
        return male;
      case UserGenderEntity.nonBinary:
        switch (user.caloriesProfile ?? CaloriesProfileEntity.averaged) {
          case CaloriesProfileEntity.averaged:
            return averaged;
          case CaloriesProfileEntity.estrogenTypical:
            return female;
          case CaloriesProfileEntity.testosteroneTypical:
            return male;
        }
    }
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
