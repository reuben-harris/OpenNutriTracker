import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';

class CreateRecipeFromIntakesUsecase {
  final ComputeRecipeNutritionUseCase _compute;
  final SaveRecipeUseCase _save;
  CreateRecipeFromIntakesUsecase(this._compute, this._save);

  Future<RecipeEntity> create({
    required String name,
    required List<IntakeEntity> entries,
  }) async {
    if (name.trim().isEmpty ||
        entries.isEmpty ||
        entries.any((entry) => entry.quantity == null)) {
      throw const FormatException(
        'A recipe needs a name and weighted ingredients',
      );
    }
    final ingredients = entries
        .map(
          (entry) => RecipeIngredientEntity(
            snapshotMeal: entry.meal,
            quantity: entry.quantity!,
          ),
        )
        .toList();
    final nutrition = _compute.compute(ingredients);
    final now = DateTime.now();
    return _save.save(
      RecipeEntity(
        id: IdGenerator.getUniqueID(),
        name: name.trim(),
        description: null,
        ingredients: ingredients,
        totalWeightG: nutrition.totalWeightG,
        aggregatedNutrimentsPer100: nutrition.perHundredG,
        createdAt: now,
        updatedAt: now,
        servingsCount: 1,
      ),
    );
  }
}
