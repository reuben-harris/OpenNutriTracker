import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/util/food_title.dart';
import 'package:opennutritracker/features/add_meal/util/meal_relevance_ranker.dart';
import 'package:opennutritracker/features/add_meal/util/resolver_relevance.dart';

MealEntity meal(
  String? name, {
  MealSourceEntity source = MealSourceEntity.fdc,
}) => MealEntity(
  code: name ?? 'nameless',
  name: name,
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: 'g',
  servingSize: null,
  nutriments: MealNutrimentsEntity.empty(),
  source: source,
);

/// `MealEntity.scoringName` (#1164): the title the scorers match a backend
/// record on is derived from its name, not carried from the backend or
/// persisted. The backend's `short_title` column measured equal to the
/// name up to its first comma on every FDC row and 7,135 of 7,140 BLS
/// rows, so the fixtures' real titles are what the derivation is held to.
/// `MealEntity.scoringQualifiers` is the rest of the same name, which the
/// scorers read only where the query names one of its words.
void main() {
  group('the derived title equals the backend short title', () {});

  group('a localized name derives a localized title', () {
    test('Milch, menschliche derives Milch', () {
      // The point a persisted English title would have got wrong: a
      // German reader's query is German, and "Milk" scores nothing on it.
      expect(meal('Milch, menschliche').scoringName, 'Milch');
    });

    test('and scores against Milch as a record called Milch does', () {
      final translated = meal('Milch, menschliche');
      final called = meal('Milch');

      expect(
        scoreMealForResolution(translated, 'Milch'),
        scoreMealForResolution(called, 'Milch'),
      );
      expect(
        scoreMealRelevance(translated, 'Milch'),
        scoreMealRelevance(called, 'Milch'),
      );
      expect(scoreMealRelevance(translated, 'Milch'), 1.0);
      // And not as "Milk" would: the English column scores nothing here.
      expect(scoreMealRelevance(meal('Milk, human'), 'Milch'), 0.0);
    });
  });

  group('the edges of the derivation', () {
    test('the title is trimmed', () {
      expect(meal('Egg , whole, raw').scoringName, 'Egg');
    });

    test('nothing before the comma falls back to the whole name', () {
      // An empty title would score nothing on everything; the name at
      // least scores what it did before the derivation existed.
      expect(meal(', whole, raw').scoringName, ', whole, raw');
      expect(meal('  , whole').scoringName, '  , whole');
    });

    test('a nameless record derives nothing', () {
      expect(meal(null).scoringName, isNull);
    });
  });

  group('the qualifiers are the rest of the name', () {
    test('a comma with nothing after it leaves no qualifiers', () {
      expect(meal('Egg,').scoringQualifiers, isNull);
      expect(meal('Egg, ').scoringQualifiers, isNull);
      expect(meal('Egg,').scoringName, 'Egg');
    });

    test('a name that is not split has no qualifiers', () {
      // Where the title falls back to the whole name, nothing is left over
      // to read past it — the two getters split the same way or not at all.
      expect(meal(', whole, raw').scoringQualifiers, isNull);
      expect(meal('Orange juice').scoringQualifiers, isNull);
      expect(meal(null).scoringQualifiers, isNull);
    });

    test('the qualifiers are trimmed', () {
      expect(meal('Egg ,  whole, raw ').scoringQualifiers, 'whole, raw');
    });
  });

  group('backend records only', () {
    test('an OFF product\'s scoring name is its full name', () {
      final off = meal('Egg, whole, raw', source: MealSourceEntity.off);

      expect(off.scoringName, 'Egg, whole, raw');
      expect(off.scoringQualifiers, isNull);
      // Which is what an OFF product has always been scored on: the three
      // tokens cost it against `eggs` where a backend twin pays nothing.
      expect(scoreMealForResolution(off, 'eggs'), closeTo(0.375, 1e-9));
      expect(
        scoreMealForResolution(meal('Egg, whole, raw'), 'eggs'),
        closeTo(0.6, 1e-9),
      );
    });

    test('a custom meal and a recipe score on the whole name too', () {
      for (final source in [
        MealSourceEntity.custom,
        MealSourceEntity.recipe,
        MealSourceEntity.unknown,
      ]) {
        expect(
          meal('Soup, my own', source: source).scoringName,
          'Soup, my own',
          reason: source.name,
        );
        expect(
          meal('Soup, my own', source: source).scoringQualifiers,
          isNull,
          reason: source.name,
        );
      }
    });
  });

  group('a cached row scores as its fresh twin on the title', () {});

  group('the entity and the data source derive the same title (#1170)', () {
    // `deriveTitle` and `deriveQualifiers` are what the data source scores
    // a raw backend row on before any entity exists; the entity's getters
    // must be the same derivation, or the twenty rows kept and the one
    // picked among them are chosen by two rules.

    test('and on the edges', () {
      expect(deriveTitle('Orange juice'), 'Orange juice');
      expect(deriveQualifiers('Orange juice'), isNull);
      expect(deriveTitle('Egg , whole, raw'), 'Egg');
      expect(deriveQualifiers('Egg ,  whole, raw '), 'whole, raw');
      expect(deriveTitle('Egg,'), 'Egg');
      expect(deriveQualifiers('Egg,'), isNull);
      expect(deriveQualifiers('Egg, '), isNull);
      expect(deriveTitle(', whole, raw'), ', whole, raw');
      expect(deriveQualifiers(', whole, raw'), isNull);
      expect(deriveTitle('  , whole'), '  , whole');
      expect(deriveTitle(''), '');
      expect(deriveQualifiers(''), isNull);
    });

    test('the helper knows nothing of the source; the entity does', () {
      // The data source's rows are always backend rows, so it derives
      // without asking. The entity guards, because an OFF product name
      // with a comma in it is not split.
      expect(deriveTitle('Egg, whole, raw'), 'Egg');
      expect(
        meal('Egg, whole, raw', source: MealSourceEntity.off).scoringName,
        'Egg, whole, raw',
      );
    });
  });
}
