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

      expect(entity.energyKcal100, 250);
      expect(entity.carbohydrates100, 30);
      expect(entity.fat100, 10);
      expect(entity.proteins100, 15);
      expect(entity.sugars100, 5);
      expect(entity.saturatedFat100, 3);
      expect(entity.fiber100, 2);
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

      expect(entity.monounsaturatedFat100, 1.1);
      expect(entity.polyunsaturatedFat100, 2.2);
      expect(entity.transFat100, 0.5);
      expect(entity.cholesterol100, 55);
      expect(entity.sodium100, 120);
      expect(entity.potassium100, 300);
      expect(entity.magnesium100, 25);
      expect(entity.calcium100, 100);
      expect(entity.iron100, 2);
      expect(entity.zinc100, 1);
      expect(entity.phosphorus100, 150);
      expect(entity.vitaminA100, 90);
      expect(entity.vitaminC100, 45);
      expect(entity.vitaminD100, 5);
      expect(entity.vitaminB6100, 0.3);
      expect(entity.vitaminB12100, 1.5);
      expect(entity.niacin100, 8);
    });

    test('absent micronutrients are null', () {
      final entity = MealNutrimentsEntity.fromCatalogue({'energyKcal100': 100});

      expect(entity.monounsaturatedFat100, isNull);
      expect(entity.sodium100, isNull);
      expect(entity.vitaminC100, isNull);
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

      expect(entity.energyKcal100, 200.0);
      expect(entity.carbohydrates100, 25.0);
      expect(entity.fat100, 8.0);
      expect(entity.proteins100, 12.0);
      expect(entity.sugars100, 4.0);
      expect(entity.saturatedFat100, 2.5);
      expect(entity.fiber100, 3.0);
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

      expect(entity.energyKcal100, 200.0);
      expect(entity.carbohydrates100, 25.0);
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

      expect(entity.energyKcal100, 200.0);
      expect(entity.carbohydrates100, 25.0);
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
      expect(entity.monounsaturatedFat100, 1.1);
      expect(entity.polyunsaturatedFat100, 2.2);
      expect(entity.transFat100, 0.5);
      // Milligrams from here down.
      expect(entity.cholesterol100, 55.0);
      expect(entity.sodium100, 120.0);
      expect(entity.potassium100, 300.0);
      expect(entity.magnesium100, 25.0);
      expect(entity.calcium100, 100.0);
      expect(entity.iron100, 2.0);
      expect(entity.zinc100, 1.0);
      expect(entity.phosphorus100, 150.0);
      // Micrograms for A, D and B12; the rest of the vitamins are milligrams.
      expect(entity.vitaminA100, 90.0);
      expect(entity.vitaminC100, 45.0);
      expect(entity.vitaminD100, 5.0);
      expect(entity.vitaminB6100, 0.3);
      expect(entity.vitaminB12100, 1.5);
      expect(entity.niacin100, 8.0);
    });

    // Values copied from live OFF responses rather than invented, so the
    // fixture cannot drift away from what the API really sends: iron for
    // barcode 3168930010265 and sodium for 3017620422003, both reported with
    // `_unit: "g"`.
    test('matches what the live OFF API returns for real barcodes', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(iron: 0.0021, sodium: 0.0428),
      );

      expect(entity.iron100, closeTo(2.1, 1e-9));
      expect(entity.sodium100, closeTo(42.8, 1e-9));
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

      expect(fromOff.cholesterol100, fromFdc.cholesterol100);
      expect(fromOff.sodium100, fromFdc.sodium100);
      expect(fromOff.potassium100, fromFdc.potassium100);
      expect(fromOff.magnesium100, fromFdc.magnesium100);
      expect(fromOff.calcium100, fromFdc.calcium100);
      expect(fromOff.iron100, fromFdc.iron100);
      expect(fromOff.zinc100, fromFdc.zinc100);
      expect(fromOff.phosphorus100, fromFdc.phosphorus100);
      expect(fromOff.vitaminA100, fromFdc.vitaminA100);
      expect(fromOff.vitaminC100, fromFdc.vitaminC100);
      expect(fromOff.vitaminD100, fromFdc.vitaminD100);
      expect(fromOff.vitaminB6100, fromFdc.vitaminB6100);
      expect(fromOff.vitaminB12100, fromFdc.vitaminB12100);
      expect(fromOff.niacin100, fromFdc.niacin100);
    });

    // A declared zero is a fact about the food and has to survive the
    // conversion as a zero, not become a null the panel then ignores.
    test('keeps a declared zero as zero rather than null', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(
        buildDto(sodium: 0, vitaminD: 0.0),
      );

      expect(entity.sodium100, 0.0);
      expect(entity.vitaminD100, 0.0);
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

      expect(entity.monounsaturatedFat100, isNull);
      expect(entity.sodium100, isNull);
      expect(entity.vitaminC100, isNull);
      expect(entity.vitaminD100, isNull);
    });

    test('returns empty entity when DTO is null', () {
      final entity = MealNutrimentsEntity.fromOffNutriments(null);
      expect(entity.energyKcal100, isNull);
      expect(entity.carbohydrates100, isNull);
    });
  });

  group('MealNutrimentsEntity.hasMicronutrientData', () {
    test('returns false when all micronutrients are null', () {
      const entity = MealNutrimentsEntity(
        energyKcal100: 200,
        carbohydrates100: 30,
        fat100: 10,
        proteins100: 15,
        sugars100: 5,
        saturatedFat100: 3,
        fiber100: 2,
      );
      expect(entity.hasMicronutrientData, isFalse);
    });

    test('returns true when any micronutrient is non-null', () {
      const entity = MealNutrimentsEntity(
        energyKcal100: 200,
        carbohydrates100: 30,
        fat100: 10,
        proteins100: 15,
        sugars100: 5,
        saturatedFat100: 3,
        fiber100: 2,
        sodium100: 120,
      );
      expect(entity.hasMicronutrientData, isTrue);
    });

    test('returns false for empty entity', () {
      final entity = MealNutrimentsEntity.empty();
      expect(entity.hasMicronutrientData, isFalse);
    });
  });

  group('MealNutrimentsEntity.fromMealNutrimentsDBO (#1254)', () {
    test('reads NaN and infinite values back as null', () {
      // What a custom meal saved with a base quantity of 0 stored: every
      // typed 0 became NaN, every other value infinity.
      final entity = MealNutrimentsEntity.fromMealNutrimentsDBO(
        MealNutrimentsDBO(
          energyKcal100: double.nan,
          carbohydrates100: double.infinity,
          fat100: double.negativeInfinity,
          proteins100: double.nan,
          sugars100: double.nan,
          saturatedFat100: double.nan,
          fiber100: double.nan,
          sodium100: double.nan,
        ),
      );

      expect(entity.energyKcal100, isNull);
      expect(entity.carbohydrates100, isNull);
      expect(entity.fat100, isNull);
      expect(entity.proteins100, isNull);
      expect(entity.sugars100, isNull);
      expect(entity.saturatedFat100, isNull);
      expect(entity.fiber100, isNull);
      expect(entity.sodium100, isNull);
      expect(entity.energyPerUnit, isNull);
    });

    test('keeps finite values, zero included', () {
      final entity = MealNutrimentsEntity.fromMealNutrimentsDBO(
        MealNutrimentsDBO(
          energyKcal100: 0,
          carbohydrates100: 30,
          fat100: 10,
          proteins100: 15,
          sugars100: null,
          saturatedFat100: 3,
          fiber100: 2,
        ),
      );

      expect(entity.energyKcal100, 0);
      expect(entity.carbohydrates100, 30);
      expect(entity.fat100, 10);
      expect(entity.proteins100, 15);
      expect(entity.sugars100, isNull);
      expect(entity.saturatedFat100, 3);
      expect(entity.fiber100, 2);
    });
  });
}
