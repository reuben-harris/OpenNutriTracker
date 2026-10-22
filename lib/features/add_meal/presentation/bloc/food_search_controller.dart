import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class FoodSearchController extends Cubit<FoodSearchSnapshot> {
  FoodSearchController(this.engine)
    : super(
        FoodSearchSnapshot(
          request: FoodSearchRequest('', language: AppLocale.localeName),
        ),
      ) {
    _cacheSubscription = engine.cache.cleared.listen((_) => _cacheCleared());
    _catalogueSubscription = engine.cataloguePreferences?.changes.listen(
      (_) => resetContext(),
    );
  }
  final FoodSearchEngine engine;
  final query = ValueNotifier<String>('');
  // Presentation observes operation starts even when pending and completion
  // snapshots arrive before Flutter paints another frame.
  int _loadingSequence = 0;
  int get loadingSequence => _loadingSequence;
  String get _scrollKey =>
      '${state.request.filter.name}:${state.request.query}';
  final _offsets = <String, double>{};
  final _positionKeys = <ScrollPosition, String>{};
  late final ScrollController scroll = ScrollController(
    keepScrollOffset: false,
    onAttach: (position) {
      final key = _scrollKey;
      _positionKeys[position] = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.positions.contains(position) && _scrollKey == key) {
          position.jumpTo(
            (_offsets[key] ?? 0).clamp(0, position.maxScrollExtent),
          );
        }
      });
    },
    onDetach: (position) {
      final key = _positionKeys.remove(position);
      if (key != null) _offsets[key] = position.pixels;
    },
  );
  late final StreamSubscription<void> _cacheSubscription;
  StreamSubscription<void>? _catalogueSubscription;
  FoodSearchSession? _session;
  StreamSubscription<FoodSearchSnapshot>? _subscription;
  Future<List<MealEntity>>? _recent;

  void search(String query, FoodSearchFilter filter, {bool submit = false}) {
    this.query.value = query;
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
    if (session.state.pending.isNotEmpty) _loadingSequence++;
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

  void retry() {
    if (_session == null || state.failures.isEmpty) return;
    _loadingSequence++;
    _session!.retry();
  }

  void loadMore() {
    if (_session == null ||
        !state.hasMore ||
        state.pending.contains(FoodSearchSource.online)) {
      return;
    }
    _loadingSequence++;
    _session!.loadMore();
  }

  void resetContext() {
    _offsets.clear();
    _recent = null;
    search(state.request.query, state.request.filter);
  }

  @override
  Future<void> close() async {
    query.dispose();
    scroll.dispose();
    _session?.cancel();
    await _subscription?.cancel();
    await _cacheSubscription.cancel();
    await _catalogueSubscription?.cancel();
    return super.close();
  }
}
