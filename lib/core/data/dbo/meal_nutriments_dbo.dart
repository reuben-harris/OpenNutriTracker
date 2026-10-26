import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

part 'meal_nutriments_dbo.g.dart';

@HiveType(typeId: 3)
@JsonSerializable()
class MealNutrimentsDBO extends HiveObject {
  @HiveField(0)
  final NutrientAmount? energyKcal100;
  @HiveField(1)
  final NutrientAmount? carbohydrates100;
  @HiveField(2)
  final NutrientAmount? fat100;
  @HiveField(3)
  final NutrientAmount? proteins100;
  @HiveField(4)
  final NutrientAmount? sugars100;
  @HiveField(5)
  final NutrientAmount? saturatedFat100;
  @HiveField(6)
  final NutrientAmount? fiber100;
  // #237: Extended lipid profile
  @HiveField(7)
  final NutrientAmount? monounsaturatedFat100;
  @HiveField(8)
  final NutrientAmount? polyunsaturatedFat100;
  @HiveField(9)
  final NutrientAmount? transFat100;
  @HiveField(10)
  final NutrientAmount? cholesterol100;
  // #237: Minerals (mg per 100g)
  @HiveField(11)
  final NutrientAmount? sodium100;
  @HiveField(12)
  final NutrientAmount? potassium100;
  @HiveField(13)
  final NutrientAmount? magnesium100;
  @HiveField(14)
  final NutrientAmount? calcium100;
  @HiveField(15)
  final NutrientAmount? iron100;
  @HiveField(16)
  final NutrientAmount? zinc100;
  @HiveField(17)
  final NutrientAmount? phosphorus100;
  // #237: Vitamins
  @HiveField(18)
  final NutrientAmount? vitaminA100; // µg RAE
  @HiveField(19)
  final NutrientAmount? vitaminC100; // mg
  @HiveField(20)
  final NutrientAmount? vitaminD100; // µg
  @HiveField(21)
  final NutrientAmount? vitaminB6100; // mg
  @HiveField(22)
  final NutrientAmount? vitaminB12100; // µg
  @HiveField(23)
  final NutrientAmount? niacin100; // mg (B3)

  @HiveField(24)
  final NutrientAmount? thiamin100;
  @HiveField(25)
  final NutrientAmount? riboflavin100;
  @HiveField(26)
  final NutrientAmount? pantothenicAcid100;
  @HiveField(27)
  final NutrientAmount? biotin100;
  @HiveField(28)
  final NutrientAmount? folateDfe100;
  @HiveField(29)
  final NutrientAmount? vitaminE100;
  @HiveField(30)
  final NutrientAmount? vitaminK1100;
  @HiveField(31)
  final NutrientAmount? copper100;
  @HiveField(32)
  final NutrientAmount? manganese100;
  @HiveField(33)
  final NutrientAmount? selenium100;
  @HiveField(34)
  final NutrientAmount? iodine100;
  @HiveField(35)
  final NutrientAmount? choline100;
  @HiveField(36)
  final NutrientAmount? omega3100;
  @HiveField(37)
  final NutrientAmount? alphaLinolenicAcid100;
  @HiveField(38)
  final NutrientAmount? epa100;
  @HiveField(39)
  final NutrientAmount? dha100;
  @HiveField(40)
  final NutrientAmount? omega6100;
  @HiveField(41)
  final NutrientAmount? linoleicAcid100;
  @HiveField(42)
  final NutrientAmount? addedSugars100;
  @HiveField(43)
  final NutrientAmount? starch100;
  @HiveField(44)
  final NutrientAmount? caffeine100;
  @HiveField(45)
  final NutrientAmount? alcohol100;

  // Individual amino acids, grams per 100 g of food.
  @HiveField(46)
  final NutrientAmount? histidine100;
  @HiveField(47)
  final NutrientAmount? isoleucine100;
  @HiveField(48)
  final NutrientAmount? leucine100;
  @HiveField(49)
  final NutrientAmount? lysine100;
  @HiveField(50)
  final NutrientAmount? methionine100;
  @HiveField(51)
  final NutrientAmount? phenylalanine100;
  @HiveField(52)
  final NutrientAmount? threonine100;
  @HiveField(53)
  final NutrientAmount? tryptophan100;
  @HiveField(54)
  final NutrientAmount? valine100;
  @HiveField(55)
  final NutrientAmount? alanine100;
  @HiveField(56)
  final NutrientAmount? arginine100;
  @HiveField(57)
  final NutrientAmount? asparagine100;
  @HiveField(58)
  final NutrientAmount? asparticAcid100;
  @HiveField(59)
  final NutrientAmount? cysteine100;
  @HiveField(60)
  final NutrientAmount? cystine100;
  @HiveField(61)
  final NutrientAmount? glutamicAcid100;
  @HiveField(62)
  final NutrientAmount? glutamine100;
  @HiveField(63)
  final NutrientAmount? glycine100;
  @HiveField(64)
  final NutrientAmount? hydroxyproline100;
  @HiveField(65)
  final NutrientAmount? proline100;
  @HiveField(66)
  final NutrientAmount? serine100;
  @HiveField(67)
  final NutrientAmount? tyrosine100;

