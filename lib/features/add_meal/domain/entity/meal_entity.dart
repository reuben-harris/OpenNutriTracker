import 'package:equatable/equatable.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';
import 'package:opennutritracker/core/utils/supported_language.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_food_dto.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/util/food_title.dart';

/// A number immediately followed by a metric mass or volume unit, as it
/// appears inside an Open Food Facts `serving_size` string.
final _servingSizeMetric = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:g|ml)\b',
  caseSensitive: false,
);

class MealEntity extends Equatable {
  static const liquidUnits = {'ml', 'l', 'dl', 'cl', 'fl oz', 'fl.oz'};
  static const solidUnits = {'kg', 'g', 'mg', 'µg', 'oz'};

  final String? code;
  final String? name;

  final String? brands;

  final String? thumbnailImageUrl;
  final String? mainImageUrl;

  final String? url;

  final String? mealQuantity;
  final String? mealUnit;
  final double? servingQuantity;
  final String? servingUnit;
  final String? servingSize;

  // Issue #158: many OFF products carry serving data (servingQuantity or
  // servingSize) but no overall package `quantity`, which left `servingUnit`
  // null and made the meal-detail dropdown default to 100 g/ml on every
  // scan. Treat a product as having serving values when either side of the
  // OFF data is present — the dropdown text in `_getServingDropdownItem`
  // already falls back to `servingSize` when `servingUnit` is missing.
  bool get hasServingValues => servingQuantity != null || servingSize != null;

  /// A number of grams or millilitres per serving, or null when the record
  /// carries none that can be scaled.
  ///
  /// [servingQuantity] is Open Food Facts' parsed numeric, and it is often
  /// absent while `serving_size` carries the same figure as text — "30 g",
  /// "2 Tbsp (32 g)", "1 slice (25g)". Reading it back matters because
  /// [hasServingValues] is true for those records while nothing can scale
  /// them: the meal-detail screen defaulted them to "1 serving" and logged
  /// one *gram* (#629).
  ///
  /// The last `g`/`ml` figure wins, so a parenthesised metric equivalent
  /// beats the imperial measure in front of it ("12 oz (355 ml)" is 355).
  /// A serving with no metric figure at all — "1 egg" — yields null, and
  /// the caller falls back to a weight the user can see.
  double? get scalableServingQuantity {
    final parsed = servingQuantity;
    if (parsed != null) return parsed;

    final text = servingSize;
    if (text == null) return null;
    final matches = _servingSizeMetric.allMatches(text);
    if (matches.isEmpty) return null;
    return double.tryParse(matches.last.group(1)!.replaceAll(',', '.'));
  }

  final MealSourceEntity source;

  /// Optional household measures with a known gram weight. Not persisted.
  final List<MealPortionEntity> portions;

  /// Distinguishes an unavailable portion lookup from a confirmed empty list.
  final bool portionsUnavailable;

  /// Relative path (`meal_images/<code>.webp`) to a user-attached photo
  /// for a custom meal, or null if none is set. Resolved to an absolute
  /// path at render time via `MealImageStorage.absolutePath`. Always
  /// null for OFF / FDC / recipe-derived meals — those carry remote URLs
  /// in `thumbnailImageUrl` / `mainImageUrl` instead.
  final String? localImagePath;

  final MealNutrimentsEntity nutriments;

  /// Whether this meal carries the full product record (serving fields and
  /// micronutrients). Open Food Facts text search now comes from the
  /// Search-a-licious index, which only returns a thin projection
  /// (`detailed == false`); opening such a result hydrates it to the full
  /// record via the v2 product endpoint (`detailed == true`). Barcode scans
  /// and FDC/custom meals are always full. See [hasServingValues] and the
  /// hydration step in MealDetailBloc.
  final bool detailed;

  final bool isQuickAdd;

  bool get hasQuickAddWeight =>
      isQuickAdd &&
      mealUnit != 'gml' &&
      (double.tryParse(mealQuantity ?? '') ?? 0) > 0;

  bool get isCatalogueFood =>
      source == MealSourceEntity.fdc && (code?.startsWith('usda:') ?? false);

  bool get isLiquid => liquidUnits.contains(mealUnit);

  bool get isSolid => solidUnits.contains(mealUnit);

  String? get scoringName {
    final text = name;
    if (text == null || source != MealSourceEntity.fdc) return text;
    return deriveTitle(text);
  }

  String? get scoringQualifiers {
    final text = name;
    if (text == null || source != MealSourceEntity.fdc) return null;
    return deriveQualifiers(text);
  }

