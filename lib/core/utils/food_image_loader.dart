import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

enum FoodImageMode { preview, fullSize }

class FoodImageLoad {
  final File? file;
  final bool isDownloading;

  const FoodImageLoad.downloading() : file = null, isDownloading = true;
  const FoodImageLoad.complete(this.file) : isDownloading = false;
}

/// Resolves only images already attached to a meal. Cache hits never revalidate.
class FoodImageLoader {
  final BaseCacheManager cacheManager;
  final Future<String> Function(String) resolveLocalPath;

  FoodImageLoader({
    required this.cacheManager,
    this.resolveLocalPath = UserImageStorage.absolutePath,
  });

  Stream<FoodImageLoad> load(
    MealEntity meal, {
    FoodImageMode mode = FoodImageMode.preview,
  }) => _load(meal, mode: mode);

  Stream<FoodImageLoad> _load(
    MealEntity meal, {
    required FoodImageMode mode,
    String? failedDownload,
  }) async* {
    final localPath = _nonEmpty(meal.localImagePath);
    if (localPath != null) {
      try {
        final file = File(await resolveLocalPath(localPath));
        if (await _readable(file)) {
          yield FoodImageLoad.complete(file);
          return;
        }
      } catch (_) {
        // A missing/unreadable local photo must not hide cached remote images.
      }
    }

    final thumbnail = _nonEmpty(meal.thumbnailImageUrl);
    final main = _nonEmpty(meal.mainImageUrl);
    final urls = mode == FoodImageMode.fullSize ? {?main} : {?thumbnail, ?main};
    for (final url in urls) {
      try {
        final cached = await cacheManager.getFileFromCache(url);
        if (cached != null && await _readable(cached.file)) {
          yield FoodImageLoad.complete(cached.file);
          return;
        }
      } catch (_) {
        // Continue through the remaining sources if a cache entry is unusable.
      }
    }

    final downloadUrl = mode == FoodImageMode.fullSize
        ? main
        : thumbnail ?? main;
    if (downloadUrl != null && downloadUrl != failedDownload) {
      yield const FoodImageLoad.downloading();
      try {
        final downloaded = await cacheManager.downloadFile(downloadUrl);
        if (await _readable(downloaded.file)) {
          yield FoodImageLoad.complete(downloaded.file);
          return;
        }
      } catch (_) {
        // Image failures are presented as the shared food fallback.
      }
    }
    if (mode == FoodImageMode.fullSize) {
      yield* _load(meal, mode: FoodImageMode.preview, failedDownload: main);
      return;
    }
    yield const FoodImageLoad.complete(null);
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  Future<bool> _readable(File file) async {
    RandomAccessFile? opened;
    try {
      opened = await file.open();
      return await opened.length() > 0;
    } on FileSystemException {
      return false;
    } finally {
      await opened?.close();
    }
  }
}
