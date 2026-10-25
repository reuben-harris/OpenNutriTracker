import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

class SharedRecipeParseException implements Exception {
  final String message;
  SharedRecipeParseException(this.message);

  @override
  String toString() => 'SharedRecipeParseException: $message';
}

double? _toDouble(dynamic v) => (v as num?)?.toDouble();

/// Compact array form of one recipe ingredient. Field order:
///   [name, brands, quantitySnapshot,
///    kcal/100, carbs/100, fat/100, protein/100,
///    sugars/100, satFat/100, fiber/100, thumbUrl]
///
/// Extended micros (vitamins/minerals) are intentionally excluded from the
/// QR payload to keep the encoded size within QR capacity. Recipients
/// reconstruct the recipe with macro data only; the aggregated micro
/// fields will be null on the imported recipe.
class SharedRecipeIngredient {
  final String? name;
  final String? brands;
  final FoodAmountSelection quantity;
  final NutrientAmount? energyKcal100;
  final NutrientAmount? carbohydrates100;
  final NutrientAmount? fat100;
  final NutrientAmount? proteins100;
  final NutrientAmount? sugars100;
  final NutrientAmount? saturatedFat100;
  final NutrientAmount? fiber100;
  final String? thumbnailImageUrl;

  const SharedRecipeIngredient({
    required this.name,
    required this.brands,
    required this.quantity,
    required this.energyKcal100,
    required this.carbohydrates100,
    required this.fat100,
    required this.proteins100,
    required this.sugars100,
    required this.saturatedFat100,
    required this.fiber100,
    required this.thumbnailImageUrl,
  });

  factory SharedRecipeIngredient.fromIngredient(RecipeIngredientEntity i) {
    final n = i.snapshotMeal.nutriments;
    return SharedRecipeIngredient(
      name: i.snapshotMeal.name,
      brands: i.snapshotMeal.brands,
      quantity: i.quantity,
      energyKcal100: n.energyKcal100,
      carbohydrates100: n.carbohydrates100,
      fat100: n.fat100,
      proteins100: n.proteins100,
      sugars100: n.sugars100,
      saturatedFat100: n.saturatedFat100,
      fiber100: n.fiber100,
      thumbnailImageUrl: i.snapshotMeal.thumbnailImageUrl,
    );
  }

  factory SharedRecipeIngredient.fromArray(List<dynamic> a) {
    String? atStr(int i) => a.length > i ? a[i] as String? : null;
    return SharedRecipeIngredient(
      name: a[0] as String?,
      brands: a[1] as String?,
      quantity: FoodAmountSelection.fromJson(
        Map<String, dynamic>.from(a[2] as Map),
      ),
      energyKcal100: NutrientAmount.fromSource(a[3]),
      carbohydrates100: NutrientAmount.fromSource(a[4]),
      fat100: NutrientAmount.fromSource(a[5]),
      proteins100: NutrientAmount.fromSource(a[6]),
      sugars100: NutrientAmount.fromSource(a[7]),
      saturatedFat100: NutrientAmount.fromSource(a[8]),
      fiber100: NutrientAmount.fromSource(a[9]),
      thumbnailImageUrl: atStr(10),
    );
  }

  List<dynamic> toArray() => [
    name,
    brands,
    quantity.toJson(),
    energyKcal100?.toJson(),
    carbohydrates100?.toJson(),
    fat100?.toJson(),
    proteins100?.toJson(),
    sugars100?.toJson(),
    saturatedFat100?.toJson(),
    fiber100?.toJson(),
    thumbnailImageUrl,
  ];

  RecipeIngredientEntity toIngredient() {
    return RecipeIngredientEntity(
      snapshotMeal: MealEntity(
        code: IdGenerator.getUniqueID(),
        name: name,
        brands: brands,
        thumbnailImageUrl: thumbnailImageUrl,
        mainImageUrl: null,
        url: null,
        mealQuantity: null,
        mealUnit: null,
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        nutriments: MealNutrimentsEntity(
          energyKcal100: energyKcal100,
          carbohydrates100: carbohydrates100,
          fat100: fat100,
          proteins100: proteins100,
          sugars100: sugars100,
          saturatedFat100: saturatedFat100,
          fiber100: fiber100,
        ),
        source: MealSourceEntity.custom,
      ),
      quantity: quantity,
    );
  }
}

/// Wire format (top-level array — compact, version-stamped):
///   [version, name, description, servingsCount, totalWeightG,
///    [aggregated kcal, c, f, p, sg, sf, fb],
///    [ingredients...], cookedWeightG]
class SharedRecipePayload {
  static const int _currentVersion = 4;

  // Cap the post-decompression payload size to make zip-bomb-style QR
  // codes a clean parse failure rather than an OOM. 64 KiB comfortably
  // covers the largest legitimate recipe share (a recipe with many
  // ingredients including embedded snapshots) while staying well below
  // memory pressure on any device the app targets.
  static const int _kMaxDecompressedBytes = 64 * 1024;

  final int version;
  final String name;
  final String? description;
  final int? servingsCount;
  final double totalWeightG;
  final double? cookedWeightG;
  final NutrientAmount? energyKcal100;
  final NutrientAmount? carbohydrates100;
  final NutrientAmount? fat100;
  final NutrientAmount? proteins100;
  final NutrientAmount? sugars100;
  final NutrientAmount? saturatedFat100;
  final NutrientAmount? fiber100;
  final List<SharedRecipeIngredient> ingredients;

