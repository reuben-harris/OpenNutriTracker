import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'nutrient_amount.g.dart';

/// Source qualification is independent of the numeric contribution to totals.
@HiveType(typeId: 25)
enum NutrientQualification {
  @HiveField(0)
  none,
  @HiveField(1)
  trace,
  @HiveField(2)
  lessThan,
  @HiveField(3)
  lessThanOrEqual,
  @HiveField(4)
  greaterThan,
  @HiveField(5)
  greaterThanOrEqual,
  @HiveField(6)
  approximate,
  @HiveField(7)
  belowDetection,
  @HiveField(8)
  belowQuantification,
  @HiveField(9)
  belowDetectionOrQuantification,
  @HiveField(10)
  aggregate,
}

@HiveType(typeId: 24)
class NutrientAmount extends Equatable {
  @HiveField(0)
  final double value;
  @HiveField(1)
  final NutrientQualification qualification;

  /// A reported threshold, in the same units as [value]. Never inferred.
  @HiveField(2)
  final double? limit;

  @HiveField(3)
  final bool isPartial;

  const NutrientAmount(
    this.value, {
    this.qualification = NutrientQualification.none,
    this.limit,
    this.isPartial = false,
  });

  bool get isQualified => qualification != NutrientQualification.none;
  double get calculationValue =>
      qualification == NutrientQualification.trace ? 0 : value;
  bool get isFinite => value.isFinite && (limit?.isFinite ?? true);

  NutrientAmount scale(num factor) => NutrientAmount(
    calculationValue * factor,
    qualification: qualification,
    isPartial: isPartial,
    limit: limit == null ? null : limit! * factor,
  );

  static NutrientAmount? fromNumber(num? value) =>
      value == null || !value.isFinite
      ? null
      : NutrientAmount(value.toDouble());

  factory NutrientAmount.fromJson(Map<String, dynamic> json) => NutrientAmount(
    (json['value'] as num).toDouble(),
    qualification: NutrientQualification.values.byName(
      json['qualification'] as String,
    ),
    limit: (json['limit'] as num?)?.toDouble(),
    isPartial: json['isPartial'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'value': value,
    'qualification': qualification.name,
    'limit': limit,
    'isPartial': isPartial,
  };

  /// Catalogue decimals retain their original spelling until this boundary.
  static NutrientAmount? fromSource(Object? raw, {String? modifier}) {
    if (raw is Map) {
      final amount = NutrientAmount.fromJson({
        ...Map<String, dynamic>.from(raw),
        'value': double.parse(raw['value'].toString()),
        'limit': raw['limit'] == null
            ? null
            : double.parse(raw['limit'].toString()),
      });
      return amount.isFinite ? amount : null;
    }
    final text = raw?.toString().trim() ?? '';
    final match = RegExp(
      r'^(<=|>=|≤|≥|<|>|~|≈)?\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)$',
    ).firstMatch(text);
    final mark = modifier?.trim().toLowerCase() ?? match?.group(1) ?? '';
    if (mark == 'trace' || text.toLowerCase() == 'trace' || mark == 'tr') {
      return const NutrientAmount(
        0,
        qualification: NutrientQualification.trace,
      );
    }
    if (match == null) return null;
    final value = double.parse(match.group(2)!);
    if (!value.isFinite) return null;
    final qualification = switch (mark) {
      '<' => NutrientQualification.lessThan,
      '<=' || '≤' => NutrientQualification.lessThanOrEqual,
      '>' => NutrientQualification.greaterThan,
      '>=' || '≥' => NutrientQualification.greaterThanOrEqual,
      '~' || '≈' => NutrientQualification.approximate,
      _ => NutrientQualification.none,
    };
    return NutrientAmount(value, qualification: qualification);
  }

  @override
  List<Object?> get props => [value, qualification, limit, isPartial];
}

/// Never combines mathematical bounds. Qualified inputs qualify the sum.
class NutrientAccumulator {
  double _value = 0;
  bool _present = false;
  bool _partial = false;
  bool _qualified = false;
  bool _trace = false;
  bool _onlyTraceAndZero = true;

  void add(NutrientAmount? amount, {double scale = 1}) {
    if (scale == 0) return;
    if (amount == null) {
      _partial = true;
      return;
    }
    _partial |= amount.isPartial;
    _present = true;
    _value += amount.calculationValue * scale;
    _qualified |= amount.isQualified;
    _trace |= amount.qualification == NutrientQualification.trace;
    _onlyTraceAndZero &=
        amount.qualification == NutrientQualification.trace ||
        (!amount.isQualified && amount.value == 0);
  }

  NutrientAmount? get total => !_present
      ? null
      : NutrientAmount(
          _value,
          isPartial: _partial,
          qualification: _trace && _onlyTraceAndZero
              ? NutrientQualification.trace
              : _qualified
              ? NutrientQualification.aggregate
              : NutrientQualification.none,
        );
}
