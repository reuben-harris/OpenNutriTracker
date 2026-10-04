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
      expect(stored.nutriments.energyKcal100, isNull);
      expect(stored.nutriments.carbohydrates100, 0);
      expect(stored.nutriments.fat100, isNull);
      expect(stored.nutriments.proteins100, 12);
      await bloc.close();
    },
  );
}
