import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import '../../../helpers/locator_test_setup.dart';
import '../../../helpers/pump_until.dart';
import '../../../helpers/test_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_recipe_by_id_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

// Keep main alive when a recipe is edited and logged from a stack without
// an Add Meal route. Emptying that stack used to leave a black screen after
// successfully writing the intake.
void main() {
  useTestLocator();
  final getIt = GetIt.instance;
  final loggedIntakes = <IntakeEntity>[];
  late _RecipeRepository recipes;

  const nutriments = MealNutrimentsEntity(
    energyKcal100: NutrientAmount(120),
    carbohydrates100: NutrientAmount(10),
    fat100: NutrientAmount(5),
    proteins100: NutrientAmount(8),
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  );
  final recipe = RecipeEntity(
    id: 'a3f1c0de-0000-4000-8000-000000000001',
    name: 'Chicken curry',
    description: null,
    ingredients: [
      RecipeIngredientEntity(
        snapshotMeal: const MealEntity(
          code: 'curry',
          name: 'Curry ingredients',
          url: null,
          mealQuantity: '800',
          mealUnit: 'g',
          servingQuantity: null,
          servingUnit: null,
          servingSize: null,
          nutriments: nutriments,
          source: MealSourceEntity.custom,
        ),
        quantity: const FoodAmountSelection(
          800,
          FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
        ),
      ),
    ],
    totalWeightG: 800,
    aggregatedNutrimentsPer100: nutriments,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
    servingsCount: 4,
  );
  final day = DateTime(2026, 8, 19);

  setUp(() {
    loggedIntakes.clear();
    recipes = _RecipeRepository(recipe);
    final compute = ComputeRecipeNutritionUseCase();
    getIt.registerSingleton<GetRecipeByIdUseCase>(
      GetRecipeByIdUseCase(recipes),
    );
    getIt.registerFactory<RecipeBuilderBloc>(
      () => RecipeBuilderBloc(compute, SaveRecipeUseCase(recipes, compute)),
    );
    getIt.registerFactory<MealDetailBloc>(
      () => MealDetailBloc(
        _FakeAddIntakeUsecase(loggedIntakes),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        _FakeGetTrackedDayUsecase(),
        _FakeProductsRepository(),
        _FakeRemoteSearchCacheDataSource(),
        recipeRepository: recipes,
      ),
    );
    getIt.registerLazySingleton<GetConfigUsecase>(_FakeGetConfigUsecase.new);
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    await getIt.resetScope();
  });

  // Recipe results use the shared meal-information route with their logging
  // context. No Add Meal route is present to serve as an unwind destination.
  Future<NavigatorState> pumpRecipeLogStack(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();

    Route<void> routeFor(RouteSettings settings) {
      final WidgetBuilder builder = switch (settings.name) {
        NavigationOptions.mealDetailRoute => (_) => const MealDetailScreen(),
        _ => (_) => Scaffold(body: Text('${settings.name}-stub')),
      };
      return MaterialPageRoute<void>(settings: settings, builder: builder);
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          initialRoute: NavigationOptions.mainRoute,
          onGenerateInitialRoutes: (_) => [
            routeFor(const RouteSettings(name: NavigationOptions.mainRoute)),
            routeFor(
              RouteSettings(
                name: NavigationOptions.mealDetailRoute,
                arguments: MealDetailScreenArguments(
                  recipe.toMealEntity(),
                  IntakeTypeEntity.dinner,
                  day,
                  false,
                ),
              ),
            ),
          ],
          onGenerateRoute: routeFor,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return navigatorKey.currentState!;
  }

  testWidgets('editing and logging a recipe leaves the main screen standing', (
    tester,
  ) async {
    final navigator = await pumpRecipeLogStack(tester);
    expect(find.text(recipe.name), findsWidgets);

    await tester.tap(find.text(l10nEn.recipeDetailsTabLabel));
    await tester.pumpAndSettle();
    final name = find.descendant(
      of: find.bySemanticsIdentifier('recipe-name'),
      matching: find.byType(TextField),
    );
    await tester.enterText(name, 'Updated curry');
    await tester.pump();
    expect(
      navigator.canPop(),
      isTrue,
      reason: 'main must remain below the recipe',
    );

    await tester.tap(find.bySemanticsIdentifier('recipe-log-item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '50');
    await tester.tap(find.bySemanticsIdentifier('food-amount-confirm'));
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () => find
          .text('${NavigationOptions.mainRoute}-stub')
          .evaluate()
          .isNotEmpty,
    );
    await tester.pumpAndSettle();

    // The intake is written whatever the navigator does — that is why the
    // bug reads as "my food was logged and then the app went black".
    expect(loggedIntakes, hasLength(1));
    expect(loggedIntakes.single.type, IntakeTypeEntity.dinner);
    expect(loggedIntakes.single.dateTime, day);
    expect(loggedIntakes.single.baseAmount, 50);
    expect(loggedIntakes.single.meal.name, 'Updated curry');
    expect(loggedIntakes.single.recipeSnapshot?.name, 'Updated curry');
    expect(recipes.recipe.name, 'Updated curry');

    expect(find.text('${NavigationOptions.mainRoute}-stub'), findsOneWidget);
    expect(
      find.byType(Scaffold),
      findsWidgets,
      reason: 'an empty navigator renders as a black screen',
    );
  });
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _RecipeRepository implements RecipeRepository {
  RecipeEntity recipe;
  _RecipeRepository(this.recipe);
  @override
  RecipeEntity? getRecipeById(String id) => recipe.id == id ? recipe : null;
  @override
  Future<void> saveRecipe(RecipeEntity recipe) async {
    this.recipe = recipe;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  final List<IntakeEntity> logged;

  _FakeAddIntakeUsecase(this.logged);

  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    logged.add(intakeEntity);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddTrackedDayUsecase implements AddTrackedDayUsecase {
  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double kcal) async {}

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetKcalGoalUsecase implements GetKcalGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetMacroGoalUsecase implements GetMacroGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetTrackedDayUsecase implements GetTrackedDayUsecase {
  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async =>
      TrackedDayEntity(
        day: day,
        calorieGoal: 2200,
        caloriesTracked: 800,
        carbsGoal: 250,
        carbsTracked: 100,
        fatGoal: 70,
        fatTracked: 30,
        proteinGoal: 120,
        proteinTracked: 50,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeProductsRepository implements ProductsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeRemoteSearchCacheDataSource implements RemoteSearchCacheDataSource {
  @override
  int get generation => 0;
  @override
  String get language => 'en';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetIntakeUsecase implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getDinnerIntakeByDay(
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

/// The three refresh blocs the intake sheet pokes on its way out. They only
/// ever receive an event here, so swallowing it is the whole contract.
class _FakeHomeBloc implements HomeBloc {
  @override
  void add(HomeEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeDiaryBloc implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCalendarDayBloc implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

/// The meal screens render a [CachedNetworkImage] for non-custom meals; an
/// empty stream sends it straight to its error widget.
class _FakeCacheManager implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream<FileResponse>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}
