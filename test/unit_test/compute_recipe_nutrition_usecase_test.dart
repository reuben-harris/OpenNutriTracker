import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

MealEntity _meal({
  String code = '1',
  required MealNutrimentsEntity nutriments,
  double? servingQuantity,
}) {
  return MealEntity(
    code: code,
    name: 'test',
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: servingQuantity,
    servingUnit: servingQuantity != null ? 'g' : null,
    servingSize: null,
    nutriments: nutriments,
    source: MealSourceEntity.custom,
  );
}

MealNutrimentsEntity _nutr({
  double? kcal,
  double? carbs,
  double? fat,
  double? protein,
  double? sugar,
  double? satFat,
  double? fiber,
  double? sodium,
  double? iron,
}) {
  return MealNutrimentsEntity(
    energyKcal100: NutrientAmount.fromNumber(kcal),
    carbohydrates100: NutrientAmount.fromNumber(carbs),
    fat100: NutrientAmount.fromNumber(fat),
    proteins100: NutrientAmount.fromNumber(protein),
    sugars100: NutrientAmount.fromNumber(sugar),
    saturatedFat100: NutrientAmount.fromNumber(satFat),
    fiber100: NutrientAmount.fromNumber(fiber),
    sodium100: NutrientAmount.fromNumber(sodium),
    iron100: NutrientAmount.fromNumber(iron),
  );
}

RecipeIngredientEntity _ingredient(
  MealEntity meal,
  double amount,
  String unit,
  double convertedG,
) {
  return RecipeIngredientEntity(
    snapshotMeal: meal,
    quantity: FoodAmountSelection.fromSnapshot(
      amount: amount,
      unit: unit,
      baseUnit: 'g',
      factor: (convertedG) / (amount),
    ),
  );
}

