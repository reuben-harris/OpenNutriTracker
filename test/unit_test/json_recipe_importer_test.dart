import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/json_recipe_importer.dart';

void main() {
  for (final unit in ['serving', 'tablespoon', 'portion:missing']) {
    test('unresolved $unit rejects only its recipe', () {
      final result = JsonRecipeImporter.parse(
        '[{"name":"Bad","ingredients":[{"name":"Bread","amount":2,"unit":"$unit","kcalPer100":100}]},{"name":"Good","ingredients":[{"name":"Milk","amount":2,"unit":"cl","kcalPer100":50}]}]',
      );
      expect(result.recipes.map((r) => r.name), ['Good']);
      expect(result.recipes.single.totalWeightG, 20);
      expect(
        result.recipes.single.ingredients.single.quantity.option.baseUnit,
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

  group('JsonRecipeImporter.parse cooked weight', () {
    test('sets cookedWeightG when the JSON supplies totalWeight', () {
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
      expect(result.recipes.single.cookedWeightG, 1500);
      expect(result.recipes.single.name, 'Vanilla Cake');
    });

    test('leaves cookedWeightG null when totalWeight is absent', () {
      const json = '''{
  "name": "Smoothie",
  "ingredients": [
    {"name": "Banana", "amount": 300, "unit": "g", "kcalPer100": 89}
  ]
}''';

      final result = JsonRecipeImporter.parse(json);

      expect(result.errors, isEmpty);
      expect(result.recipes.single.cookedWeightG, isNull);
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

    for (final invalid in ['null', '""', '"unknown"']) {
      test(
        'explicit unusable totalWeight $invalid cannot select automatic mode',
        () {
          final result = JsonRecipeImporter.parse(
            '{"name":"Bread","totalWeight":$invalid,"ingredients":'
            '[{"name":"Flour","amount":100,"unit":"g","kcalPer100":200}]}',
          );
          expect(result.recipes, isEmpty);
          expect(result.errors.single, contains('totalWeight'));
        },
      );
    }

    test('sets cooked weight per recipe when a batch mixes both shapes', () {
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
      final byName = {for (final r in result.recipes) r.name: r};
      expect(byName['Cake']!.cookedWeightG, 1500);
      expect(byName['Smoothie']!.cookedWeightG, isNull);
    });
  });
}
