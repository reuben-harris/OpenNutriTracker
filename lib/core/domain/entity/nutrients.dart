import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum NutrientGroup {
  carbohydrates,
  lipids,
  proteins,
  vitamins,
  minerals,
  other;

  String label(S s) => switch (this) {
    carbohydrates => s.nutrientGroupCarbohydrates,
    lipids => s.nutrientGroupLipids,
    proteins => s.nutrientGroupProtein,
    vitamins => s.nutrientGroupVitamins,
    minerals => s.nutrientGroupMinerals,
    other => s.nutrientGroupOther,
  };
}

enum NutrientGoalKind { target, limit }

class NutrientDefinition {
  final String key, field, unit;
  final NutrientGroup group;
  final String Function(S) label;
  final bool core;
  final NutrientGoalKind goalKind;
  const NutrientDefinition(
    this.key,
    this.field,
    this.unit,
    this.group,
    this.label, {
    this.core = false,
    this.goalKind = NutrientGoalKind.target,
  });
  String get csvColumn =>
      '${switch (key) {
        NutrientKeys.energy => 'kcal',
        NutrientKeys.carbohydrates => 'carbs',
        NutrientKeys.sugar => 'sugars',
        _ => key,
      }}_per_100g';
  NutrientAmount? amount(MealNutrimentsEntity n) => n.amounts[field];
}

class NutrientKeys {
  NutrientKeys._();
  static const energy = 'energy';
  static const carbohydrates = 'carbohydrates';
  static const fat = 'fat';
  static const protein = 'protein';
  static const sugar = 'sugar';
  static const saturatedFat = 'saturated_fat';
  static const fiber = 'fiber';
  static const monounsaturatedFat = 'monounsaturated_fat';
  static const polyunsaturatedFat = 'polyunsaturated_fat';
  static const transFat = 'trans_fat';
  static const cholesterol = 'cholesterol';
  static const sodium = 'sodium';
  static const potassium = 'potassium';
  static const magnesium = 'magnesium';
  static const calcium = 'calcium';
  static const iron = 'iron';
  static const zinc = 'zinc';
  static const phosphorus = 'phosphorus';
  static const vitaminA = 'vitamin_a';
  static const vitaminC = 'vitamin_c';
  static const vitaminD = 'vitamin_d';
  static const vitaminB6 = 'vitamin_b6';
  static const vitaminB12 = 'vitamin_b12';
  static const niacin = 'niacin';
  static const thiamin = 'thiamin';
  static const riboflavin = 'riboflavin';
  static const pantothenicAcid = 'pantothenic_acid';
  static const biotin = 'biotin';
  static const folateDfe = 'folate_dfe';
  static const vitaminE = 'vitamin_e';
  static const vitaminK1 = 'vitamin_k1';
  static const copper = 'copper';
  static const manganese = 'manganese';
  static const selenium = 'selenium';
  static const iodine = 'iodine';
  static const choline = 'choline';
  static const omega3 = 'omega3';
  static const alphaLinolenicAcid = 'ala';
  static const epa = 'epa';
  static const dha = 'dha';
  static const omega6 = 'omega6';
  static const linoleicAcid = 'linoleic_acid';
  static const addedSugars = 'added_sugars';
  static const starch = 'starch';
  static const caffeine = 'caffeine';
  static const alcohol = 'alcohol';
  static const histidine = 'histidine';
  static const isoleucine = 'isoleucine';
  static const leucine = 'leucine';
  static const lysine = 'lysine';
  static const methionine = 'methionine';
  static const phenylalanine = 'phenylalanine';
  static const threonine = 'threonine';
  static const tryptophan = 'tryptophan';
  static const valine = 'valine';
  static const alanine = 'alanine';
  static const arginine = 'arginine';
  static const asparagine = 'asparagine';
  static const asparticAcid = 'aspartic_acid';
  static const cysteine = 'cysteine';
  static const cystine = 'cystine';
  static const glutamicAcid = 'glutamic_acid';
  static const glutamine = 'glutamine';
  static const glycine = 'glycine';
  static const hydroxyproline = 'hydroxyproline';
  static const proline = 'proline';
  static const serine = 'serine';
  static const tyrosine = 'tyrosine';
  static Iterable<String> get all => Nutrients.additional.map((n) => n.key);
}

