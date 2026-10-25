// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_portion_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealPortionDBOAdapter extends TypeAdapter<MealPortionDBO> {
  @override
  final typeId = 23;

  @override
  MealPortionDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPortionDBO(
      id: fields[0] as String,
      label: fields[1] as String,
      gramWeight: (fields[3] as num).toDouble(),
      localized: fields[4] as bool,
      englishLabel: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealPortionDBO obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.englishLabel)
      ..writeByte(3)
      ..write(obj.gramWeight)
      ..writeByte(4)
      ..write(obj.localized);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPortionDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealPortionDBO _$MealPortionDBOFromJson(Map<String, dynamic> json) =>
    MealPortionDBO(
      id: json['id'] as String,
      label: json['label'] as String,
      gramWeight: (json['gramWeight'] as num).toDouble(),
      localized: json['localized'] as bool,
      englishLabel: json['englishLabel'] as String?,
    );

Map<String, dynamic> _$MealPortionDBOToJson(MealPortionDBO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'englishLabel': instance.englishLabel,
      'gramWeight': instance.gramWeight,
      'localized': instance.localized,
    };
