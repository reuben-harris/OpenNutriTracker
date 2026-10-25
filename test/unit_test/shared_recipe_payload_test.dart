import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/recipes/domain/entity/shared_recipe_payload.dart';

RecipeEntity _testRecipe() {
  final flour = MealEntity(
    code: 'flour',
    name: 'Flour',
    brands: 'King Arthur',
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: NutrientAmount(340),
      carbohydrates100: NutrientAmount(70),
      fat100: NutrientAmount(1),
      proteins100: NutrientAmount(10),
      sugars100: NutrientAmount(0),
      saturatedFat100: NutrientAmount(0),
      fiber100: NutrientAmount(3),
    ),
    source: MealSourceEntity.off,
    thumbnailImageUrl: 'https://example.com/flour.jpg',
  );
  final sugar = MealEntity(
    code: 'sugar',
    name: 'Sugar',
    brands: null,
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: NutrientAmount(390),
      carbohydrates100: NutrientAmount(100),
      fat100: NutrientAmount(0),
      proteins100: NutrientAmount(0),
      sugars100: NutrientAmount(100),
      saturatedFat100: NutrientAmount(0),
      fiber100: NutrientAmount(0),
    ),
    source: MealSourceEntity.off,
  );
  return RecipeEntity(
    id: 'recipe-1',
    name: 'Vanilla Cake',
    description: 'A simple cake',
    ingredients: [
      RecipeIngredientEntity(
        snapshotMeal: flour,
        quantity: FoodAmountSelection.fromSnapshot(
          amount: 200,
          unit: 'g',
          baseUnit: 'g',
          factor: (200) / (200),
        ),
      ),
      RecipeIngredientEntity(
        snapshotMeal: sugar,
        quantity: FoodAmountSelection.fromSnapshot(
          amount: 100,
          unit: 'g',
          baseUnit: 'g',
          factor: (100) / (100),
        ),
      ),
    ],
    totalWeightG: 300,
    aggregatedNutrimentsPer100: MealNutrimentsEntity(
      energyKcal100: NutrientAmount(356.7),
      carbohydrates100: NutrientAmount(80),
      fat100: NutrientAmount(0.7),
      proteins100: NutrientAmount(6.7),
      sugars100: NutrientAmount(33.3),
      saturatedFat100: NutrientAmount(0),
      fiber100: NutrientAmount(2),
    ),
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 2),
    servingsCount: 8,
  );
}

// Note: RecipeEntity tags default to const [], so we don't pass them above.

