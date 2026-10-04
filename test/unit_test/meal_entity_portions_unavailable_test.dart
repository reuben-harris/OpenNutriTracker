import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';

MealEntity _meal() => MealEntity(
  code: '123',
  name: 'Bread, rye',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: 38,
  servingUnit: 'g',
  servingSize: '1 slice (38 g)',
  source: MealSourceEntity.fdc,
  nutriments: MealNutrimentsEntity.empty(),
);

final _portion = MealPortionEntity(
  label: '1 slice',
  gramWeight: 38,
  localized: false,
);

void main() {
  group('MealEntity.portionsUnavailable (#1170 review)', () {
    test('is off until the repository says otherwise', () {
      expect(_meal().portionsUnavailable, isFalse);
    });

    test('withPortions carries it across', () {
      // Each copier touches the one thing it is for and nothing else, the
      // flag included; the penalty reads the portions first, so a marked
      // record that is handed portions is simply a record with portions.
      final marked = _meal().withPortionsUnavailable().withPortions([_portion]);

      expect(marked.portions, [_portion]);
      expect(marked.portionsUnavailable, isTrue);
    });

    test('the MealDBO round trip drops it, as it drops the portions', () {
      // Nothing persists this provenance. A copy read back from the search
      // cache is a cached copy, not a failed lookup, and must not inherit
      // the exemption — see the field's comment for why the cached case
      // stays penalised.
      final marked = _meal().withPortionsUnavailable();
      final dbo = MealDBO.fromMealEntity(marked);
      final cached = MealEntity.fromMealDBO(dbo);

      expect(dbo.toJson().keys, isNot(contains('portionsUnavailable')));
      expect(cached.portionsUnavailable, isFalse);
      expect(cached.portions, isEmpty);
    });
  });
}
