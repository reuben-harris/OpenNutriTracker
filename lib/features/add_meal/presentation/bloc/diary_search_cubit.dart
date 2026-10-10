import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class DiarySearchCubit extends Cubit<FoodSearchSnapshot> {
  DiarySearchCubit(this.engine)
    : super(
        FoodSearchSnapshot(
          request: FoodSearchRequest('', language: AppLocale.localeName),
        ),
      ) {
    _cacheSubscription = engine.cache.cleared.listen((_) => _cacheCleared());
  }
  final FoodSearchEngine engine;
  late final StreamSubscription<void> _cacheSubscription;
  FoodSearchSession? _session;
  StreamSubscription<FoodSearchSnapshot>? _subscription;
  Future<List<MealEntity>>? _recent;

  void search(String query, FoodSearchFilter filter, {bool submit = false}) {
    final previous = _session;
    if (submit &&
        previous != null &&
        previous.request.query == query &&
        previous.request.filter == filter &&
        previous.request.language == AppLocale.localeName) {
      previous.submit();
      return;
    }
    previous?.cancel();
    unawaited(_subscription?.cancel());
    if (filter != FoodSearchFilter.recent) {
      _recent = null;
    } else {
      _recent ??= engine.recentMeals();
    }
    final session = engine.search(
      FoodSearchRequest(query, filter: filter, language: AppLocale.localeName),
      immediate: submit,
      recentSnapshot: _recent,
    );
    _session = session;
    emit(session.state);
    _subscription = session.updates.listen((snapshot) {
      if (!isClosed && identical(_session, session)) emit(snapshot);
    });
  }

  void _cacheCleared() {
    if (isClosed) return;
    _session?.cancel();
    _session = null;
    unawaited(_subscription?.cancel());
    emit(
      FoodSearchSnapshot(
        request: state.request,
        meals: state.request.filter == FoodSearchFilter.recent
            ? state.meals
            : state.meals
                  .where((meal) => meal.source != MealSourceEntity.off)
                  .toList(),
      ),
    );
  }

  void retry() => _session?.retry();
  void loadMore() => _session?.loadMore();
  void resetContext() {
    _recent = null;
    search(state.request.query, state.request.filter);
  }

  @override
  Future<void> close() async {
    _session?.cancel();
    await _subscription?.cancel();
    await _cacheSubscription.cancel();
    return super.close();
  }
}
