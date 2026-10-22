import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

part 'recipe_builder_event.dart';
part 'recipe_builder_state.dart';

class RecipeBuilderBloc extends Bloc<RecipeBuilderEvent, RecipeBuilderState> {
  final ComputeRecipeNutritionUseCase _computeUseCase;
  final SaveRecipeUseCase _saveUseCase;
  DateTime _createdAt = DateTime.now();

  RecipeBuilderBloc(this._computeUseCase, this._saveUseCase)
    : super(RecipeBuilderState.initial()) {
    on<InitializeBuilderEvent>(_onInitialize);
    on<UpdateNameEvent>(_onUpdateName);
    on<UpdateDescriptionEvent>(_onUpdateDescription);
    on<UpdateServingsCountEvent>(_onUpdateServings);
    on<UpdateTagsEvent>((event, emit) {
      emit(state.copyWith(tags: event.tags, clearSaveError: true));
    });
    on<UpdateImagePathEvent>((event, emit) {
      emit(
        state.copyWith(
          imagePath: event.imagePath,
          clearImagePath: event.imagePath == null,
        ),
      );
    });
    on<AddIngredientEvent>(_onAddIngredient);
    on<UpdateIngredientEvent>(_onUpdateIngredient);
    on<RemoveIngredientEvent>(_onRemoveIngredient);
    on<ExplodeIngredientEvent>((event, emit) {
      if (event.index < 0 ||
          event.index >= state.ingredients.length ||
          event.recipe.ingredients.isEmpty ||
          !event.recipe.totalWeightG.isFinite ||
          event.recipe.totalWeightG <= 0) {
        return;
      }
      final parent = state.ingredients[event.index];
      if (parent.snapshotMeal.source != MealSourceEntity.recipe ||
          parent.snapshotMeal.code != event.recipe.id) {
        return;
      }
      final scale = parent.quantity.baseAmount / event.recipe.totalWeightG;
      final children = event.recipe.ingredients
          .map(
            (ingredient) => ingredient.copyWith(
              quantity: FoodAmountSelection(
                ingredient.quantity.amount * scale,
                ingredient.quantity.option,
              ),
            ),
          )
          .toList();
      final ingredients = [...state.ingredients]
        ..replaceRange(event.index, event.index + 1, children);
      emit(state.copyWith(ingredients: ingredients));
      _recompute(emit);
    });
    on<UpdateWeightModeEvent>(_onUpdateWeightMode);
    on<UpdateCookedWeightEvent>(_onUpdateCookedWeight);
    on<SaveRecipeEvent>(
      _onSave,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  void _onInitialize(
    InitializeBuilderEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    if (event.existing == null) {
      // Generate the recipe id eagerly so any photo the user attaches
      // before they hit save can be filed under the correct filename
      // (recipe_images/<id>.webp). The id is still kept on save below.
      emit(
        RecipeBuilderState.initial().copyWith(id: IdGenerator.getUniqueID()),
      );
    } else {
      final r = event.existing!;
      _createdAt = r.id.isEmpty ? DateTime.now() : r.createdAt;
      // Empty id is the sentinel used by the duplicate-recipe action: keep
      // the field values but treat the builder as a fresh create so save()
      // assigns a new uuid.
      final isDuplicate = r.id.isEmpty;
      emit(
        RecipeBuilderState.initial().copyWith(
          id: isDuplicate ? null : r.id,
          name: r.name,
          description: r.description,
          servingsCount: r.servingsCount,
          ingredients: r.ingredients,
          totalWeightG: r.totalWeightG,
          weightMode: r.cookedWeightG == null
              ? RecipeWeightMode.automatic
              : RecipeWeightMode.custom,
          cookedWeightG: r.cookedWeightG,
          aggregatedNutrimentsPer100: r.aggregatedNutrimentsPer100,
          isExistingRecipe: !isDuplicate,
          tags: r.tags,
          // Duplicates start without an image — the photo is tied to the
          // original recipe id and copying it isn't worth the disk churn
          // here. The user can attach a fresh photo to the new recipe.
          imagePath: isDuplicate ? null : r.imagePath,
          clearImagePath: isDuplicate ? true : (r.imagePath == null),
        ),
      );
      _recompute(emit);
    }
  }

  void _onUpdateName(UpdateNameEvent event, Emitter<RecipeBuilderState> emit) {
    emit(state.copyWith(name: event.name, clearSaveError: true));
  }

  void _onUpdateDescription(
    UpdateDescriptionEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    emit(state.copyWith(description: event.description, clearSaveError: true));
  }

  void _onUpdateServings(
    UpdateServingsCountEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    emit(
      state.copyWith(
        servingsCount: event.servingsCount,
        clearServingsCount: event.servingsCount == null,
        clearSaveError: true,
      ),
    );
  }

  void _onAddIngredient(
    AddIngredientEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    final newIngredient = RecipeIngredientEntity(
      snapshotMeal: event.meal,
      quantity: event.quantity,
    );
    emit(state.copyWith(ingredients: [...state.ingredients, newIngredient]));
    _recompute(emit);
  }

  void _onUpdateIngredient(
    UpdateIngredientEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    if (event.index < 0 || event.index >= state.ingredients.length) return;
    final old = state.ingredients[event.index];
    final updated = old.copyWith(quantity: event.quantity);
    final newList = List<RecipeIngredientEntity>.from(state.ingredients);
    newList[event.index] = updated;
    emit(state.copyWith(ingredients: newList));
    _recompute(emit);
  }

  void _onRemoveIngredient(
    RemoveIngredientEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    if (event.index < 0 || event.index >= state.ingredients.length) return;
    final newList = List<RecipeIngredientEntity>.from(state.ingredients)
      ..removeAt(event.index);
    emit(state.copyWith(ingredients: newList));
    _recompute(emit);
  }

  void _onUpdateWeightMode(
    UpdateWeightModeEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    if (event.mode == state.weightMode) return;
    emit(
      state.copyWith(
        weightMode: event.mode,
        clearCookedWeight: true,
        clearSaveError: true,
      ),
    );
    _recompute(emit);
  }

  void _onUpdateCookedWeight(
    UpdateCookedWeightEvent event,
    Emitter<RecipeBuilderState> emit,
  ) {
    if (state.weightMode != RecipeWeightMode.custom) return;
    final value = event.cookedWeightG;
    final valid = value != null && value.isFinite && value > 0;
    emit(
      state.copyWith(
        cookedWeightG: valid ? value : null,
        clearCookedWeight: !valid,
        clearSaveError: true,
      ),
    );
    _recompute(emit);
  }

  void _recompute(Emitter<RecipeBuilderState> emit) {
    if (state.weightMode == RecipeWeightMode.custom &&
        state.cookedWeightG == null) {
      emit(state.copyWith(clearNutrition: true));
      return;
    }
    final result = _computeUseCase.compute(
      state.ingredients,
      cookedWeightG: state.cookedWeightG,
    );
    emit(
      state.copyWith(
        totalWeightG: result.totalWeightG,
        aggregatedNutrimentsPer100: result.perHundredG,
        clearSaveError: true,
      ),
    );
  }

  Future<void> _onSave(
    SaveRecipeEvent event,
    Emitter<RecipeBuilderState> emit,
  ) async {
    final trimmedName = state.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(saveError: SaveError.nameRequired));
      event.onCompleted?.call(false);
      return;
    }
    if (state.ingredients.isEmpty && event.closeAfterSave) {
      emit(state.copyWith(saveError: SaveError.needsIngredients));
      event.onCompleted?.call(false);
      return;
    }
    if ((state.weightMode == RecipeWeightMode.custom &&
            state.cookedWeightG == null) ||
        (state.ingredients.isNotEmpty && !state.hasValidWeight)) {
      emit(state.copyWith(saveError: SaveError.invalidTotalWeight));
      event.onCompleted?.call(false);
      return;
    }

    emit(state.copyWith(isSaving: true, clearSaveError: true));
    try {
      final now = DateTime.now();
      final recipe = RecipeEntity(
        id: state.id ?? IdGenerator.getUniqueID(),
        name: trimmedName,
        description: state.description?.trim().isEmpty ?? true
            ? null
            : state.description?.trim(),
        ingredients: state.ingredients,
        totalWeightG: state.totalWeightG!,
        cookedWeightG: state.cookedWeightG,
        aggregatedNutrimentsPer100: state.aggregatedNutrimentsPer100!,
        createdAt: _createdAt,
        updatedAt: now,
        servingsCount: state.servingsCount,
        tags: state.tags,
        imagePath: state.imagePath,
      );
      await _saveUseCase.save(recipe);
      emit(state.copyWith(isSaving: false, didSave: event.closeAfterSave));
      event.onCompleted?.call(true);
    } catch (e) {
      event.onCompleted?.call(false);
      emit(
        state.copyWith(
          isSaving: false,
          saveError: SaveError.unknown,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
