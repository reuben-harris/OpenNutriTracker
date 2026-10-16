// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_ingredient_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeIngredientDBOAdapter extends TypeAdapter<RecipeIngredientDBO> {
  @override
  final typeId = 17;

  @override
  RecipeIngredientDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeIngredientDBO(
      snapshotMeal: fields[0] as MealDBO,
      quantityAmount: (fields[4] as num).toDouble(),
      quantityUnit: fields[5] as String,
      quantityBaseUnit: fields[6] as String,
      quantityUnitFactor: (fields[7] as num).toDouble(),
      quantityUnitLabel: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeIngredientDBO obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.snapshotMeal)
      ..writeByte(4)
      ..write(obj.quantityAmount)
      ..writeByte(5)
      ..write(obj.quantityUnit)
      ..writeByte(6)
      ..write(obj.quantityBaseUnit)
      ..writeByte(7)
      ..write(obj.quantityUnitFactor)
      ..writeByte(8)
      ..write(obj.quantityUnitLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredientDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecipeIngredientDBO _$RecipeIngredientDBOFromJson(Map<String, dynamic> json) =>
    RecipeIngredientDBO(
      snapshotMeal: MealDBO.fromJson(
        json['snapshotMeal'] as Map<String, dynamic>,
      ),
      quantityAmount: (json['quantityAmount'] as num).toDouble(),
      quantityUnit: json['quantityUnit'] as String,
      quantityBaseUnit: json['quantityBaseUnit'] as String,
      quantityUnitFactor: (json['quantityUnitFactor'] as num).toDouble(),
      quantityUnitLabel: json['quantityUnitLabel'] as String?,
    );

Map<String, dynamic> _$RecipeIngredientDBOToJson(
  RecipeIngredientDBO instance,
) => <String, dynamic>{
  'snapshotMeal': instance.snapshotMeal,
  'quantityAmount': instance.quantityAmount,
  'quantityUnit': instance.quantityUnit,
  'quantityBaseUnit': instance.quantityBaseUnit,
  'quantityUnitFactor': instance.quantityUnitFactor,
  'quantityUnitLabel': instance.quantityUnitLabel,
};
