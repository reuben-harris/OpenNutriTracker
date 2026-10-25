import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';

class _Config extends Fake implements GetConfigUsecase {}

class _Custom extends Fake implements CustomMealDataSource {}

class _Repository extends Fake implements ConfigRepository {}

void main() {
  test(
    'untouched qualifications survive and explicit replacements become numeric',
    () async {
      final bloc = EditMealBloc(_Config(), _Custom(), _Repository());
      final old = MealEntity(
        code: 'trace',
        name: 'Food',
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        source: MealSourceEntity.custom,
        nutriments: MealNutrimentsEntity.fromCatalogue({
          'fat100': {'value': '0', 'qualification': 'trace', 'limit': null},
          'vitaminB12100': {
            'value': '0',
            'qualification': 'trace',
            'limit': null,
          },
        }),
      );
      final edited = bloc.createNewMealEntity(
        old,
        'Renamed',
        '',
        '100',
        '100',
        '100',
        'gml',
        '',
        '',
        '2',
        '',
        editedNutrients: {'fat100'},
      );
      expect(edited.nutriments.fat100!.value, 2);
      expect(edited.nutriments.fat100!.isQualified, isFalse);
      expect(edited.nutriments.vitaminB12100!.isQualified, isTrue);
      await bloc.close();
    },
  );
  test(
    'blank custom nutrients persist as unknown and explicit zero persists',
    () async {
      final bloc = EditMealBloc(_Config(), _Custom(), _Repository());
      final meal = bloc.createNewMealEntity(
        MealEntity.empty(),
        'Food',
        '',
        '100',
        '100',
        '100',
        'gml',
        '',
        '0',
        '',
        '12',
      );
      final stored = MealEntity.fromMealDBO(
        MealDBO.fromJson(
          jsonDecode(jsonEncode(MealDBO.fromMealEntity(meal).toJson())),
        ),
      );
      expect(stored.nutriments.energyKcal100?.value, isNull);
      expect(stored.nutriments.carbohydrates100?.value, 0);
      expect(stored.nutriments.fat100?.value, isNull);
      expect(stored.nutriments.proteins100?.value, 12);
      await bloc.close();
    },
  );
}
