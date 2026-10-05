import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_food_nutriment_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';

/// Quotes FTS tokens as literals; only the last word is a prefix.
/// Punctuation (including FTS operators) is treated as a word separator.
String? catalogueMatch(String query) {
  final words = RegExp(
    r'[\p{L}\p{N}]+',
    unicode: true,
  ).allMatches(query).map((m) => m.group(0)!).toList();
  if (words.isEmpty) return null;
  return [
    for (var i = 0; i < words.length; i++)
      '"${words[i].replaceAll('"', '""')}"${i == words.length - 1 ? '*' : ''}',
  ].join(' AND ');
}

abstract class FoodCatalogue {
  Future<List<MealEntity>> search(String query);
  Future<MealEntity?> getById(String catalogueId);
}

/// Public, unencrypted catalogue, separate from the personal Hive databases.
/// Queries and conversion run in short-lived background isolates. Connections
/// are read-only and closed before the isolate returns.
class SQLiteFoodCatalogue implements FoodCatalogue {
  SQLiteFoodCatalogue({CatalogueInstaller? installer})
    : _installer = installer ?? CatalogueInstaller();
  final CatalogueInstaller _installer;

  @override
  Future<List<MealEntity>> search(String query) async {
    final match = catalogueMatch(query);
    if (match == null) return const [];
    final path = await _installer.install();
    return Isolate.run(() => searchCatalogueFile(path, match));
  }

  @override
  Future<MealEntity?> getById(String catalogueId) async {
    final match = RegExp(r'^usda:([1-9][0-9]*)$').firstMatch(catalogueId);
    final id = match == null ? null : int.tryParse(match.group(1)!);
    if (id == null) return null;
    final path = await _installer.install();
    return Isolate.run(() {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        final rows = db.select(
          "SELECT fdc_id, description FROM food_name WHERE fdc_id = ? AND locale = 'en'",
          [id],
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

List<MealEntity> searchCatalogueFile(String path, String match) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final rows = db.select(
      "SELECT fdc_id, description FROM food_search "
      "WHERE food_search MATCH ? AND locale = 'en' "
      'ORDER BY rank, CAST(fdc_id AS INTEGER) LIMIT 25',
      [match],
    );
    return [for (final row in rows) catalogueMeal(db, row)];
  } finally {
    db.close();
  }
}

MealEntity catalogueMeal(Database db, Row row) {
  final id = row['fdc_id'] as int;
  final nutrients = db.select(
    'SELECT nutrient_id, amount FROM food_nutrient WHERE fdc_id = ? ORDER BY nutrient_id, id',
    [id],
  );
  final portions = <MealPortionEntity>[];
  for (final portion in db.select(
    'SELECT p.amount, p.portion_description, p.modifier, p.gram_weight, m.name AS unit_name '
    'FROM food_portion p LEFT JOIN measure_unit m '
    'ON m.dataset = p.dataset AND m.id = p.measure_unit_id '
    'WHERE p.fdc_id = ? ORDER BY p.seq_num, p.id',
    [id],
  )) {
    final weight = double.tryParse(portion['gram_weight']?.toString() ?? '');
    if (weight == null || !weight.isFinite || weight <= 0) continue;
    final description = (portion['portion_description'] as String?)?.trim();
    final modifier = (portion['modifier'] as String?)?.trim();
    final unit = portion['unit_name'] as String?;
    final amount = double.tryParse(portion['amount']?.toString() ?? '');
    final count = amount == null || !amount.isFinite || amount <= 0
        ? 1.0
        : amount;
    final measure = unit == null || unit == 'undetermined' ? modifier : unit;
    final label = description != null && description.isNotEmpty
        ? (RegExp(r'^\d').hasMatch(description)
              ? description
              : '${_number(count)} $description')
        : '${_number(count)} ${measure == null || measure.isEmpty ? 'portion' : measure}';
    portions.add(
      MealPortionEntity(
        label: label,
        englishLabel: label,
        gramWeight: weight,
        localized: false,
      ),
    );
  }
  return MealEntity(
    code: 'usda:$id',
    name: row['description'] as String,
    url: FDCConst.getFoodDetailUrlString('$id'),
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    nutriments: MealNutrimentsEntity.fromFDCNutriments([
      for (final nutrient in nutrients)
        FDCFoodNutrimentDTO(
          nutrientId: nutrient['nutrient_id'] as int,
          amount: double.tryParse(nutrient['amount']?.toString() ?? ''),
        ),
    ]),
    source: MealSourceEntity.fdc,
    detailed: true,
    portions: portions,
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
