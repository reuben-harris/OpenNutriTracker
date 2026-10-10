import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_geometry.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/food_image_loader.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodThumbnail extends StatefulWidget {
  final MealEntity meal;
  final bool isRefreshing;
  final FoodImageLoader? imageLoader;

  const FoodThumbnail({
    super.key,
    required this.meal,
    this.isRefreshing = false,
    this.imageLoader,
  });

  @override
  State<FoodThumbnail> createState() => _FoodThumbnailState();
}

class _FoodThumbnailState extends State<FoodThumbnail> {
  StreamSubscription<FoodImageLoad>? _subscription;
  Timer? _feedbackTimer;
  File? _file;
  bool _showProgress = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FoodThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal.localImagePath != widget.meal.localImagePath ||
        oldWidget.meal.thumbnailImageUrl != widget.meal.thumbnailImageUrl ||
        oldWidget.meal.mainImageUrl != widget.meal.mainImageUrl ||
        oldWidget.imageLoader != widget.imageLoader) {
      _load(
        preserveImage:
            widget.isRefreshing && oldWidget.meal.code == widget.meal.code,
      );
    }
  }

  void _load({bool preserveImage = false}) {
    final generation = ++_generation;
    _subscription?.cancel();
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    if (!preserveImage) _file = null;
    _showProgress = false;
    final meal = widget.meal;
    if ([
      meal.localImagePath,
      meal.thumbnailImageUrl,
      meal.mainImageUrl,
    ].every((value) => value == null || value.trim().isEmpty)) {
      _file = null;
      return;
    }
    _subscription = (widget.imageLoader ?? locator<FoodImageLoader>())
        .load(meal)
        .listen(
          (result) {
            if (!mounted || generation != _generation) return;
            if (result.isDownloading) {
              _feedbackTimer ??= Timer(const Duration(milliseconds: 200), () {
                if (mounted && generation == _generation) {
                  setState(() => _showProgress = true);
                }
              });
            } else {
              _finish(generation, result.file);
            }
          },
          onError: (Object error) => _finish(generation, null),
          onDone: () {
            if (mounted && generation == _generation) {
              _finish(generation, _file);
            }
          },
        );
  }

  void _finish(int generation, File? file) {
    if (!mounted || generation != _generation) return;
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    setState(() {
      _file = file;
      _showProgress = false;
    });
  }

  @override
  void dispose() {
    ++_generation;
    _feedbackTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final loading = widget.isRefreshing || _showProgress;
    final content = _file == null
        ? _fallback(palette)
        : Image.file(
            _file!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(palette),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(FoodCardGeometry.thumbnailRadius),
      child: SizedBox.square(
        dimension: FoodCardGeometry.thumbnailSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (loading)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: content,
              )
            else
              content,
            if (loading)
              ColoredBox(
                color: palette.surface.withValues(alpha: 0.35),
                child: Center(
                  child: Semantics(
                    identifier: widget.isRefreshing
                        ? 'diary-intake-refresh-progress'
                        : 'food-image-loading-progress',
                    label: widget.isRefreshing
                        ? S.of(context).diaryRefreshLabel
                        : S.of(context).foodImageLoadingLabel,
                    excludeSemantics: true,
                    child: const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(AppPalette palette) => ColoredBox(
    color: palette.surfaceMuted,
    child: Icon(Icons.restaurant_rounded, color: palette.textMuted, size: 24),
  );
}
