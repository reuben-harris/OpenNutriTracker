import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/bulk_add_bloc.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/resolve_parsed_meals_usecase.dart';
import 'package:opennutritracker/features/add_meal/util/meal_text_parser.dart';

MealEntity _meal({
  double? servingQuantity,
  List<MealPortionEntity> portions = const [],
}) => MealEntity(
  code: '1',
  name: 'Bread',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: servingQuantity,
  servingUnit: 'g',
  servingSize: null,
  source: MealSourceEntity.catalogue,
  nutriments: MealNutrimentsEntity.empty(),
  portions: portions,
);

const _cup = MealPortionEntity(
  id: 'test:0',
  label: '1 cup',
  gramWeight: 244,
  localized: false,
);
const _slice = MealPortionEntity(
  id: 'test:1',
  label: '1 slice',
  gramWeight: 38,
  localized: false,
);
const _ounce = MealPortionEntity(
  id: 'test:2',
  label: '1 oz',
  gramWeight: 28,
  localized: false,
);

BulkAddRow _row(MealEntity meal, String unit, {String query = 'bread'}) =>
    BulkAddRow(
      resolved: ResolvedMealItem(
        parsed: ParsedMealItem(query: query),
        candidates: [meal],
        selectedIndex: 0,
        confidence: 0.9,
      ),
      selectedIndex: 0,
      amountText: '2',
      unit: unit,
    );

void main() {
  test('bulk offers stable portion identities alongside weights', () {
    final row = _row(_meal(portions: [_cup, _slice, _ounce]), 'portion:test:1');
    expect(row.options.where((o) => o.isNamed).map((o) => o.unit), [
      'portion:test:0',
      'portion:test:1',
      'portion:test:2',
    ]);
    expect(row.options.map((o) => o.unit), containsAll(['g', 'oz']));
    expect(row.selection!.baseAmount, 76);
  });
  test('portion and generic serving have separate meanings', () {
    final meal = _meal(servingQuantity: 30, portions: [_cup, _slice]);
    expect(resolveFoodAmount(2, 'serving', meal)!.baseAmount, 60);
    expect(resolveFoodAmount(2, 'portion:test:0', meal)!.baseAmount, 488);
    expect(resolveFoodAmount(3, 'portion:test:1', meal)!.baseAmount, 114);
  });
  test('reordering portions preserves the selected identity', () {
    final row = _row(_meal(portions: [_slice, _cup]), 'portion:test:0');
    expect(row.selection!.baseAmount, 488);
  });
  test('missing portions cannot fall back to a serving or grams', () {
    final row = _row(
      _meal(servingQuantity: 30, portions: [_cup]),
      'portion:test:1',
    );
    expect(row.selection, isNull);
    expect(row.amountNeedsCheck, isTrue);
    expect(row.willBeLogged, isFalse);
    expect(resolveFoodAmount(2, 'serving#9', row.meal!), isNull);
  });
}