class Nutrients {
  Nutrients._();
  static final all = <NutrientDefinition>[
    NutrientDefinition(
      NutrientKeys.energy,
      'energyKcal100',
      'kcal',
      NutrientGroup.other,
      (s) => s.energyLabel,
      core: true,
    ),
    NutrientDefinition(
      NutrientKeys.carbohydrates,
      'carbohydrates100',
      'g',
      NutrientGroup.carbohydrates,
      (s) => s.carbohydrateLabel,
      core: true,
    ),
    NutrientDefinition(
      NutrientKeys.fat,
      'fat100',
      'g',
      NutrientGroup.lipids,
      (s) => s.fatLabel,
      core: true,
    ),
    NutrientDefinition(
      NutrientKeys.protein,
      'proteins100',
      'g',
      NutrientGroup.proteins,
      (s) => s.proteinLabel,
      core: true,
    ),
    NutrientDefinition(
      NutrientKeys.sugar,
      'sugars100',
      'g',
      NutrientGroup.carbohydrates,
      (s) => s.sugarLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.saturatedFat,
      'saturatedFat100',
      'g',
      NutrientGroup.lipids,
      (s) => s.saturatedFatLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.fiber,
      'fiber100',
      'g',
      NutrientGroup.carbohydrates,
      (s) => s.fiberLabel,
    ),
    NutrientDefinition(
      NutrientKeys.monounsaturatedFat,
      'monounsaturatedFat100',
      'g',
      NutrientGroup.lipids,
      (s) => s.monounsaturatedFatLabel,
    ),
    NutrientDefinition(
      NutrientKeys.polyunsaturatedFat,
      'polyunsaturatedFat100',
      'g',
      NutrientGroup.lipids,
      (s) => s.polyunsaturatedFatLabel,
    ),
    NutrientDefinition(
      NutrientKeys.transFat,
      'transFat100',
      'g',
      NutrientGroup.lipids,
      (s) => s.transFatLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.cholesterol,
      'cholesterol100',
      'mg',
      NutrientGroup.lipids,
      (s) => s.cholesterolLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.sodium,
      'sodium100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.sodiumLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.potassium,
      'potassium100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.potassiumLabel,
    ),
    NutrientDefinition(
      NutrientKeys.magnesium,
      'magnesium100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.magnesiumLabel,
    ),
    NutrientDefinition(
      NutrientKeys.calcium,
      'calcium100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.calciumLabel,
    ),
    NutrientDefinition(
      NutrientKeys.iron,
      'iron100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.ironLabel,
    ),
    NutrientDefinition(
      NutrientKeys.zinc,
      'zinc100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.zincLabel,
    ),
    NutrientDefinition(
      NutrientKeys.phosphorus,
      'phosphorus100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.phosphorusLabel,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminA,
      'vitaminA100',
      'µg',
      NutrientGroup.vitamins,
      (s) => s.vitaminALabel,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminC,
      'vitaminC100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.vitaminCLabel,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminD,
      'vitaminD100',
      'µg',
      NutrientGroup.vitamins,
      (s) => s.vitaminDLabel,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminB6,
      'vitaminB6100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.vitaminB6Label,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminB12,
      'vitaminB12100',
      'µg',
      NutrientGroup.vitamins,
      (s) => s.vitaminB12Label,
    ),
    NutrientDefinition(
      NutrientKeys.niacin,
      'niacin100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.niacinLabel,
    ),
    NutrientDefinition(
      NutrientKeys.thiamin,
      'thiamin100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.thiaminLabel,
    ),
    NutrientDefinition(
      NutrientKeys.riboflavin,
      'riboflavin100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.riboflavinLabel,
    ),
    NutrientDefinition(
      NutrientKeys.pantothenicAcid,
      'pantothenicAcid100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.pantothenicAcidLabel,
    ),
    NutrientDefinition(
      NutrientKeys.biotin,
      'biotin100',
      'µg',
      NutrientGroup.vitamins,
      (s) => s.biotinLabel,
    ),
    NutrientDefinition(
      NutrientKeys.folateDfe,
      'folateDfe100',
      'µg',
      NutrientGroup.vitamins,
      (s) => s.folateDfeLabel,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminE,
      'vitaminE100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.vitaminELabel,
    ),
    NutrientDefinition(
      NutrientKeys.vitaminK1,
      'vitaminK1100',
      'µg',
      NutrientGroup.vitamins,
      (s) => s.vitaminK1Label,
    ),
    NutrientDefinition(
      NutrientKeys.copper,
      'copper100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.copperLabel,
    ),
    NutrientDefinition(
      NutrientKeys.manganese,
      'manganese100',
      'mg',
      NutrientGroup.minerals,
      (s) => s.manganeseLabel,
    ),
    NutrientDefinition(
      NutrientKeys.selenium,
      'selenium100',
      'µg',
      NutrientGroup.minerals,
      (s) => s.seleniumLabel,
    ),
    NutrientDefinition(
      NutrientKeys.iodine,
      'iodine100',
      'µg',
      NutrientGroup.minerals,
      (s) => s.iodineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.choline,
      'choline100',
      'mg',
      NutrientGroup.vitamins,
      (s) => s.cholineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.omega3,
      'omega3100',
      'g',
      NutrientGroup.lipids,
      (s) => s.omega3Label,
    ),
    NutrientDefinition(
      NutrientKeys.alphaLinolenicAcid,
      'alphaLinolenicAcid100',
      'g',
      NutrientGroup.lipids,
      (s) => s.alphaLinolenicAcidLabel,
    ),
    NutrientDefinition(
      NutrientKeys.epa,
      'epa100',
      'g',
      NutrientGroup.lipids,
      (s) => s.epaLabel,
    ),
    NutrientDefinition(
      NutrientKeys.dha,
      'dha100',
      'g',
      NutrientGroup.lipids,
      (s) => s.dhaLabel,
    ),
    NutrientDefinition(
      NutrientKeys.omega6,
      'omega6100',
      'g',
      NutrientGroup.lipids,
      (s) => s.omega6Label,
    ),
    NutrientDefinition(
      NutrientKeys.linoleicAcid,
      'linoleicAcid100',
      'g',
      NutrientGroup.lipids,
      (s) => s.linoleicAcidLabel,
    ),
    NutrientDefinition(
      NutrientKeys.addedSugars,
      'addedSugars100',
      'g',
      NutrientGroup.carbohydrates,
      (s) => s.addedSugarsLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.starch,
      'starch100',
      'g',
      NutrientGroup.carbohydrates,
      (s) => s.starchLabel,
    ),
    NutrientDefinition(
      NutrientKeys.caffeine,
      'caffeine100',
      'mg',
      NutrientGroup.other,
      (s) => s.caffeineLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.alcohol,
      'alcohol100',
      'g',
      NutrientGroup.other,
      (s) => s.alcoholLabel,
      goalKind: NutrientGoalKind.limit,
    ),
    NutrientDefinition(
      NutrientKeys.histidine,
      'histidine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.histidineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.isoleucine,
      'isoleucine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.isoleucineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.leucine,
      'leucine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.leucineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.lysine,
      'lysine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.lysineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.methionine,
      'methionine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.methionineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.phenylalanine,
      'phenylalanine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.phenylalanineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.threonine,
      'threonine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.threonineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.tryptophan,
      'tryptophan100',
      'g',
      NutrientGroup.proteins,
      (s) => s.tryptophanLabel,
    ),
    NutrientDefinition(
      NutrientKeys.valine,
      'valine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.valineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.alanine,
      'alanine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.alanineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.arginine,
      'arginine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.arginineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.asparagine,
      'asparagine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.asparagineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.asparticAcid,
      'asparticAcid100',
      'g',
      NutrientGroup.proteins,
      (s) => s.asparticAcidLabel,
    ),
    NutrientDefinition(
      NutrientKeys.cysteine,
      'cysteine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.cysteineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.cystine,
      'cystine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.cystineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.glutamicAcid,
      'glutamicAcid100',
      'g',
      NutrientGroup.proteins,
      (s) => s.glutamicAcidLabel,
    ),
    NutrientDefinition(
      NutrientKeys.glutamine,
      'glutamine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.glutamineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.glycine,
      'glycine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.glycineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.hydroxyproline,
      'hydroxyproline100',
      'g',
      NutrientGroup.proteins,
      (s) => s.hydroxyprolineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.proline,
      'proline100',
      'g',
      NutrientGroup.proteins,
      (s) => s.prolineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.serine,
      'serine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.serineLabel,
    ),
    NutrientDefinition(
      NutrientKeys.tyrosine,
      'tyrosine100',
      'g',
      NutrientGroup.proteins,
      (s) => s.tyrosineLabel,
    ),
  ];
  static final additional = all.where((n) => !n.core).toList(growable: false);
  static final additionalGroups = NutrientGroup.values
      .where((group) => additional.any((n) => n.group == group))
      .toList(growable: false);
  static final byKey = {for (final n in all) n.key: n};
  static final byField = {for (final n in all) n.field: n};
}
