import 'dart:async';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'package:opennutritracker/core/search/off_food_search_source.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

enum FoodSearchFilter { all, products, food, recent }

enum FoodSearchSource { catalogue, cache, saved, recent, online }

class FoodSearchRequest {
  const FoodSearchRequest(
    this.query, {
    this.filter = FoodSearchFilter.all,
    required this.language,
  });
  final String query;
  final FoodSearchFilter filter;
  final String language;
}

class FoodSearchSnapshot {
  const FoodSearchSnapshot({
    required this.request,
    this.meals = const [],
    this.pending = const {},
    this.failures = const {},
    this.hasMore = false,
  });
  final FoodSearchRequest request;
  final List<MealEntity> meals;
  final Set<FoodSearchSource> pending;
  final Map<FoodSearchSource, Object> failures;
  final bool hasMore;
}

/// Shared search policy; callers own presentation, selection and navigation.
class FoodSearchEngine {
  FoodSearchEngine({
    required this.catalogue,
    required this.cache,
    required this.savedMeals,
    required this.recentMeals,
    required this.online,
    required this.contextIdentity,
    this.debounce = const Duration(milliseconds: 500),
  });
  final FoodCatalogue catalogue;
  final RemoteSearchCacheDataSource cache;
  final Future<List<MealEntity>> Function() savedMeals;

  /// Newest-first, deduplicated history supplied by a consumer-independent adapter.
  final Future<List<MealEntity>> Function() recentMeals;
  final OffFoodSearchSource online;
  final String Function() contextIdentity;
  final Duration debounce;
  FoodSearchSession search(
    FoodSearchRequest request, {
    bool immediate = false,
    Future<List<MealEntity>>? recentSnapshot,
  }) => FoodSearchSession._(this, request, immediate, recentSnapshot);
}

class FoodSearchSession {
  FoodSearchSession._(
    this._engine,
    this.request,
    bool immediate,
    this._recentSnapshot,
  ) : _context = _engine.contextIdentity(),
      _cacheGeneration = _engine.cache.generation {
    final nonblank = foodSearchMatch(request.query) != null;
    if (request.filter == FoodSearchFilter.recent) {
      _pending.add(FoodSearchSource.recent);
    } else if (nonblank) {
      if (request.filter != FoodSearchFilter.products) {
        _pending.add(FoodSearchSource.catalogue);
      }
      if (request.filter != FoodSearchFilter.food) {
        _pending.add(FoodSearchSource.cache);
        if (request.filter == FoodSearchFilter.all) {
          _pending.add(FoodSearchSource.saved);
        }
        if (request.query.trim().length >= 2) {
          _pending.add(FoodSearchSource.online);
        }
      }
    }
    _state = _snapshot();
    scheduleMicrotask(() => _start(immediate));
  }
  static final _log = Logger('FoodSearch');
  final FoodSearchEngine _engine;
  final FoodSearchRequest request;
  final String _context;
  final int _cacheGeneration;
  final Future<List<MealEntity>>? _recentSnapshot;
  final _updates = StreamController<FoodSearchSnapshot>.broadcast();
  Stream<FoodSearchSnapshot> get updates => _updates.stream;
  late FoodSearchSnapshot _state;
  FoodSearchSnapshot get state => _state;
  final _pending = <FoodSearchSource>{};
  final _failures = <FoodSearchSource, Object>{};
  final _locals = <FoodSearchSource, List<MealEntity>>{};
  final _remote = <String, MealEntity>{};
  List<MealEntity> _results = [];
  bool _cancelled = false, _hasMore = false, _appendPages = false;
  bool _started = false, _submitRequested = false;
  int _page = 0, _revision = 0;
  Timer? _timer;
  OffFoodSearchCall? _call;
  bool get _active =>
      !_cancelled &&
      _engine.contextIdentity() == _context &&
      _engine.cache.generation == _cacheGeneration;
  FoodSearchSnapshot _snapshot() => FoodSearchSnapshot(
    request: request,
    meals: List.unmodifiable(_results),
    pending: Set.unmodifiable(_pending),
    failures: Map.unmodifiable(_failures),
    hasMore: _hasMore,
  );

  void _start(bool immediate) {
    if (!_active) return;
    _started = true;
    immediate = immediate || _submitRequested;
    for (final source in _pending.toList()) {
      if (source != FoodSearchSource.online) unawaited(_loadLocal(source));
    }
    if (_pending.contains(FoodSearchSource.online)) {
      if (immediate) {
        unawaited(_fetch(1));
      } else {
        _timer = Timer(_engine.debounce, () => unawaited(_fetch(1)));
      }
    }
  }

