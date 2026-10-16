import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/json_recipe_importer.dart';

// #1139: a JSON recipe carrying an explicit `totalWeight` lost that override
// on save, because the JSON import use case called SaveRecipeUseCase without
// passing `totalWeightOverridden`. The importer now hands each recipe back
// wrapped in `ImportedRecipe`, so the use case can tell save whether the
// original JSON supplied a total weight or not.

void main() {
  for (final unit in ['serving', 'tablespoon', 'portion:missing']) {
    test('unresolved $unit rejects only its recipe', () {
      final result = JsonRecipeImporter.parse(
        '[{"name":"Bad","ingredients":[{"name":"Bread","amount":2,"unit":"$unit","kcalPer100":100}]},{"name":"Good","ingredients":[{"name":"Milk","amount":2,"unit":"cl","kcalPer100":50}]}]',
      );
      expect(result.recipes.map((r) => r.recipe.name), ['Good']);
      expect(result.recipes.single.recipe.totalWeightG, 20);
      expect(
        result
            .recipes
            .single
            .recipe
            .ingredients
            .single
            .quantity
            .option
            .baseUnit,
        'ml',
      );
      expect(result.errors.single, contains('Bread'));
      expect(result.errors.single, contains(unit));
    });
  }
  test('nonfinite amounts and conversion overflow are rejected', () {
    for (final amount in ['NaN', 'Infinity', '1e308']) {
      final result = JsonRecipeImporter.parse(
        '{"name":"Bad","ingredients":[{"name":"Flour","amount":"$amount","unit":"kg","kcalPer100":100}]}',
      );
      expect(result.recipes, isEmpty);
      expect(result.errors, isNotEmpty);
    }
  });

  group('JsonRecipeImporter.parse totalWeight override flag', () {
    test('sets totalWeightOverridden when the JSON supplies totalWeight', () {
      const json = '''{
  "name": "Vanilla Cake",
  "totalWeight": 1500,
  "ingredients": [
    {"name": "Flour", "amount": 200, "unit": "g", "kcalPer100": 340}
  ]
}''';

      final result = JsonRecipeImporter.parse(json);

      expect(result.errors, isEmpty);
      expect(result.recipes, hasLength(1));
      expect(result.recipes.single.totalWeightOverridden, isTrue);
      expect(result.recipes.single.recipe.name, 'Vanilla Cake');
    });

    test('leaves totalWeightOverridden false when totalWeight is absent', () {
      const json = '''{
  "name": "Smoothie",
  "ingredients": [
    {"name": "Banana", "amount": 300, "unit": "g", "kcalPer100": 89}
  ]
}''';

      final result = JsonRecipeImporter.parse(json);

      expect(result.errors, isEmpty);
      expect(result.recipes.single.totalWeightOverridden, isFalse);
    });

    test('rejects a non-positive totalWeight instead of persisting it', () {
      const json = '''[
  {
    "name": "Zero",
    "totalWeight": 0,
    "ingredients": [
      {"name": "Flour", "amount": 200, "unit": "g", "kcalPer100": 340}
    ]
  },
  {
    "name": "Negative",
    "totalWeight": -100,
    "ingredients": [
      {"name": "Flour", "amount": 200, "unit": "g", "kcalPer100": 340}
    ]
  },
  {
    "name": "NaN",
    "totalWeight": "NaN",
    "ingredients": [
      {"name": "Flour", "amount": 200, "unit": "g", "kcalPer100": 340}
    ]
  }
]''';

      final result = JsonRecipeImporter.parse(json);

      expect(result.recipes, isEmpty);
      expect(result.errors, hasLength(3));
      for (final message in result.errors) {
        expect(
          message,
          contains('"totalWeight" must be a positive finite number'),
        );
      }
    });

    test('sets the flag per recipe when a batch mixes both shapes', () {
      const json = '''[
  {
    "name": "Cake",
    "totalWeight": 1500,
    "ingredients": [
      {"name": "Flour", "amount": 200, "unit": "g", "kcalPer100": 340}
    ]
  },
  {
    "name": "Smoothie",
    "ingredients": [
      {"name": "Banana", "amount": 300, "unit": "g", "kcalPer100": 89}
    ]
  }
]''';

      final result = JsonRecipeImporter.parse(json);

      expect(result.recipes, hasLength(2));
      final byName = {for (final r in result.recipes) r.recipe.name: r};
      expect(byName['Cake']!.totalWeightOverridden, isTrue);
      expect(byName['Smoothie']!.totalWeightOverridden, isFalse);
    });
  });
}
