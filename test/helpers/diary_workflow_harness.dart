import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_copy_cubit.dart';
import 'overview_diary_harness.dart';

class DiaryTestRecipes extends Fake implements RecipeRepository {
  RecipeEntity? recipe;
  @override
  RecipeEntity? getRecipeById(String id) => recipe?.id == id ? recipe : null;
}

class _Products extends Fake implements ProductsRepository {}

class _Cache extends Fake implements RemoteSearchCacheDataSource {
  @override
  Future<void> touch(String code) async {}
}

class DiaryWorkflowHarness extends OverviewDiaryHarness {
  late MealDetailBloc logger;
  late DiaryCopyCubit copier;
  final recipes = DiaryTestRecipes();
  int refreshes = 0;
  bool _hasCopier = false;

  void createCopier({
    AddTrackedDayUsecase? trackedWriter,
    VoidCallback? refresh,
  }) {
    _hasCopier = true;
    logger = MealDetailBloc(
      AddIntakeUsecase(intakes),
      trackedWriter ?? AddTrackedDayUsecase(tracked),
      kcal,
      GetMacroGoalUsecase(config),
      GetTrackedDayUsecase(tracked),
      _Products(),
      _Cache(),
      recipeRepository: recipes,
    );
    copier = DiaryCopyCubit(
      logger,
      getIntakes,
      getConfig,
      AddTrackedDayUsecase(tracked),
      () {
        refreshes++;
        refresh?.call();
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_hasCopier) {
      await copier.close();
      await logger.close();
    }
    await super.dispose();
  }
}