void main() {
  late ComputeRecipeNutritionUseCase useCase;

  setUp(() {
    useCase = ComputeRecipeNutritionUseCase();
  });

  for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
    test('invalid cooked weight $invalid is rejected rather than replaced', () {
      final flour = _meal(nutriments: _nutr(kcal: 200));
      expect(
        () => useCase.compute([
          _ingredient(flour, 100, 'g', 100),
        ], cookedWeightG: invalid),
        throwsFormatException,
      );
    });
  }

  group('compute', () {
    test('empty ingredient list returns empty + zero weight', () {
      final result = useCase.compute([]);

      expect(result.totalWeightG, 0);
      expect(result.perHundredG.energyKcal100?.value, isNull);
      expect(result.perHundredG.carbohydrates100?.value, isNull);
    });

    test('single ingredient passes through unchanged at per-100g', () {
      // 100 g of a 200 kcal/100g food → recipe per-100g = 200 kcal
      final flour = _meal(nutriments: _nutr(kcal: 200, carbs: 70, protein: 10));
      final result = useCase.compute([_ingredient(flour, 100, 'g', 100)]);

      expect(result.totalWeightG, 100);
      expect(result.perHundredG.energyKcal100?.value, closeTo(200, 0.001));
      expect(result.perHundredG.carbohydrates100?.value, closeTo(70, 0.001));
      expect(result.perHundredG.proteins100?.value, closeTo(10, 0.001));
    });

    test('two solid ingredients aggregate correctly', () {
      // 50 g flour @ 340 kcal/100g + 50 g sugar @ 390 kcal/100g
      // total kcal: 170 + 195 = 365 over 100 g → per-100g = 365
      final flour = _meal(code: 'flour', nutriments: _nutr(kcal: 340));
      final sugar = _meal(code: 'sugar', nutriments: _nutr(kcal: 390));
      final result = useCase.compute([
        _ingredient(flour, 50, 'g', 50),
        _ingredient(sugar, 50, 'g', 50),
      ]);

      expect(result.totalWeightG, 100);
      expect(result.perHundredG.energyKcal100?.value, closeTo(365, 0.001));
    });

    test('mixed g + ml (1:1) aggregates correctly', () {
      // 100 g flour @ 340 + 100 ml milk @ 60 (treated as 100 g)
      // total kcal: 340 + 60 = 400 over 200 g → per-100g = 200
      final flour = _meal(code: 'flour', nutriments: _nutr(kcal: 340));
      final milk = _meal(code: 'milk', nutriments: _nutr(kcal: 60));
      final result = useCase.compute([
        _ingredient(flour, 100, 'g', 100),
        _ingredient(milk, 100, 'ml', 100),
      ]);

      expect(result.totalWeightG, 200);
      expect(result.perHundredG.energyKcal100?.value, closeTo(200, 0.001));
    });

    test('cookedWeightG rescales per-100g', () {
      // 800 g of dough at 200 kcal/100g (1600 kcal total) baked down to 720 g
      // → per-100g = 1600 × 100 / 720 ≈ 222.22
      final dough = _meal(nutriments: _nutr(kcal: 200));
      final result = useCase.compute([
        _ingredient(dough, 800, 'g', 800),
      ], cookedWeightG: 720);

      expect(result.totalWeightG, 720);
      expect(result.perHundredG.energyKcal100?.value, closeTo(222.22, 0.01));
    });

    test(
      'null nutrient field treated as 0 in sum, but null preserved when ALL ingredients null',
      () {
        // ingredient A has iron, B has null iron
        // → recipe iron = (5 mg × 50 g + 0 × 50 g) × 100 / 100 = 2.5 mg
        final a = _meal(code: 'a', nutriments: _nutr(kcal: 100, iron: 5));
        final b = _meal(code: 'b', nutriments: _nutr(kcal: 100));
        final result = useCase.compute([
          _ingredient(a, 50, 'g', 50),
          _ingredient(b, 50, 'g', 50),
        ]);

        expect(result.perHundredG.iron100?.value, closeTo(2.5, 0.001));
      },
    );

    test('all ingredients null for a field → recipe field also null', () {
      final a = _meal(code: 'a', nutriments: _nutr(kcal: 100));
      final b = _meal(code: 'b', nutriments: _nutr(kcal: 100));
      final result = useCase.compute([
        _ingredient(a, 50, 'g', 50),
        _ingredient(b, 50, 'g', 50),
      ]);

      // None of the ingredients had iron data → recipe iron is null too,
      // not 0 (preserves "hide unknown micros" UI behaviour).
      expect(result.perHundredG.iron100?.value, isNull);
      expect(result.perHundredG.vitaminA100?.value, isNull);
    });

    test(
      'full-nutrient coverage: every MealNutrimentsEntity field aggregates',
      () {
        // Three ingredients each populating all 24 fields with the same value v.
        // The weighted-mean of identical values is the same value back —
        // ensures every field is summed (not just kcal/carbs/fat/protein).
        const v = 10.0;
        final fullN = MealNutrimentsEntity(
          energyKcal100: NutrientAmount.fromNumber(v),
          carbohydrates100: NutrientAmount.fromNumber(v),
          fat100: NutrientAmount.fromNumber(v),
          proteins100: NutrientAmount.fromNumber(v),
          sugars100: NutrientAmount.fromNumber(v),
          saturatedFat100: NutrientAmount.fromNumber(v),
          fiber100: NutrientAmount.fromNumber(v),
          monounsaturatedFat100: NutrientAmount.fromNumber(v),
          polyunsaturatedFat100: NutrientAmount.fromNumber(v),
          transFat100: NutrientAmount.fromNumber(v),
          cholesterol100: NutrientAmount.fromNumber(v),
          sodium100: NutrientAmount.fromNumber(v),
          potassium100: NutrientAmount.fromNumber(v),
          magnesium100: NutrientAmount.fromNumber(v),
          calcium100: NutrientAmount.fromNumber(v),
          iron100: NutrientAmount.fromNumber(v),
          zinc100: NutrientAmount.fromNumber(v),
          phosphorus100: NutrientAmount.fromNumber(v),
          vitaminA100: NutrientAmount.fromNumber(v),
          vitaminC100: NutrientAmount.fromNumber(v),
          vitaminD100: NutrientAmount.fromNumber(v),
          vitaminB6100: NutrientAmount.fromNumber(v),
          vitaminB12100: NutrientAmount.fromNumber(v),
          niacin100: NutrientAmount.fromNumber(v),
        );
        final m1 = _meal(code: 'a', nutriments: fullN);
        final m2 = _meal(code: 'b', nutriments: fullN);
        final m3 = _meal(code: 'c', nutriments: fullN);
        final result = useCase.compute([
          _ingredient(m1, 100, 'g', 100),
          _ingredient(m2, 50, 'g', 50),
          _ingredient(m3, 50, 'g', 50),
        ]);

        final p = result.perHundredG;
        // Every field must equal v (weighted mean of identical values).
        expect(p.energyKcal100?.value, closeTo(v, 0.001));
        expect(p.carbohydrates100?.value, closeTo(v, 0.001));
        expect(p.fat100?.value, closeTo(v, 0.001));
        expect(p.proteins100?.value, closeTo(v, 0.001));
        expect(p.sugars100?.value, closeTo(v, 0.001));
        expect(p.saturatedFat100?.value, closeTo(v, 0.001));
        expect(p.fiber100?.value, closeTo(v, 0.001));
        expect(p.monounsaturatedFat100?.value, closeTo(v, 0.001));
        expect(p.polyunsaturatedFat100?.value, closeTo(v, 0.001));
        expect(p.transFat100?.value, closeTo(v, 0.001));
        expect(p.cholesterol100?.value, closeTo(v, 0.001));
        expect(p.sodium100?.value, closeTo(v, 0.001));
        expect(p.potassium100?.value, closeTo(v, 0.001));
        expect(p.magnesium100?.value, closeTo(v, 0.001));
        expect(p.calcium100?.value, closeTo(v, 0.001));
        expect(p.iron100?.value, closeTo(v, 0.001));
        expect(p.zinc100?.value, closeTo(v, 0.001));
        expect(p.phosphorus100?.value, closeTo(v, 0.001));
        expect(p.vitaminA100?.value, closeTo(v, 0.001));
        expect(p.vitaminC100?.value, closeTo(v, 0.001));
        expect(p.vitaminD100?.value, closeTo(v, 0.001));
        expect(p.vitaminB6100?.value, closeTo(v, 0.001));
        expect(p.vitaminB12100?.value, closeTo(v, 0.001));
        expect(p.niacin100?.value, closeTo(v, 0.001));
      },
    );
  });
}
