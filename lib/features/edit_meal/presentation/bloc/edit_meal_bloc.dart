import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

part 'edit_meal_state.dart';

part 'edit_meal_event.dart';

/// Computes the per-100g scale factor for a typed base-quantity string.
///
/// `createNewMealEntity` multiplies every typed nutriment by this factor
/// before storing it on the per-100g fields, so values typed at the
/// user's chosen base quantity land in the canonical "per 100" slot.
/// Lifted out of the bloc so it can be unit-tested directly without
/// instantiating the bloc's dependency graph — see
/// `test/unit_test/edit_meal_simple_mode_scale_test.dart` for the
/// regression coverage on Simple-mode (#232).
///
/// A base of 0 falls back to the no-op factor like unparseable input does:
/// `100 / 0` is infinite, and a nutriment typed as 0 times infinity is NaN,
/// which reached the stored meal, the intake and the day's totals, and
/// blanked every card that rounds a total with `toInt()` (#1254).
double factorTo100gFromBase(String baseQuantity) {
  final parsed = double.tryParse(baseQuantity);
  return (parsed != null && parsed.isFinite && parsed > 0) ? (100 / parsed) : 1;
}

/// Custom meal form view mode (#232). Persisted on ConfigDBO so the form
/// remembers which view the user prefers between sessions.
enum CustomMealFormMode {
  simple,
  advanced;

  static CustomMealFormMode fromString(String? value) {
    if (value == advanced.name) return advanced;
    // Simple is the default for new users and for any unrecognised value:
    // it removes the per-100g cognitive load and matches the most common
    // request from the people who filed #232.
    return simple;
  }
}

class EditMealBloc extends Bloc<EditMealEvent, EditMealState> {
  final GetConfigUsecase _getConfigUsecase;
  final CustomMealDataSource _customMealDataSource; // #267
  final ConfigRepository _configRepository;

  EditMealBloc(
    this._getConfigUsecase,
    this._customMealDataSource,
    this._configRepository,
  ) : super(EditMealInitial()) {
    on<InitializeEditMealEvent>((event, emit) async {
      emit(EditMealLoadingState());

      final config = await _getConfigUsecase.getConfig();
      final mode = CustomMealFormMode.fromString(
        await _configRepository.getCustomMealFormMode(),
      );
      emit(
        EditMealLoadedState(
          usesImperialUnits: config.usesImperialFoodUnits,
          formMode: mode,
        ),
      );
    });
  }

  /// Persist the user's form view preference so the next custom-meal entry
  /// opens in the same mode they last used (#232).
  Future<void> setFormMode(CustomMealFormMode mode) async {
    await _configRepository.setCustomMealFormMode(mode.name);
  }

  MealEntity createNewMealEntity(
    MealEntity oldMealEntity,
    String nameText,
    String brandsText,
    String mealQuantityText,
    String servingQuantityText,
    String baseQuantity,
    String? unitText,
    String kcalText,
    String carbsText,
    String fatText,
    String proteinText, {
    Map<String, NutrientAmount?> nutrientAmounts = const {},
    String? barcodeOverride,
    String? localImagePathOverride,
    bool clearLocalImagePath = false,
    Set<String>? editedNutrients,
  }) {
    final double factorTo100g = factorTo100gFromBase(baseQuantity);

    final amounts = Map<String, NutrientAmount?>.of(
      oldMealEntity.nutriments.amounts,
    );
    final texts = <String, String>{
      'energyKcal100': kcalText,
      'carbohydrates100': carbsText,
      'fat100': fatText,
      'proteins100': proteinText,
    };
    for (final entry in texts.entries) {
      if (editedNutrients == null || editedNutrients.contains(entry.key)) {
        amounts[entry.key] = NutrientAmount.fromSource(
          entry.value,
        )?.scale(factorTo100g);
      }
    }
    for (final entry in nutrientAmounts.entries) {
      if (editedNutrients == null || editedNutrients.contains(entry.key)) {
        amounts[entry.key] = entry.value?.scale(factorTo100g);
      }
    }
    final newMealNutriments = MealNutrimentsEntity.fromAmounts(amounts);

    return MealEntity(
      // #167: a user-typed or scanned barcode wins over whatever came
      // from the originating OFF/FDC record, but only when the override
      // was actually supplied. Empty-string is treated as "clear" so a
      // user can erase a stored code by blanking the field.
      code: barcodeOverride ?? oldMealEntity.code,
      name: nameText.toStringOrNull(),
      brands: brandsText.toStringOrNull(),
      url: oldMealEntity.url,
      thumbnailImageUrl: oldMealEntity.thumbnailImageUrl,
      mainImageUrl: oldMealEntity.mainImageUrl,
      mealQuantity: mealQuantityText.toStringOrNull(),
      mealUnit: unitText,
      servingQuantity: servingQuantityText.toDoubleOrNull(),
      // The custom-meal form has a single unit selector shared by the meal
      // size and the serving size, so the serving unit is that selected unit
      // — not the serving *quantity* text, which used to land here and made
      // the meal-detail serving option read "Serving (50.0 50)" instead of
      // "Serving (50 g)" (#495).
      servingUnit: unitText,
      servingSize: oldMealEntity.servingSize,
      nutriments: newMealNutriments,
      source: oldMealEntity.source,
      isQuickAdd: oldMealEntity.isQuickAdd,
      // #64 follow-up: a freshly-picked local photo wins over what was
      // on the old entity; a clear flag means the user removed the
      // photo and the slug should be wiped from the saved meal.
      localImagePath: clearLocalImagePath
          ? null
          : (localImagePathOverride ?? oldMealEntity.localImagePath),
    );
  }

  /// Persist custom meal template so it appears in Recent Meals before first log (#267)
  Future<void> saveCustomMeal(MealEntity mealEntity) async {
    await _customMealDataSource.saveCustomMeal(
      MealDBO.fromMealEntity(mealEntity),
    );
  }
}
