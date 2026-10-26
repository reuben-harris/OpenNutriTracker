import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_nutriments_dto.dart';

class MealNutrimentsEntity extends Equatable {
  final NutrientAmount? energyKcal100;

  bool get isIncomplete =>
      energyKcal100 == null ||
      carbohydrates100 == null ||
      fat100 == null ||
      proteins100 == null;

  final NutrientAmount? carbohydrates100;
  final NutrientAmount? fat100;
  final NutrientAmount? proteins100;
  final NutrientAmount? sugars100;
  final NutrientAmount? saturatedFat100;
  final NutrientAmount? fiber100;
  // #237: Extended lipid profile
  final NutrientAmount? monounsaturatedFat100;
  final NutrientAmount? polyunsaturatedFat100;
  final NutrientAmount? transFat100;
  final NutrientAmount? cholesterol100;
  // #237: Minerals (mg per 100g)
  final NutrientAmount? sodium100;
  final NutrientAmount? potassium100;
  final NutrientAmount? magnesium100;
  final NutrientAmount? calcium100;
  final NutrientAmount? iron100;
  final NutrientAmount? zinc100;
  final NutrientAmount? phosphorus100;
  // #237: Vitamins
  final NutrientAmount? vitaminA100; // µg RAE
  final NutrientAmount? vitaminC100; // mg
  final NutrientAmount? vitaminD100; // µg
  final NutrientAmount? vitaminB6100; // mg
  final NutrientAmount? vitaminB12100; // µg
  final NutrientAmount? niacin100; // mg (B3)

  final NutrientAmount? thiamin100;
  final NutrientAmount? riboflavin100;
  final NutrientAmount? pantothenicAcid100;
  final NutrientAmount? biotin100;
  final NutrientAmount? folateDfe100;
  final NutrientAmount? vitaminE100;
  final NutrientAmount? vitaminK1100;
  final NutrientAmount? copper100;
  final NutrientAmount? manganese100;
  final NutrientAmount? selenium100;
  final NutrientAmount? iodine100;
  final NutrientAmount? choline100;
  final NutrientAmount? omega3100;
  final NutrientAmount? alphaLinolenicAcid100;
  final NutrientAmount? epa100;
  final NutrientAmount? dha100;
  final NutrientAmount? omega6100;
  final NutrientAmount? linoleicAcid100;
  final NutrientAmount? addedSugars100;
  final NutrientAmount? starch100;
  final NutrientAmount? caffeine100;
  final NutrientAmount? alcohol100;
  final NutrientAmount? histidine100;
  final NutrientAmount? isoleucine100;
  final NutrientAmount? leucine100;
  final NutrientAmount? lysine100;
  final NutrientAmount? methionine100;
  final NutrientAmount? phenylalanine100;
  final NutrientAmount? threonine100;
  final NutrientAmount? tryptophan100;
  final NutrientAmount? valine100;
  final NutrientAmount? alanine100;
  final NutrientAmount? arginine100;
  final NutrientAmount? asparagine100;
  final NutrientAmount? asparticAcid100;
  final NutrientAmount? cysteine100;
  final NutrientAmount? cystine100;
  final NutrientAmount? glutamicAcid100;
  final NutrientAmount? glutamine100;
  final NutrientAmount? glycine100;
  final NutrientAmount? hydroxyproline100;
  final NutrientAmount? proline100;
  final NutrientAmount? serine100;
  final NutrientAmount? tyrosine100;

  NutrientAmount? get energyPerUnit => _getValuePerUnit(energyKcal100);

  NutrientAmount? get carbohydratesPerUnit =>
      _getValuePerUnit(carbohydrates100);

  NutrientAmount? get fatPerUnit => _getValuePerUnit(fat100);

  NutrientAmount? get proteinsPerUnit => _getValuePerUnit(proteins100);

