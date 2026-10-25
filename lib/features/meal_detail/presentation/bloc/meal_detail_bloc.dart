import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/calc/daily_nutrient_references.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

part 'meal_detail_event.dart';

part 'meal_detail_state.dart';

class MealDetailBloc extends Bloc<MealDetailEvent, MealDetailState> {
  final log = Logger('MealDetailBloc');
  final AddIntakeUsecase _addIntakeUseCase;
  final AddTrackedDayUsecase _addTrackedDayUsecase;
  final GetKcalGoalUsecase _getKcalGoalUsecase;
  final GetMacroGoalUsecase _getMacroGoalUsecase;
  final GetTrackedDayUsecase _getTrackedDayUsecase;
  final ProductsRepository _productsRepository;
  final RemoteSearchCacheDataSource _remoteSearchCacheDataSource;
  final RecipeRepository? _recipeRepository;
  final FoodCatalogue? _catalogue;
  final GetUserUsecase? _getUserUsecase;

  int _mealRequest = 0;
  Future<void>? _hydrationCacheWrite;

  MealDetailBloc(
    this._addIntakeUseCase,
    this._addTrackedDayUsecase,
    this._getKcalGoalUsecase,
    this._getMacroGoalUsecase,
    this._getTrackedDayUsecase,
    this._productsRepository,
    this._remoteSearchCacheDataSource, {
    RecipeRepository? recipeRepository,
    FoodCatalogue? catalogue,
    GetUserUsecase? getUserUsecase,
  }) : _recipeRepository = recipeRepository,
       _catalogue = catalogue,
       _getUserUsecase = getUserUsecase,
       super(const MealDetailInitial()) {
    on<UpdateKcalEvent>((event, emit) {
      event.selection.validate();
      final scale = event.selection.baseAmount / 100;
      final nutrients = event.meal.nutriments;
      emit(
        state.copyWith(
          totalKcal: scale * (nutrients.energyKcal100?.calculationValue ?? 0),
          totalCarbs:
              scale * (nutrients.carbohydrates100?.calculationValue ?? 0),
          totalFat: scale * (nutrients.fat100?.calculationValue ?? 0),
          totalProtein: scale * (nutrients.proteins100?.calculationValue ?? 0),
        ),
      );
    });

    on<LoadDailyTotalsEvent>((event, emit) async {
      emit(
        state.copyWith(dailyTotalsStatus: MealInformationLoadStatus.loading),
      );
      try {
        final tracked = await _getTrackedDayUsecase.getTrackedDay(event.day);
        final goal =
            tracked?.calorieGoal ??
            await _getKcalGoalUsecase.getKcalGoal(day: event.day);
        final carbs =
            tracked?.carbsGoal ?? await _getMacroGoalUsecase.getCarbsGoal(goal);
        final fat =
            tracked?.fatGoal ?? await _getMacroGoalUsecase.getFatsGoal(goal);
        final protein =
            tracked?.proteinGoal ??
            await _getMacroGoalUsecase.getProteinsGoal(goal);
        UserEntity? user;
        try {
          user = await _getUserUsecase?.getUserData();
        } catch (error, stack) {
          log.warning(
            'User data unavailable for nutrient references',
            error,
            stack,
          );
        }
        final references = DailyNutrientReferences.resolve(
          trackedDay: tracked,
          user: user,
        );
        if (emit.isDone) return;
        emit(
          state.copyWith(
            dailyTotalsStatus: MealInformationLoadStatus.ready,
            dayKcalConsumed: tracked?.caloriesTracked ?? 0,
            dayKcalGoal: goal,
            dayCarbsGoal: carbs,
            dayFatGoal: fat,
            dayProteinGoal: protein,
            dayNutrientGoals: {
              'energy': goal,
              'carbohydrates': carbs,
              'fat': fat,
              'protein': protein,
              ...references,
            },
          ),
        );
      } catch (e) {
        log.severe('Error loading daily totals: $e');
        if (!emit.isDone) {
          emit(
            state.copyWith(
              dailyTotalsStatus: MealInformationLoadStatus.failure,
            ),
          );
        }
      }
    });

    on<HydrateMealEvent>((event, emit) async {
      final meal = event.meal;
      final code = meal.code;
      if (meal.isCatalogueFood && _catalogue != null) {
        if (state.isRefreshing) return;
        final request = ++_mealRequest;
        emit(
          state.copyWith(hydrationStatus: MealInformationLoadStatus.loading),
        );
        try {
          final full = await _catalogue.getById(code!);
          if (emit.isDone || request != _mealRequest) return;
          if (full != null) {
            emit(
              state.copyWith(
                hydratedMeal: full,
                mealRevision: state.mealRevision + 1,
                hydrationStatus: MealInformationLoadStatus.ready,
              ),
            );
          } else {
            emit(
              state.copyWith(
                hydrationStatus: MealInformationLoadStatus.failure,
              ),
            );
          }
        } catch (error, stack) {
          log.warning('Catalogue lookup failed for $code', error, stack);
          if (!emit.isDone && request == _mealRequest) {
            emit(
              state.copyWith(
                hydrationStatus: MealInformationLoadStatus.failure,
              ),
            );
          }
        }
        return;
      }
      if (state.refreshStatus != ProductRefreshStatus.idle ||
          meal.source != MealSourceEntity.off ||
          meal.detailed ||
          code == null ||
          code.isEmpty) {
        if (state.refreshStatus == ProductRefreshStatus.idle) {
          emit(
            state.copyWith(hydrationStatus: MealInformationLoadStatus.ready),
          );
        }
        return;
      }

      final request = ++_mealRequest;
      emit(state.copyWith(hydrationStatus: MealInformationLoadStatus.loading));
      try {
        // A full cache entry (from an earlier scan/hydration) lets us skip the
        // network entirely and works offline; otherwise fetch and cache it.
        final generation = _remoteSearchCacheDataSource.generation;
        final language = _remoteSearchCacheDataSource.language;
        final cached = await _remoteSearchCacheDataSource.getDetailedByBarcode(
          code,
        );
        final full = cached != null
            ? MealEntity.fromMealDBO(cached)
            : await _productsRepository.getOFFProductByBarcode(code);
        if (request != _mealRequest || emit.isDone) return;
        if (cached == null) {
          await (_hydrationCacheWrite = _remoteSearchCacheDataSource.cache(
            MealDBO.fromMealEntity(full),
            generation: generation,
            language: language,
          ));
        }
        if (request != _mealRequest || emit.isDone) return;
        emit(
          state.copyWith(
            hydratedMeal: full,
            mealRevision: state.mealRevision + 1,
            hydrationStatus: MealInformationLoadStatus.ready,
          ),
        );
      } catch (e, st) {
        // Soft failure: keep the thin result so the user can still log
        // macros-only. The Add button is never blocked on hydration.
        log.warning('OFF hydration failed for $code', e, st);
        if (request != _mealRequest || emit.isDone) return;
        emit(
          state.copyWith(hydrationStatus: MealInformationLoadStatus.failure),
        );
      }
    });

    on<RefreshMealEvent>((event, emit) async {
      final code = event.meal.code;
      if (state.isRefreshing ||
          (event.meal.source != MealSourceEntity.off &&
              !event.meal.isCatalogueFood) ||
          code == null ||
          code.isEmpty) {
        return;
      }

      // Invalidate an older hydration before starting the direct OFF request.
      ++_mealRequest;
      emit(state.copyWith(refreshStatus: ProductRefreshStatus.loading));
      final generation = _remoteSearchCacheDataSource.generation;
      final language = _remoteSearchCacheDataSource.language;
      try {
        final fresh = event.meal.isCatalogueFood
            ? await _catalogue?.getById(code)
            : await _productsRepository.getOFFProductByBarcode(code);
        if (fresh == null) throw StateError('Catalogue food unavailable');
        if (emit.isDone) return;
        // If hydration was already writing, let it finish first so this fresh
        // result is the last cache write. Its response cannot update the UI.
        try {
          await _hydrationCacheWrite;
        } catch (_) {
          // A failed older write does not prevent caching the fresh response.
        }
        if (emit.isDone) return;
        if (fresh.source == MealSourceEntity.off) {
          await _remoteSearchCacheDataSource.cache(
            MealDBO.fromMealEntity(fresh),
            generation: generation,
            language: language,
          );
        }
        if (emit.isDone) return;
        emit(
          state.copyWith(
            hydratedMeal: fresh,
            hydrationStatus: MealInformationLoadStatus.ready,
            mealRevision: state.mealRevision + 1,
            refreshStatus: ProductRefreshStatus.success,
          ),
        );
      } catch (e, st) {
        log.warning('Meal refresh failed for $code', e, st);
        if (emit.isDone) return;
        emit(
          state.copyWith(
            refreshStatus: ProductRefreshStatus.failure,
            hydrationStatus: MealInformationLoadStatus.failure,
          ),
        );
      }
    });
  }

