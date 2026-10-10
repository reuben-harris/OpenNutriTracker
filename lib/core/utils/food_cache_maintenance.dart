import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';

/// The settings action covers product data and all downloaded meal images.
/// User-attached photos and the bundled catalogue use separate storage.
class FoodCacheMaintenance {
  FoodCacheMaintenance(this.products, this.images);
  final RemoteSearchCacheDataSource products;
  final CacheManager images;
  Future<int> getStorageSizeBytes() async {
    final sizes = await Future.wait([
      products.getStorageSizeBytes(),
      _imageStorageSizeBytes(),
    ]);
    return sizes.fold<int>(0, (total, size) => total + size);
  }

  Future<int> _imageStorageSizeBytes() async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, images.config.cacheKey),
    );
    if (!await directory.exists()) return 0;
    var bytes = 0;
    await for (final entry in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File) {
        try {
          bytes += await entry.length();
        } on FileSystemException {
          /* Concurrent image eviction. */
        }
      }
    }
    return bytes;
  }

  Future<void> clear() async {
    await Future.wait([products.clear(), images.emptyCache()]);
    images.store.emptyMemoryCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