  const MealNutrimentsEntity({
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

  factory MealNutrimentsEntity.empty() => const MealNutrimentsEntity(
    energyKcal100: null,
    carbohydrates100: null,
    fat100: null,
    proteins100: null,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  );

  /// Stored values that are NaN or infinite read back as null ("unknown").
  /// A custom meal saved with a base quantity of 0 was stored that way
  /// (#1254); read through unchanged, one such row turned every total it
  /// fed into NaN and threw in the widgets that round those totals.
  factory MealNutrimentsEntity.fromMealNutrimentsDBO(
    MealNutrimentsDBO nutriments,
  ) {
    NutrientAmount? finite(NutrientAmount? value) =>
        value != null && value.isFinite ? value : null;
    return MealNutrimentsEntity(
      energyKcal100: finite(nutriments.energyKcal100),
      carbohydrates100: finite(nutriments.carbohydrates100),
      fat100: finite(nutriments.fat100),
      proteins100: finite(nutriments.proteins100),
      sugars100: finite(nutriments.sugars100),
      saturatedFat100: finite(nutriments.saturatedFat100),
      fiber100: finite(nutriments.fiber100),
      monounsaturatedFat100: finite(nutriments.monounsaturatedFat100),
      polyunsaturatedFat100: finite(nutriments.polyunsaturatedFat100),
      transFat100: finite(nutriments.transFat100),
      cholesterol100: finite(nutriments.cholesterol100),
      sodium100: finite(nutriments.sodium100),
      potassium100: finite(nutriments.potassium100),
      magnesium100: finite(nutriments.magnesium100),
      calcium100: finite(nutriments.calcium100),
      iron100: finite(nutriments.iron100),
      zinc100: finite(nutriments.zinc100),
      phosphorus100: finite(nutriments.phosphorus100),
      vitaminA100: finite(nutriments.vitaminA100),
      vitaminC100: finite(nutriments.vitaminC100),
      vitaminD100: finite(nutriments.vitaminD100),
      vitaminB6100: finite(nutriments.vitaminB6100),
      vitaminB12100: finite(nutriments.vitaminB12100),
      niacin100: finite(nutriments.niacin100),
      thiamin100: finite(nutriments.thiamin100),
      riboflavin100: finite(nutriments.riboflavin100),
      pantothenicAcid100: finite(nutriments.pantothenicAcid100),
      biotin100: finite(nutriments.biotin100),
      folateDfe100: finite(nutriments.folateDfe100),
      vitaminE100: finite(nutriments.vitaminE100),
      vitaminK1100: finite(nutriments.vitaminK1100),
      copper100: finite(nutriments.copper100),
      manganese100: finite(nutriments.manganese100),
      selenium100: finite(nutriments.selenium100),
      iodine100: finite(nutriments.iodine100),
      choline100: finite(nutriments.choline100),
      omega3100: finite(nutriments.omega3100),
      alphaLinolenicAcid100: finite(nutriments.alphaLinolenicAcid100),
      epa100: finite(nutriments.epa100),
      dha100: finite(nutriments.dha100),
      omega6100: finite(nutriments.omega6100),
      linoleicAcid100: finite(nutriments.linoleicAcid100),
      addedSugars100: finite(nutriments.addedSugars100),
      starch100: finite(nutriments.starch100),
      caffeine100: finite(nutriments.caffeine100),
      alcohol100: finite(nutriments.alcohol100),
      histidine100: finite(nutriments.histidine100),
      isoleucine100: finite(nutriments.isoleucine100),
      leucine100: finite(nutriments.leucine100),
      lysine100: finite(nutriments.lysine100),
      methionine100: finite(nutriments.methionine100),
      phenylalanine100: finite(nutriments.phenylalanine100),
      threonine100: finite(nutriments.threonine100),
      tryptophan100: finite(nutriments.tryptophan100),
      valine100: finite(nutriments.valine100),
      alanine100: finite(nutriments.alanine100),
      arginine100: finite(nutriments.arginine100),
      asparagine100: finite(nutriments.asparagine100),
      asparticAcid100: finite(nutriments.asparticAcid100),
      cysteine100: finite(nutriments.cysteine100),
      cystine100: finite(nutriments.cystine100),
      glutamicAcid100: finite(nutriments.glutamicAcid100),
      glutamine100: finite(nutriments.glutamine100),
      glycine100: finite(nutriments.glycine100),
      hydroxyproline100: finite(nutriments.hydroxyproline100),
      proline100: finite(nutriments.proline100),
      serine100: finite(nutriments.serine100),
      tyrosine100: finite(nutriments.tyrosine100),
    );
  }

  factory MealNutrimentsEntity.fromOffNutriments(
    OFFProductNutrimentsDTO? offNutriments,
  ) {
    if (offNutriments == null) return MealNutrimentsEntity.empty();

    return MealNutrimentsEntity(
      energyKcal100: NutrientAmount.fromSource(
        offNutriments.energy_kcal_100g,
        modifier: offNutriments.modifiers['energy-kcal'],
      )?.scale(1),
      carbohydrates100: NutrientAmount.fromSource(
        offNutriments.carbohydrates_100g,
        modifier: offNutriments.modifiers['carbohydrates'],
      )?.scale(1),
      fat100: NutrientAmount.fromSource(
        offNutriments.fat_100g,
        modifier: offNutriments.modifiers['fat'],
      )?.scale(1),
      proteins100: NutrientAmount.fromSource(
        offNutriments.proteins_100g,
        modifier: offNutriments.modifiers['proteins'],
      )?.scale(1),
      sugars100: NutrientAmount.fromSource(
        offNutriments.sugars_100g,
        modifier: offNutriments.modifiers['sugars'],
      )?.scale(1),
      saturatedFat100: NutrientAmount.fromSource(
        offNutriments.saturated_fat_100g,
        modifier: offNutriments.modifiers['saturated-fat'],
      )?.scale(1),
      fiber100: NutrientAmount.fromSource(
        offNutriments.fiber_100g,
        modifier: offNutriments.modifiers['fiber'],
      )?.scale(1),
      monounsaturatedFat100: NutrientAmount.fromSource(
        offNutriments.monounsaturated_fat_100g,
        modifier: offNutriments.modifiers['monounsaturated-fat'],
      )?.scale(1),
      polyunsaturatedFat100: NutrientAmount.fromSource(
        offNutriments.polyunsaturated_fat_100g,
        modifier: offNutriments.modifiers['polyunsaturated-fat'],
      )?.scale(1),
      transFat100: NutrientAmount.fromSource(
        offNutriments.trans_fat_100g,
        modifier: offNutriments.modifiers['trans-fat'],
      )?.scale(1),
      cholesterol100: NutrientAmount.fromSource(
        offNutriments.cholesterol_100g,
        modifier: offNutriments.modifiers['cholesterol'],
      )?.scale(1000),
      sodium100: NutrientAmount.fromSource(
        offNutriments.sodium_100g,
        modifier: offNutriments.modifiers['sodium'],
      )?.scale(1000),
      potassium100: NutrientAmount.fromSource(
        offNutriments.potassium_100g,
        modifier: offNutriments.modifiers['potassium'],
      )?.scale(1000),
      magnesium100: NutrientAmount.fromSource(
        offNutriments.magnesium_100g,
        modifier: offNutriments.modifiers['magnesium'],
      )?.scale(1000),
      calcium100: NutrientAmount.fromSource(
        offNutriments.calcium_100g,
        modifier: offNutriments.modifiers['calcium'],
      )?.scale(1000),
      iron100: NutrientAmount.fromSource(
        offNutriments.iron_100g,
        modifier: offNutriments.modifiers['iron'],
      )?.scale(1000),
      zinc100: NutrientAmount.fromSource(
        offNutriments.zinc_100g,
        modifier: offNutriments.modifiers['zinc'],
      )?.scale(1000),
      phosphorus100: NutrientAmount.fromSource(
        offNutriments.phosphorus_100g,
        modifier: offNutriments.modifiers['phosphorus'],
      )?.scale(1000),
      vitaminA100: NutrientAmount.fromSource(
        offNutriments.vitamin_a_100g,
        modifier: offNutriments.modifiers['vitamin-a'],
      )?.scale(1000000),
      vitaminC100: NutrientAmount.fromSource(
        offNutriments.vitamin_c_100g,
        modifier: offNutriments.modifiers['vitamin-c'],
      )?.scale(1000),
      vitaminD100: NutrientAmount.fromSource(
        offNutriments.vitamin_d_100g,
        modifier: offNutriments.modifiers['vitamin-d'],
      )?.scale(1000000),
      vitaminB6100: NutrientAmount.fromSource(
        offNutriments.vitamin_b6_100g,
        modifier: offNutriments.modifiers['vitamin-b6'],
      )?.scale(1000),
      vitaminB12100: NutrientAmount.fromSource(
        offNutriments.vitamin_b12_100g,
        modifier: offNutriments.modifiers['vitamin-b12'],
      )?.scale(1000000),
      niacin100: NutrientAmount.fromSource(
        offNutriments.niacin_100g,
        modifier: offNutriments.modifiers['vitamin-pp'],
      )?.scale(1000),
      thiamin100: NutrientAmount.fromSource(
        offNutriments.vitamin_b1_100g,
        modifier: offNutriments.modifiers['vitamin-b1'],
      )?.scale(1000),
      riboflavin100: NutrientAmount.fromSource(
        offNutriments.vitamin_b2_100g,
        modifier: offNutriments.modifiers['vitamin-b2'],
      )?.scale(1000),
      pantothenicAcid100: NutrientAmount.fromSource(
        offNutriments.pantothenic_acid_100g,
        modifier: offNutriments.modifiers['pantothenic-acid'],
      )?.scale(1000),
      biotin100: NutrientAmount.fromSource(
        offNutriments.biotin_100g,
        modifier: offNutriments.modifiers['biotin'],
      )?.scale(1000000),
      copper100: NutrientAmount.fromSource(
        offNutriments.copper_100g,
        modifier: offNutriments.modifiers['copper'],
      )?.scale(1000),
      manganese100: NutrientAmount.fromSource(
        offNutriments.manganese_100g,
        modifier: offNutriments.modifiers['manganese'],
      )?.scale(1000),
      selenium100: NutrientAmount.fromSource(
        offNutriments.selenium_100g,
        modifier: offNutriments.modifiers['selenium'],
      )?.scale(1000000),
      iodine100: NutrientAmount.fromSource(
        offNutriments.iodine_100g,
        modifier: offNutriments.modifiers['iodine'],
      )?.scale(1000000),
      choline100: NutrientAmount.fromSource(
        offNutriments.choline_100g,
        modifier: offNutriments.modifiers['choline'],
      )?.scale(1000),
      omega3100: NutrientAmount.fromSource(
        offNutriments.omega_3_fat_100g,
        modifier: offNutriments.modifiers['omega-3-fat'],
      )?.scale(1),
      alphaLinolenicAcid100: NutrientAmount.fromSource(
        offNutriments.alpha_linolenic_acid_100g,
        modifier: offNutriments.modifiers['alpha-linolenic-acid'],
      )?.scale(1),
      epa100: NutrientAmount.fromSource(
        offNutriments.eicosapentaenoic_acid_100g,
        modifier: offNutriments.modifiers['eicosapentaenoic-acid'],
      )?.scale(1),
      dha100: NutrientAmount.fromSource(
        offNutriments.docosahexaenoic_acid_100g,
        modifier: offNutriments.modifiers['docosahexaenoic-acid'],
      )?.scale(1),
      omega6100: NutrientAmount.fromSource(
        offNutriments.omega_6_fat_100g,
        modifier: offNutriments.modifiers['omega-6-fat'],
      )?.scale(1),
      linoleicAcid100: NutrientAmount.fromSource(
        offNutriments.linoleic_acid_100g,
        modifier: offNutriments.modifiers['linoleic-acid'],
      )?.scale(1),
      addedSugars100: NutrientAmount.fromSource(
        offNutriments.added_sugars_100g,
        modifier: offNutriments.modifiers['added-sugars'],
      )?.scale(1),
      starch100: NutrientAmount.fromSource(
        offNutriments.starch_100g,
        modifier: offNutriments.modifiers['starch'],
      )?.scale(1),
      isoleucine100: NutrientAmount.fromSource(
        offNutriments.l_isoleucine_100g,
        modifier: offNutriments.modifiers['l-isoleucine'],
      ),
      leucine100: NutrientAmount.fromSource(
        offNutriments.l_leucine_100g,
        modifier: offNutriments.modifiers['l-leucine'],
      ),
      valine100: NutrientAmount.fromSource(
        offNutriments.l_valine_100g,
        modifier: offNutriments.modifiers['l-valine'],
      ),
      arginine100: NutrientAmount.fromSource(
        offNutriments.l_arginine_100g,
        modifier: offNutriments.modifiers['l-arginine'],
      ),
      cysteine100: NutrientAmount.fromSource(
        offNutriments.l_cysteine_100g,
        modifier: offNutriments.modifiers['l-cysteine'],
      ),
      glutamine100: NutrientAmount.fromSource(
        offNutriments.l_glutamine_100g,
        modifier: offNutriments.modifiers['l-glutamine'],
      ),
      caffeine100: NutrientAmount.fromSource(
        offNutriments.caffeine_100g,
        modifier: offNutriments.modifiers['caffeine'],
      )?.scale(1000),
    );
  }

  /// Values are in the app's canonical units per 100 g or 100 ml.
  factory MealNutrimentsEntity.fromAmounts(
    Map<String, NutrientAmount?> amounts,
  ) => MealNutrimentsEntity(
    energyKcal100: amounts['energyKcal100'],
    carbohydrates100: amounts['carbohydrates100'],
    fat100: amounts['fat100'],
    proteins100: amounts['proteins100'],
    sugars100: amounts['sugars100'],
    saturatedFat100: amounts['saturatedFat100'],
    fiber100: amounts['fiber100'],
    monounsaturatedFat100: amounts['monounsaturatedFat100'],
    polyunsaturatedFat100: amounts['polyunsaturatedFat100'],
    transFat100: amounts['transFat100'],
    cholesterol100: amounts['cholesterol100'],
    sodium100: amounts['sodium100'],
    potassium100: amounts['potassium100'],
    magnesium100: amounts['magnesium100'],
    calcium100: amounts['calcium100'],
    iron100: amounts['iron100'],
    zinc100: amounts['zinc100'],
    phosphorus100: amounts['phosphorus100'],
    vitaminA100: amounts['vitaminA100'],
    vitaminC100: amounts['vitaminC100'],
    vitaminD100: amounts['vitaminD100'],
    vitaminB6100: amounts['vitaminB6100'],
    vitaminB12100: amounts['vitaminB12100'],
    niacin100: amounts['niacin100'],
    thiamin100: amounts['thiamin100'],
    riboflavin100: amounts['riboflavin100'],
    pantothenicAcid100: amounts['pantothenicAcid100'],
    biotin100: amounts['biotin100'],
    folateDfe100: amounts['folateDfe100'],
    vitaminE100: amounts['vitaminE100'],
    vitaminK1100: amounts['vitaminK1100'],
    copper100: amounts['copper100'],
    manganese100: amounts['manganese100'],
    selenium100: amounts['selenium100'],
    iodine100: amounts['iodine100'],
    choline100: amounts['choline100'],
    omega3100: amounts['omega3100'],
    alphaLinolenicAcid100: amounts['alphaLinolenicAcid100'],
    epa100: amounts['epa100'],
    dha100: amounts['dha100'],
    omega6100: amounts['omega6100'],
    linoleicAcid100: amounts['linoleicAcid100'],
    addedSugars100: amounts['addedSugars100'],
    starch100: amounts['starch100'],
    caffeine100: amounts['caffeine100'],
    alcohol100: amounts['alcohol100'],
    histidine100: amounts['histidine100'],
    isoleucine100: amounts['isoleucine100'],
    leucine100: amounts['leucine100'],
    lysine100: amounts['lysine100'],
    methionine100: amounts['methionine100'],
    phenylalanine100: amounts['phenylalanine100'],
    threonine100: amounts['threonine100'],
    tryptophan100: amounts['tryptophan100'],
    valine100: amounts['valine100'],
    alanine100: amounts['alanine100'],
    arginine100: amounts['arginine100'],
    asparagine100: amounts['asparagine100'],
    asparticAcid100: amounts['asparticAcid100'],
    cysteine100: amounts['cysteine100'],
    cystine100: amounts['cystine100'],
    glutamicAcid100: amounts['glutamicAcid100'],
    glutamine100: amounts['glutamine100'],
    glycine100: amounts['glycine100'],
    hydroxyproline100: amounts['hydroxyproline100'],
    proline100: amounts['proline100'],
    serine100: amounts['serine100'],
    tyrosine100: amounts['tyrosine100'],
  );

  factory MealNutrimentsEntity.fromCatalogue(Map<String, dynamic> values) =>
      MealNutrimentsEntity.fromAmounts({
        for (final entry in values.entries)
          entry.key: NutrientAmount.fromSource(entry.value),
      });

  static NutrientAmount? _getValuePerUnit(NutrientAmount? valuePer100) {
    if (valuePer100 != null) {
      return valuePer100.scale(0.01);
    } else {
      return null;
    }
  }

  bool get hasQualifications =>
      amounts.values.any((a) => a?.isQualified ?? false);

  Map<String, NutrientAmount?> get amounts => {
    'energyKcal100': energyKcal100,
    'carbohydrates100': carbohydrates100,
    'fat100': fat100,
    'proteins100': proteins100,
    'sugars100': sugars100,
    'saturatedFat100': saturatedFat100,
    'fiber100': fiber100,
    'monounsaturatedFat100': monounsaturatedFat100,
    'polyunsaturatedFat100': polyunsaturatedFat100,
    'transFat100': transFat100,
    'cholesterol100': cholesterol100,
    'sodium100': sodium100,
    'potassium100': potassium100,
    'magnesium100': magnesium100,
    'calcium100': calcium100,
    'iron100': iron100,
    'zinc100': zinc100,
    'phosphorus100': phosphorus100,
    'vitaminA100': vitaminA100,
    'vitaminC100': vitaminC100,
    'vitaminD100': vitaminD100,
    'vitaminB6100': vitaminB6100,
    'vitaminB12100': vitaminB12100,
    'niacin100': niacin100,
    'thiamin100': thiamin100,
    'riboflavin100': riboflavin100,
    'pantothenicAcid100': pantothenicAcid100,
    'biotin100': biotin100,
    'folateDfe100': folateDfe100,
    'vitaminE100': vitaminE100,
    'vitaminK1100': vitaminK1100,
    'copper100': copper100,
    'manganese100': manganese100,
    'selenium100': selenium100,
    'iodine100': iodine100,
    'choline100': choline100,
    'omega3100': omega3100,
    'alphaLinolenicAcid100': alphaLinolenicAcid100,
    'epa100': epa100,
    'dha100': dha100,
    'omega6100': omega6100,
    'linoleicAcid100': linoleicAcid100,
    'addedSugars100': addedSugars100,
    'starch100': starch100,
    'caffeine100': caffeine100,
    'alcohol100': alcohol100,
    'histidine100': histidine100,
    'isoleucine100': isoleucine100,
    'leucine100': leucine100,
    'lysine100': lysine100,
    'methionine100': methionine100,
    'phenylalanine100': phenylalanine100,
    'threonine100': threonine100,
    'tryptophan100': tryptophan100,
    'valine100': valine100,
    'alanine100': alanine100,
    'arginine100': arginine100,
    'asparagine100': asparagine100,
    'asparticAcid100': asparticAcid100,
    'cysteine100': cysteine100,
    'cystine100': cystine100,
    'glutamicAcid100': glutamicAcid100,
    'glutamine100': glutamine100,
    'glycine100': glycine100,
    'hydroxyproline100': hydroxyproline100,
    'proline100': proline100,
    'serine100': serine100,
    'tyrosine100': tyrosine100,
  };

  @override
  List<Object?> get props => [amounts];
}

class NutrimentsValidationResult {
  final bool isConsistent;
  final String? failureReason;

  const NutrimentsValidationResult.ok()
    : isConsistent = true,
      failureReason = null;

  const NutrimentsValidationResult.failed(this.failureReason)
    : isConsistent = false;
}

/// Tolerance applied to weight-summation and subset-of comparisons. Source
/// data is typically rounded to 0.1g or 1g, and the per-nutrient values do
/// not always sum exactly; a small slack keeps us from dropping items that
/// are merely noisy rather than corrupt.
const double _nutrimentsValidationToleranceG = 1.0;

/// Returns true when [nutriments] passes the three physical-plausibility
/// rules from issue #222:
///
///   1. `sugars100 <= carbohydrates100` (sugars are a subset of carbs)
///   2. `saturatedFat100 <= fat100` (sat fat is a subset of total fat)
///   3. `carbohydrates100 + fat100 + proteins100 <= 100g` (per-100g basis)
///
/// A null on either side of a comparison skips the rule (we cannot prove a
/// violation without both values). A small tolerance absorbs rounding from
/// the source.
///
/// Convenience wrapper around [validateNutriments] for callers that only
/// need the pass/fail bit.
bool isNutrimentsConsistent(MealNutrimentsEntity nutriments) =>
    validateNutriments(nutriments).isConsistent;

/// Full validation result. Use this when you need the failing rule name —
/// for example, to log the reason at the call site that dropped the
/// item from search results.
NutrimentsValidationResult validateNutriments(MealNutrimentsEntity nutriments) {
  final sugars = nutriments.sugars100?.isQualified == false
      ? nutriments.sugars100!.value
      : null;
  final carbs = nutriments.carbohydrates100?.isQualified == false
      ? nutriments.carbohydrates100!.value
      : null;
  if (sugars != null &&
      carbs != null &&
      sugars > carbs + _nutrimentsValidationToleranceG) {
    return const NutrimentsValidationResult.failed('sugars_exceed_carbs');
  }

  final satFat = nutriments.saturatedFat100?.isQualified == false
      ? nutriments.saturatedFat100!.value
      : null;
  final fat = nutriments.fat100?.isQualified == false
      ? nutriments.fat100!.value
      : null;
  if (satFat != null &&
      fat != null &&
      satFat > fat + _nutrimentsValidationToleranceG) {
    return const NutrimentsValidationResult.failed(
      'saturated_fat_exceeds_total_fat',
    );
  }

  // Per-100g basis: the weight-bearing macros (carbs + fat + protein) cannot
  // sum to more than 100g. Fibre is intentionally excluded because it is
  // typically already inside the carbohydrate total in both FDC and OFF
  // accounting, so adding it would double-count. Micronutrients are in
  // mg/µg so they do not enter the sum.
  final protein = nutriments.proteins100?.isQualified == false
      ? nutriments.proteins100!.value
      : null;
  final macroSum = (carbs ?? 0) + (fat ?? 0) + (protein ?? 0);
  if (macroSum > 100 + _nutrimentsValidationToleranceG) {
    return const NutrimentsValidationResult.failed('macros_exceed_100g');
  }

  return const NutrimentsValidationResult.ok();
}

/// Maximum relative gap between declared and Atwater-computed energy before a
/// product is treated as data-incoherent for ranking. Deliberately generous:
/// across a sample of ~700 Open Food Facts products the legitimate noise floor
/// (energy/macro rounding, food-specific Atwater factors, the EU/US fibre-in-
/// carbs convention) reaches ~10-15%, while genuine data errors are gross
/// (77% to >20000%). 25% sits in the empty gap between the two, so it demotes
/// real errors without penalising correctly-entered data.
const double atwaterEnergyTolerance = 0.25;

/// Relative difference between the declared energy and the energy implied by
/// the macros via the general Atwater factors (carbs 4, protein 4, fat 9
/// kcal/g). Fibre is not added separately for the same reason the macro-sum
/// check omits it — it is already inside the carbohydrate total here.
///
/// Returns null when there is nothing to judge (no declared kcal, or none of
/// the three macros present); callers should treat null as "no opinion" rather
/// than as inconsistent, so products with sparse data are ranked on the other
/// signals instead of being penalised.
double? atwaterEnergyRelativeError(MealNutrimentsEntity nutriments) {
  final energy = nutriments.energyKcal100?.isQualified == false
      ? nutriments.energyKcal100!.value
      : null;
  if (energy == null || energy <= 0) return null;
  final carbs = nutriments.carbohydrates100?.isQualified == false
      ? nutriments.carbohydrates100!.value
      : null;
  final fat = nutriments.fat100?.isQualified == false
      ? nutriments.fat100!.value
      : null;
  final protein = nutriments.proteins100?.isQualified == false
      ? nutriments.proteins100!.value
      : null;
  if (carbs == null || fat == null || protein == null) return null;

  final computed = 4 * carbs + 4 * protein + 9 * fat;
  return (energy - computed).abs() / energy;
}

/// True when a product's declared energy is coherent with its macros (within
/// [atwaterEnergyTolerance]) or cannot be judged. False only for products that
/// are computable AND diverge beyond the tolerance — the gross-error outliers.
bool isAtwaterConsistent(MealNutrimentsEntity nutriments) {
  final error = atwaterEnergyRelativeError(nutriments);
  return error == null || error <= atwaterEnergyTolerance;
}
