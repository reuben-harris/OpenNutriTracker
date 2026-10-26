import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/nutrition/reference_assessment.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_reference_details.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<void> showNutrientReferenceOverlay(
  BuildContext context, {
  required NutrientDefinition nutrient,
  required NutrientAmount? amount,
  required NutrientReferenceRange range,
  required DateTime day,
}) => showDialog<void>(
  context: context,
  builder: (_) => NutrientReferenceOverlay(
    nutrient: nutrient,
    amount: amount,
    range: range,
    day: day,
  ),
);

class NutrientReferenceOverlay extends StatelessWidget {
  final NutrientDefinition nutrient;
  final NutrientAmount? amount;
  final NutrientReferenceRange range;
  final DateTime day;
  const NutrientReferenceOverlay({
    super.key,
    required this.nutrient,
    required this.amount,
    required this.range,
    required this.day,
  });
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final assessment = ReferenceAssessment(amount, range);
    final a = range.adequacy?.comparable == true ? range.adequacy : null;
    final u = range.upper?.comparable == true ? range.upper : null;
    final intake = amount?.isFinite == true ? amount!.calculationValue : null;
    final color = assessment.state == ReferenceRangeState.above
        ? Theme.of(context).colorScheme.error
        : assessment.state == ReferenceRangeState.within
        ? Colors.green
        : Theme.of(context).colorScheme.onSurface;
    final state = switch (assessment.state) {
      ReferenceRangeState.above => s.nutrientAboveUpper,
      ReferenceRangeState.below => s.nutrientBelowAdequacy,
      ReferenceRangeState.within => s.nutrientBetweenThresholds,
      ReferenceRangeState.adequate => s.nutrientAtAdequacy,
      ReferenceRangeState.belowUpper => s.nutrientWithinUpper,
      ReferenceRangeState.unavailable => s.nutrientNoAssessment,
    };
    return AlertDialog(
      scrollable: true,
      title: Text(nutrient.label(s)),
      content: Semantics(
        identifier: 'nutrient-reference-overlay',
        child: SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(day),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.nutrientRecordedAmount}: ${formatNutrientAmount(amount, s, unit: nutrient.unit, trimTrailingZeros: true)}',
              ),
              if (nutrientQualificationLabel(amount, s).isNotEmpty)
                Text(nutrientQualificationLabel(amount, s)),
              const SizedBox(height: 12),
              Text(
                s.nutrientReferenceRange,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (a != null || u != null) ...[
                // Text labels below provide the complete accessible equivalent.
                ExcludeSemantics(
                  child: SizedBox(
                    key: const ValueKey('reference-range-graphic'),
                    height: 72 + MediaQuery.textScalerOf(context).scale(30),
                    child: CustomPaint(
                      painter: _ReferenceRangePainter(
                        adequacyLabel: a == null
                            ? null
                            : referenceTermLabel(a.term, s),
                        upperLabel: u == null
                            ? null
                            : referenceTermLabel(u.term, s),
                        textScale:
                            MediaQuery.textScalerOf(context).scale(12) / 12,
                        textDirection: Directionality.of(context),
                        adequacy: a?.amount,
                        upper: u?.amount,
                        intake: intake,
                        line: Theme.of(context).colorScheme.outline,
                        intakeColor: color,
                      ),
                    ),
                  ),
                ),
                if (intake != null)
                  Text(
                    key: const ValueKey('reference-intake-marker'),
                    '↓ ${s.nutrientIntakeMarker}: ${formatNutrientAmount(amount, s, unit: nutrient.unit, trimTrailingZeros: true)}',
                  ),
              ],
              for (final threshold in [range.adequacy, range.upper].nonNulls)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '| ${referenceAmountLabel(threshold, s)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (!threshold.comparable)
                        Text(
                          '${referenceScopeLabel(threshold.scope, s)}${threshold.rangeEnd != null ? ' · ${s.referencePublishedRange}' : ''}. ${s.referenceAssessmentUnavailable}',
                        ),
                    ],
                  ),
                ),
              Text(
                state,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              if (range.unavailable != null)
                Text(referenceUnavailableLabel(range.unavailable, s)),
              if (u == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.referenceNoUpper),
                ),
              if (range.reference != null) ...[
                const Divider(),
                Text(
                  '${range.reference!.source.name} · ${range.reference!.edition}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (range.frozen)
                  Text(
                    '${s.referenceFrozen}: ${range.frozenOn?.toIso8601String().split('T').first ?? '—'}',
                  ),
                for (final reference in range.reference!.values.where(
                  (r) => r != range.adequacy && r != range.upper,
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${referenceAmountLabel(reference, s)} · ${referenceScopeLabel(reference.scope, s)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('nutrient-reference-sources'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  SourcesScreen(referenceRegion: range.reference?.region),
            ),
          ),
          child: Text(s.settingsSourcesLabel),
        ),
        TextButton(
          key: const ValueKey('nutrient-reference-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(s.nutrientClose),
        ),
      ],
    );
  }
}

class _ReferenceRangePainter extends CustomPainter {
  final double? adequacy, upper, intake;
  final Color line, intakeColor;
  final String? adequacyLabel, upperLabel;
  final double textScale;
  final TextDirection textDirection;
  const _ReferenceRangePainter({
    this.adequacy,
    this.upper,
    this.intake,
    required this.line,
    required this.intakeColor,
    this.adequacyLabel,
    this.upperLabel,
    this.textScale = 1,
    this.textDirection = TextDirection.ltr,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue =
        [adequacy, upper, intake, 1.0].nonNulls.reduce(math.max) * 1.15;
    double x(double value) =>
        12 + (size.width - 24) * (value / maxValue).clamp(0, 1);
    const y = 42.0;
    canvas.drawLine(
      Offset(12, y),
      Offset(size.width - 12, y),
      Paint()
        ..color = line
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    if (adequacy != null && upper != null && upper! >= adequacy!) {
      canvas.drawLine(
        Offset(x(adequacy!), y),
        Offset(x(upper!), y),
        Paint()
          ..color = Colors.green
          ..strokeWidth = 10,
      );
    }
    for (final value in [adequacy, upper].nonNulls) {
      canvas.drawLine(
        Offset(x(value), y - 12),
        Offset(x(value), y + 12),
        Paint()
          ..color = line
          ..strokeWidth = 2,
      );
    }
    void label(String? label, double? value, double y) {
      if (label == null || value == null) return;
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 12 * textScale, color: line),
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width - 24);
      text.paint(
        canvas,
        Offset(
          (x(value) - text.width / 2).clamp(0, size.width - text.width),
          y,
        ),
      );
    }

    label(adequacyLabel, adequacy, 58);
    label(upperLabel, upper, 58 + 14 * textScale);
    if (intake != null) {
      final px = x(intake!);
      final arrow = Path()
        ..moveTo(px - 6, y - 26)
        ..lineTo(px + 6, y - 26)
        ..lineTo(px, y - 16)
        ..close();
      canvas.drawPath(arrow, Paint()..color = intakeColor);
      canvas.drawLine(
        Offset(px, y - 38),
        Offset(px, y - 26),
        Paint()
          ..color = intakeColor
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceRangePainter old) =>
      old.adequacy != adequacy ||
      old.upper != upper ||
      old.intake != intake ||
      old.line != line ||
      old.intakeColor != intakeColor ||
      old.adequacyLabel != adequacyLabel ||
      old.upperLabel != upperLabel ||
      old.textScale != textScale ||
      old.textDirection != textDirection;
}
