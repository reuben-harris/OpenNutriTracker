// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrient_policy.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NutrientPolicyAdapter extends TypeAdapter<NutrientPolicy> {
  @override
  final typeId = 30;

  @override
  NutrientPolicy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutrientPolicy(
      source: fields[0] == null ? 'usCanada' : fields[0] as String,
      autoAdjust: fields[1] == null ? true : fields[1] as bool,
      adequacyMode: fields[2] == null
          ? ThresholdMode.reference
          : fields[2] as ThresholdMode,
      upperMode: fields[3] == null
          ? ThresholdMode.reference
          : fields[3] as ThresholdMode,
      target: (fields[4] as num?)?.toDouble(),
      upper: (fields[5] as num?)?.toDouble(),
      frozenReference: (fields[6] as Map?)?.cast<String, dynamic>(),
      frozenOn: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, NutrientPolicy obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.source)
      ..writeByte(1)
      ..write(obj.autoAdjust)
      ..writeByte(2)
      ..write(obj.adequacyMode)
      ..writeByte(3)
      ..write(obj.upperMode)
      ..writeByte(4)
      ..write(obj.target)
      ..writeByte(5)
      ..write(obj.upper)
      ..writeByte(6)
      ..write(obj.frozenReference)
      ..writeByte(7)
      ..write(obj.frozenOn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutrientPolicyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThresholdModeAdapter extends TypeAdapter<ThresholdMode> {
  @override
  final typeId = 31;

  @override
  ThresholdMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ThresholdMode.reference;
      case 1:
        return ThresholdMode.custom;
      case 2:
        return ThresholdMode.unset;
      default:
        return ThresholdMode.reference;
    }
  }

  @override
  void write(BinaryWriter writer, ThresholdMode obj) {
    switch (obj) {
      case ThresholdMode.reference:
        writer.writeByte(0);
      case ThresholdMode.custom:
        writer.writeByte(1);
      case ThresholdMode.unset:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThresholdModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NutrientPolicy _$NutrientPolicyFromJson(Map<String, dynamic> json) =>
    NutrientPolicy(
      source: json['source'] as String? ?? 'usCanada',
      autoAdjust: json['autoAdjust'] as bool? ?? true,
      adequacyMode:
          $enumDecodeNullable(_$ThresholdModeEnumMap, json['adequacyMode']) ??
          ThresholdMode.reference,
      upperMode:
          $enumDecodeNullable(_$ThresholdModeEnumMap, json['upperMode']) ??
          ThresholdMode.reference,
      target: (json['target'] as num?)?.toDouble(),
      upper: (json['upper'] as num?)?.toDouble(),
      frozenReference: json['frozenReference'] as Map<String, dynamic>?,
      frozenOn: json['frozenOn'] == null
          ? null
          : DateTime.parse(json['frozenOn'] as String),
    );

Map<String, dynamic> _$NutrientPolicyToJson(NutrientPolicy instance) =>
    <String, dynamic>{
      'source': instance.source,
      'autoAdjust': instance.autoAdjust,
      'adequacyMode': _$ThresholdModeEnumMap[instance.adequacyMode]!,
      'upperMode': _$ThresholdModeEnumMap[instance.upperMode]!,
      'target': instance.target,
      'upper': instance.upper,
      'frozenReference': instance.frozenReference,
      'frozenOn': instance.frozenOn?.toIso8601String(),
    };

const _$ThresholdModeEnumMap = {
  ThresholdMode.reference: 'reference',
  ThresholdMode.custom: 'custom',
  ThresholdMode.unset: 'unset',
};
