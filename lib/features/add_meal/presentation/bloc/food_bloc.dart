import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/search_debounce.dart';

part 'food_event.dart';
part 'food_state.dart';

class FoodBloc extends Bloc<FoodEvent, FoodState> {
  final log = Logger('FoodBloc');
  final SearchProductsUseCase? _localSearch;
  final FoodCatalogue? _catalogue;
  final GetConfigUsecase _config;
  String _query = '';
  int _request = 0;

  /// Recipe picker retains its existing timing and local lookups.
  FoodBloc(SearchProductsUseCase localSearch, this._config)
    : _localSearch = localSearch,
      _catalogue = null,
      super(FoodInitial()) {
    on<LoadFoodEvent>((event, emit) => _search(event.searchString, emit));
    on<SearchFoodInputChangedEvent>(
      (event, emit) => _search(event.searchString, emit),
      transformer: debounceRestartable(searchDebounceDuration),
    );
    on<RefreshFoodEvent>((event, emit) => _search(_query, emit));
  }

  /// Diary Food searches only the public catalogue, immediately on changes.
  /// One event bucket prevents a retry or submit from outliving newer input.
  FoodBloc.catalogue(FoodCatalogue catalogue, this._config)
    : _localSearch = null,
      _catalogue = catalogue,
      super(FoodInitial()) {
    on<FoodEvent>((event, emit) {
      final query = switch (event) {
        LoadFoodEvent() => event.searchString,
        SearchFoodInputChangedEvent() => event.searchString,
        _ => _query,
      };
      return _search(query, emit);
    }, transformer: restartable());
  }

  Future<void> _search(String query, Emitter<FoodState> emit) async {
    _query = query;
    final request = ++_request;
    final catalogue = _catalogue;
    if (catalogue != null
        ? catalogueMatch(query) == null
        : query.trim().length < minQueryLength) {
      emit(FoodInitial());
      return;
    }
    emit(FoodLoadingState());
    try {
      final meals = catalogue != null
          ? await catalogue.search(query)
          : (await _localSearch!.searchLocalFoodsByString(query)).meals;
      final config = await _config.getConfig();
      if (emit.isDone || request != _request) return;
      emit(
        FoodLoadedState(
          food: meals,
          query: query,
          usesImperialUnits: config.usesImperialFoodUnits,
        ),
      );
    } catch (error, stack) {
      log.warning('Food search failed', error, stack);
      if (!emit.isDone && request == _request) emit(FoodFailedState());
    }
  }
}
