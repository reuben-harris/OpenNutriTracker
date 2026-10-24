part of 'recipe_builder_bloc.dart';

sealed class RecipeBuilderEvent extends Equatable {
  const RecipeBuilderEvent();

  @override
  List<Object?> get props => [];
}

class InitializeBuilderEvent extends RecipeBuilderEvent {
  final RecipeEntity? existing;
  const InitializeBuilderEvent({this.existing});

  @override
  List<Object?> get props => [existing];
}

class UpdateNameEvent extends RecipeBuilderEvent {
  final String name;
  const UpdateNameEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class UpdateDescriptionEvent extends RecipeBuilderEvent {
  final String description;
  const UpdateDescriptionEvent(this.description);

  @override
  List<Object?> get props => [description];
}

class UpdateServingsCountEvent extends RecipeBuilderEvent {
  final int? servingsCount;
  const UpdateServingsCountEvent(this.servingsCount);

  @override
  List<Object?> get props => [servingsCount];
}

class UpdateTagsEvent extends RecipeBuilderEvent {
  final List<String> tags;
  const UpdateTagsEvent(this.tags);

  @override
  List<Object?> get props => [tags];
}

class AddIngredientEvent extends RecipeBuilderEvent {
  final MealEntity meal;
  final FoodAmountSelection quantity;
  const AddIngredientEvent({required this.meal, required this.quantity});

  @override
  List<Object?> get props => [meal, quantity];
}

class UpdateIngredientEvent extends RecipeBuilderEvent {
  final int index;
  final MealEntity meal;
  final FoodAmountSelection quantity;
  const UpdateIngredientEvent({
    required this.index,
    required this.meal,
    required this.quantity,
  });

  @override
  List<Object?> get props => [index, meal, quantity];
}

class RemoveIngredientEvent extends RecipeBuilderEvent {
  final int index;
  const RemoveIngredientEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class UpdateWeightModeEvent extends RecipeBuilderEvent {
  final RecipeWeightMode mode;
  const UpdateWeightModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

class UpdateCookedWeightEvent extends RecipeBuilderEvent {
  final double? cookedWeightG;
  const UpdateCookedWeightEvent(this.cookedWeightG);

  @override
  List<Object?> get props => [cookedWeightG];
}

class SaveRecipeEvent extends RecipeBuilderEvent {
  final bool closeAfterSave;
  final void Function(bool)? onCompleted;
  const SaveRecipeEvent({this.closeAfterSave = true, this.onCompleted});

  @override
  List<Object?> get props => [closeAfterSave, onCompleted];
}

class UpdateImagePathEvent extends RecipeBuilderEvent {
  // Relative slug under the app documents directory, or null to clear.
  final String? imagePath;
  const UpdateImagePathEvent(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class ExplodeIngredientEvent extends RecipeBuilderEvent {
  final int index;
  final RecipeEntity recipe;
  const ExplodeIngredientEvent({required this.index, required this.recipe});
  @override
  List<Object?> get props => [index, recipe];
}
