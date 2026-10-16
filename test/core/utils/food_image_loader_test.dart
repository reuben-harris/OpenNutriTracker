import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:opennutritracker/core/utils/food_image_loader.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

MealEntity imageMeal({String? local, String? thumbnail, String? main}) =>
    MealEntity(
      code: 'food',
      name: 'Food',
      localImagePath: local,
      thumbnailImageUrl: thumbnail,
      mainImageUrl: main,
      url: null,
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: MealNutrimentsEntity.empty(),
      source: MealSourceEntity.off,
    );

class ImageCache extends Fake implements BaseCacheManager {
  final cached = <String, FileInfo>{};
  final reads = <String>[];
  final downloads = <String>[];
  final failures = <String>{};
  FileInfo? downloaded;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    reads.add(key);
    if (failures.contains(key)) throw FileSystemException('unreadable cache');
    return cached[key];
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    downloads.add(url);
    if (downloaded == null) throw const HttpException('image unavailable');
    return downloaded!;
  }
}

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String directory;
  _Paths(this.directory);
  @override
  Future<String?> getTemporaryPath() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File local;
  late File thumbnail;
  late File main;
  late ImageCache cache;
  late FoodImageLoader loader;
  late IOFileSystem files;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('food-images-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    files = IOFileSystem('cache');
    local = await File('${directory.path}/local').writeAsBytes([1]);
    final thumbnailFile = await files.createFile('thumbnail');
    final mainFile = await files.createFile('main');
    thumbnail = await thumbnailFile.writeAsBytes([2]);
    main = await mainFile.writeAsBytes([3]);
    cache = ImageCache()
      ..cached['thumb-url'] = FileInfo(
        thumbnailFile,
        FileSource.Cache,
        DateTime(2000),
        'thumb-url',
      )
      ..cached['main-url'] = FileInfo(
        mainFile,
        FileSource.Cache,
        DateTime(2000),
        'main-url',
      );
    loader = FoodImageLoader(
      cacheManager: cache,
      resolveLocalPath: (path) async => '${directory.path}/$path',
    );
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test(
    'existing local photo wins without consulting cache or network',
    () async {
      final result = await loader
          .load(
            imageMeal(local: 'local', thumbnail: 'thumb-url', main: 'main-url'),
          )
          .toList();
      expect(result.single.file!.path, local.path);
      expect(cache.reads, isEmpty);
      expect(cache.downloads, isEmpty);
    },
  );

  test('expired cached thumbnail wins without revalidation', () async {
    final result = await loader
        .load(imageMeal(thumbnail: 'thumb-url', main: 'main-url'))
        .toList();
    expect(result.single.file!.path, thumbnail.path);
    expect(cache.reads, ['thumb-url']);
    expect(cache.downloads, isEmpty);
  });

  test(
    'cached detail image is reused before downloading a thumbnail',
    () async {
      cache.cached.remove('thumb-url');
      final result = await loader
          .load(imageMeal(thumbnail: 'thumb-url', main: 'main-url'))
          .toList();
      expect(result.single.file!.path, main.path);
      expect(cache.reads, ['thumb-url', 'main-url']);
      expect(cache.downloads, isEmpty);
    },
  );

  test('missing local and cached files do not block later sources', () async {
    await thumbnail.delete();
    final result = await loader
        .load(
          imageMeal(local: 'missing', thumbnail: 'thumb-url', main: 'main-url'),
        )
        .toList();
    expect(result.single.file!.path, main.path);
    expect(cache.downloads, isEmpty);
  });

  test(
    'unreadable local file and failed cache lookup skip to detail',
    () async {
      cache.failures.add('thumb-url');
      final result = await loader
          .load(imageMeal(local: '.', thumbnail: 'thumb-url', main: 'main-url'))
          .toList();
      expect(result.single.file!.path, main.path);
    },
  );

  test(
    'empty local and URLs produce fallback without cache or requests',
    () async {
      final result = await loader
          .load(imageMeal(local: '', thumbnail: '  ', main: ''))
          .toList();
      expect(result.single.file, isNull);
      expect(result.single.isDownloading, isFalse);
      expect(cache.reads, isEmpty);
      expect(cache.downloads, isEmpty);
    },
  );

  test('cold cache downloads only the attached thumbnail URL', () async {
    cache.cached.clear();
    cache.downloaded = FileInfo(
      await files.createFile('thumbnail'),
      FileSource.Online,
      DateTime(2100),
      'thumb-url',
    );
    final result = await loader
        .load(imageMeal(thumbnail: 'thumb-url', main: 'main-url'))
        .toList();
    expect(result.first.isDownloading, isTrue);
    expect(result.last.file!.path, thumbnail.path);
    expect(cache.downloads, ['thumb-url']);
  });

  test('main URL downloads only when no thumbnail URL exists', () async {
    cache.cached.clear();
    cache.downloaded = FileInfo(
      await files.createFile('main'),
      FileSource.Online,
      DateTime(2100),
      'main-url',
    );
    final result = await loader
        .load(imageMeal(thumbnail: ' ', main: 'main-url'))
        .toList();
    expect(result.last.file!.path, main.path);
    expect(cache.downloads, ['main-url']);
  });

  test(
    'identical URLs are read once and failures finish with fallback',
    () async {
      cache.cached.clear();
      final result = await loader
          .load(imageMeal(thumbnail: 'same-url', main: 'same-url'))
          .toList();
      expect(cache.reads, ['same-url']);
      expect(cache.downloads, ['same-url']);
      expect(result.first.isDownloading, isTrue);
      expect(result.last.isDownloading, isFalse);
      expect(result.last.file, isNull);
    },
  );

  test('an unreadable downloaded file finishes with fallback', () async {
    cache.cached.clear();
    cache.downloaded = FileInfo(
      await files.createFile('missing'),
      FileSource.Online,
      DateTime(2100),
      'thumb-url',
    );
    final result = await loader
        .load(imageMeal(thumbnail: 'thumb-url'))
        .toList();
    expect(result.last.file, isNull);
    expect(result.last.isDownloading, isFalse);
  });
  test(
    'full size prefers local then cached main without reading thumbnail',
    () async {
      final meal = imageMeal(
        local: 'local',
        thumbnail: 'thumb-url',
        main: 'main-url',
      );
      expect(
        (await loader.load(meal, mode: FoodImageMode.fullSize).toList())
            .single
            .file!
            .path,
        local.path,
      );
      expect(cache.reads, isEmpty);
      await local.delete();
      expect(
        (await loader.load(meal, mode: FoodImageMode.fullSize).toList())
            .single
            .file!
            .path,
        main.path,
      );
      expect(cache.reads, ['main-url']);
      expect(cache.downloads, isEmpty);
    },
  );
  test(
    'full size downloads main directly even with a cached preview',
    () async {
      cache.cached.remove('main-url');
      cache.downloaded = FileInfo(
        await files.createFile('main'),
        FileSource.Online,
        DateTime(2100),
        'main-url',
      );
      final result = await loader
          .load(
            imageMeal(thumbnail: 'thumb-url', main: 'main-url'),
            mode: FoodImageMode.fullSize,
          )
          .toList();
      expect(result.first.isDownloading, true);
      expect(result.last.file!.path, main.path);
      expect(cache.reads, ['main-url']);
      expect(cache.downloads, ['main-url']);
    },
  );
  test(
    'full size falls back to cached preview after a main download failure',
    () async {
      cache.cached.remove('main-url');
      final result = await loader
          .load(
            imageMeal(thumbnail: 'thumb-url', main: 'main-url'),
            mode: FoodImageMode.fullSize,
          )
          .toList();
      expect(result.first.isDownloading, true);
      expect(result.last.file!.path, thumbnail.path);
      expect(cache.downloads, ['main-url']);
    },
  );
  test(
    'full size uses preview when main is absent and never retries a failed main',
    () async {
      expect(
        (await loader
                .load(
                  imageMeal(thumbnail: 'thumb-url'),
                  mode: FoodImageMode.fullSize,
                )
                .toList())
            .single
            .file!
            .path,
        thumbnail.path,
      );
      cache.cached.clear();
      final result = await loader
          .load(imageMeal(main: 'main-url'), mode: FoodImageMode.fullSize)
          .toList();
      expect(result.last.file, isNull);
      expect(cache.downloads, ['main-url']);
    },
  );
  test(
    'recipe meal carries its attached photo and ingredient preview fallback',
    () async {
      final recipe = RecipeEntity(
        id: 'recipe',
        name: 'Recipe',
        description: null,
        ingredients: [
          RecipeIngredientEntity(
            snapshotMeal: imageMeal(thumbnail: 'thumb-url'),
            quantity: FoodAmountSelection.fromSnapshot(
              amount: 100,
              unit: 'g',
              baseUnit: 'g',
              factor: (100) / (100),
            ),
          ),
        ],
        totalWeightG: 100,
        aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        servingsCount: null,
        imagePath: 'local',
      );
      final meal = recipe.toMealEntity();
      expect(meal.localImagePath, 'local');
      expect(meal.thumbnailImageUrl, 'thumb-url');
      expect((await loader.load(meal).toList()).single.file!.path, local.path);
      expect(
        (await loader
                .load(recipe.copyWith(clearImagePath: true).toMealEntity())
                .toList())
            .single
            .file!
            .path,
        thumbnail.path,
      );
    },
  );
}
