// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'height_reading.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HeightReadingAdapter extends TypeAdapter<HeightReading> {
  @override
  final typeId = 27;

  @override
  HeightReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeightReading(
      date: fields[0] as DateTime,
      centimetres: (fields[1] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, HeightReading obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.centimetres);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeightReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HeightReading _$HeightReadingFromJson(Map<String, dynamic> json) =>
    HeightReading(
      date: DateTime.parse(json['date'] as String),
      centimetres: (json['centimetres'] as num).toDouble(),
    );

Map<String, dynamic> _$HeightReadingToJson(HeightReading instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'centimetres': instance.centimetres,
    };