void main() {
  for (final cookedWeight in [null, 0.0123456789, 250.123456789, 300.0]) {
    test('sharing preserves explicit cooked weight $cookedWeight', () {
      final recipe = _testRecipe().copyWith(
        cookedWeightG: cookedWeight,
        totalWeightG: cookedWeight ?? 300,
      );
      final payload = SharedRecipePayload.fromRecipe(recipe);
      final restored = SharedRecipePayload.fromJsonString(
        payload.toJsonString(),
      ).toRecipeEntity();
      expect(restored.cookedWeightG, cookedWeight);
      expect(restored.totalWeightG, recipe.totalWeightG);
    });
  }

  test(
    'invalid cooked weights and the previous sharing version are rejected',
    () {
      final payload = SharedRecipePayload.fromRecipe(
        _testRecipe(),
      ).toJsonArray();
      payload[0] = 2;
      expect(
        () => SharedRecipePayload.fromJsonArray(payload),
        throwsA(isA<SharedRecipeParseException>()),
      );
      payload[0] = 3;
      for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
        payload[7] = invalid;
        expect(
          () => SharedRecipePayload.fromJsonArray(payload),
          throwsA(isA<SharedRecipeParseException>()),
        );
      }
    },
  );

  test('portion snapshots survive sharing at full precision', () {
    const quantity = FoodAmountSelection(
      2.123456789,
      FoodAmountOption(
        unit: 'portion:slice',
        baseUnit: 'g',
        factor: 38.123456789,
        label: '1 slice',
      ),
    );
    final recipe = _testRecipe();
    final ingredient = recipe.ingredients.first.copyWith(quantity: quantity);
    final shared = SharedRecipePayload.fromRecipe(
      recipe.copyWith(ingredients: [ingredient]),
    );
    final restored = SharedRecipePayload.fromJsonString(
      shared.toJsonString(),
    ).toRecipeEntity();
    expect(restored.ingredients.single.quantity, quantity);
    expect(
      restored.ingredients.single.quantity.baseAmount,
      quantity.baseAmount,
    );
    expect(restored.ingredients.single.snapshotMeal.portions, isEmpty);
  });
  test(
    'previous recipe payload version and invalid snapshots are rejected',
    () {
      final payload = SharedRecipePayload.fromRecipe(
        _testRecipe(),
      ).toJsonArray();
      payload[0] = 1;
      expect(
        () => SharedRecipePayload.fromJsonArray(payload),
        throwsA(isA<SharedRecipeParseException>()),
      );
      final invalid = SharedRecipePayload.fromRecipe(
        _testRecipe(),
      ).toJsonArray();
      ((invalid[6] as List).first as List)[2] = {
        'amount': 1,
        'unit': 'serving',
        'baseUnit': 'g',
        'factor': 0,
      };
      expect(
        () => SharedRecipePayload.fromJsonString(jsonEncode(invalid)),
        throwsA(isA<SharedRecipeParseException>()),
      );
    },
  );

  group('SharedRecipePayload', () {
    test('round-trips name, description, and ingredient count', () {
      final payload = SharedRecipePayload.fromRecipe(_testRecipe());
      final encoded = payload.toJsonString();
      final decoded = SharedRecipePayload.fromJsonString(encoded);

      expect(decoded.name, 'Vanilla Cake');
      expect(decoded.description, 'A simple cake');
      expect(decoded.servingsCount, 8);
      expect(decoded.totalWeightG, 300);
      expect(decoded.ingredients, hasLength(2));
    });

    test('preserves macro nutrients on aggregated and per-ingredient', () {
      final encoded = SharedRecipePayload.fromRecipe(
        _testRecipe(),
      ).toJsonString();
      final decoded = SharedRecipePayload.fromJsonString(encoded);

      // 1dp tolerance because we round during compaction.
      expect(decoded.energyKcal100?.value, closeTo(356.7, 0.1));
      expect(decoded.carbohydrates100?.value, closeTo(80, 0.1));
      expect(decoded.fat100?.value, closeTo(0.7, 0.1));
      expect(decoded.proteins100?.value, closeTo(6.7, 0.1));

      final flour = decoded.ingredients.first;
      expect(flour.name, 'Flour');
      expect(flour.brands, 'King Arthur');
      expect(flour.quantity.amount, 200);
      expect(flour.quantity.option.unit, 'g');
      expect(flour.quantity.baseAmount, 200);
      expect(flour.energyKcal100?.value, closeTo(340, 0.1));
      expect(flour.thumbnailImageUrl, 'https://example.com/flour.jpg');
    });

    test('toRecipeEntity rebuilds a valid RecipeEntity', () {
      final encoded = SharedRecipePayload.fromRecipe(
        _testRecipe(),
      ).toJsonString();
      final decoded = SharedRecipePayload.fromJsonString(encoded);
      final reconstructed = decoded.toRecipeEntity();

      expect(reconstructed.name, 'Vanilla Cake');
      expect(reconstructed.ingredients, hasLength(2));
      // Ingredient meals get fresh UUID codes since they're snapshots.
      expect(reconstructed.ingredients.first.snapshotMeal.code, isNotNull);
      expect(
        reconstructed.ingredients.first.snapshotMeal.source,
        MealSourceEntity.custom,
      );
    });

    test('throws on malformed input', () {
      expect(
        () => SharedRecipePayload.fromJsonString('not-a-recipe'),
        throwsA(isA<SharedRecipeParseException>()),
      );
    });

    test('throws on unsupported version', () {
      // Manually craft a payload with version 99
      final fakeJson =
          '[99,"name",null,null,100,[null,null,null,null,null,null,null],[]]';
      expect(
        () => SharedRecipePayload.fromJsonString(fakeJson),
        throwsA(isA<SharedRecipeParseException>()),
      );
    });

    test(
      'oversized decompressed payload throws SharedRecipeParseException',
      () {
        // 1 MiB of repeated bytes compresses to ~1 KiB but expands well
        // past the 64 KiB cap. A malicious QR could in principle ship
        // something like this; the cap keeps the parse predictable.
        final blob = List<int>.filled(1024 * 1024, 0x42);
        final compressed = gzip.encode(blob);
        final raw = base64Url.encode(compressed);
        expect(
          () => SharedRecipePayload.fromJsonString(raw),
          throwsA(
            isA<SharedRecipeParseException>().having(
              (e) => e.message,
              'message',
              contains('too large'),
            ),
          ),
        );
      },
    );
  });
}
