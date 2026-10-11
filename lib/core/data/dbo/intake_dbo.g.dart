// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intake_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IntakeDBOAdapter extends TypeAdapter<IntakeDBO> {
  @override
  final typeId = 0;

  @override
  IntakeDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IntakeDBO(
      id: fields[0] as String,
      type: fields[3] as IntakeTypeDBO,
      meal: fields[4] as MealDBO,
      dateTime: fields[5] as DateTime,
      quantityAmount: (fields[8] as num?)?.toDouble(),
      quantityUnit: fields[9] as String?,
      quantityBaseUnit: fields[10] as String?,
      quantityUnitFactor: (fields[11] as num?)?.toDouble(),
      quantityUnitLabel: fields[12] as String?,
      recipeSnapshot: fields[6] as RecipeDBO?,
      conversionParentId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IntakeDBO obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.meal)
      ..writeByte(5)
      ..write(obj.dateTime)
      ..writeByte(6)
      ..write(obj.recipeSnapshot)
      ..writeByte(7)
      ..write(obj.conversionParentId)
      ..writeByte(8)
      ..write(obj.quantityAmount)
      ..writeByte(9)
      ..write(obj.quantityUnit)
      ..writeByte(10)
      ..write(obj.quantityBaseUnit)
      ..writeByte(11)
      ..write(obj.quantityUnitFactor)
      ..writeByte(12)
      ..write(obj.quantityUnitLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntakeDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IntakeDBO _$IntakeDBOFromJson(Map<String, dynamic> json) => IntakeDBO(
  id: json['id'] as String,
  type: $enumDecode(_$IntakeTypeDBOEnumMap, json['type']),
  meal: MealDBO.fromJson(json['meal'] as Map<String, dynamic>),
  dateTime: DateTime.parse(json['dateTime'] as String),
  quantityAmount: (json['quantityAmount'] as num?)?.toDouble(),
  quantityUnit: json['quantityUnit'] as String?,
  quantityBaseUnit: json['quantityBaseUnit'] as String?,
  quantityUnitFactor: (json['quantityUnitFactor'] as num?)?.toDouble(),
  quantityUnitLabel: json['quantityUnitLabel'] as String?,
  recipeSnapshot: json['recipeSnapshot'] == null
      ? null
      : RecipeDBO.fromJson(json['recipeSnapshot'] as Map<String, dynamic>),
  conversionParentId: json['conversionParentId'] as String?,
);

Map<String, dynamic> _$IntakeDBOToJson(IntakeDBO instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$IntakeTypeDBOEnumMap[instance.type]!,
  'meal': instance.meal,
  'dateTime': instance.dateTime.toIso8601String(),
  'recipeSnapshot': instance.recipeSnapshot,
  'conversionParentId': instance.conversionParentId,
  'quantityAmount': instance.quantityAmount,
  'quantityUnit': instance.quantityUnit,
  'quantityBaseUnit': instance.quantityBaseUnit,
  'quantityUnitFactor': instance.quantityUnitFactor,
  'quantityUnitLabel': instance.quantityUnitLabel,
};

const _$IntakeTypeDBOEnumMap = {
  IntakeTypeDBO.breakfast: 'breakfast',
  IntakeTypeDBO.lunch: 'lunch',
  IntakeTypeDBO.dinner: 'dinner',
  IntakeTypeDBO.snack: 'snack',
};