  const MealEntity({
    required this.code,
    required this.name,
    this.brands,
    this.thumbnailImageUrl,
    this.mainImageUrl,
    required this.url,
    required this.mealQuantity,
    required this.mealUnit,
    required this.servingQuantity,
    required this.servingUnit,
    required this.servingSize,
    required this.nutriments,
    required this.source,
    this.portions = const [],
    this.portionsUnavailable = false,
    this.localImagePath,
    this.detailed = false,
    this.isQuickAdd = false,
  });

  MealEntity withPortions(List<MealPortionEntity> found) => MealEntity(
    code: code,
    name: name,
    brands: brands,
    thumbnailImageUrl: thumbnailImageUrl,
    mainImageUrl: mainImageUrl,
    url: url,
    mealQuantity: mealQuantity,
    mealUnit: mealUnit,
    servingQuantity: servingQuantity,
    servingUnit: servingUnit,
    servingSize: servingSize,
    nutriments: nutriments,
    source: source,
    portions: found,
    portionsUnavailable: portionsUnavailable,
    localImagePath: localImagePath,
    detailed: detailed,
    isQuickAdd: isQuickAdd,
  );

  /// The same meal, recording that its portions could not be looked up.
  ///
  /// [portions] stays as it is — empty, on the one path that calls this —
  /// and nothing else moves; see [portionsUnavailable] for what the flag
  /// changes and where it is read.
  MealEntity withPortionsUnavailable() => MealEntity(
    code: code,
    name: name,
    brands: brands,
    thumbnailImageUrl: thumbnailImageUrl,
    mainImageUrl: mainImageUrl,
    url: url,
    mealQuantity: mealQuantity,
    mealUnit: mealUnit,
    servingQuantity: servingQuantity,
    servingUnit: servingUnit,
    servingSize: servingSize,
    nutriments: nutriments,
    source: source,
    portions: portions,
    portionsUnavailable: true,
    localImagePath: localImagePath,
    detailed: detailed,
    isQuickAdd: isQuickAdd,
  );

  factory MealEntity.empty() => MealEntity(
    code: IdGenerator.getUniqueID(),
    name: null,
    url: null,
    mealQuantity: null,
    mealUnit: 'gml',
    servingQuantity: null,
    servingUnit: 'gml',
    servingSize: '',
    nutriments: MealNutrimentsEntity.empty(),
    source: MealSourceEntity.custom,
  );

  factory MealEntity.fromMealDBO(MealDBO mealDBO) => MealEntity(
    code: mealDBO.code,
    name: mealDBO.name,
    brands: mealDBO.brands,
    thumbnailImageUrl: mealDBO.thumbnailImageUrl,
    mainImageUrl: mealDBO.mainImageUrl,
    url: mealDBO.url,
    mealQuantity: mealDBO.mealQuantity,
    mealUnit: mealDBO.mealUnit,
    servingQuantity: mealDBO.servingQuantity,
    servingUnit: mealDBO.servingUnit,
    servingSize: mealDBO.servingSize,
    nutriments: MealNutrimentsEntity.fromMealNutrimentsDBO(mealDBO.nutriments),
    source: MealSourceEntity.fromMealSourceDBO(mealDBO.source),
    localImagePath: mealDBO.localImagePath,
    detailed: mealDBO.detailed ?? false,
    isQuickAdd: mealDBO.isQuickAdd ?? _isHistoricalQuickAdd(mealDBO),
  );

  static bool _isHistoricalQuickAdd(MealDBO m) =>
      m.source == MealSourceDBO.custom &&
      m.mealQuantity == '100' &&
      m.mealUnit == 'gml' &&
      m.servingQuantity == null &&
      m.servingUnit == 'gml' &&
      m.servingSize == '' &&
      m.brands == null &&
      m.url == null &&
      m.thumbnailImageUrl == null &&
      m.mainImageUrl == null &&
      m.localImagePath == null;

  /// [detailed] is true for full-product responses (the v2 barcode endpoint),
  /// false for the thin Search-a-licious text-search projection.
  factory MealEntity.fromOFFProduct(
    OFFProductDTO offProduct, {
    bool detailed = false,
  }) {
    // Unit precedence: OFF's normalised serving unit, then the unit parsed
    // from the serving_size text ("30 g"), then the package quantity string.
    // Serving data beats the package because it describes how the product
    // is actually consumed — and package quantity is missing often enough
    // that deriving from it alone left the unit null ("N/A" in the meal
    // detail's unit dropdown).
    final unit =
        _normalizeOffUnit(offProduct.serving_quantity_unit) ??
        _tryGetUnit(offProduct.serving_size) ??
        _tryGetUnit(offProduct.quantity);
    return MealEntity(
      code: offProduct.code,
      name: offProduct.getLocaleName(
        SupportedLanguage.fromCode(AppLocale.localeName),
      ),
      brands: offProduct.brands,
      thumbnailImageUrl: offProduct.image_front_thumb_url,
      mainImageUrl: offProduct.image_front_url,
      url: offProduct.url,
      mealQuantity: offProduct.product_quantity?.toString(),
      mealUnit: unit,
      servingQuantity: _tryQuantityCast(offProduct.serving_quantity),
      servingUnit: unit,
      servingSize: offProduct.serving_size,
      nutriments: MealNutrimentsEntity.fromOffNutriments(offProduct.nutriments),
      source: MealSourceEntity.off,
      detailed: detailed,
    );
  }

