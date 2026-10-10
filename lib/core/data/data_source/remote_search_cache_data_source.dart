import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';
import 'package:opennutritracker/core/search/food_search_ranker.dart';

/// Public product cache. Serialized background operations keep SQLite off the
/// UI isolate and order writes, pruning, and clearing without Hive adapters.
class RemoteSearchCacheDataSource {
  RemoteSearchCacheDataSource({
    Future<String> Function()? databasePath,
    DateTime Function()? now,
  }) : _databasePath = databasePath ?? _defaultPath,
       _now = now ?? DateTime.now;
  final Future<String> Function() _databasePath;
  final DateTime Function() _now;
  Future<String>? _path;
  Future<void> _tail = Future<void>.value();
  int _generation = 0;
  final _cleared = StreamController<void>.broadcast();
  Stream<void> get cleared => _cleared.stream;
  int get generation => _generation;
  String get language => AppLocale.localeName;

  static Future<String> _defaultPath() async =>
      p.join((await getApplicationSupportDirectory()).path, 'off-cache.sqlite');

  Future<Object?> _run(
    String operation,
    List<Object?> arguments, {
    int? generation,
  }) {
    final result = _tail.then((_) async {
      if (generation != null && generation != _generation) return null;
      final path = await (_path ??= _databasePath());
      return _runCacheTask(path, operation, arguments);
    });
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<List<MealDBO>> getAll() async =>
      _decodeRows(await _run('all', [language]));
  Future<List<MealDBO>> search(String query, {String? language}) async {
    final match = foodSearchMatch(query);
    if (match == null) return [];
    return _decodeRows(
      await _run('search', [
        language ?? this.language,
        match,
        normalizeFoodSearchText(query),
      ]),
    );
  }

  Future<MealDBO?> getByBarcode(String barcode) => _lookup(barcode, false);
  Future<MealDBO?> getDetailedByBarcode(String barcode) =>
      _lookup(barcode, true);
  Future<MealDBO?> _lookup(String code, bool detailed) async {
    final rows = _decodeRows(await _run('lookup', [language, code, detailed]));
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> cache(MealDBO meal, {int? generation, String? language}) =>
      cacheAll([meal], generation: generation, language: language);
  Future<void> cacheAll(
    Iterable<MealDBO> meals, {
    int? generation,
    String? language,
  }) async {
    final rows = [
      for (final meal in meals)
        if (meal.source == MealSourceDBO.off &&
            (meal.code?.isNotEmpty ?? false))
          jsonEncode(meal.toJson()),
    ];
    if (rows.isEmpty) return;
    await _run('save', [
      language ?? this.language,
      _now().millisecondsSinceEpoch,
      rows,
    ], generation: generation ?? _generation);
  }

  Future<void> cacheFromSearch(
    Iterable<MealDBO> meals, {
    int? generation,
    String? language,
  }) => cacheAll(meals, generation: generation, language: language);
  Future<int> get count async => (await _run('count', [])) as int;
  Future<int> getStorageSizeBytes() async {
    await _tail;
    final path = await (_path ??= _databasePath());
    var bytes = 0;
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (await file.exists()) bytes += await file.length();
    }
    return bytes;
  }

  Future<int> pruneStale(Duration maxAge) async =>
      (await _run('prune', [_now().subtract(maxAge).millisecondsSinceEpoch]))
          as int;
  Future<void> clear() async {
    ++_generation;
    await _run('clear', []);
    _cleared.add(null);
  }
}

List<MealDBO> _decodeRows(Object? rows) => [
  for (final json in (rows as List? ?? const []))
    MealDBO.fromJson(jsonDecode(json as String) as Map<String, dynamic>),
];
Future<Object?> _runCacheTask(
  String path,
  String operation,
  List<Object?> args,
) => Isolate.run(() => _cacheOperation(path, operation, args));

Object? _cacheOperation(String path, String operation, List<Object?> args) {
  Directory(p.dirname(path)).createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY, language TEXT NOT NULL, code TEXT NOT NULL,
        name TEXT NOT NULL, brand TEXT NOT NULL, payload TEXT NOT NULL,
        detailed INTEGER NOT NULL, fetched_at INTEGER NOT NULL, UNIQUE(language, code)
      );
      CREATE INDEX IF NOT EXISTS product_age ON products(fetched_at);
      CREATE VIRTUAL TABLE IF NOT EXISTS product_search USING fts5(
        name, brand, content='products', content_rowid='id',
        tokenize='unicode61 remove_diacritics 2', prefix='2 3 4'
      );
      CREATE TRIGGER IF NOT EXISTS product_insert AFTER INSERT ON products BEGIN
        INSERT INTO product_search(rowid, name, brand) VALUES(new.id, new.name, new.brand);
      END;
      CREATE TRIGGER IF NOT EXISTS product_delete AFTER DELETE ON products BEGIN
        INSERT INTO product_search(product_search, rowid, name, brand) VALUES('delete', old.id, old.name, old.brand);
      END;
      CREATE TRIGGER IF NOT EXISTS product_update AFTER UPDATE ON products BEGIN
        INSERT INTO product_search(product_search, rowid, name, brand) VALUES('delete', old.id, old.name, old.brand);
        INSERT INTO product_search(rowid, name, brand) VALUES(new.id, new.name, new.brand);
      END;
    ''');
    db.createFunction(
      functionName: 'normalize_name',
      argumentCount: const AllowedArgumentCount(1),
      function: (args) => normalizeFoodSearchText(args.single as String),
    );
    switch (operation) {
      case 'all':
        return db
            .select(
              'SELECT payload FROM products WHERE language = ? ORDER BY code',
              args,
            )
            .map((r) => r['payload'])
            .toList();
      case 'search':
        return db
            .select(
              '''SELECT p.payload FROM product_search JOIN products p ON p.id = product_search.rowid
          WHERE p.language = ? AND product_search MATCH ?
          ORDER BY CASE WHEN normalize_name(p.name) = ? THEN 0 ELSE 1 END,
          bm25(product_search, 5, 2), p.code LIMIT 25''',
              args,
            )
            .map((r) => r['payload'])
            .toList();
      case 'lookup':
        return db
            .select(
              'SELECT payload FROM products WHERE language = ? AND code = ? AND (? = 0 OR detailed = 1)',
              [args[0], args[1], args[2] == true ? 1 : 0],
            )
            .map((r) => r['payload'])
            .toList();
      case 'save':
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final raw in args[2] as List) {
            var value = jsonDecode(raw as String) as Map<String, dynamic>;
            final old = db.select(
              'SELECT payload FROM products WHERE language = ? AND code = ?',
              [args[0], value['code']],
            );
            if (old.isNotEmpty && value['detailed'] != true) {
              value = mergeFoodPayloads(
                jsonDecode(old.single['payload'] as String)
                    as Map<String, dynamic>,
                value,
              );
            }
            db.execute(
              '''INSERT INTO products(language, code, name, brand, payload, detailed, fetched_at)
              VALUES(?, ?, ?, ?, ?, ?, ?) ON CONFLICT(language, code) DO UPDATE SET
              name=excluded.name, brand=excluded.brand, payload=excluded.payload,
              detailed=excluded.detailed, fetched_at=excluded.fetched_at''',
              [
                args[0],
                value['code'],
                value['name'] ?? '',
                value['brands'] ?? '',
                jsonEncode(value),
                value['detailed'] == true ? 1 : 0,
                args[1],
              ],
            );
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
        return null;
      case 'count':
        return db.select('SELECT count(*) AS n FROM products').single['n'];
      case 'prune':
        db.execute('DELETE FROM products WHERE fetched_at < ?', args);
        return db.updatedRows;
      case 'clear':
        db.execute('DELETE FROM products');
        db.execute('VACUUM');
        return null;
      default:
        throw ArgumentError.value(operation);
    }
  } finally {
    db.close();
  }
}

/// Refresh supplied search fields while retaining full-only serving/nutrient data.
Map<String, dynamic> mergeFoodPayloads(
  Map<String, dynamic> old,
  Map<String, dynamic> fresh,
) => _mergeFoodMaps(
  jsonDecode(jsonEncode(old)) as Map<String, dynamic>,
  jsonDecode(jsonEncode(fresh)) as Map<String, dynamic>,
);

Map<String, dynamic> _mergeFoodMaps(
  Map<String, dynamic> old,
  Map<String, dynamic> fresh,
) {
  final merged = {...old};
  for (final entry in fresh.entries) {
    if (entry.value == null) continue;
    if (entry.key == 'detailed') {
      merged[entry.key] = old[entry.key] == true || entry.value == true;
    } else if (entry.value is Map && old[entry.key] is Map) {
      merged[entry.key] = _mergeFoodMaps(
        Map<String, dynamic>.from(old[entry.key] as Map),
        Map<String, dynamic>.from(entry.value as Map),
      );
    } else {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}