  /// Returns a future so callers writing more than one intake can await
  /// each in turn. The tracked-day totals are accumulated with a
  /// read-modify-write (`TrackedDayDataSource.addDayCaloriesTracked`), so
  /// overlapping calls interleave their reads and silently lose updates —
  /// a batch logged concurrently under-counts the day.
  Future<void> addIntake(
    BuildContext context,
    FoodAmountSelection? quantity,
    IntakeTypeEntity type,
    MealEntity meal,
    DateTime day, {
    IntakeEntity? copiedFrom,
  }) async {
    final intakeEntity = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      quantity: quantity,
      type: type,
      meal: meal,
      dateTime: day,
      recipeSnapshot: meal.source == MealSourceEntity.recipe
          ? copiedFrom != null
                ? copiedFrom.recipeSnapshot
                : _recipeRepository?.getRecipeById(meal.code ?? '')
          : null,
    );
    // Write the intake immediately so the Home/Diary refresh that
    // follows on the caller side picks it up. The cache refresh happens
    // in the background — the user shouldn't wait for an OFF round-trip
    // (up to 60 s timeout) before seeing their item logged. Stale meal
    // data in the intake is fine; nutrition values rarely change, and
    // the cache update means the next search shows the freshest data.
    await _addIntakeUseCase.addIntake(intakeEntity);
    await _updateTrackedDay(intakeEntity, day);
    unawaited(_refreshCacheForSelectedMeal(meal));
  }

  /// Best-effort cache refresh after the user logs a meal. For OFF items
  /// with a barcode, attempts a fresh lookup and overwrites the cache
  /// entry with the result. Catalogue and personal foods bypass this cache.
  Future<void> _refreshCacheForSelectedMeal(MealEntity meal) async {
    final code = meal.code;
    if (code == null || code.isEmpty || meal.source != MealSourceEntity.off) {
      return;
    }
    final generation = _remoteSearchCacheDataSource.generation;
    final language = _remoteSearchCacheDataSource.language;
    try {
      final fresh = await _productsRepository.getOFFProductByBarcode(code);
      await _remoteSearchCacheDataSource.cache(
        MealDBO.fromMealEntity(fresh),
        generation: generation,
        language: language,
      );
    } catch (e, st) {
      log.warning('Background OFF refresh failed for $code', e, st);
    }
  }

  Future<void> _updateTrackedDay(
    IntakeEntity intakeEntity,
    DateTime day,
  ) async {
    final hasTrackedDay = await _addTrackedDayUsecase.hasTrackedDay(day);
    if (!hasTrackedDay) {
      final totalKcalGoal = await _getKcalGoalUsecase.getKcalGoal(day: day);
      final totalCarbsGoal = await _getMacroGoalUsecase.getCarbsGoal(
        totalKcalGoal,
      );
      final totalFatGoal = await _getMacroGoalUsecase.getFatsGoal(
        totalKcalGoal,
      );
      final totalProteinGoal = await _getMacroGoalUsecase.getProteinsGoal(
        totalKcalGoal,
      );

      await _addTrackedDayUsecase.addNewTrackedDay(
        day,
        totalKcalGoal,
        totalCarbsGoal,
        totalFatGoal,
        totalProteinGoal,
      );
    }

    await _addTrackedDayUsecase.addDayCaloriesTracked(
      day,
      intakeEntity.totalKcal,
    );
    await _addTrackedDayUsecase.addDayMacrosTracked(
      day,
      carbsTracked: intakeEntity.totalCarbsGram,
      fatTracked: intakeEntity.totalFatsGram,
      proteinTracked: intakeEntity.totalProteinsGram,
    );
  }
}
