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
      thiamin100: fields[24] as NutrientAmount?,
      riboflavin100: fields[25] as NutrientAmount?,
      pantothenicAcid100: fields[26] as NutrientAmount?,
      biotin100: fields[27] as NutrientAmount?,
      folateDfe100: fields[28] as NutrientAmount?,
      vitaminE100: fields[29] as NutrientAmount?,
      vitaminK1100: fields[30] as NutrientAmount?,
      copper100: fields[31] as NutrientAmount?,
      manganese100: fields[32] as NutrientAmount?,
      selenium100: fields[33] as NutrientAmount?,
      iodine100: fields[34] as NutrientAmount?,
      choline100: fields[35] as NutrientAmount?,
      omega3100: fields[36] as NutrientAmount?,
      alphaLinolenicAcid100: fields[37] as NutrientAmount?,
      epa100: fields[38] as NutrientAmount?,
      dha100: fields[39] as NutrientAmount?,
      omega6100: fields[40] as NutrientAmount?,
      linoleicAcid100: fields[41] as NutrientAmount?,
      addedSugars100: fields[42] as NutrientAmount?,
      starch100: fields[43] as NutrientAmount?,
      caffeine100: fields[44] as NutrientAmount?,
      alcohol100: fields[45] as NutrientAmount?,
      histidine100: fields[46] as NutrientAmount?,
      isoleucine100: fields[47] as NutrientAmount?,
      leucine100: fields[48] as NutrientAmount?,
      lysine100: fields[49] as NutrientAmount?,
      methionine100: fields[50] as NutrientAmount?,
      phenylalanine100: fields[51] as NutrientAmount?,
      threonine100: fields[52] as NutrientAmount?,
      tryptophan100: fields[53] as NutrientAmount?,
      valine100: fields[54] as NutrientAmount?,
      alanine100: fields[55] as NutrientAmount?,
      arginine100: fields[56] as NutrientAmount?,
      asparagine100: fields[57] as NutrientAmount?,
      asparticAcid100: fields[58] as NutrientAmount?,
      cysteine100: fields[59] as NutrientAmount?,
      cystine100: fields[60] as NutrientAmount?,
      glutamicAcid100: fields[61] as NutrientAmount?,
      glutamine100: fields[62] as NutrientAmount?,
      glycine100: fields[63] as NutrientAmount?,
      hydroxyproline100: fields[64] as NutrientAmount?,
      proline100: fields[65] as NutrientAmount?,
      serine100: fields[66] as NutrientAmount?,
      tyrosine100: fields[67] as NutrientAmount?,
    );
  }

  @override
  void write(BinaryWriter writer, MealNutrimentsDBO obj) {
    writer
      ..writeByte(68)
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
      ..write(obj.niacin100)
      ..writeByte(24)
      ..write(obj.thiamin100)
      ..writeByte(25)
      ..write(obj.riboflavin100)
      ..writeByte(26)
      ..write(obj.pantothenicAcid100)
      ..writeByte(27)
      ..write(obj.biotin100)
      ..writeByte(28)
      ..write(obj.folateDfe100)
      ..writeByte(29)
      ..write(obj.vitaminE100)
      ..writeByte(30)
      ..write(obj.vitaminK1100)
      ..writeByte(31)
      ..write(obj.copper100)
      ..writeByte(32)
      ..write(obj.manganese100)
      ..writeByte(33)
      ..write(obj.selenium100)
      ..writeByte(34)
      ..write(obj.iodine100)
      ..writeByte(35)
      ..write(obj.choline100)
      ..writeByte(36)
      ..write(obj.omega3100)
      ..writeByte(37)
      ..write(obj.alphaLinolenicAcid100)
      ..writeByte(38)
      ..write(obj.epa100)
      ..writeByte(39)
      ..write(obj.dha100)
      ..writeByte(40)
      ..write(obj.omega6100)
      ..writeByte(41)
      ..write(obj.linoleicAcid100)
      ..writeByte(42)
      ..write(obj.addedSugars100)
      ..writeByte(43)
      ..write(obj.starch100)
      ..writeByte(44)
      ..write(obj.caffeine100)
      ..writeByte(45)
      ..write(obj.alcohol100)
      ..writeByte(46)
      ..write(obj.histidine100)
      ..writeByte(47)
      ..write(obj.isoleucine100)
      ..writeByte(48)
      ..write(obj.leucine100)
      ..writeByte(49)
      ..write(obj.lysine100)
      ..writeByte(50)
      ..write(obj.methionine100)
      ..writeByte(51)
      ..write(obj.phenylalanine100)
      ..writeByte(52)
      ..write(obj.threonine100)
      ..writeByte(53)
      ..write(obj.tryptophan100)
      ..writeByte(54)
      ..write(obj.valine100)
      ..writeByte(55)
      ..write(obj.alanine100)
      ..writeByte(56)
      ..write(obj.arginine100)
      ..writeByte(57)
      ..write(obj.asparagine100)
      ..writeByte(58)
      ..write(obj.asparticAcid100)
      ..writeByte(59)
      ..write(obj.cysteine100)
      ..writeByte(60)
      ..write(obj.cystine100)
      ..writeByte(61)
      ..write(obj.glutamicAcid100)
      ..writeByte(62)
      ..write(obj.glutamine100)
      ..writeByte(63)
      ..write(obj.glycine100)
      ..writeByte(64)
      ..write(obj.hydroxyproline100)
      ..writeByte(65)
      ..write(obj.proline100)
      ..writeByte(66)
      ..write(obj.serine100)
      ..writeByte(67)
      ..write(obj.tyrosine100);
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
  thiamin100: json['thiamin100'] == null
      ? null
      : NutrientAmount.fromJson(json['thiamin100'] as Map<String, dynamic>),
  riboflavin100: json['riboflavin100'] == null
      ? null
      : NutrientAmount.fromJson(json['riboflavin100'] as Map<String, dynamic>),
  pantothenicAcid100: json['pantothenicAcid100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['pantothenicAcid100'] as Map<String, dynamic>,
        ),
  biotin100: json['biotin100'] == null
      ? null
      : NutrientAmount.fromJson(json['biotin100'] as Map<String, dynamic>),
  folateDfe100: json['folateDfe100'] == null
      ? null
      : NutrientAmount.fromJson(json['folateDfe100'] as Map<String, dynamic>),
  vitaminE100: json['vitaminE100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminE100'] as Map<String, dynamic>),
  vitaminK1100: json['vitaminK1100'] == null
      ? null
      : NutrientAmount.fromJson(json['vitaminK1100'] as Map<String, dynamic>),
  copper100: json['copper100'] == null
      ? null
      : NutrientAmount.fromJson(json['copper100'] as Map<String, dynamic>),
  manganese100: json['manganese100'] == null
      ? null
      : NutrientAmount.fromJson(json['manganese100'] as Map<String, dynamic>),
  selenium100: json['selenium100'] == null
      ? null
      : NutrientAmount.fromJson(json['selenium100'] as Map<String, dynamic>),
  iodine100: json['iodine100'] == null
      ? null
      : NutrientAmount.fromJson(json['iodine100'] as Map<String, dynamic>),
  choline100: json['choline100'] == null
      ? null
      : NutrientAmount.fromJson(json['choline100'] as Map<String, dynamic>),
  omega3100: json['omega3100'] == null
      ? null
      : NutrientAmount.fromJson(json['omega3100'] as Map<String, dynamic>),
  alphaLinolenicAcid100: json['alphaLinolenicAcid100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['alphaLinolenicAcid100'] as Map<String, dynamic>,
        ),
  epa100: json['epa100'] == null
      ? null
      : NutrientAmount.fromJson(json['epa100'] as Map<String, dynamic>),
  dha100: json['dha100'] == null
      ? null
      : NutrientAmount.fromJson(json['dha100'] as Map<String, dynamic>),
  omega6100: json['omega6100'] == null
      ? null
      : NutrientAmount.fromJson(json['omega6100'] as Map<String, dynamic>),
  linoleicAcid100: json['linoleicAcid100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['linoleicAcid100'] as Map<String, dynamic>,
        ),
  addedSugars100: json['addedSugars100'] == null
      ? null
      : NutrientAmount.fromJson(json['addedSugars100'] as Map<String, dynamic>),
  starch100: json['starch100'] == null
      ? null
      : NutrientAmount.fromJson(json['starch100'] as Map<String, dynamic>),
  caffeine100: json['caffeine100'] == null
      ? null
      : NutrientAmount.fromJson(json['caffeine100'] as Map<String, dynamic>),
  alcohol100: json['alcohol100'] == null
      ? null
      : NutrientAmount.fromJson(json['alcohol100'] as Map<String, dynamic>),
  histidine100: json['histidine100'] == null
      ? null
      : NutrientAmount.fromJson(json['histidine100'] as Map<String, dynamic>),
  isoleucine100: json['isoleucine100'] == null
      ? null
      : NutrientAmount.fromJson(json['isoleucine100'] as Map<String, dynamic>),
  leucine100: json['leucine100'] == null
      ? null
      : NutrientAmount.fromJson(json['leucine100'] as Map<String, dynamic>),
  lysine100: json['lysine100'] == null
      ? null
      : NutrientAmount.fromJson(json['lysine100'] as Map<String, dynamic>),
  methionine100: json['methionine100'] == null
      ? null
      : NutrientAmount.fromJson(json['methionine100'] as Map<String, dynamic>),
  phenylalanine100: json['phenylalanine100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['phenylalanine100'] as Map<String, dynamic>,
        ),
  threonine100: json['threonine100'] == null
      ? null
      : NutrientAmount.fromJson(json['threonine100'] as Map<String, dynamic>),
  tryptophan100: json['tryptophan100'] == null
      ? null
      : NutrientAmount.fromJson(json['tryptophan100'] as Map<String, dynamic>),
  valine100: json['valine100'] == null
      ? null
      : NutrientAmount.fromJson(json['valine100'] as Map<String, dynamic>),
  alanine100: json['alanine100'] == null
      ? null
      : NutrientAmount.fromJson(json['alanine100'] as Map<String, dynamic>),
  arginine100: json['arginine100'] == null
      ? null
      : NutrientAmount.fromJson(json['arginine100'] as Map<String, dynamic>),
  asparagine100: json['asparagine100'] == null
      ? null
      : NutrientAmount.fromJson(json['asparagine100'] as Map<String, dynamic>),
  asparticAcid100: json['asparticAcid100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['asparticAcid100'] as Map<String, dynamic>,
        ),
  cysteine100: json['cysteine100'] == null
      ? null
      : NutrientAmount.fromJson(json['cysteine100'] as Map<String, dynamic>),
  cystine100: json['cystine100'] == null
      ? null
      : NutrientAmount.fromJson(json['cystine100'] as Map<String, dynamic>),
  glutamicAcid100: json['glutamicAcid100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['glutamicAcid100'] as Map<String, dynamic>,
        ),
  glutamine100: json['glutamine100'] == null
      ? null
      : NutrientAmount.fromJson(json['glutamine100'] as Map<String, dynamic>),
  glycine100: json['glycine100'] == null
      ? null
      : NutrientAmount.fromJson(json['glycine100'] as Map<String, dynamic>),
  hydroxyproline100: json['hydroxyproline100'] == null
      ? null
      : NutrientAmount.fromJson(
          json['hydroxyproline100'] as Map<String, dynamic>,
        ),
  proline100: json['proline100'] == null
      ? null
      : NutrientAmount.fromJson(json['proline100'] as Map<String, dynamic>),
  serine100: json['serine100'] == null
      ? null
      : NutrientAmount.fromJson(json['serine100'] as Map<String, dynamic>),
  tyrosine100: json['tyrosine100'] == null
      ? null
      : NutrientAmount.fromJson(json['tyrosine100'] as Map<String, dynamic>),
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
      'thiamin100': instance.thiamin100,
      'riboflavin100': instance.riboflavin100,
      'pantothenicAcid100': instance.pantothenicAcid100,
      'biotin100': instance.biotin100,
      'folateDfe100': instance.folateDfe100,
      'vitaminE100': instance.vitaminE100,
      'vitaminK1100': instance.vitaminK1100,
      'copper100': instance.copper100,
      'manganese100': instance.manganese100,
      'selenium100': instance.selenium100,
      'iodine100': instance.iodine100,
      'choline100': instance.choline100,
      'omega3100': instance.omega3100,
      'alphaLinolenicAcid100': instance.alphaLinolenicAcid100,
      'epa100': instance.epa100,
      'dha100': instance.dha100,
      'omega6100': instance.omega6100,
      'linoleicAcid100': instance.linoleicAcid100,
      'addedSugars100': instance.addedSugars100,
      'starch100': instance.starch100,
      'caffeine100': instance.caffeine100,
      'alcohol100': instance.alcohol100,
      'histidine100': instance.histidine100,
      'isoleucine100': instance.isoleucine100,
      'leucine100': instance.leucine100,
      'lysine100': instance.lysine100,
      'methionine100': instance.methionine100,
      'phenylalanine100': instance.phenylalanine100,
      'threonine100': instance.threonine100,
      'tryptophan100': instance.tryptophan100,
      'valine100': instance.valine100,
      'alanine100': instance.alanine100,
      'arginine100': instance.arginine100,
      'asparagine100': instance.asparagine100,
      'asparticAcid100': instance.asparticAcid100,
      'cysteine100': instance.cysteine100,
      'cystine100': instance.cystine100,
      'glutamicAcid100': instance.glutamicAcid100,
      'glutamine100': instance.glutamine100,
      'glycine100': instance.glycine100,
      'hydroxyproline100': instance.hydroxyproline100,
      'proline100': instance.proline100,
      'serine100': instance.serine100,
      'tyrosine100': instance.tyrosine100,
    };