  MealNutrimentsDBO({
    required this.energyKcal100,
    required this.carbohydrates100,
    required this.fat100,
    required this.proteins100,
    required this.sugars100,
    required this.saturatedFat100,
    required this.fiber100,
    this.monounsaturatedFat100,
    this.polyunsaturatedFat100,
    this.transFat100,
    this.cholesterol100,
    this.sodium100,
    this.potassium100,
    this.magnesium100,
    this.calcium100,
    this.iron100,
    this.zinc100,
    this.phosphorus100,
    this.vitaminA100,
    this.vitaminC100,
    this.vitaminD100,
    this.vitaminB6100,
    this.vitaminB12100,
    this.niacin100,
    this.thiamin100,
    this.riboflavin100,
    this.pantothenicAcid100,
    this.biotin100,
    this.folateDfe100,
    this.vitaminE100,
    this.vitaminK1100,
    this.copper100,
    this.manganese100,
    this.selenium100,
    this.iodine100,
    this.choline100,
    this.omega3100,
    this.alphaLinolenicAcid100,
    this.epa100,
    this.dha100,
    this.omega6100,
    this.linoleicAcid100,
    this.addedSugars100,
    this.starch100,
    this.caffeine100,
    this.alcohol100,
    this.histidine100,
    this.isoleucine100,
    this.leucine100,
    this.lysine100,
    this.methionine100,
    this.phenylalanine100,
    this.threonine100,
    this.tryptophan100,
    this.valine100,
    this.alanine100,
    this.arginine100,
    this.asparagine100,
    this.asparticAcid100,
    this.cysteine100,
    this.cystine100,
    this.glutamicAcid100,
    this.glutamine100,
    this.glycine100,
    this.hydroxyproline100,
    this.proline100,
    this.serine100,
    this.tyrosine100,
  });

  factory MealNutrimentsDBO.fromProductNutrimentsEntity(
    MealNutrimentsEntity nutriments,
  ) {
    return MealNutrimentsDBO(
      energyKcal100: nutriments.energyKcal100,
      carbohydrates100: nutriments.carbohydrates100,
      fat100: nutriments.fat100,
      proteins100: nutriments.proteins100,
      sugars100: nutriments.sugars100,
      saturatedFat100: nutriments.saturatedFat100,
      fiber100: nutriments.fiber100,
      monounsaturatedFat100: nutriments.monounsaturatedFat100,
      polyunsaturatedFat100: nutriments.polyunsaturatedFat100,
      transFat100: nutriments.transFat100,
      cholesterol100: nutriments.cholesterol100,
      sodium100: nutriments.sodium100,
      potassium100: nutriments.potassium100,
      magnesium100: nutriments.magnesium100,
      calcium100: nutriments.calcium100,
      iron100: nutriments.iron100,
      zinc100: nutriments.zinc100,
      phosphorus100: nutriments.phosphorus100,
      vitaminA100: nutriments.vitaminA100,
      vitaminC100: nutriments.vitaminC100,
      vitaminD100: nutriments.vitaminD100,
      vitaminB6100: nutriments.vitaminB6100,
      vitaminB12100: nutriments.vitaminB12100,
      niacin100: nutriments.niacin100,
      thiamin100: nutriments.thiamin100,
      riboflavin100: nutriments.riboflavin100,
      pantothenicAcid100: nutriments.pantothenicAcid100,
      biotin100: nutriments.biotin100,
      folateDfe100: nutriments.folateDfe100,
      vitaminE100: nutriments.vitaminE100,
      vitaminK1100: nutriments.vitaminK1100,
      copper100: nutriments.copper100,
      manganese100: nutriments.manganese100,
      selenium100: nutriments.selenium100,
      iodine100: nutriments.iodine100,
      choline100: nutriments.choline100,
      omega3100: nutriments.omega3100,
      alphaLinolenicAcid100: nutriments.alphaLinolenicAcid100,
      epa100: nutriments.epa100,
      dha100: nutriments.dha100,
      omega6100: nutriments.omega6100,
      linoleicAcid100: nutriments.linoleicAcid100,
      addedSugars100: nutriments.addedSugars100,
      starch100: nutriments.starch100,
      caffeine100: nutriments.caffeine100,
      alcohol100: nutriments.alcohol100,
      histidine100: nutriments.histidine100,
      isoleucine100: nutriments.isoleucine100,
      leucine100: nutriments.leucine100,
      lysine100: nutriments.lysine100,
      methionine100: nutriments.methionine100,
      phenylalanine100: nutriments.phenylalanine100,
      threonine100: nutriments.threonine100,
      tryptophan100: nutriments.tryptophan100,
      valine100: nutriments.valine100,
      alanine100: nutriments.alanine100,
      arginine100: nutriments.arginine100,
      asparagine100: nutriments.asparagine100,
      asparticAcid100: nutriments.asparticAcid100,
      cysteine100: nutriments.cysteine100,
      cystine100: nutriments.cystine100,
      glutamicAcid100: nutriments.glutamicAcid100,
      glutamine100: nutriments.glutamine100,
      glycine100: nutriments.glycine100,
      hydroxyproline100: nutriments.hydroxyproline100,
      proline100: nutriments.proline100,
      serine100: nutriments.serine100,
      tyrosine100: nutriments.tyrosine100,
    );
  }

  factory MealNutrimentsDBO.fromJson(Map<String, dynamic> json) =>
      _$MealNutrimentsDBOFromJson(json);

  Map<String, dynamic> toJson() => _$MealNutrimentsDBOToJson(this);
}
