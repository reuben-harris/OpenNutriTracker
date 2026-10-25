import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_nutriments_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  group('MealNutrimentsEntity.fromCatalogue', () {
    test('maps core macros correctly', () {
      final entity = MealNutrimentsEntity.fromCatalogue({
        'energyKcal100': 250,
        'carbohydrates100': 30,
        'fat100': 10,
        'proteins100': 15,
        'sugars100': 5,
        'saturatedFat100': 3,
        'fiber100': 2,
      });

      expect(entity.energyKcal100?.value, 250);
      expect(entity.carbohydrates100?.value, 30);
      expect(entity.fat100?.value, 10);
      expect(entity.proteins100?.value, 15);
      expect(entity.sugars100?.value, 5);
      expect(entity.saturatedFat100?.value, 3);
      expect(entity.fiber100?.value, 2);
    });

    test('maps all micronutrient fields correctly', () {
      final entity = MealNutrimentsEntity.fromCatalogue({
        'monounsaturatedFat100': 1.1,
        'polyunsaturatedFat100': 2.2,
        'transFat100': 0.5,
        'cholesterol100': 55,
        'sodium100': 120,
        'potassium100': 300,
        'magnesium100': 25,
        'calcium100': 100,
        'iron100': 2,
        'zinc100': 1,
        'phosphorus100': 150,
        'vitaminA100': 90,
        'vitaminC100': 45,
        'vitaminD100': 5,
        'vitaminB6100': 0.3,
        'vitaminB12100': 1.5,
        'niacin100': 8,
      });

      expect(entity.monounsaturatedFat100?.value, 1.1);
      expect(entity.polyunsaturatedFat100?.value, 2.2);
      expect(entity.transFat100?.value, 0.5);
      expect(entity.cholesterol100?.value, 55);
      expect(entity.sodium100?.value, 120);
      expect(entity.potassium100?.value, 300);
      expect(entity.magnesium100?.value, 25);
      expect(entity.calcium100?.value, 100);
      expect(entity.iron100?.value, 2);
      expect(entity.zinc100?.value, 1);
      expect(entity.phosphorus100?.value, 150);
      expect(entity.vitaminA100?.value, 90);
      expect(entity.vitaminC100?.value, 45);
      expect(entity.vitaminD100?.value, 5);
      expect(entity.vitaminB6100?.value, 0.3);
      expect(entity.vitaminB12100?.value, 1.5);
      expect(entity.niacin100?.value, 8);
    });

    test('absent micronutrients are null', () {
      final entity = MealNutrimentsEntity.fromCatalogue({'energyKcal100': 100});

      expect(entity.monounsaturatedFat100?.value, isNull);
      expect(entity.sodium100?.value, isNull);
      expect(entity.vitaminC100?.value, isNull);
    });
  });

  group('MealNutrimentsEntity.fromOffNutriments', () {
    OFFProductNutrimentsDTO buildDto({
      dynamic energyKcal,
      dynamic carbs,
      dynamic fat,
      dynamic proteins,
      dynamic sugars,
      dynamic saturatedFat,
      dynamic fiber,
      dynamic monounsaturatedFat,
      dynamic polyunsaturatedFat,
      dynamic transFat,
      dynamic cholesterol,
      dynamic sodium,
      dynamic potassium,
      dynamic magnesium,
      dynamic calcium,
      dynamic iron,
      dynamic zinc,
      dynamic phosphorus,
      dynamic vitaminA,
      dynamic vitaminC,
      dynamic vitaminD,
      dynamic vitaminB6,
      dynamic vitaminB12,
      dynamic niacin,
    }) => OFFProductNutrimentsDTO(
      energy_kcal_100g: energyKcal,
      carbohydrates_100g: carbs,
      fat_100g: fat,
      proteins_100g: proteins,
      sugars_100g: sugars,
      saturated_fat_100g: saturatedFat,
      fiber_100g: fiber,
      monounsaturated_fat_100g: monounsaturatedFat,
      polyunsaturated_fat_100g: polyunsaturatedFat,
      trans_fat_100g: transFat,
      cholesterol_100g: cholesterol,
      sodium_100g: sodium,
      potassium_100g: potassium,
      magnesium_100g: magnesium,
      calcium_100g: calcium,
      iron_100g: iron,
      zinc_100g: zinc,
      phosphorus_100g: phosphorus,
      vitamin_a_100g: vitaminA,
      vitamin_c_100g: vitaminC,
      vitamin_d_100g: vitaminD,
      vitamin_b6_100g: vitaminB6,
      vitamin_b12_100g: vitaminB12,
      niacin_100g: niacin,
    );

    test('maps core macros correctly', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(
          energyKcal: 200.0,
          carbs: 25.0,
          fat: 8.0,
          proteins: 12.0,
          sugars: 4.0,
          saturatedFat: 2.5,
          fiber: 3.0,
        ),
      );

      expect(entity.energyKcal100?.value, 200.0);
      expect(entity.carbohydrates100?.value, 25.0);
      expect(entity.fat100?.value, 8.0);
      expect(entity.proteins100?.value, 12.0);
      expect(entity.sugars100?.value, 4.0);
      expect(entity.saturatedFat100?.value, 2.5);
      expect(entity.fiber100?.value, 3.0);
    });

    test('handles integer values from OFF (dynamic type)', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(
          energyKcal: 200,
          carbs: 25,
          fat: 8,
          proteins: 12,
          sugars: 4,
          saturatedFat: 2,
          fiber: 3,
        ),
      );

      expect(entity.energyKcal100?.value, 200.0);
      expect(entity.carbohydrates100?.value, 25.0);
    });

    test('handles string values from OFF (dynamic type)', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(
          energyKcal: '200',
          carbs: '25',
          fat: '8',
          proteins: '12',
          sugars: null,
          saturatedFat: null,
          fiber: null,
        ),
      );

      expect(entity.energyKcal100?.value, 200.0);
      expect(entity.carbohydrates100?.value, 25.0);
    });

    // Every value below is what Open Food Facts actually sends: it normalises
    // each `<nutrient>_100g` field to grams, whatever unit the label used.
    // The expectations are the app's own units, so this is the conversion
    // #716 was missing, read in both directions at once.
    test('converts micronutrients out of the grams OFF sends them in', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(
          energyKcal: 0,
          carbs: 0,
          fat: 0,
          proteins: 0,
          sugars: 0,
          saturatedFat: 0,
          fiber: 0,
          monounsaturatedFat: 1.1,
          polyunsaturatedFat: 2.2,
          transFat: 0.5,
          cholesterol: 0.055,
          sodium: 0.12,
          potassium: 0.3,
          magnesium: 0.025,
          calcium: 0.1,
          iron: 0.002,
          zinc: 0.001,
          phosphorus: 0.15,
          vitaminA: 0.00009,
          vitaminC: 0.045,
          vitaminD: 0.000005,
          vitaminB6: 0.0003,
          vitaminB12: 0.0000015,
          niacin: 0.008,
        ),
      );

      // Lipids are grams on both sides, so they pass straight through.
      expect(entity.monounsaturatedFat100?.value, 1.1);
      expect(entity.polyunsaturatedFat100?.value, 2.2);
      expect(entity.transFat100?.value, 0.5);
      // Milligrams from here down.
      expect(entity.cholesterol100?.value, 55.0);
      expect(entity.sodium100?.value, 120.0);
      expect(entity.potassium100?.value, 300.0);
      expect(entity.magnesium100?.value, 25.0);
      expect(entity.calcium100?.value, 100.0);
      expect(entity.iron100?.value, 2.0);
      expect(entity.zinc100?.value, 1.0);
      expect(entity.phosphorus100?.value, 150.0);
      // Micrograms for A, D and B12; the rest of the vitamins are milligrams.
      expect(entity.vitaminA100?.value, 90.0);
      expect(entity.vitaminC100?.value, 45.0);
      expect(entity.vitaminD100?.value, 5.0);
      expect(entity.vitaminB6100?.value, 0.3);
      expect(entity.vitaminB12100?.value, 1.5);
      expect(entity.niacin100?.value, 8.0);
    });

    // Values copied from live OFF responses rather than invented, so the
    // fixture cannot drift away from what the API really sends: iron for
    // barcode 3168930010265 and sodium for 3017620422003, both reported with
    // `_unit: "g"`.
    test('matches what the live OFF API returns for real barcodes', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(iron: 0.0021, sodium: 0.0428),
      );

      expect(entity.iron100?.value, closeTo(2.1, 1e-9));
      expect(entity.sodium100?.value, closeTo(42.8, 1e-9));
    });

    // The point of #716 in one assertion: the same food should read the same
    // whichever database it came from. Before the conversion the OFF entity
    // was a thousand times smaller than the FDC one on every mineral, and a
    // million times smaller on vitamins A, D and B12.
    test('agrees with the FDC mapping for the same food', () {
      final fromOff = MealNutrimentsEntity.fromOffNutriments(
        buildDto(
          cholesterol: 0.055,
          sodium: 0.12,
          potassium: 0.3,
          magnesium: 0.025,
          calcium: 0.1,
          iron: 0.002,
          zinc: 0.001,
          phosphorus: 0.15,
          vitaminA: 0.00009,
          vitaminC: 0.045,
          vitaminD: 0.000005,
          vitaminB6: 0.0003,
          vitaminB12: 0.0000015,
          niacin: 0.008,
        ),
      );
      final fromFdc = MealNutrimentsEntity.fromCatalogue({
        'cholesterol100': 55,
        'sodium100': 120,
        'potassium100': 300,
        'magnesium100': 25,
        'calcium100': 100,
        'iron100': 2,
        'zinc100': 1,
        'phosphorus100': 150,
        'vitaminA100': 90,
        'vitaminC100': 45,
        'vitaminD100': 5,
        'vitaminB6100': 0.3,
        'vitaminB12100': 1.5,
        'niacin100': 8,
      });

      expect(fromOff.cholesterol100?.value, fromFdc.cholesterol100?.value);
      expect(fromOff.sodium100?.value, fromFdc.sodium100?.value);
      expect(fromOff.potassium100?.value, fromFdc.potassium100?.value);
      expect(fromOff.magnesium100?.value, fromFdc.magnesium100?.value);
      expect(fromOff.calcium100?.value, fromFdc.calcium100?.value);
      expect(fromOff.iron100?.value, fromFdc.iron100?.value);
      expect(fromOff.zinc100?.value, fromFdc.zinc100?.value);
      expect(fromOff.phosphorus100?.value, fromFdc.phosphorus100?.value);
      expect(fromOff.vitaminA100?.value, fromFdc.vitaminA100?.value);
      expect(fromOff.vitaminC100?.value, fromFdc.vitaminC100?.value);
      expect(fromOff.vitaminD100?.value, fromFdc.vitaminD100?.value);
      expect(fromOff.vitaminB6100?.value, fromFdc.vitaminB6100?.value);
      expect(fromOff.vitaminB12100?.value, fromFdc.vitaminB12100?.value);
      expect(fromOff.niacin100?.value, fromFdc.niacin100?.value);
    });

    // A declared zero is a fact about the food and has to survive the
    // conversion as a zero, not become a null the panel then ignores.
    test('keeps a declared zero as zero rather than null', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(sodium: 0, vitaminD: 0.0),
      );

      expect(entity.sodium100?.value, 0.0);
      expect(entity.vitaminD100?.value, 0.0);
    });

    test('absent micronutrients are null', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(
          energyKcal: 100,
          carbs: 10,
          fat: 5,
          proteins: 5,
          sugars: 2,
          saturatedFat: 1,
          fiber: 1,
        ),
      );

      expect(entity.monounsaturatedFat100?.value, isNull);
      expect(entity.sodium100?.value, isNull);
      expect(entity.vitaminC100?.value, isNull);
      expect(entity.vitaminD100?.value, isNull);
    });

    test('returns empty entity when DTO is null', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(null);
      expect(entity.energyKcal100?.value, isNull);
      expect(entity.carbohydrates100?.value, isNull);
    });
  });

  group('MealNutrimentsEntity.fromMealNutrimentsDBO (#1254)', () {
    test('reads NaN and infinite values back as null', () {
      // What a custom meal saved with a base quantity of 0 stored: every
      // typed 0 became NaN, every other value infinity.
      final entity = MealNutrimentsEntity.fromMealNutrimentsDBO(
        MealNutrimentsDBO(
          energyKcal100: NutrientAmount.fromNumber(double.nan),
          carbohydrates100: NutrientAmount.fromNumber(double.infinity),
          fat100: NutrientAmount.fromNumber(double.negativeInfinity),
          proteins100: NutrientAmount.fromNumber(double.nan),
          sugars100: NutrientAmount.fromNumber(double.nan),
          saturatedFat100: NutrientAmount.fromNumber(double.nan),
          fiber100: NutrientAmount.fromNumber(double.nan),
          sodium100: NutrientAmount.fromNumber(double.nan),
        ),
      );

      expect(entity.energyKcal100?.value, isNull);
      expect(entity.carbohydrates100?.value, isNull);
      expect(entity.fat100?.value, isNull);
      expect(entity.proteins100?.value, isNull);
      expect(entity.sugars100?.value, isNull);
      expect(entity.saturatedFat100?.value, isNull);
      expect(entity.fiber100?.value, isNull);
      expect(entity.sodium100?.value, isNull);
      expect(entity.energyPerUnit?.value, isNull);
    });

    test('keeps finite values, zero included', () {
      final entity = MealNutrimentsEntity.fromMealNutrimentsDBO(
        MealNutrimentsDBO(
          energyKcal100: NutrientAmount(0),
          carbohydrates100: NutrientAmount(30),
          fat100: NutrientAmount(10),
          proteins100: NutrientAmount(15),
          sugars100: null,
          saturatedFat100: NutrientAmount(3),
          fiber100: NutrientAmount(2),
        ),
      );

      expect(entity.energyKcal100?.value, 0);
      expect(entity.carbohydrates100?.value, 30);
      expect(entity.fat100?.value, 10);
      expect(entity.proteins100?.value, 15);
      expect(entity.sugars100?.value, isNull);
      expect(entity.saturatedFat100?.value, 3);
      expect(entity.fiber100?.value, 2);
    });
  });
}
