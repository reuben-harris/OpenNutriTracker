import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:collection/collection.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/scanner/data/product_not_found_exception.dart';

class DiarySourceUnavailable implements Exception {}

/// Refreshes one occurrence by identity, never by a similar search result.
class RefreshDiaryIntakeUsecase {
  final HiveDBProvider _db;
  final IntakeRepository _intakes;
  final ProductsRepository _products;
  final CustomMealDataSource _custom;
  final RecipeRepository _recipes;
  final RemoteSearchCacheDataSource _cache;
  final FoodCatalogue? _catalogue;
  final _inFlight = <(Object, String, String), Future<IntakeEntity?>>{};

  RefreshDiaryIntakeUsecase(
    this._db,
    this._intakes,
    this._products,
    this._custom,
    this._recipes,
    this._cache, {
    FoodCatalogue? catalogue,
  }) : _catalogue = catalogue;

  Future<IntakeEntity?> refresh(String id) async {
    final box = _db.intakeBox;
    final profile = _db.activeProfileId;
    final key = (box, profile, id);
    final running = _inFlight[key];
    if (running != null) return running;
    final run = _refresh(id, box, profile);
    _inFlight[key] = run;
    try {
      return await run;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<IntakeEntity?> _refresh(String id, Object box, String profile) async {
    final intake = await _intakes.getIntakeById(id);
    if (intake == null ||
        (!identical(box, _db.intakeBox) || profile != _db.activeProfileId)) {
      return null;
    }
    final source = intake.meal;
    final code = source.code;
    MealEntity? meal;
    final fields = <String, dynamic>{};
    switch (source.source) {
      case MealSourceEntity.off:
        if (code != null) {
          try {
            meal = await _products.getOFFProductByBarcode(code);
          } on ProductNotFoundException {
            throw DiarySourceUnavailable();
          }
        }
      case MealSourceEntity.fdc:
        if (code != null) meal = await _catalogue?.getById(code);
      case MealSourceEntity.custom:
        final saved = _custom.getAllCustomMeals().firstWhereOrNull(
          (m) => code != null
              ? m.code == code
              : m.code == null && m.name == source.name,
        );
        if (saved != null) meal = MealEntity.fromMealDBO(saved);
      case MealSourceEntity.recipe:
        final recipe = code == null ? null : _recipes.getRecipeById(code);
        if (recipe != null) {
          meal = recipe.toMealEntity();
          fields['recipeSnapshot'] = recipe.toDBO();
        }
      case MealSourceEntity.unknown:
        break;
    }
    if ((!identical(box, _db.intakeBox) || profile != _db.activeProfileId)) {
      return null;
    }
    if (meal == null) throw DiarySourceUnavailable();
    if (meal.source == MealSourceEntity.off &&
        !validateNutriments(meal.nutriments).isConsistent) {
      throw StateError('Invalid source nutrition');
    }
    // Re-read after the network wait; amount, type and date may have changed.
    final latest = await _intakes.getIntakeById(id);
    if (latest == null ||
        (!identical(box, _db.intakeBox) || profile != _db.activeProfileId)) {
      return null;
    }
    if (latest.meal.code != code || latest.meal.source != source.source) {
      return null;
    }
    final dbo = MealDBO.fromMealEntity(meal);
    fields['meal'] = dbo;
    final updated = await _intakes.updateIntake(id, fields);
    if (identical(box, _db.intakeBox) &&
        profile == _db.activeProfileId &&
        meal.source == MealSourceEntity.off) {
      await _cache.cache(dbo);
    }
    return updated;
  }
}
