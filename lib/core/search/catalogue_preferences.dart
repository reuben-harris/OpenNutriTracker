import 'dart:async';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';

/// Device-wide source overrides. Missing IDs, including newly bundled sources,
/// default to enabled. Publication follows persistence so failed writes never
/// change active searches.
class CataloguePreferences {
  CataloguePreferences({
    required FoodCatalogue catalogue,
    required Future<Map<String, bool>> Function() read,
    required Future<void> Function(Map<String, bool>) write,
  }) : _catalogue = catalogue,
       _read = read,
       _write = write;

  final FoodCatalogue _catalogue;
  final Future<Map<String, bool>> Function() _read;
  final Future<void> Function(Map<String, bool>) _write;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  int get revision => _revision;
  int _revision = 0;
  List<CatalogueSource> _sources = const [];
  List<CatalogueSource> get sources => _sources;
  Map<String, bool> _overrides = const {};
  Future<void>? _loading;
  Future<void>? _pending;

  Future<void> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });

  Future<void> _load() async {
    final (sources, overrides) = await (_catalogue.sources(), _read()).wait;
    _sources = List.unmodifiable(sources);
    _overrides = Map.unmodifiable(overrides);
  }

  bool isEnabled(String id) => _overrides[id] ?? true;

  Future<Set<String>> enabledSourceIds() async {
    await load();
    return {
      for (final source in _sources)
        if (isEnabled(source.id)) source.id,
    };
  }

  Future<void> setEnabled(String id, bool enabled) {
    final previous = _pending;
    final update = previous == null
        ? _setEnabled(id, enabled)
        : previous
              .catchError((Object _) {})
              .then((_) => _setEnabled(id, enabled));
    _pending = update;
    return update;
  }

  Future<void> _setEnabled(String id, bool enabled) async {
    await load();
    if (!_sources.any((source) => source.id == id)) {
      throw ArgumentError.value(id, 'id', 'Database is not bundled');
    }
    if (isEnabled(id) == enabled) return;
    final candidate = {..._overrides, id: enabled};
    await _write(candidate);
    _overrides = Map.unmodifiable(candidate);
    _revision++;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
