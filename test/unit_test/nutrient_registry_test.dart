import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/core/utils/csv_meal_importer.dart';
import 'package:opennutritracker/core/utils/csv_recipe_importer.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import '../fixture/diary_entry_fixtures.dart';

RecipeIngredientEntity ingredient(MealNutrimentsEntity amounts) =>
    RecipeIngredientEntity(
      snapshotMeal: nutrientFood(amounts),
      quantity: FoodAmountSelection(
        100,
        FoodAmountOption.standard(FoodAmountUnit.g),
      ),
    );

void main() {
  test('all supported fields have one definition and survive JSON storage', () {
    expect(Nutrients.all, hasLength(68));
    expect(Nutrients.additional, hasLength(64));
    expect(
      Nutrients.all.map((n) => n.field).toSet(),
      MealNutrimentsEntity.empty().amounts.keys.toSet(),
    );
    const source = NutrientAmount(
      0.00000123456789,
      qualification: NutrientQualification.lessThan,
      limit: 0.000002,
      isPartial: true,
    );
    final amounts = MealNutrimentsEntity.fromAmounts({
      for (final n in Nutrients.all) n.field: source,
    });
    final dbo = MealNutrimentsDBO.fromProductNutrimentsEntity(amounts);
    final stored = MealNutrimentsEntity.fromMealNutrimentsDBO(
      MealNutrimentsDBO.fromJson(
        jsonDecode(jsonEncode(dbo)) as Map<String, dynamic>,
      ),
    );
    for (final n in Nutrients.all) {
      expect(n.amount(stored), source, reason: n.key);
    }
  });
  test(
    'meal and recipe CSV imports retain decimal commas and source qualifications',
    () {
      final meal = CsvMealImporter.parse(
        'name,kcal_per_100g,sugars_per_100g,selenium_per_100g\n'
        'Food,100,"1,5","<0,00123"\n',
      ).meals.single;
      expect(meal.nutriments.sugars100, const NutrientAmount(1.5));
      expect(
        meal.nutriments.selenium100,
        const NutrientAmount(
          0.00123,
          qualification: NutrientQualification.lessThan,
        ),
      );
      final recipe = CsvRecipeImporter.parse(
        'recipe_name,ingredient_name,ingredient_amount,ingredient_unit,ingredient_kcal_100,ingredient_selenium_per_100g\n'
        'Recipe,Food,100,g,100,"<0,00123"\n',
      ).recipes.single;
      expect(recipe.aggregatedNutrimentsPer100.selenium100!.value, 0.00123);
      expect(
        recipe.aggregatedNutrimentsPer100.selenium100!.isQualified,
        isTrue,
      );
    },
  );
  test(
    'CSV backup retains every expanded field, qualification and partial flag',
    () {
      const source = NutrientAmount(
        0.00000123456789,
        qualification: NutrientQualification.approximate,
        isPartial: true,
      );
      final nutrition = MealNutrimentsEntity.fromAmounts({
        for (final n in Nutrients.all) n.field: source,
      });
      final original = IntakeDBO.fromIntakeEntity(diaryEntry());
      original.meal = MealDBO.fromMealEntity(nutrientFood(nutrition));
      final csv = CsvDataExporter.intakesToCsv([original]);
      final restored = MealNutrimentsEntity.fromMealNutrimentsDBO(
        CsvDataExporter.parseIntakesFromCsv(csv).single.meal.nutriments,
      );
      for (final n in Nutrients.all) {
        expect(n.amount(restored), source, reason: n.key);
      }
    },
  );
  test(
    'partial recipes retain known values and qualifications through nesting',
    () {
      const value = NutrientAmount(
        0.001,
        qualification: NutrientQualification.approximate,
      );
      final input = MealNutrimentsEntity.fromAmounts({'selenium100': value});
      final compute = ComputeRecipeNutritionUseCase();
      final first = compute.compute([
        ingredient(input),
        ingredient(MealNutrimentsEntity.empty()),
      ], cookedWeightG: 100);
      final selenium = first.perHundredG.selenium100!;
      expect(selenium.value, 0.001);
      expect(selenium.isPartial, isTrue);
      expect(selenium.isQualified, isTrue);
      expect(first.perHundredG.iodine100, isNull);
      final nested = compute.compute([
        ingredient(first.perHundredG),
      ], cookedWeightG: 200);
      expect(nested.perHundredG.selenium100!.value, 0.0005);
      expect(nested.perHundredG.selenium100!.isPartial, isTrue);
    },
  );
  test('missing, zero, trace and partial are separate states', () {
    expect((NutrientAccumulator()..add(null)).total, isNull);
    final zero = (NutrientAccumulator()..add(const NutrientAmount(0))).total!;
    expect(zero.value, 0);
    expect(zero.isPartial, isFalse);
    const trace = NutrientAmount(0, qualification: NutrientQualification.trace);
    final mixed =
        (NutrientAccumulator()
              ..add(trace)
              ..add(null))
            .total!;
    expect(mixed.qualification, NutrientQualification.trace);
    expect(mixed.isPartial, isTrue);
  });
}
