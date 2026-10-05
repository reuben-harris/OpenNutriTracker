import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';

class _Config implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      ConfigEntity(true, true, false, AppThemeEntity.system);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Catalogue implements FoodCatalogue {
  final queries = <String>[];
  final pending = <Completer<List<MealEntity>>>[];
  @override
  Future<List<MealEntity>> search(String query) {
    queries.add(query);
    final response = Completer<List<MealEntity>>();
    pending.add(response);
    return response.future;
  }

  @override
  Future<MealEntity?> getById(String catalogueId) => throw UnimplementedError();
}

void main() {
  late _Catalogue catalogue;
  late FoodBloc bloc;
  setUp(() {
    catalogue = _Catalogue();
    bloc = FoodBloc.catalogue(catalogue, _Config());
  });
  tearDown(() => bloc.close());

  test('single-character input starts immediately, without debounce', () async {
    bloc.add(const SearchFoodInputChangedEvent(searchString: 'a'));
    await Future<void>.delayed(Duration.zero);
    expect(catalogue.queries, ['a']);
    expect(bloc.state, isA<FoodLoadingState>());
    final loaded = bloc.stream.firstWhere((s) => s is FoodLoadedState);
    catalogue.pending.single.complete([]);
    expect((await loaded as FoodLoadedState).food, isEmpty);
  });

  test(
    'new input supersedes changed, submitted and retried searches',
    () async {
      bloc.add(const SearchFoodInputChangedEvent(searchString: 'a'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LoadFoodEvent(searchString: 'ap'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SearchFoodInputChangedEvent(searchString: 'apple'));
      await Future<void>.delayed(Duration.zero);
      expect(catalogue.queries, ['a', 'ap', 'apple']);
      final loaded = bloc.stream.firstWhere((s) => s is FoodLoadedState);
      catalogue.pending.last.complete([]);
      expect((await loaded as FoodLoadedState).query, 'apple');
      catalogue.pending.first.completeError(StateError('superseded failure'));
      catalogue.pending[1].complete([MealEntity.empty()]);
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as FoodLoadedState).query, 'apple');
    },
  );

  test(
    'clearing or punctuation cancels older results without searching',
    () async {
      for (final clear in ['', ' - " ! ']) {
        bloc.add(const SearchFoodInputChangedEvent(searchString: 'a'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(SearchFoodInputChangedEvent(searchString: clear));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<FoodInitial>());
        catalogue.pending.last.complete([MealEntity.empty()]);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<FoodInitial>());
      }
      expect(catalogue.queries, ['a', 'a']);
    },
  );

  test(
    'failed search exposes an error and retry repeats the same query',
    () async {
      bloc.add(const LoadFoodEvent(searchString: 'egg'));
      await Future<void>.delayed(Duration.zero);
      final failed = bloc.stream.firstWhere((s) => s is FoodFailedState);
      catalogue.pending.single.completeError(
        StateError('database unavailable'),
      );
      await failed;
      bloc.add(const RefreshFoodEvent());
      await Future<void>.delayed(Duration.zero);
      expect(catalogue.queries, ['egg', 'egg']);
      expect(bloc.state, isA<FoodLoadingState>());
      final loaded = bloc.stream.firstWhere((s) => s is FoodLoadedState);
      catalogue.pending.last.complete([]);
      expect((await loaded as FoodLoadedState).query, 'egg');
    },
  );
}
