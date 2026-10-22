import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temporary;
  late Uint8List bytes;
  late String fingerprint;
  late CatalogueInstaller installer;
  late SQLiteFoodCatalogue catalogue;
  final reads = <String>[];

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('food-catalogue-test-');
    final file = File('${temporary.path}/fixture.sqlite');
    final db = sqlite3.open(file.path);
    db.execute(File('nix/food-data/schema.sql').readAsStringSync());
    db.execute(
      "INSERT INTO catalogue_source VALUES ('usda', 'FoodData Central', '{}', 'USDA', 'https://fdc.nal.usda.gov/', 'https://fdc.nal.usda.gov/', 0)",
    );
    for (final (id, name) in [
      (2, 'Apple raw'),
      (1, 'Apple raw'),
      (3, 'Apple juice'),
      (4, 'Pineapple'),
      (5, 'Raw apples'),
    ]) {
      insertFood(db, id, name);
    }
    db.execute("UPDATE food SET nutrition=? WHERE code='usda:1'", [
      '{"energyKcal100":"52","fat100":"0","proteins100":null,"sodium100":"2"}',
    ]);
    db.execute(
      "INSERT INTO food_portion VALUES ('usda:survey:1', 'usda:1', 1, '1 cup', '140')",
    );
    db.close();
    bytes = await file.readAsBytes();
    fingerprint = sha256.convert(bytes).toString();
    reads.clear();
    installer = CatalogueInstaller(
      supportDirectory: () async => Directory('${temporary.path}/support'),
      readAsset: (name) async {
        reads.add(name);
        return name.endsWith('fingerprint')
            ? Uint8List.fromList(fingerprint.codeUnits)
            : bytes;
      },
    );
    catalogue = SQLiteFoodCatalogue(installer: installer);
  });

  tearDown(() => temporary.delete(recursive: true));

  test(
    'single-character prefixes and all-word matching use relevance and ID ties',
    () async {
      expect(
        (await catalogue.search('a')).map((m) => m.code),
        contains('usda:1'),
      );
      final matches = await catalogue.search('apple r');
      expect(matches.map((m) => m.code), ['usda:1', 'usda:2']);
      expect(
        await catalogue.search('app raw'),
        isEmpty,
      ); // Only final word is a prefix.
      expect((await catalogue.search('APPLE, "r"!')).map((m) => m.code), [
        'usda:1',
        'usda:2',
      ]);
    },
  );

  test('built-in relevance precedes numeric ID', () async {
    final path = await installer.install();
    final db = sqlite3.open(path);
    insertFood(db, 10, 'Apple');
    db.close();
    expect((await catalogue.search('apple')).first.code, 'usda:10');
  });

  test(
    'exact primary title is selected before the 25-candidate limit',
    () async {
      final path = await installer.install();
      final db = sqlite3.open(path);
      for (var id = 10; id < 50; id++) {
        insertFood(db, id, 'Orange chicken');
      }
      insertFood(db, 999, 'Orange, raw');
      db.close();
      expect((await catalogue.search('ORANGE')).first.code, 'usda:999');
    },
  );

  test('source discovery and filtering retain independent food identities', () async {
    final path = await installer.install();
    final db = sqlite3.open(path);
    db.execute(
      "INSERT INTO catalogue_source VALUES ('other', 'Another database', '{\"main\":\"2024\"}', 'Publisher', 'https://example.org/', 'https://example.org/terms', 1)",
    );
    db.execute(
      "INSERT INTO food VALUES ('other:A1', 'other', 'A1', 'en', 'Apple raw', 'Kūmara', 'https://example.org/', '{}')",
    );
    db.execute(
      "INSERT INTO food_search VALUES ('other:A1', 'other', 'en', 'Apple raw', 'Kūmara')",
    );
    db.close();
    final sources = await catalogue.sources();
    expect(sources.map((s) => s.id), ['other', 'usda']);
    expect(sources.first.termsRequired, isTrue);
    expect(sources.first.releases, {'main': '2024'});
    expect(
      (await catalogue.search(
        'apple',
        sourceIds: {'other'},
      )).map((m) => m.code),
      ['other:A1'],
    );
    expect(
      (await catalogue.search('kumara')).single.catalogueSourceName,
      'Another database',
    );
    expect(
      await catalogue.search('apple', sourceIds: {"other') OR 1=1 --"}),
      isEmpty,
    );
    expect((await catalogue.getById('other:A1'))!.name, 'Apple raw');
  });

  test('no enabled sources returns immediately without installation', () async {
    expect(await catalogue.search('apple', sourceIds: {}), isEmpty);
    expect(reads, isEmpty);
  });

  test('empty and punctuation clear without installing or querying', () async {
    expect(await catalogue.search(''), isEmpty);
    expect(await catalogue.search('" -*?!'), isEmpty);
    expect(reads, isEmpty);
    // Operator words are literal terms rather than FTS syntax.
    expect(await catalogue.search('apple OR juice'), isEmpty);
  });

  test(
    'exact identity validates namespace and preserves null, zero and units',
    () async {
      for (final id in ['1', 'other:1', 'usda:-1', 'usda:1 OR 2', 'usda:01']) {
        expect(await catalogue.getById(id), isNull);
      }
      expect(await catalogue.getById('usda:999'), isNull);
      final meal = (await catalogue.getById('usda:1'))!;
      expect(meal.code, 'usda:1');
      expect(meal.mealUnit, 'g');
      expect(meal.servingQuantity, isNull);
      expect(meal.nutriments.energyKcal100, 52);
      expect(meal.nutriments.fat100, 0);
      expect(meal.nutriments.proteins100, isNull);
      expect(meal.nutriments.sodium100, 2);
      expect(meal.portions, hasLength(1));
      expect(meal.portions.single.label, '1 cup');
      expect(
        resolveFoodAmount(
          2,
          'portion:${meal.portions.first.id}',
          meal,
        )!.baseAmount,
        280,
      );
      expect(meal.nutriments.energyPerUnit! * 280, closeTo(145.6, 0.001));
    },
  );

  test(
    'installation is shared, read-only, reusable and replaces changed fingerprints',
    () async {
      final paths = await Future.wait([
        installer.install(),
        installer.install(),
      ]);
      expect(paths[0], paths[1]);
      expect(reads.where((s) => s.endsWith('.sqlite')), hasLength(1));
      final db = sqlite3.open(paths.first, mode: OpenMode.readOnly);
      expect(
        () => db.execute("DELETE FROM food"),
        throwsA(isA<SqliteException>()),
      );
      db.close();
      reads.clear();
      final reuse = CatalogueInstaller(
        supportDirectory: () async => Directory('${temporary.path}/support'),
        readAsset: (name) async {
          reads.add(name);
          return Uint8List.fromList(fingerprint.codeUnits);
        },
      );
      expect(await reuse.install(), paths.first);
      expect(reads, ['assets/food-data/fingerprint']);
      final secondFile = File('${temporary.path}/second.sqlite');
      await secondFile.writeAsBytes(bytes);
      final changed = sqlite3.open(secondFile.path);
      changed.execute(
        "UPDATE food SET name = 'Updated apple' WHERE code = 'usda:1'",
      );
      changed.close();
      bytes = await secondFile.readAsBytes();
      fingerprint = sha256.convert(bytes).toString();
      final replacement = CatalogueInstaller(
        supportDirectory: () async => Directory('${temporary.path}/support'),
        readAsset: (name) async => name.endsWith('fingerprint')
            ? Uint8List.fromList(fingerprint.codeUnits)
            : bytes,
      );
      final newPath = await replacement.install();
      expect(newPath, isNot(paths.first));
      expect(await File(paths.first).exists(), isFalse);
      expect(
        (await SQLiteFoodCatalogue(
          installer: replacement,
        ).getById('usda:1'))!.name,
        'Updated apple',
      );
    },
  );

  test(
    'installation failure can be retried and never publishes partial data',
    () async {
      var broken = true;
      final retry = CatalogueInstaller(
        supportDirectory: () async => Directory('${temporary.path}/retry'),
        readAsset: (name) async => name.endsWith('fingerprint')
            ? Uint8List.fromList(fingerprint.codeUnits)
            : broken
            ? Uint8List.fromList([1, 2])
            : bytes,
      );
      await expectLater(retry.install(), throwsFormatException);
      expect(
        Directory('${temporary.path}/retry/food-catalogue').listSync(),
        isEmpty,
      );
      broken = false;
      expect(await File(await retry.install()).exists(), isTrue);
    },
  );

  test('at most 25 matches ordered by built-in rank then numeric ID', () async {
    final path = await installer.install();
    // Mutate the test fixture, never the production connection.
    final db = sqlite3.open(path);
    for (var id = 10; id < 40; id++) {
      insertFood(db, id, 'Banana');
    }
    db.close();
    final matches = await catalogue.search('b');
    expect(matches, hasLength(25));
    expect(matches.first.code, 'usda:10');
    expect(matches.last.code, 'usda:34');
  });
}

void insertFood(Database db, int id, String name) {
  db.execute('INSERT INTO food VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
    'usda:$id',
    'usda',
    '$id',
    'en',
    name,
    '',
    'https://fdc.nal.usda.gov/fdc-app.html#/food-details/$id/nutrients',
    '{}',
  ]);
  db.execute('INSERT INTO food_search VALUES (?, ?, ?, ?, ?)', [
    'usda:$id',
    'usda',
    'en',
    name,
    '',
  ]);
}
