part of 'recipe_builder_bloc.dart';

enum SaveError { nameRequired, needsIngredients, invalidTotalWeight, unknown }

enum RecipeWeightMode { automatic, custom }

class RecipeBuilderState extends Equatable {
  final String? id;
  final String name;
  final String? description;
  final int? servingsCount;
  final List<RecipeIngredientEntity> ingredients;
  final double? totalWeightG;
  final RecipeWeightMode weightMode;
  final double? cookedWeightG;
  final MealNutrimentsEntity? aggregatedNutrimentsPer100;
  final List<String> tags;
  final String? imagePath;
  final bool isExistingRecipe;
  final bool isSaving;
  final bool didSave;
  final SaveError? saveError;
  final String? errorMessage;

  const RecipeBuilderState({
    required this.id,
    required this.name,
    required this.description,
    required this.servingsCount,
    required this.ingredients,
    required this.totalWeightG,
    required this.weightMode,
    required this.cookedWeightG,
    required this.aggregatedNutrimentsPer100,
    required this.tags,
    required this.imagePath,
    required this.isExistingRecipe,
    required this.isSaving,
    required this.didSave,
    required this.saveError,
    required this.errorMessage,
  });

  factory RecipeBuilderState.initial() => RecipeBuilderState(
    id: null,
    name: '',
    description: null,
    servingsCount: null,
    ingredients: const [],
    totalWeightG: 0,
    weightMode: RecipeWeightMode.automatic,
    cookedWeightG: null,
    aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
    tags: const [],
    imagePath: null,
    isExistingRecipe: false,
    isSaving: false,
    didSave: false,
    saveError: null,
    errorMessage: null,
  );

  RecipeBuilderState copyWith({
    String? id,
    String? name,
    String? description,
    int? servingsCount,
    List<RecipeIngredientEntity>? ingredients,
    double? totalWeightG,
    RecipeWeightMode? weightMode,
    double? cookedWeightG,
    bool clearCookedWeight = false,
    bool clearNutrition = false,
    MealNutrimentsEntity? aggregatedNutrimentsPer100,
    List<String>? tags,
    String? imagePath,
    bool? isExistingRecipe,
    bool? isSaving,
    bool? didSave,
    SaveError? saveError,
    String? errorMessage,
    bool clearServingsCount = false,
    bool clearSaveError = false,
    bool clearImagePath = false,
  }) {
    return RecipeBuilderState(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      servingsCount: clearServingsCount
          ? null
          : (servingsCount ?? this.servingsCount),
      ingredients: ingredients ?? this.ingredients,
      totalWeightG: clearNutrition ? null : (totalWeightG ?? this.totalWeightG),
      weightMode: weightMode ?? this.weightMode,
      cookedWeightG: clearCookedWeight
          ? null
          : (cookedWeightG ?? this.cookedWeightG),
      aggregatedNutrimentsPer100: clearNutrition
          ? null
          : (aggregatedNutrimentsPer100 ?? this.aggregatedNutrimentsPer100),
      tags: tags ?? this.tags,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      isExistingRecipe: isExistingRecipe ?? this.isExistingRecipe,
      isSaving: isSaving ?? this.isSaving,
      didSave: didSave ?? this.didSave,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get hasValidWeight =>
      totalWeightG != null && totalWeightG!.isFinite && totalWeightG! > 0;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    servingsCount,
    ingredients,
    totalWeightG,
    weightMode,
    cookedWeightG,
    aggregatedNutrimentsPer100,
    tags,
    imagePath,
    isExistingRecipe,
    isSaving,
    didSave,
    saveError,
    errorMessage,
  ];
}
