import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';

part 'nutrient_policy.g.dart';

@HiveType(typeId: 31)
enum ThresholdMode {
  @HiveField(0)
  reference,
  @HiveField(1)
  custom,
  @HiveField(2)
  unset,
}

@HiveType(typeId: 30)
@JsonSerializable()
class NutrientPolicy extends Equatable {
  @HiveField(0)
  final String source;
  @HiveField(1)
  final bool autoAdjust;
  @HiveField(2)
  final ThresholdMode adequacyMode;
  @HiveField(3)
  final ThresholdMode upperMode;
  @HiveField(4)
  final double? target;
  @HiveField(5)
  final double? upper;
  @HiveField(6)
  final Map<String, dynamic>? frozenReference;
  @HiveField(7)
  final DateTime? frozenOn;
  const NutrientPolicy({
    this.source = 'usCanada',
    this.autoAdjust = true,
    this.adequacyMode = ThresholdMode.reference,
    this.upperMode = ThresholdMode.reference,
    this.target,
    this.upper,
    this.frozenReference,
    this.frozenOn,
  });
  ReferenceRegion get region => ReferenceRegion.values.byName(source);
  bool get valid =>
      ReferenceRegion.values.any((r) => r.name == source) &&
      (adequacyMode != ThresholdMode.custom ||
          target != null && target!.isFinite && target! > 0) &&
      (upperMode != ThresholdMode.custom ||
          upper != null && upper!.isFinite && upper! >= 0) &&
      !(adequacyMode == ThresholdMode.custom &&
          upperMode == ThresholdMode.custom &&
          target != null &&
          upper != null &&
          target! > upper!);
  NutrientPolicy copyWith({
    ReferenceRegion? region,
    bool? autoAdjust,
    ThresholdMode? adequacyMode,
    ThresholdMode? upperMode,
    double? target,
    double? upper,
    ReferenceSelection? frozen,
    DateTime? frozenOn,
  }) => NutrientPolicy(
    source: region?.name ?? source,
    autoAdjust: autoAdjust ?? this.autoAdjust,
    adequacyMode: adequacyMode ?? this.adequacyMode,
    upperMode: upperMode ?? this.upperMode,
    target: target ?? this.target,
    upper: upper ?? this.upper,
    frozenReference: frozen?.toJson() ?? frozenReference,
    frozenOn: frozenOn ?? this.frozenOn,
  );
  factory NutrientPolicy.fromJson(Map<String, dynamic> json) =>
      _$NutrientPolicyFromJson(json);
  Map<String, dynamic> toJson() => _$NutrientPolicyToJson(this);
  @override
  List<Object?> get props => [
    source,
    autoAdjust,
    adequacyMode,
    upperMode,
    target,
    upper,
    frozenReference,
    frozenOn,
  ];
}
