import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';

class _FakeAddIntakeUsecase extends Fake implements AddIntakeUsecase {}

class _FakeAddTrackedDayUsecase extends Fake implements AddTrackedDayUsecase {}

class _FakeGetKcalGoalUsecase extends Fake implements GetKcalGoalUsecase {}

class _FakeGetMacroGoalUsecase extends Fake implements GetMacroGoalUsecase {}

class _FakeGetTrackedDayUsecase extends Fake implements GetTrackedDayUsecase {}

class _FakeProductsRepository extends Fake implements ProductsRepository {}

class _FakeRemoteSearchCacheDataSource extends Fake
    implements RemoteSearchCacheDataSource {
  @override
  int get generation => 0;
  @override
  String get language => 'en';
}

MealDetailBloc _buildBloc() => MealDetailBloc(
  _FakeAddIntakeUsecase(),
  _FakeAddTrackedDayUsecase(),
  _FakeGetKcalGoalUsecase(),
  _FakeGetMacroGoalUsecase(),
  _FakeGetTrackedDayUsecase(),
  _FakeProductsRepository(),
  _FakeRemoteSearchCacheDataSource(),
);

MealEntity _meal({
  double? servingQuantity,
  String? servingUnit,
  String? servingSize,
}) {
  return MealEntity(
    code: 'manual-add-test',
    name: 'Test product',
    url: null,
    mealQuantity: null,
    mealUnit: null,
    servingQuantity: servingQuantity,
    servingUnit: servingUnit,
    servingSize: servingSize,
    nutriments: const MealNutrimentsEntity(
      energyKcal100: NutrientAmount(100),
      carbohydrates100: NutrientAmount(10),
      fat100: NutrientAmount(5),
      proteins100: NutrientAmount(5),
      sugars100: NutrientAmount(2),
      saturatedFat100: NutrientAmount(1),
      fiber100: NutrientAmount(1),
    ),
    source: MealSourceEntity.off,
  );
}

void main() {
  for (final meal in [
    _meal(servingSize: '2 Tbsp (32 g)'),
    _meal(servingQuantity: 30),
  ]) {
    test(
      'preview uses the resolved serving conversion ${meal.scalableServingQuantity}',
      () async {
        final bloc = _buildBloc();
        addTearDown(bloc.close);
        final selection = resolveFoodAmount(2, 'serving', meal)!;
        final updated = bloc.stream.first;
        bloc.add(UpdateKcalEvent(meal: meal, selection: selection));
        final state = await updated;
        expect(state.totalKcal, selection.baseAmount);
        expect(state.totalProtein, selection.baseAmount * 0.05);
      },
    );
  }
  test(
    'unscalable serving does not resolve; explicit weight preview works',
    () async {
      final meal = _meal(servingSize: '1 egg');
      expect(resolveFoodAmount(1, 'serving', meal), isNull);
      final bloc = _buildBloc();
      addTearDown(bloc.close);
      final updated = bloc.stream.first;
      bloc.add(UpdateKcalEvent(meal: meal, selection: defaultFoodAmount(meal)));
      expect((await updated).totalKcal, 100);
    },
  );
}
