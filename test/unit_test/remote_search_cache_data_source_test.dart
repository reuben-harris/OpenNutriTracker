import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';

MealDBO meal(
  String code,
  String name, {
  bool detailed = false,
  double? kcal,
  double? vitamin,
  double? serving,
}) => MealDBO(
  code: code,
  name: name,
  brands: 'Test Brand',
  thumbnailImageUrl: null,
  mainImageUrl: null,
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: serving,
  servingUnit: 'g',
  servingSize: null,
  source: MealSourceDBO.off,
  detailed: detailed,
  nutriments: MealNutrimentsDBO(
    energyKcal100: kcal,
    carbohydrates100: null,
    fat100: null,
    proteins100: null,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
    vitaminC100: vitamin,
  ),
);

void main() {
  late Directory directory;
  late RemoteSearchCacheDataSource cache;
  late DateTime now;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('off-sql-test-');
    now = DateTime(2026, 1, 1);
    cache = RemoteSearchCacheDataSource(
      databasePath: () async => '${directory.path}/cache.sqlite',
      now: () => now,
    );
  });
  tearDown(() async {
    AppLocale.reset();
    await directory.delete(recursive: true);
  });
  test('persists and searches without any Hive box or adapter', () async {
    await cache.cacheAll([meal('1', 'Orange chocolate'), meal('2', 'Orange')]);
    expect(await cache.count, 2);
    expect((await cache.search('ORANGE')).first.code, '2');
    expect(await cache.search('orange OR chocolate'), isEmpty);
    expect(await cache.search('" -*'), isEmpty);
    final reopened = RemoteSearchCacheDataSource(
      databasePath: () async => '${directory.path}/cache.sqlite',
    );
    expect((await reopened.getByBarcode('2'))!.name, 'Orange');
    expect(await reopened.getStorageSizeBytes(), greaterThan(0));
  });
  test(
    'search refreshes supplied fields, full-only fields and zero survive',
    () async {
      await cache.cache(
        meal(
          '1',
          'Old name',
          detailed: true,
          kcal: 100,
          vitamin: 15,
          serving: 30,
        ),
      );
      await cache.cacheFromSearch([meal('1', 'New name', kcal: 0)]);
      final saved = (await cache.getDetailedByBarcode('1'))!;
      expect(saved.name, 'New name');
      expect(saved.nutriments.energyKcal100, 0);
      expect(saved.nutriments.vitaminC100, 15);
      expect(saved.servingQuantity, 30);
      expect(await cache.search('old'), isEmpty);
      expect((await cache.search('new')).single.code, '1');
      expect(await cache.count, 1);
    },
  );
  test(
    'full fetch authoritatively replaces a previously detailed record',
    () async {
      await cache.cache(
        meal('1', 'Old', detailed: true, vitamin: 15, serving: 30),
      );
      await cache.cache(meal('1', 'Fresh', detailed: true));
      final saved = (await cache.getDetailedByBarcode('1'))!;
      expect(saved.nutriments.vitaminC100, isNull);
      expect(saved.servingQuantity, isNull);
      await cache.cache(meal('2', 'Summary'));
      expect(await cache.getDetailedByBarcode('2'), isNull);
    },
  );
  test('successful repeated search extends retention; reads do not', () async {
    await cache.cacheAll([meal('1', 'Orange'), meal('2', 'Apple')]);
    now = now.add(const Duration(days: 89));
    await cache.cacheFromSearch([meal('1', 'Orange refreshed')]);
    await cache.getByBarcode('2');
    now = now.add(const Duration(days: 2));
    expect(await cache.pruneStale(const Duration(days: 90)), 1);
    expect(await cache.getByBarcode('2'), isNull);
    expect(await cache.getByBarcode('1'), isNotNull);
    expect(await cache.search('apple'), isEmpty);
  });
  test('localized entries never answer a lookup in another language', () async {
    await cache.cache(meal('1', 'Apple'), language: 'en');
    await cache.cache(meal('1', 'Apfel'), language: 'de');
    expect((await cache.getByBarcode('1'))!.name, 'Apple');
    AppLocale.select('de');
    expect((await cache.getByBarcode('1'))!.name, 'Apfel');
    expect(await cache.search('apple'), isEmpty);
    AppLocale.select('fr');
    expect(await cache.getByBarcode('1'), isNull);
  });
  test('clear rejects late writes and reclaims cached payload space', () async {
    final oldGeneration = cache.generation;
    await cache.cacheAll([
      for (var i = 0; i < 50; i++) meal('$i', 'Orange ${'x' * 2000}'),
    ]);
    final before = await cache.getStorageSizeBytes();
    await cache.clear();
    await cache.cache(meal('late', 'Orange'), generation: oldGeneration);
    expect(await cache.count, 0);
    expect(await cache.search('orange'), isEmpty);
    expect(await cache.getStorageSizeBytes(), lessThan(before));
    await cache.cache(meal('new', 'Orange'));
    expect(await cache.count, 1);
  });
  test(
    'simultaneous duplicate writes are serialized and never duplicate',
    () async {
      await Future.wait([
        cache.cache(meal('1', 'First')),
        cache.cache(meal('1', 'Second')),
      ]);
      expect(await cache.count, 1);
      expect((await cache.getByBarcode('1'))!.name, 'Second');
    },
  );
}
