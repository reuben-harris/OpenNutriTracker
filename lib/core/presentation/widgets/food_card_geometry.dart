import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

abstract final class FoodCardGeometry {
  static const double thumbnailSize = 52;
  static const double thumbnailRadius = Dimens.radiusS;
  static const double radius = Dimens.radiusM;
  static const double gap = Dimens.spacing12;
  static const padding = EdgeInsets.all(Dimens.spacing12);
  static const margin = EdgeInsets.symmetric(
    horizontal: Dimens.spacing16,
    vertical: Dimens.spacing4,
  );
}
