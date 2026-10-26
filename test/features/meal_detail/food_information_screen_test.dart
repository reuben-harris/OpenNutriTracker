import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/share_qr_dialog.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_recipe_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/food_amount_card.dart';
import '../../helpers/locator_test_setup.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_macro_nutrients.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_recipe_by_id_usecase.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import '../../helpers/overview_diary_harness.dart';
import '../../helpers/pump_until.dart';

const _nutriments = MealNutrimentsEntity(
  energyKcal100: NutrientAmount(100),
  carbohydrates100: NutrientAmount(10),
  fat100: NutrientAmount(5),
  proteins100: NutrientAmount(5),
  sugars100: NutrientAmount(2),
  saturatedFat100: NutrientAmount(1),
  fiber100: NutrientAmount(1),
);

MealEntity _solidWithServing({
  double serving = 30,
  bool liquid = false,
  String name = 'Solid product',
  String? brands,
  MealNutrimentsEntity nutriments = _nutriments,
  MealSourceEntity source = MealSourceEntity.custom,
}) => MealEntity(
  code: 'raw-units-test-solid',
  name: name,
  brands: brands,
  url: null,
  mealQuantity: '100',
  mealUnit: liquid ? 'ml' : 'g',
  servingQuantity: serving,
  servingUnit: liquid ? 'ml' : 'g',
  servingSize: '$serving g',
  nutriments: nutriments,
  source: source,
);

double _maxScrollOffset(WidgetTester tester) {
  final states = tester.stateList<ScrollableState>(find.byType(Scrollable));
  return states.fold<double>(0, (m, s) => math.max(m, s.position.pixels));
}

