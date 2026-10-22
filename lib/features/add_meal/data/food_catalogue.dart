import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';

/// Quotes FTS tokens as literals; only the last word is a prefix.
/// Punctuation (including FTS operators) is treated as a word separator.
String? catalogueMatch(String query) => foodSearchMatch(query);

class CatalogueSource {
  const CatalogueSource({
    required this.id,
    required this.name,
    required this.releases,
    required this.attribution,
    required this.website,
    required this.termsUrl,
    required this.termsRequired,
  });
  final String id;
  final String name;
  final Map<String, String> releases;
  final String attribution;
  final String website;
  final String termsUrl;
  final bool termsRequired;

  String get releaseSummary =>
      (releases.values.toSet().toList()..sort()).join(', ');

  factory CatalogueSource.fromRow(Row row) => CatalogueSource(
    id: row['id'] as String,
    name: row['name'] as String,
    releases: Map<String, String>.from(
      jsonDecode(row['releases'] as String) as Map,
    ),
    attribution: row['attribution'] as String,
    website: row['website'] as String,
    termsUrl: row['terms_url'] as String,
    termsRequired: row['terms_required'] == 1,
  );
}

abstract class FoodCatalogue {
  Future<List<CatalogueSource>> sources();
  Future<List<MealEntity>> search(String query, {Set<String>? sourceIds});
  Future<MealEntity?> getById(String catalogueId);
}

/// Public catalogue connections are read-only and confined to background isolates.
class SQLiteFoodCatalogue implements FoodCatalogue {
  SQLiteFoodCatalogue({CatalogueInstaller? installer})
    : _installer = installer ?? CatalogueInstaller();
  final CatalogueInstaller _installer;

  @override
  Future<List<CatalogueSource>> sources() async {
    final path = await _installer.install();
    return Isolate.run(() {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        return db
            .select('SELECT * FROM catalogue_source ORDER BY name, id')
            .map(CatalogueSource.fromRow)
            .toList();
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<List<MealEntity>> search(
    String query, {
    Set<String>? sourceIds,
  }) async {
    final match = catalogueMatch(query);
    if (match == null || (sourceIds != null && sourceIds.isEmpty)) {
      return const [];
    }
    final path = await _installer.install();
    return Isolate.run(
      () => searchCatalogueFile(
        path,
        match,
        exactName: normalizeFoodSearchText(query),
        sourceIds: sourceIds,
      ),
    );
  }

  @override
  Future<MealEntity?> getById(String catalogueId) async {
    if (!RegExp(
      r'^[a-z][a-z0-9-]*:[A-Za-z0-9][A-Za-z0-9._-]*$',
    ).hasMatch(catalogueId)) {
      return null;
    }
    final path = await _installer.install();
    return Isolate.run(() {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        final rows = db.select(
          'SELECT f.*, s.name AS source_name FROM food f '
          'JOIN catalogue_source s ON s.id=f.source WHERE code=?',
          [catalogueId],
        );
        return rows.isEmpty ? null : catalogueMeal(db, rows.single);
      } finally {
        db.close();
      }
    });
  }
}

/// Serializes installation and resets after failures so Retry can try again.
/// Content-addressed files make replacement atomic even if an old reader is
/// still active. A rename publishes only a complete, fingerprint-checked file.
class CatalogueInstaller {
  CatalogueInstaller({
    Future<Directory> Function()? supportDirectory,
    Future<Uint8List> Function(String)? readAsset,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _readAsset = readAsset ?? _bundleBytes;

  final Future<Directory> Function() _supportDirectory;
  final Future<Uint8List> Function(String) _readAsset;
  Future<String>? _installation;

  static Future<Uint8List> _bundleBytes(String name) async {
    final data = await rootBundle.load(name);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<String> install() =>
      _installation ??= _install().catchError((Object e) {
        _installation = null;
        throw e;
      });

  Future<String> _install() async {
    final fingerprint = String.fromCharCodes(
      await _readAsset('assets/food-data/fingerprint'),
    ).trim();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      throw const FormatException('Invalid catalogue fingerprint');
    }
    final directory = Directory(
      p.join((await _supportDirectory()).path, 'food-catalogue'),
    );
    await directory.create(recursive: true);
    final destination = p.join(directory.path, '$fingerprint.sqlite');
    if (await File(destination).exists()) return destination;
    final bytes = await _readAsset('assets/food-data/food-data.sqlite');
    await Isolate.run(() async {
      if (sha256.convert(bytes).toString() != fingerprint) {
        throw const FormatException('Catalogue fingerprint mismatch');
      }
      final temporary = File('$destination.tmp');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(destination);
        // The support directory belongs exclusively to this public catalogue.
        for (final file in directory.listSync().whereType<File>()) {
          if (file.path != destination && file.path.endsWith('.sqlite')) {
            await file.delete();
          }
        }
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
    return destination;
  }
}

List<MealEntity> searchCatalogueFile(
  String path,
  String match, {
  String exactName = '',
  Set<String>? sourceIds,
}) {
  if (sourceIds != null && sourceIds.isEmpty) return const [];
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    db.createFunction(
      functionName: 'primary_name',
      argumentCount: const AllowedArgumentCount(1),
      function: (args) =>
          normalizeFoodSearchText((args.single as String).split(',').first),
    );
    final sources = sourceIds == null ? null : (sourceIds.toList()..sort());
    final filter = sources == null
        ? ''
        : ' AND food_search.source IN (${List.filled(sources.length, '?').join(',')})';
    final rows = db.select(
      "SELECT f.*, s.name AS source_name FROM food_search JOIN food f ON f.code=food_search.code "
      "JOIN catalogue_source s ON s.id=f.source WHERE food_search MATCH ? AND food_search.locale='en'$filter "
      'ORDER BY CASE WHEN primary_name(f.name)=? THEN 0 ELSE 1 END, rank, '
      'f.source, CAST(f.source_id AS INTEGER), f.code LIMIT 25',
      [match, ...?sources, exactName],
    );
    return [for (final row in rows) catalogueMeal(db, row)];
  } finally {
    db.close();
  }
}

MealEntity catalogueMeal(Database db, Row row) {
  final code = row['code'] as String;
  return MealEntity(
    code: code,
    name: row['name'] as String,
    url: row['url'] as String,
    catalogueSourceName: row['source_name'] as String,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    nutriments: MealNutrimentsEntity.fromCatalogue(
      jsonDecode(row['nutrition'] as String) as Map<String, dynamic>,
    ),
    source: MealSourceEntity.catalogue,
    detailed: true,
    portions: [
      for (final portion in db.select(
        'SELECT * FROM food_portion WHERE code=? ORDER BY position, id',
        [code],
      ))
        MealPortionEntity(
          id: portion['id'] as String,
          label: portion['label'] as String,
          englishLabel: portion['label'] as String,
          gramWeight: double.parse(portion['gram_weight'] as String),
          localized: false,
        ),
    ],
  );
}
