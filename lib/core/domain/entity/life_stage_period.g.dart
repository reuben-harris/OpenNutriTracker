// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'life_stage_period.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LifeStagePeriodAdapter extends TypeAdapter<LifeStagePeriod> {
  @override
  final typeId = 28;

  @override
  LifeStagePeriod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LifeStagePeriod(
      stage: fields[0] as LifeStage,
      start: fields[1] as DateTime,
      end: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LifeStagePeriod obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.stage)
      ..writeByte(1)
      ..write(obj.start)
      ..writeByte(2)
      ..write(obj.end);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LifeStagePeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LifeStageAdapter extends TypeAdapter<LifeStage> {
  @override
  final typeId = 29;

  @override
  LifeStage read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LifeStage.pregnancy;
      case 1:
        return LifeStage.breastfeeding;
      default:
        return LifeStage.pregnancy;
    }
  }

  @override
  void write(BinaryWriter writer, LifeStage obj) {
    switch (obj) {
      case LifeStage.pregnancy:
        writer.writeByte(0);
      case LifeStage.breastfeeding:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LifeStageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LifeStagePeriod _$LifeStagePeriodFromJson(Map<String, dynamic> json) =>
    LifeStagePeriod(
      stage: $enumDecode(_$LifeStageEnumMap, json['stage']),
      start: DateTime.parse(json['start'] as String),
      end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
    );

Map<String, dynamic> _$LifeStagePeriodToJson(LifeStagePeriod instance) =>
    <String, dynamic>{
      'stage': _$LifeStageEnumMap[instance.stage]!,
      'start': instance.start.toIso8601String(),
      'end': instance.end?.toIso8601String(),
    };

const _$LifeStageEnumMap = {
  LifeStage.pregnancy: 'pregnancy',
  LifeStage.breastfeeding: 'breastfeeding',
};
