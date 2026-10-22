import 'package:flutter/material.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// OFF foods always have a brand label, including a styled missing-value label.
TextSpan? foodBrandSpan(BuildContext context, MealEntity meal) {
  final brand = meal.brands?.trim();
  if (brand != null && brand.isNotEmpty) return TextSpan(text: brand);
  if (meal.source != MealSourceEntity.off) return null;
  return TextSpan(
    text: S.of(context).unknownBrandLabel,
    style: const TextStyle(fontStyle: FontStyle.italic),
  );
}
