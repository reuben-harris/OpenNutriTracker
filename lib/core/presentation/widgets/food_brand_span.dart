import 'package:flutter/material.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The brand-position label for packaged foods and local database entries.
TextSpan? foodBrandSpan(BuildContext context, MealEntity meal) {
  if (meal.source == MealSourceEntity.catalogue) {
    return TextSpan(
      text: meal.catalogueSourceName ?? S.of(context).foodSourceCatalogueLabel,
    );
  }
  final brand = meal.brands?.trim();
  if (brand != null && brand.isNotEmpty) return TextSpan(text: brand);
  if (meal.source != MealSourceEntity.off) return null;
  return TextSpan(
    text: S.of(context).unknownBrandLabel,
    style: const TextStyle(fontStyle: FontStyle.italic),
  );
}
