import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/food_image_loader.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodImage extends StatefulWidget {
  final MealEntity meal;
  final bool isRefreshing;
  final FoodImageLoader? imageLoader;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final FoodImageMode mode;
  final String? refreshIdentifier, refreshLabel;
  final VoidCallback? onTap;
  final String? tapLabel;
  final String tapIdentifier;

  const FoodImage({
    super.key,
    required this.meal,
    this.isRefreshing = false,
    this.imageLoader,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.fallbackIcon = Icons.restaurant_rounded,
    this.mode = FoodImageMode.preview,
    this.refreshIdentifier,
    this.refreshLabel,
    this.onTap,
    this.tapLabel,
    this.tapIdentifier = 'food-image-enlarge',
  });

  @override
  State<FoodImage> createState() => _FoodImageState();
}

class _FoodImageState extends State<FoodImage> {
  StreamSubscription<FoodImageLoad>? _subscription;
  Timer? _feedbackTimer;
  File? _file;
  bool _showProgress = false;
  bool _photoReady = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FoodImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal.localImagePath != widget.meal.localImagePath ||
        oldWidget.meal.thumbnailImageUrl != widget.meal.thumbnailImageUrl ||
        oldWidget.meal.mainImageUrl != widget.meal.mainImageUrl ||
        oldWidget.imageLoader != widget.imageLoader ||
        oldWidget.mode != widget.mode) {
      _load(
        preserveImage:
            (widget.isRefreshing || oldWidget.isRefreshing) &&
            oldWidget.meal.code == widget.meal.code,
      );
    }
  }

  void _load({bool preserveImage = false}) {
    final generation = ++_generation;
    _subscription?.cancel();
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    if (!preserveImage) {
      _file = null;
      _photoReady = false;
    }
    _showProgress = false;
    final meal = widget.meal;
    if ([
      meal.localImagePath,
      meal.thumbnailImageUrl,
      meal.mainImageUrl,
    ].every((value) => value == null || value.trim().isEmpty)) {
      _file = null;
      _photoReady = false;
      return;
    }
    _subscription = (widget.imageLoader ?? locator<FoodImageLoader>())
        .load(meal, mode: widget.mode)
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
      if (_file != file) _photoReady = false;
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
    final photo = _file;
    final content = photo == null
        ? _fallback(palette)
        : Image.file(
            photo,
            fit: widget.fit,
            frameBuilder: (_, child, frame, synchronous) {
              if (frame != null || synchronous) _markPhotoReady(true, photo);
              return child;
            },
            errorBuilder: (_, _, _) {
              _markPhotoReady(false, photo);
              return _fallback(palette);
            },
          );
    final rendered = ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
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
                        ? widget.refreshIdentifier ??
                              'food-image-refresh-progress'
                        : 'food-image-loading-progress',
                    label: widget.isRefreshing
                        ? widget.refreshLabel ??
                              S.of(context).foodImageLoadingLabel
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
    if (widget.onTap == null || !_photoReady || loading) return rendered;
    return Semantics(
      identifier: widget.tapIdentifier,
      label: widget.tapLabel,
      child: GestureDetector(onTap: widget.onTap, child: rendered),
    );
  }

  void _markPhotoReady(bool ready, File photo) {
    if (widget.onTap == null || _photoReady == ready) return;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _generation &&
          _file == photo &&
          _photoReady != ready) {
        setState(() => _photoReady = ready);
      }
    });
  }

  Widget _fallback(AppPalette palette) => ColoredBox(
    color: palette.surfaceMuted,
    child: Icon(widget.fallbackIcon, color: palette.textMuted, size: 24),
  );
}