  /// Maps OFF's serving_quantity_unit to the app's g/ml entry units.
  /// Usually already 'g' or 'ml'; the volume variants collapse to ml and
  /// anything unrecognised returns null so the next fallback can try.
  static String? _normalizeOffUnit(String? rawUnit) {
    switch (rawUnit?.trim().toLowerCase()) {
      case 'g':
        return 'g';
      case 'ml':
      case 'cl':
      case 'dl':
      case 'l':
        return 'ml';
      default:
        return null;
    }
  }

  factory MealEntity.fromFDCFood(FDCFoodDTO fdcFood) {
    final fdcId = fdcFood.fdcId?.toInt().toString();

    return MealEntity(
      code: fdcId,
      name: fdcFood.description,
      brands: fdcFood.brandName,
      url: FDCConst.getFoodDetailUrlString(fdcId),
      mealQuantity: fdcFood.packageWeight,
      mealUnit: fdcFood.servingSizeUnit,
      servingQuantity: fdcFood.servingSize,
      servingUnit: fdcFood.servingSizeUnit,
      servingSize: fdcFood.servingSizeUnit,
      nutriments: MealNutrimentsEntity.fromFDCNutriments(fdcFood.foodNutrients),
      source: MealSourceEntity.fdc,
    );
  }

  /// Value returned from OFF can either be String, int or double.
  /// Try casting it to a double value for calculation
  static double? _tryQuantityCast(dynamic value) {
    double? parsedValue;

    if (value == null) {
      parsedValue = null;
    } else if (value is double) {
      parsedValue = value;
    } else if (value is int) {
      parsedValue = value.toDouble();
    } else if (value is String) {
      value.replaceAll(RegExp("mg|g|kg|ml|cl|l| "), ""); // TODO extract
      final doubleParsed =
          double.tryParse(value) ?? int.tryParse(value)?.toDouble();
      parsedValue = doubleParsed;
    }
    return parsedValue;
  }

  /// Unit can either be 100g or 100ml. Looks for a number immediately
  /// followed by a recognised weight/volume unit token (e.g. "38 g" in
  /// "1 slice (38 g)") rather than scanning the whole string for the letter
  /// "l" — free-text serving descriptions like "1 slice", "1 roll", "1 bowl"
  /// or "1 fillet" all contain an "l" and would otherwise be misclassified
  /// as liquid. When several tokens are present (e.g. a household measure
  /// followed by its gram equivalent in parentheses) the last one wins, as
  /// it's usually the precise weight/volume. Falls back to "g" when no unit
  /// token is found, matching the previous default.
  static String? _tryGetUnit(String? quantityString) {
    if (quantityString == null) return null;

    final matches = RegExp(
      r'\b(?:mg|kg|ml|cl|dl|l|g)\b',
      caseSensitive: false,
    ).allMatches(quantityString.replaceAll(RegExp(r'\d'), '')).toList();

    final unitToken = matches.isEmpty
        ? null
        : matches.last.group(0)?.toLowerCase();

    switch (unitToken) {
      case 'ml':
      case 'cl':
      case 'dl':
      case 'l':
        return 'ml';
      default:
        return 'g';
    }
  }

  @override
  List<Object?> get props => [
    code,
    name,
    nutriments,
    isQuickAdd,
    mealQuantity,
    mealUnit,
    servingUnit,
    servingQuantity,
    servingSize,
    localImagePath,
  ];
}

enum MealSourceEntity {
  unknown,
  custom,
  off,
  fdc,
  recipe;

  factory MealSourceEntity.fromMealSourceDBO(MealSourceDBO mealSourceDBO) {
    MealSourceEntity mealSourceEntity;
    switch (mealSourceDBO) {
      case MealSourceDBO.unknown:
        mealSourceEntity = MealSourceEntity.unknown;
        break;
      case MealSourceDBO.custom:
        mealSourceEntity = MealSourceEntity.custom;
        break;
      case MealSourceDBO.off:
        mealSourceEntity = MealSourceEntity.off;
        break;
      case MealSourceDBO.fdc:
        mealSourceEntity = MealSourceEntity.fdc;
        break;
      case MealSourceDBO.recipe:
        mealSourceEntity = MealSourceEntity.recipe;
        break;
    }
    return mealSourceEntity;
  }
}