  Future<void> _loadLocal(FoodSearchSource source) async {
    try {
      final meals = switch (source) {
        FoodSearchSource.catalogue => await _engine.catalogue.search(
          request.query,
        ),
        FoodSearchSource.cache => (await _engine.cache.search(
          request.query,
          language: request.language,
        )).map(MealEntity.fromMealDBO).toList(),
        FoodSearchSource.saved => await _engine.savedMeals(),
        FoodSearchSource.recent =>
          await (_recentSnapshot ?? _engine.recentMeals()),
        FoodSearchSource.online => throw StateError('Not a local source'),
      };
      if (!_active) return;
      _locals[source] = meals;
      _failures.remove(source);
    } catch (error, stack) {
      if (!_active) return;
      _failures[source] = error;
      _log.warning('Local search source $source failed', error, stack);
    }
    _pending.remove(source);
    await _publish();
  }

  Future<void> _publish() async {
    if (!_active) return;
    final revision = ++_revision;
    try {
      final byId = <String, MealEntity>{};
      for (final meals in _locals.values) {
        for (final meal in meals) {
          byId[foodIdentity(meal)] = meal;
        }
      }
      for (final entry in _remote.entries) {
        final cached = byId[entry.key];
        byId[entry.key] = cached == null
            ? entry.value
            : MealEntity.fromMealDBO(
                MealDBO.fromJson(
                  mergeFoodPayloads(
                    MealDBO.fromMealEntity(cached).toJson(),
                    MealDBO.fromMealEntity(entry.value).toJson(),
                  ),
                ),
              );
      }
      final ranked = await rankFoodCandidates(
        request.query,
        byId.values.toList(),
        remoteIdentities: _remote.keys.toSet(),
        chronological: request.filter == FoodSearchFilter.recent,
      );
      if (!_active || revision != _revision) return;
      if (_appendPages) {
        final remaining = {for (final meal in ranked) foodIdentity(meal): meal};
        _results = [
          for (final meal in _results)
            if (remaining.containsKey(foodIdentity(meal)))
              remaining.remove(foodIdentity(meal))!,
          ...remaining.values,
        ];
      } else {
        _results = ranked;
      }
    } catch (error, stack) {
      if (!_active || revision != _revision) return;
      _log.warning('Food ranking failed', error, stack);
      _failures[FoodSearchSource.cache] = error;
    }
    _state = _snapshot();
    _updates.add(_state);
  }

  Future<void> _fetch(int page) async {
    if (!_active || _call != null) return;
    _timer?.cancel();
    _timer = null;
    _pending.add(FoodSearchSource.online);
    _failures.remove(FoodSearchSource.online);
    _state = _snapshot();
    _updates.add(_state);
    OffFoodSearchCall? call;
    try {
      call = _engine.online.search(
        request.query,
        language: request.language,
        page: page,
      );
      _call = call;
      final result = await call.result;
      if (!_active) return;
      for (final meal in result.meals) {
        _remote[foodIdentity(meal)] = meal;
      }
      _call = null;
      _page = page;
      _hasMore = result.hasMore;
      if (page > 1) _appendPages = true;
      _pending.remove(FoodSearchSource.online);
      await _publish();
      if (_active) {
        unawaited(
          _engine.cache
              .cacheFromSearch(
                result.meals.map(MealDBO.fromMealEntity),
                generation: _cacheGeneration,
                language: request.language,
              )
              .catchError((Object error, StackTrace stack) {
                _log.warning('OFF cache write failed', error, stack);
              }),
        );
      }
    } catch (error, stack) {
      if (!_active) return;
      _pending.remove(FoodSearchSource.online);
      _failures[FoodSearchSource.online] = error;
      _log.fine('Online food search failed', error, stack);
      await _publish();
    } finally {
      if (identical(_call, call)) _call = null;
    }
  }

  void submit() {
    if (!_active ||
        request.query.trim().length < 2 ||
        request.filter == FoodSearchFilter.food ||
        request.filter == FoodSearchFilter.recent) {
      return;
    }
    if (!_started) {
      _submitRequested = true;
      return;
    }
    if (_timer != null) {
      unawaited(_fetch(1));
    } else if (_call == null && _page == 0) {
      unawaited(_fetch(1));
    }
  }

  void loadMore() {
    if (_hasMore && !_pending.contains(FoodSearchSource.online)) {
      unawaited(_fetch(_page + 1));
    }
  }

  void retry() {
    if (!_active) return;
    for (final source in _failures.keys.toList()) {
      if (source == FoodSearchSource.online) {
        unawaited(_fetch(_page == 0 ? 1 : _page + 1));
      } else {
        _pending.add(source);
        unawaited(_loadLocal(source));
      }
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    ++_revision;
    _timer?.cancel();
    _call?.cancel();
    unawaited(_updates.close());
  }
}
