import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_builder.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Daily recorded amounts, with the same nutrient visibility as Overview.
class MicronutrientsTrendCard extends StatefulWidget {
  final DateTime today;
  final int rangeDays;
  final Map<DateTime, NutrientTotals> nutrientsByDay;
  final Map<String, bool> visibility;

  const MicronutrientsTrendCard({
    super.key,
    required this.today,
    required this.rangeDays,
    required this.nutrientsByDay,
    required this.visibility,
  });

  @override
  State<MicronutrientsTrendCard> createState() =>
      _MicronutrientsTrendCardState();
}

class _MicronutrientsTrendCardState extends State<MicronutrientsTrendCard> {
  String _selected = NutrientKeys.fiber;

  @override
  Widget build(BuildContext context) => NutrientVisibilityBuilder(
    builder: (context, config) => _build(context, {
      ...widget.visibility,
      ...config.nutrientPanelVisibility,
    }),
  );

  Widget _build(BuildContext context, Map<String, bool> visibility) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final options = Nutrients.additional
        .where((n) => visibility[n.key] ?? true)
        .toList();
    final title = AutoSizeText(
      s.totalNutrientsLabel,
      style: theme.textTheme.titleMedium,
      maxLines: 1,
      minFontSize: 12,
      overflow: TextOverflow.ellipsis,
    );
    if (options.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            Text(s.nutrientPanelAllHiddenLabel),
          ],
        ),
      );
    }
    final nutrient = options.firstWhere(
      (n) => n.key == _selected,
      orElse: () => options.first,
    );
    final start = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day - widget.rangeDays + 1,
    );
    DateTime dateAt(int index) =>
        DateTime(start.year, start.month, start.day + index);
    NutrientTotals dayTotals(int index) =>
        widget.nutrientsByDay[dateAt(index)] ?? NutrientTotals.zero;
    NutrientAmount? dayAmount(int index) =>
        dayTotals(index).amounts[nutrient.field];
    final spots = [
      for (var i = 0; i < widget.rangeDays; i++)
        switch (dayAmount(i)) {
          final amount? => FlSpot(i.toDouble(), amount.calculationValue),
          null => FlSpot.nullSpot,
        },
    ];
    final average = NutrientTotals.averageDays([
      for (var i = 0; i < widget.rangeDays; i++) dayTotals(i),
    ]).amounts[nutrient.field];
    final maximum = spots.fold<double>(
      0,
      (max, spot) => !spot.isNull() && spot.y > max ? spot.y : max,
    );
    final locale = Localizations.localeOf(context).toString();
    String amount(NutrientAmount? value) => formatNutrientAmount(
      value,
      s,
      unit: nutrient.unit,
      decimals: 1,
      trimTrailingZeros: true,
    );
    final averageLabel = '${s.trendsDailyAverageLabel}: ${amount(average)}';
    final dateFormat = DateFormat.MMMd(locale);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          Semantics(
            identifier: 'trends-nutrient-selector',
            child: DropdownButtonFormField<String>(
              key: ValueKey(nutrient.key),
              initialValue: nutrient.key,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option.key,
                    child: AutoSizeText(
                      option.label(s),
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selected = value);
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            averageLabel,
            semanticsLabel:
                '$averageLabel. ${nutrientQualificationLabel(average, s)}',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 20),
          Semantics(
            identifier: 'trends-nutrients-chart',
            label:
                '${nutrient.label(s)}. $averageLabel. ${nutrientQualificationLabel(average, s)}',
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (widget.rangeDays - 1).toDouble(),
                  minY: 0,
                  maxY: maximum > 0 ? maximum * 1.15 : 1,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touched) => [
                        for (final spot in touched)
                          LineTooltipItem(
                            '${dateFormat.format(dateAt(spot.x.round()))}\n'
                            '${amount(dayAmount(spot.x.round()))}',
                            theme.textTheme.labelMedium!.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                      ],
                      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: widget.rangeDays <= 7),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  dateFormat.format(start),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateFormat.format(widget.today),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
