// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrient_amount.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NutrientAmountAdapter extends TypeAdapter<NutrientAmount> {
  @override
  final typeId = 24;

  @override
  NutrientAmount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutrientAmount(
      (fields[0] as num).toDouble(),
      qualification: fields[1] == null
          ? NutrientQualification.none
          : fields[1] as NutrientQualification,
      limit: (fields[2] as num?)?.toDouble(),
      isPartial: fields[3] == null ? false : fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NutrientAmount obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.value)
      ..writeByte(1)
      ..write(obj.qualification)
      ..writeByte(2)
      ..write(obj.limit)
      ..writeByte(3)
      ..write(obj.isPartial);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutrientAmountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NutrientQualificationAdapter extends TypeAdapter<NutrientQualification> {
  @override
  final typeId = 25;

  @override
  NutrientQualification read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NutrientQualification.none;
      case 1:
        return NutrientQualification.trace;
      case 2:
        return NutrientQualification.lessThan;
      case 3:
        return NutrientQualification.lessThanOrEqual;
      case 4:
        return NutrientQualification.greaterThan;
      case 5:
        return NutrientQualification.greaterThanOrEqual;
      case 6:
        return NutrientQualification.approximate;
      case 7:
        return NutrientQualification.belowDetection;
      case 8:
        return NutrientQualification.belowQuantification;
      case 9:
        return NutrientQualification.belowDetectionOrQuantification;
      case 10:
        return NutrientQualification.aggregate;
      default:
        return NutrientQualification.none;
    }
  }

  @override
  void write(BinaryWriter writer, NutrientQualification obj) {
    switch (obj) {
      case NutrientQualification.none:
        writer.writeByte(0);
      case NutrientQualification.trace:
        writer.writeByte(1);
      case NutrientQualification.lessThan:
        writer.writeByte(2);
      case NutrientQualification.lessThanOrEqual:
        writer.writeByte(3);
      case NutrientQualification.greaterThan:
        writer.writeByte(4);
      case NutrientQualification.greaterThanOrEqual:
        writer.writeByte(5);
      case NutrientQualification.approximate:
        writer.writeByte(6);
      case NutrientQualification.belowDetection:
        writer.writeByte(7);
      case NutrientQualification.belowQuantification:
        writer.writeByte(8);
      case NutrientQualification.belowDetectionOrQuantification:
        writer.writeByte(9);
      case NutrientQualification.aggregate:
        writer.writeByte(10);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutrientQualificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
