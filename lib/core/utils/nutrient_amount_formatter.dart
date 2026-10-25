import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Shared precision policy: a known nonzero value must never display as zero.
String nutrientNumber(double value, {int decimals = 2}) {
  if (!value.isFinite) return '—';
  var precision = decimals;
  while (value != 0 &&
      double.parse(value.toStringAsFixed(precision)) == 0 &&
      precision < 12) {
    precision++;
  }
  if (value != 0 && double.parse(value.toStringAsFixed(precision)) == 0) {
    return value.toString();
  }
  return value.toStringAsFixed(precision);
}

String formatNutrientAmount(
  NutrientAmount? amount,
  S s, {
  String unit = '',
  int decimals = 2,
  bool trimTrailingZeros = false,
}) {
  if (amount == null) return s.nutritionNoDataLabel;
  final q = amount.qualification;
  if (q == NutrientQualification.trace) return '${s.nutrientTraceLabel}*';
  final prefix = switch (q) {
    NutrientQualification.lessThan ||
    NutrientQualification.belowDetection ||
    NutrientQualification.belowQuantification ||
    NutrientQualification.belowDetectionOrQuantification => '<',
    NutrientQualification.lessThanOrEqual => '≤',
    NutrientQualification.greaterThan => '>',
    NutrientQualification.greaterThanOrEqual => '≥',
    NutrientQualification.approximate => '≈',
    _ => '',
  };
  final special = switch (q) {
    NutrientQualification.belowDetection => s.nutrientBelowDetectionLabel,
    NutrientQualification.belowQuantification =>
      s.nutrientBelowQuantificationLabel,
    NutrientQualification.belowDetectionOrQuantification =>
      s.nutrientBelowDetectionOrQuantificationLabel,
    _ => null,
  };
  if (special != null && amount.limit == null) return '$special*';
  final value = amount.limit ?? amount.value;
  if (q == NutrientQualification.approximate && value == 0) return '≈0*';
  var number = q == NutrientQualification.approximate && value == 0
      ? '0'
      : nutrientNumber(value, decimals: decimals);
  if ((trimTrailingZeros || amount.isQualified) &&
      number.contains('.') &&
      !number.contains('e')) {
    number = number
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return '$prefix$number${unit.isEmpty ? '' : ' $unit'}${amount.isQualified ? '*' : ''}';
}

String nutrientQualificationLabel(NutrientAmount? amount, S s) =>
    switch (amount?.qualification) {
      null || NutrientQualification.none => '',
      NutrientQualification.trace => s.nutrientTraceLabel,
      NutrientQualification.lessThan => s.nutrientLessThanLabel,
      NutrientQualification.lessThanOrEqual => s.nutrientAtMostLabel,
      NutrientQualification.greaterThan => s.nutrientGreaterThanLabel,
      NutrientQualification.greaterThanOrEqual => s.nutrientAtLeastLabel,
      NutrientQualification.approximate => s.nutrientApproximateLabel,
      NutrientQualification.belowDetection => s.nutrientBelowDetectionLabel,
      NutrientQualification.belowQuantification =>
        s.nutrientBelowQuantificationLabel,
      NutrientQualification.belowDetectionOrQuantification =>
        s.nutrientBelowDetectionOrQuantificationLabel,
      NutrientQualification.aggregate => s.nutrientQualifiedTotalLabel,
    };

String formatNutrientPercentage(NutrientAmount? amount, double? goal) {
  if (amount == null || goal == null || !goal.isFinite || goal <= 0) return '—';
  return '${nutrientNumber(amount.calculationValue / goal * 100, decimals: 0)}%${amount.isQualified ? '*' : ''}';
}
