import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/food_cache_maintenance.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'food_search_engine_test.dart' show food;

class Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  Paths(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'one action clears product and image files, keeps photos/catalogue, refreshes size',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'food-cache-clear-',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = Paths(directory.path);
      final images = CacheManager(
        Config(
          'images',
          repo: JsonCacheInfoRepository.withFile(
            File('${directory.path}/images.json'),
          ),
        ),
      );
      final products = RemoteSearchCacheDataSource(
        databasePath: () async => '${directory.path}/off.sqlite',
      );
      try {
        await products.cache(MealDBO.fromMealEntity(food('1', 'Orange')));
        final first = await images.putFile(
          'https://example.test/1',
          Uint8List.fromList([1, 2, 3]),
        );
        final orphan = await images.putFile(
          'https://example.test/expired-product',
          Uint8List.fromList([4, 5]),
        );
        final photo = File('${directory.path}/my-photo.webp')
          ..writeAsBytesSync([9]);
        final catalogue = File('${directory.path}/catalogue.sqlite')
          ..writeAsBytesSync([8]);
        final action = FoodCacheMaintenance(products, images);
        expect(await action.getStorageSizeBytes(), greaterThan(0));
        await action.clear();
        expect(await products.count, 0);
        expect(await first.exists(), isFalse);
        expect(await orphan.exists(), isFalse);
        expect(await images.getFileFromCache('https://example.test/1'), isNull);
        expect(await photo.readAsBytes(), [9]);
        expect(await catalogue.readAsBytes(), [8]);
        expect(
          await action.getStorageSizeBytes(),
          await products.getStorageSizeBytes(),
        );
      } finally {
        await images.dispose();
        PathProviderPlatform.instance = previous;
        await directory.delete(recursive: true);
      }
    },
  );
}
