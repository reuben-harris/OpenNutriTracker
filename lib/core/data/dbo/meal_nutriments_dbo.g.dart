// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_nutriments_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealNutrimentsDBOAdapter extends TypeAdapter<MealNutrimentsDBO> {
  @override
  final typeId = 3;

  @override
  MealNutrimentsDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealNutrimentsDBO(
      energyKcal100: fields[0] as NutrientAmount?,
      carbohydrates100: fields[1] as NutrientAmount?,
      fat100: fields[2] as NutrientAmount?,
      proteins100: fields[3] as NutrientAmount?,
      sugars100: fields[4] as NutrientAmount?,
      saturatedFat100: fields[5] as NutrientAmount?,
      fiber100: fields[6] as NutrientAmount?,
      monounsaturatedFat100: fields[7] as NutrientAmount?,
      polyunsaturatedFat100: fields[8] as NutrientAmount?,
      transFat100: fields[9] as NutrientAmount?,
      cholesterol100: fields[10] as NutrientAmount?,
      sodium100: fields[11] as NutrientAmount?,
      potassium100: fields[12] as NutrientAmount?,
      magnesium100: fields[13] as NutrientAmount?,
      calcium100: fields[14] as NutrientAmount?,
      iron100: fields[15] as NutrientAmount?,
      zinc100: fields[16] as NutrientAmount?,
      phosphorus100: fields[17] as NutrientAmount?,
      vitaminA100: fields[18] as NutrientAmount?,
      vitaminC100: fields[19] as NutrientAmount?,
      vitaminD100: fields[20] as NutrientAmount?,
      vitaminB6100: fields[21] as NutrientAmount?,
      vitaminB12100: fields[22] as NutrientAmount?,
      niacin100: fields[23] as NutrientAmount?,
    );
  }

  @override
  void write(BinaryWriter writer, MealNutrimentsDBO obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.energyKcal100)
      ..writeByte(1)
      ..write(obj.carbohydrates100)
      ..writeByte(2)
      ..write(obj.fat100)
      ..writeByte(3)
      ..write(obj.proteins100)
      ..writeByte(4)
      ..write(obj.sugars100)
      ..writeByte(5)
      ..write(obj.saturatedFat100)
      ..writeByte(6)
      ..write(obj.fiber100)
      ..writeByte(7)
      ..write(obj.monounsaturatedFat100)
      ..writeByte(8)
      ..write(obj.polyunsaturatedFat100)
      ..writeByte(9)
      ..write(obj.transFat100)
      ..writeByte(10)
      ..write(obj.cholesterol100)
      ..writeByte(11)
      ..write(obj.sodium100)
      ..writeByte(12)
      ..write(obj.potassium100)
      ..writeByte(13)
      ..write(obj.magnesium100)
      ..writeByte(14)
      ..write(obj.calcium100)
      ..writeByte(15)
      ..write(obj.iron100)
      ..writeByte(16)
      ..write(obj.zinc100)
      ..writeByte(17)
      ..write(obj.phosphorus100)
      ..writeByte(18)
      ..write(obj.vitaminA100)
      ..writeByte(19)
      ..write(obj.vitaminC100)
      ..writeByte(20)
      ..write(obj.vitaminD100)
      ..writeByte(21)
      ..write(obj.vitaminB6100)
      ..writeByte(22)
      ..write(obj.vitaminB12100)
      ..writeByte(23)
      ..write(obj.niacin100);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealNutrimentsDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealNutrimentsDBO _$MealNutrimentsDBOFromJson(
  Map<String, dynamic> json,
) => MealNutrimentsDBO(
  energyKcal100: json['energyKcal100'] == null
      ? null
      : NutrientAmount.fromJson(json['energyKcal100'] as Map<String, dynamic>),
  carbohydrates100: json['carbohydrates100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['carbohydrates100'] as Map<String, dynamic>,
        ),
  fat100: json['fat100'] == null
      ? null
      : NutrientAmount.fromJson(json['fat100'] as Map<String, dynamic>),
  proteins100: json['proteins100'] == null
      ? null
      : NutrientAmount.fromJson(json['proteins100'] as Map<String, dynamic>),
  sugars100: json['sugars100'] == null
      ? null
      : NutrientAmount.fromJson(json['sugars100'] as Map<String, dynamic>),
  saturatedFat100: json['saturatedFat100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['saturatedFat100'] as Map<String, dynamic>,
        ),
  fiber100: json['fiber100'] == null
      ? null
      : NutrientAmount.fromJson(json['fiber100'] as Map<String, dynamic>),
  monounsaturatedFat100: json['monounsaturatedFat100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['monounsaturatedFat100'] as Map<String, dynamic>,
        ),
  polyunsaturatedFat100: json['polyunsaturatedFat100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['polyunsaturatedFat100'] as Map<String, dynamic>,
        ),
  transFat100: json['transFat100'] == null
      ? null
      : NutrientAmount.fromJson(json['transFat100'] as Map<String, dynamic>),
  cholesterol100: json['cholesterol100'] == null
      ? null
      : NutrientAmount.fromJson(json['cholesterol100'] as Map<String, dynamic>),
  sodium100: json['sodium100'] == null
      ? null
      : NutrientAmount.fromJson(json['sodium100'] as Map<String, dynamic>),
  potassium100: json['potassium100'] == null
      ? null
      : NutrientAmount.fromJson(json['potassium100'] as Map<String, dynamic>),
  magnesium100: json['magnesium100'] == null
      ? null
      : NutrientAmount.fromJson(json['magnesium100'] as Map<String, dynamic>),
  calcium100: json['calcium100'] == null
      ? null
      : NutrientAmount.fromJson(json['calcium100'] as Map<String, dynamic>),
  iron100: json['iron100'] == null
      ? null
      : NutrientAmount.fromJson(json['iron100'] as Map<String, dynamic>),
  zinc100: json['zinc100'] == null
      ? null
      : NutrientAmount.fromJson(json['zinc100'] as Map<String, dynamic>),
  phosphorus100: json['phosphorus100'] == null
      ? null
      : NutrientAmount.fromJson(json['phosphorus100'] as Map<String, dynamic>),
  vitaminA100: json['vitaminA100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminA100'] as Map<String, dynamic>),
  vitaminC100: json['vitaminC100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminC100'] as Map<String, dynamic>),
  vitaminD100: json['vitaminD100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminD100'] as Map<String, dynamic>),
  vitaminB6100: json['vitaminB6100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminB6100'] as Map<String, dynamic>),
  vitaminB12100: json['vitaminB12100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminB12100'] as Map<String, dynamic>),
  niacin100: json['niacin100'] == null
      ? null
      : NutrientAmount.fromJson(json['niacin100'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MealNutrimentsDBOToJson(MealNutrimentsDBO instance) =>
    <String, dynamic>{
      'energyKcal100': instance.energyKcal100,
      'carbohydrates100': instance.carbohydrates100,
      'fat100': instance.fat100,
      'proteins100': instance.proteins100,
      'sugars100': instance.sugars100,
      'saturatedFat100': instance.saturatedFat100,
      'fiber100': instance.fiber100,
      'monounsaturatedFat100': instance.monounsaturatedFat100,
      'polyunsaturatedFat100': instance.polyunsaturatedFat100,
      'transFat100': instance.transFat100,
      'cholesterol100': instance.cholesterol100,
      'sodium100': instance.sodium100,
      'potassium100': instance.potassium100,
      'magnesium100': instance.magnesium100,
      'calcium100': instance.calcium100,
      'iron100': instance.iron100,
      'zinc100': instance.zinc100,
      'phosphorus100': instance.phosphorus100,
      'vitaminA100': instance.vitaminA100,
      'vitaminC100': instance.vitaminC100,
      'vitaminD100': instance.vitaminD100,
      'vitaminB6100': instance.vitaminB6100,
      'vitaminB12100': instance.vitaminB12100,
      'niacin100': instance.niacin100,
    };