  const SharedRecipePayload({
    required this.version,
    required this.name,
    required this.description,
    required this.servingsCount,
    required this.totalWeightG,
    required this.cookedWeightG,
    required this.energyKcal100,
    required this.carbohydrates100,
    required this.fat100,
    required this.proteins100,
    required this.sugars100,
    required this.saturatedFat100,
    required this.fiber100,
    required this.ingredients,
  });

  factory SharedRecipePayload.fromRecipe(RecipeEntity recipe) {
    final n = recipe.aggregatedNutrimentsPer100;
    return SharedRecipePayload(
      version: _currentVersion,
      name: recipe.name,
      description: recipe.description,
      servingsCount: recipe.servingsCount,
      totalWeightG: recipe.totalWeightG,
      cookedWeightG: recipe.cookedWeightG,
      energyKcal100: n.energyKcal100,
      carbohydrates100: n.carbohydrates100,
      fat100: n.fat100,
      proteins100: n.proteins100,
      sugars100: n.sugars100,
      saturatedFat100: n.saturatedFat100,
      fiber100: n.fiber100,
      ingredients: recipe.ingredients
          .map(SharedRecipeIngredient.fromIngredient)
          .toList(),
    );
  }

  factory SharedRecipePayload.fromJsonString(String input) {
    try {
      String jsonString;
      try {
        final decompressed = gzip.decode(
          base64Url.decode(base64Url.normalize(input)),
        );
        if (decompressed.length > _kMaxDecompressedBytes) {
          throw SharedRecipeParseException(
            'Payload too large to decode (>$_kMaxDecompressedBytes bytes)',
          );
        }
        jsonString = utf8.decode(decompressed);
      } on SharedRecipeParseException {
        // Size violations are real errors, not malformed input — don't
        // fall back to treating the raw input as JSON.
        rethrow;
      } catch (_) {
        jsonString = input;
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        throw SharedRecipeParseException('Invalid payload format');
      }
      return SharedRecipePayload.fromJsonArray(decoded);
    } on SharedRecipeParseException {
      rethrow;
    } catch (e) {
      throw SharedRecipeParseException('Failed to parse payload: $e');
    }
  }

  /// Parse the inner array form (without base64+gzip outer encoding). Used
  /// when this payload is nested inside a SharedMealPayload.
  factory SharedRecipePayload.fromJsonArray(List<dynamic> decoded) {
    final version = decoded[0] as int;
    if (version != _currentVersion) {
      throw SharedRecipeParseException('Unsupported version: $version');
    }

    final cookedWeightG = _toDouble(decoded[7]);
    if (cookedWeightG != null &&
        (!cookedWeightG.isFinite || cookedWeightG <= 0)) {
      throw SharedRecipeParseException(
        'Cooked weight must be positive and finite',
      );
    }
    final aggregated = decoded[5] as List<dynamic>;
    final rawIngredients = decoded[6] as List<dynamic>;

    return SharedRecipePayload(
      version: version,
      name: decoded[1] as String,
      description: decoded[2] as String?,
      servingsCount: (decoded[3] as num?)?.toInt(),
      totalWeightG: (decoded[4] as num).toDouble(),
      cookedWeightG: cookedWeightG,
      energyKcal100: NutrientAmount.fromSource(aggregated[0]),
      carbohydrates100: NutrientAmount.fromSource(aggregated[1]),
      fat100: NutrientAmount.fromSource(aggregated[2]),
      proteins100: NutrientAmount.fromSource(aggregated[3]),
      sugars100: NutrientAmount.fromSource(aggregated[4]),
      saturatedFat100: NutrientAmount.fromSource(aggregated[5]),
      fiber100: NutrientAmount.fromSource(aggregated[6]),
      ingredients: rawIngredients
          .map((e) => SharedRecipeIngredient.fromArray(e as List<dynamic>))
          .toList(),
    );
  }

  /// Inner array form (no base64+gzip). Used when nesting inside a
  /// SharedMealPayload.
  List<dynamic> toJsonArray() {
    return [
      version,
      name,
      description,
      servingsCount,
      totalWeightG,
      [
        energyKcal100?.toJson(),
        carbohydrates100?.toJson(),
        fat100?.toJson(),
        proteins100?.toJson(),
        sugars100?.toJson(),
        saturatedFat100?.toJson(),
        fiber100?.toJson(),
      ],
      ingredients.map((i) => i.toArray()).toList(),
      cookedWeightG,
    ];
  }

  String toJsonString() {
    final json = jsonEncode(toJsonArray());
    return base64Url.encode(gzip.encode(utf8.encode(json)));
  }

  /// Builds a fresh RecipeEntity from this payload. Caller is responsible
  /// for persisting via SaveRecipeUseCase, which re-aggregates nutrition
  /// from the ingredients (the aggregated values in the payload are
  /// transmitted for display purposes during the import-confirm step but
  /// are recomputed on save).
  RecipeEntity toRecipeEntity() {
    final now = DateTime.now();
    return RecipeEntity(
      id: IdGenerator.getUniqueID(),
      name: name,
      description: description,
      ingredients: ingredients.map((i) => i.toIngredient()).toList(),
      totalWeightG: totalWeightG,
      cookedWeightG: cookedWeightG,
      aggregatedNutrimentsPer100: MealNutrimentsEntity(
        energyKcal100: energyKcal100,
        carbohydrates100: carbohydrates100,
        fat100: fat100,
        proteins100: proteins100,
        sugars100: sugars100,
        saturatedFat100: saturatedFat100,
        fiber100: fiber100,
      ),
      createdAt: now,
      updatedAt: now,
      servingsCount: servingsCount,
    );
  }
}