void main() {
  useTestLocator();
  final getIt = GetIt.instance;
  MealDetailBloc? bloc;
  GetUserUsecase? users;
  MealEntity? hydratedFor;
  late bool imperialFoodUnits;
  late _FakeCatalogue catalogue;
  late List<IntakeEntity> logged;
  RecipeEntity? savedRecipe;
  late _FakeGetTrackedDayUsecase daily;

  setUp(() {
    bloc = null;
    users = null;
    hydratedFor = null;
    imperialFoodUnits = false;
    catalogue = _FakeCatalogue();
    logged = [];
    savedRecipe = null;
    daily = _FakeGetTrackedDayUsecase();
    getIt.registerSingleton<GetRecipeByIdUseCase>(_Recipes(() => savedRecipe));
    getIt.registerFactory<MealDetailBloc>(
      () => bloc = MealDetailBloc(
        _FakeAddIntakeUsecase(logged),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        daily,
        _FakeProductsRepository(() => hydratedFor),
        _FakeRemoteSearchCacheDataSource(),
        catalogue: catalogue,
        getUserUsecase: users,
      ),
    );
    getIt.registerLazySingleton<GetConfigUsecase>(
      () => _FakeGetConfigUsecase(() => imperialFoodUnits),
    );
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    await getIt.resetScope();
  });

  Future<NavigatorState> pumpMealDetail(
    WidgetTester tester,
    MealEntity meal, {
    Widget Function(RouteSettings)? destination,
    bool recipeDetail = false,
    Size size = const Size(600, 800),
    double textScale = 1,
    Future<bool> Function(MealEntity, FoodAmountSelection)? onConfirm,
  }) async {
    // 600x800 leaves the CustomScrollView with a real maxScrollExtent, so
    // the scroll-offset assertion below can actually fail if the race guard
    // regresses. A taller viewport clamps `animateTo` to 0 and the test
    // passes vacuously.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    Route<dynamic> routeFor(RouteSettings settings) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => settings.name == NavigationOptions.mealDetailRoute
            ? const MealDetailScreen()
            : destination!(settings),
      );
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          initialRoute: NavigationOptions.mealDetailRoute,
          onGenerateInitialRoutes: (_) => [
            routeFor(
              RouteSettings(
                name: recipeDetail
                    ? NavigationOptions.recipeDetailRoute
                    : NavigationOptions.mealDetailRoute,
                arguments: recipeDetail
                    ? RecipeDetailArguments(recipeId: savedRecipe!.id)
                    : MealDetailScreenArguments(
                        meal,
                        IntakeTypeEntity.breakfast,
                        DateTime(2026, 9, 14),
                        imperialFoodUnits,
                        onConfirm: onConfirm,
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

  Future<void> openAmount(WidgetTester tester) async {
    final informationBloc = bloc;
    await tester.tap(find.bySemanticsIdentifier('meal-detail-log-food'));
    await tester.pumpAndSettle();
    bloc = informationBloc;
  }

  Future<void> chooseBasis(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<_LiveRecipes> openRecipe(
    WidgetTester tester, {
    double textScale = 1,
    bool fromSearch = false,
    MealEntity? ingredient,
    double grams = 100,
    Widget Function(RouteSettings)? editDestination,
  }) async {
    final food = ingredient ?? _solidWithServing();
    savedRecipe = RecipeEntity(
      id: 'recipe-live',
      name: 'My recipe',
      description: 'Description',
      ingredients: [
        RecipeIngredientEntity(
          snapshotMeal: food,
          quantity: FoodAmountSelection(
            grams,
            foodAmountOptions(food).firstWhere((o) => o.unit == 'g'),
          ),
        ),
      ],
      totalWeightG: grams,
      aggregatedNutrimentsPer100: food.nutriments,
      servingsCount: 2,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
    final saves = _LiveRecipes();
    getIt.registerSingleton<SaveRecipeUseCase>(saves);
    getIt.registerSingleton<DeleteRecipeUseCase>(saves);
    getIt.registerFactory<RecipeBuilderBloc>(
      () => RecipeBuilderBloc(ComputeRecipeNutritionUseCase(), saves),
    );
    final selectedDay = SelectedDayCubit(getIt<GetConfigUsecase>());
    getIt.registerSingleton<SelectedDayCubit>(selectedDay);
    addTearDown(selectedDay.close);
    await pumpMealDetail(
      tester,
      savedRecipe!.toMealEntity(),
      recipeDetail: !fromSearch,
      size: const Size(360, 800),
      textScale: textScale,
      destination: (settings) =>
          settings.name == NavigationOptions.editMealRoute
          ? editDestination!(settings)
          : const RecipeDetailScreen(),
    );
    return saves;
  }

  testWidgets('food and recipe info share both eye-toggle choices', (
    tester,
  ) async {
    final h = OverviewDiaryHarness();
    await tester.runAsync(h.initialize);
    await getIt.unregister<GetConfigUsecase>();
    getIt.registerSingleton<GetConfigUsecase>(h.getConfig);
    getIt.registerSingleton<AddConfigUsecase>(AddConfigUsecase(h.config));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await pumpUntilComplete(
        tester,
        h.dispose(),
        reason: 'closing shared info preferences',
      );
    });
    final missing = find.byKey(const ValueKey('nutrition-row-vitamin_b12'));
    await pumpMealDetail(tester, _solidWithServing());
    final show = find.byTooltip('Show nutrients with no data');
    await pumpUntil(tester, () => show.evaluate().isNotEmpty);
    expect(missing, findsNothing);
    await tester.ensureVisible(show);
    await tester.tap(show);
    await pumpUntil(tester, () => missing.evaluate().isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await openRecipe(tester);
    final hide = find.byTooltip('Hide nutrients with no data');
    await pumpUntil(tester, () => hide.evaluate().isNotEmpty);
    expect(missing, findsOneWidget);
    await tester.ensureVisible(hide);
    await tester.tap(hide);
    await pumpUntil(tester, () => missing.evaluate().isEmpty);
    await tester.pumpWidget(const SizedBox());
    await pumpMealDetail(tester, _solidWithServing());
    await pumpUntil(tester, () => show.evaluate().isNotEmpty);
    expect(missing, findsNothing);
  });

  testWidgets(
    'recipe reuses nutrition and logging, and details edits save on leaving',
    (tester) async {
      final saves = await openRecipe(tester);
      expect(find.text('Log this item'), findsOneWidget);
      expect(find.byType(MealDetailNutrimentsTable), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      final logRect = tester.getRect(
        find.bySemanticsIdentifier('recipe-log-item'),
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.bySemanticsIdentifier('recipe-log-item')),
        logRect,
      );
      final name = find.descendant(
        of: find.bySemanticsIdentifier('recipe-name'),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Updated recipe');
      await tester.pump();
      // Leave before the debounce expires; the final write must still complete.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(saves.saved.last.name, 'Updated recipe');
      expect(saves.saved.last.createdAt, DateTime(2026, 1, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ingredient swipes copy and delete, quantity edits update nutrition and save',
    (tester) async {
      final saves = await openRecipe(tester);
      final original = savedRecipe!.ingredients.single.snapshotMeal;
      await tester.tap(find.text('Ingredients').first);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('recipe-ingredients-sort'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      await tester.drag(
        find.byType(FoodAmountCard).first,
        const Offset(-240, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('recipe-ingredient-copy'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(saves.saved.last.ingredients, hasLength(2));
      await tester.tap(find.byType(FoodAmountCard).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '50');
      await tester.tap(find.bySemanticsIdentifier('food-amount-confirm'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(saves.saved.last.totalWeightG, 150);
      expect(saves.saved.last.ingredients.first.snapshotMeal, same(original));
      await tester.drag(
        find.byType(FoodAmountCard).last,
        const Offset(-240, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('recipe-ingredient-delete').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(saves.saved.last.ingredients, hasLength(1));
      expect(saves.saved.last.totalWeightG, 50);
      await tester.tap(find.text('Nutrition'));
      await tester.pumpAndSettle();
      expect(find.text('1 serving (25 g)'), findsOneWidget);
      expect(bloc!.state.totalKcal, 25);
      expect(logged, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final refresh in [false, true]) {
    for (final grams in <double?>[200, 250, null]) {
      testWidgets(
        'recipe ingredient ${refresh ? 'refresh' : 'edit'} '
        '${grams == null ? 'leaves the recipe unchanged on cancellation' : 'saves updated food at $grams g'}',
        (tester) async {
          final source = refresh
              ? MealSourceEntity.off
              : MealSourceEntity.custom;
          final original = _solidWithServing(source: source);
          final updated = _solidWithServing(
            source: source,
            name: 'Updated yoghurt',
            brands: 'Updated brand',
            serving: 40,
            nutriments: const MealNutrimentsEntity(
              energyKcal100: NutrientAmount(150),
              carbohydrates100: null,
              fat100: NutrientAmount(5),
              proteins100: NutrientAmount(12),
              sugars100: null,
              saturatedFat100: NutrientAmount(1),
              fiber100: null,
              calcium100: NutrientAmount(120),
            ),
          );
          hydratedFor = original;
          final saves = await openRecipe(
            tester,
            ingredient: original,
            grams: 200,
            editDestination: (_) =>
                const Scaffold(body: Text('Ingredient editor')),
          );
          await tester.tap(find.text('Ingredients').first);
          await tester.pumpAndSettle();
          await tester.drag(find.byType(FoodAmountCard), const Offset(150, 0));
          await tester.pumpAndSettle();
          await tester.tap(
            find.bySemanticsIdentifier('recipe-ingredient-info'),
          );
          await tester.pumpAndSettle();
          if (refresh) {
            hydratedFor = updated;
            await tester.tap(find.bySemanticsIdentifier('meal-detail-refresh'));
          } else {
            await tester.tap(find.bySemanticsIdentifier('meal-detail-edit'));
            await tester.pumpAndSettle();
            Navigator.of(
              tester.element(find.text('Ingredient editor')),
            ).pop(updated);
          }
          await tester.pumpAndSettle();
          await openAmount(tester);
          if (grams == null) {
            await tester.tap(find.bySemanticsIdentifier('food-amount-cancel'));
            await tester.pumpAndSettle();
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.bySemanticsIdentifier('food-amount-unit'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('g').last);
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField).last, '$grams');
            await tester.tap(find.bySemanticsIdentifier('food-amount-confirm'));
          }
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 450));
          await tester.pumpAndSettle();

          final card = tester.widget<FoodAmountCard>(
            find.byType(FoodAmountCard),
          );
          if (grams == null) {
            expect(card.meal, same(original));
            expect(card.quantity!.baseAmount, 200);
            expect(saves.saved, isEmpty);
          } else {
            final totalKcal = 150 * grams / 100;
            expect(card.meal, same(updated));
            expect(card.quantity!.baseAmount, grams);
            expect(
              find.descendant(
                of: find.byType(FoodAmountCard),
                matching: find.text('${totalKcal.toStringAsFixed(0)} kcal'),
              ),
              findsOneWidget,
            );
            final saved = saves.saved.last;
            expect(saved.ingredients.single.snapshotMeal, same(updated));
            expect(saved.ingredients.single.quantity.baseAmount, grams);
            expect(saved.aggregatedNutrimentsPer100, updated.nutriments);
            expect(saved.totalWeightG, grams);
          }
          expect(logged, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'recipe logging opens the amount sheet and logs the selected quantity',
    (tester) async {
      await openRecipe(tester);
      await tester.tap(find.bySemanticsIdentifier('recipe-log-item'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('recipe-log-breakfast'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '40');
      await tester.tap(find.bySemanticsIdentifier('food-amount-confirm'));
      await tester.pumpAndSettle();
      expect(logged.single.baseAmount, 40);
      expect(logged.single.meal.source, MealSourceEntity.recipe);
      expect(find.bySemanticsIdentifier('recipe-log-item'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'recipe quick add requires weight and adds an ingredient without logging',
    (tester) async {
      final saves = await openRecipe(tester);
      await tester.tap(find.text('Ingredients').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(FoodAmountCard).first,
                matching: find.byType(AppCard),
              ),
            )
            .dx,
        16,
      );
      await tester.tap(
        find.bySemanticsIdentifier('recipe-quick-add-ingredient'),
      );
      await tester.pumpAndSettle();
      Future<void> enter(String identifier, String value) => tester.enterText(
        find.descendant(
          of: find.bySemanticsIdentifier(identifier),
          matching: find.byType(TextField),
        ),
        value,
      );
      await enter('quick-add-title', 'Sauce');
      await enter('quick-add-energy', '80');
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.bySemanticsIdentifier('quick-add-submit'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await enter('quick-add-weight', '20');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('quick-add-submit'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(saves.saved.last.ingredients.last.snapshotMeal.name, 'Sauce');
      expect(saves.saved.last.totalWeightG, 120);
      expect(logged, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('recipe share displays its QR payload', (tester) async {
    await openRecipe(tester);
    await tester.tap(find.bySemanticsIdentifier('recipe-share'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareQrDialog), findsOneWidget);
    expect(
      tester.widget<ShareQrDialog>(find.byType(ShareQrDialog)).code,
      isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recipe tabs and pinned logging fit enlarged text', (
    tester,
  ) async {
    await openRecipe(tester, textScale: 3);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.bySemanticsIdentifier('recipe-log-item')).bottom,
      lessThanOrEqualTo(800),
    );
    await tester.ensureVisible(find.text('Ingredients').first);
    await tester.tap(find.text('Ingredients').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'information previews one weighted serving without amount fields',
    (tester) async {
      await pumpMealDetail(tester, _solidWithServing());
      expect(bloc!.state.totalKcal, 30);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Log this item'), findsOneWidget);
      expect(find.text('1 serving (30 g)'), findsOneWidget);
      expect(find.text('Nutrition Information'), findsNothing);
      expect(
        tester
            .getBottomLeft(
              find.bySemanticsIdentifier('meal-detail-nutrition-basis'),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('meal-detail-macro-summary')),
              )
              .dy,
        ),
      );
      expect(
        find.byKey(const ValueKey('meal-detail-macro-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('nutrition-row-vitamin_b12')),
        findsNothing,
      );
      expect(find.byTooltip('Show nutrients with no data'), findsOneWidget);
      expect(_maxScrollOffset(tester), 0);
    },
  );

  testWidgets(
    'compact header only shows the name and company and summaries fit four across at 360px',
    (tester) async {
      await pumpMealDetail(
        tester,
        _solidWithServing(brands: 'Food company'),
        size: const Size(360, 800),
      );
      final header = find.byKey(const ValueKey('meal-detail-header'));
      expect(
        find.descendant(of: header, matching: find.text('Solid product')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Food company')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.textContaining('g')),
        findsNothing,
      );
      final image = find.descendant(
        of: header,
        matching: find.byType(FoodImage),
      );
      expect(tester.getSize(image), const Size(64, 64));
      final summaries = find
          .byType(MealDetailMacroNutrients)
          .evaluate()
          .toList();
      expect(summaries, hasLength(4));
      final first = tester.getTopLeft(find.byWidget(summaries.first.widget)).dy;
      for (final summary in summaries) {
        expect(tester.getTopLeft(find.byWidget(summary.widget)).dy, first);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final imperial in [false, true]) {
    testWidgets('Log this item opens an amount sheet with imperial=$imperial', (
      tester,
    ) async {
      imperialFoodUnits = imperial;
      await pumpMealDetail(tester, _solidWithServing());
      await openAmount(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(logged, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '100',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'g:g:1.0',
      );
      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.bySemanticsIdentifier('food-amount-confirm'));
      await tester.pumpAndSettle();
      expect(logged.single.baseAmount, 50);
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets(
    'cancelling the amount sheet keeps the reference preview and logs nothing',
    (tester) async {
      await pumpMealDetail(tester, _solidWithServing());
      await chooseBasis(tester, 'Per 100g/ml');
      expect(bloc!.state.totalKcal, 100);
      await openAmount(tester);
      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.bySemanticsIdentifier('food-amount-cancel'));
      await tester.pumpAndSettle();
      expect(logged, isEmpty);
      expect(bloc!.state.totalKcal, 100);
      expect(
        tester
            .widget<MealDetailNutrimentsTable>(
              find.byType(MealDetailNutrimentsTable),
            )
            .reference,
        true,
      );
      await chooseBasis(tester, '1 serving (30 g)');
      expect(bloc!.state.totalKcal, 30);
    },
  );

  for (final serving in [0.0, -1.0, double.nan, double.infinity]) {
    testWidgets(
      'unavailable serving $serving stays visible and logging remains available',
      (tester) async {
        await pumpMealDetail(tester, _solidWithServing(serving: serving));
        final basis = tester.widget<SegmentedButton<bool>>(
          find.byType(SegmentedButton<bool>),
        );
        expect(basis.segments.first.enabled, false);
        expect(basis.selected, {true});
        expect(find.text('1 serving'), findsOneWidget);
        expect(find.text('Serving weight unavailable.'), findsOneWidget);
        expect(bloc!.state.totalKcal, 100);
        await openAmount(tester);
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.bySemanticsIdentifier('food-amount-cancel'));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'hydration enables the serving button and defaults to the weighted serving',
    (tester) async {
      hydratedFor = _solidWithServing(source: MealSourceEntity.off);
      await pumpMealDetail(
        tester,
        _solidWithServing(serving: 0, source: MealSourceEntity.off),
      );
      expect(find.text('1 serving (30 g)'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .segments
            .first
            .enabled,
        true,
      );
      expect(bloc!.state.totalKcal, 30);
    },
  );

  testWidgets('liquid serving button shows its volume', (tester) async {
    await pumpMealDetail(tester, _solidWithServing(liquid: true, serving: 240));
    expect(find.text('1 serving (240 ml)'), findsOneWidget);
    expect(bloc!.state.totalKcal, 240);
  });

  testWidgets(
    'stored goals win; absent day and absent stored macros use calculated goals',
    (tester) async {
      await pumpMealDetail(tester, _solidWithServing());
      expect(bloc!.state.dayCarbsGoal, 250);
      expect(bloc!.state.dayFatGoal, 70);
      expect(bloc!.state.dayProteinGoal, 120);
      expect(bloc!.state.nutrientReferences['saturated_fat']!.hasGoal, isFalse);
      expect(bloc!.state.nutrientReferences['sodium']!.unavailable, 'profile');
      daily.tracked = null;
      bloc!.add(LoadDailyTotalsEvent(DateTime(2026, 10, 11)));
      await tester.pumpAndSettle();
      expect(bloc!.state.dayKcalGoal, 2400);
      expect(bloc!.state.dayCarbsGoal, 300);
      expect(bloc!.state.dayFatGoal, 60);
      expect(bloc!.state.dayProteinGoal, 150);
      daily.tracked = TrackedDayEntity(
        day: DateTime(2026),
        calorieGoal: 1600,
        caloriesTracked: 700,
      );
      bloc!.add(LoadDailyTotalsEvent(DateTime(2026, 10, 12)));
      await tester.pumpAndSettle();
      expect(bloc!.state.dayKcalConsumed, 700);
      expect(bloc!.state.dayCarbsGoal, 200);
      expect(bloc!.state.dayFatGoal, 40);
      expect(bloc!.state.dayProteinGoal, 100);
    },
  );
  testWidgets(
    'missing user data preserves core daily goals and marks additional references unavailable',
    (tester) async {
      users = _UnavailableUser();
      await pumpMealDetail(tester, _solidWithServing());
      expect(bloc!.state.dayCarbsGoal, 250);
      expect(bloc!.state.nutrientReferences['sodium']!.unavailable, 'profile');
      expect(bloc!.state.nutrientReferences['fiber']!.unavailable, 'profile');
    },
  );

  for (final save in [false, true]) {
    testWidgets(
      'custom edit ${save ? 'updates the serving weight' : 'cancel keeps the serving weight'}',
      (tester) async {
        EditMealScreenArguments? args;
        final navigator = await pumpMealDetail(
          tester,
          _solidWithServing(),
          destination: (settings) {
            args = settings.arguments as EditMealScreenArguments;
            return const Scaffold(body: Text('Editor'));
          },
        );
        await tester.tap(find.bySemanticsIdentifier('meal-detail-edit'));
        await tester.pumpAndSettle();
        expect(args!.editOnly, true);
        navigator.pop(
          save ? _solidWithServing(name: 'Saved food', serving: 40) : null,
        );
        await tester.pumpAndSettle();
        expect(bloc!.state.totalKcal, save ? 40 : 30);
        expect(
          find.text(save ? '1 serving (40 g)' : '1 serving (30 g)'),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
      },
    );
  }

  testWidgets(
    'editing away the serving disables its button and uses the reference basis',
    (tester) async {
      final navigator = await pumpMealDetail(
        tester,
        _solidWithServing(),
        destination: (_) => const Scaffold(body: Text('Editor')),
      );
      await tester.tap(find.bySemanticsIdentifier('meal-detail-edit'));
      await tester.pumpAndSettle();
      navigator.pop(_solidWithServing(serving: 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .segments
            .first
            .enabled,
        false,
      );
      expect(bloc!.state.totalKcal, 100);
    },
  );

  testWidgets(
    'recipe search information opens the same tabs with no self-link',
    (tester) async {
      await openRecipe(tester, fromSearch: true);
      expect(find.text('Custom Recipe'), findsOneWidget);
      expect(find.bySemanticsIdentifier('recipe-detail-tabs'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('meal-detail-information'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('recipe-share'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final textScale in [1.0, 2.0, 3.0]) {
    testWidgets(
      '360px screen at text scale $textScale keeps logging and keyboard controls reachable',
      (tester) async {
        await pumpMealDetail(
          tester,
          _solidWithServing(name: 'Long product name ' * 20),
          size: const Size(360, 800),
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.bySemanticsIdentifier('meal-detail-information'),
        );
        expect(tester.takeException(), isNull);
        await openAmount(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.bySemanticsIdentifier('food-amount-confirm'),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getRect(find.bySemanticsIdentifier('food-amount-confirm'))
              .bottom,
          lessThanOrEqualTo(500),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.bySemanticsIdentifier('food-amount-cancel'));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'contextual logging uses the amount sheet and does not log a diary intake',
    (tester) async {
      FoodAmountSelection? selected;
      await pumpMealDetail(
        tester,
        _solidWithServing(),
        onConfirm: (food, amount) async {
          selected = amount;
          return true;
        },
      );
      await openAmount(tester);
      await tester.enterText(find.byType(TextField), '60');
      await tester.tap(find.bySemanticsIdentifier('food-amount-confirm'));
      await tester.pumpAndSettle();
      expect(selected!.baseAmount, 60);
      expect(logged, isEmpty);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Stream<ConfigEntity> watchConfig() => Stream.fromFuture(getConfig());

  final bool Function() imperialProvider;
  _FakeGetConfigUsecase(this.imperialProvider);

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(
      AppThemeEntity.system,
      usesImperialFoodUnits: imperialProvider(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  _FakeAddIntakeUsecase(this.logged);
  final List<IntakeEntity> logged;
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
  Future<double> getKcalGoal({
    UserEntity? userEntity,
    DateTime? day,
    double? totalKcalActivitiesParam,
    double? kcalUserAdjustment,
  }) async => 2400;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetMacroGoalUsecase implements GetMacroGoalUsecase {
  @override
  Future<double> getCarbsGoal(double goal) async => goal / 8;
  @override
  Future<double> getFatsGoal(double goal) async => goal / 40;
  @override
  Future<double> getProteinsGoal(double goal) async => goal / 16;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetTrackedDayUsecase implements GetTrackedDayUsecase {
  TrackedDayEntity? tracked = TrackedDayEntity(
    day: DateTime(2026),
    calorieGoal: 2200,
    caloriesTracked: 800,
    carbsGoal: 250,
    fatGoal: 70,
    proteinGoal: 120,
  );
  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async => tracked;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeProductsRepository implements ProductsRepository {
  final MealEntity? Function() hydratedProvider;

  _FakeProductsRepository(this.hydratedProvider);

  @override
  Future<MealEntity> getOFFProductByBarcode(String barcode) async {
    final hydrated = hydratedProvider();
    if (hydrated == null) {
      throw StateError('No hydrated product configured for barcode $barcode');
    }
    return hydrated;
  }

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
  Future<MealDBO?> getDetailedByBarcode(String barcode) async => null;

  @override
  Future<void> cache(MealDBO meal, {int? generation, String? language}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetIntakeUsecase implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getBreakfastIntakeByDay(
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

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

class _FakeCatalogue implements FoodCatalogue {
  @override
  Future<List<CatalogueSource>> sources() async => const [];
  final ids = <String>[];
  final meal = MealEntity(
    code: 'usda:123',
    name: 'Catalogue food',
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    nutriments: _nutriments,
    source: MealSourceEntity.catalogue,
    detailed: true,
    portions: [
      MealPortionEntity(
        id: 'test:0',
        label: '1 cup',
        englishLabel: '1 cup',
        gramWeight: 140,
        localized: false,
      ),
    ],
  );
  @override
  Future<MealEntity?> getById(String id) async {
    ids.add(id);
    return meal;
  }

  @override
  Future<List<MealEntity>> search(String query, {Set<String>? sourceIds}) =>
      throw UnimplementedError();
}

class _Recipes implements GetRecipeByIdUseCase {
  _Recipes(this.read);
  final RecipeEntity? Function() read;
  @override
  RecipeEntity? getById(String id) => read();
}

class _UnavailableUser implements GetUserUsecase {
  @override
  Future<UserEntity> getUserData() async => throw StateError('No user');
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _LiveRecipes implements SaveRecipeUseCase, DeleteRecipeUseCase {
  final saved = <RecipeEntity>[];
  final deleted = <String>[];
  @override
  Future<RecipeEntity> save(RecipeEntity recipe) async {
    saved.add(recipe);
    return recipe;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
  }
}
