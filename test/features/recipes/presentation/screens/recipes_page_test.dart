import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_all_recipes_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/custom_meals_tab.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/library_add_menu.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/locator_test_setup.dart';
import '../../../../helpers/test_l10n.dart';

class _Recipes extends Fake implements GetAllRecipesUseCase {
  List<RecipeEntity> recipes = [];
  int loads = 0;

  @override
  List<RecipeEntity> getAll() {
    loads++;
    return List.of(recipes);
  }
}

class _Config extends Fake implements GetConfigUsecase {
  bool imperial = false;

  @override
  Future<ConfigEntity> getConfig() async => ConfigEntity(
    true,
    AppThemeEntity.system,
    usesImperialFoodUnits: imperial,
  );
}

class _CustomMeals extends Fake implements CustomMealsBloc {
  int loads = 0;

  @override
  CustomMealsState get state => CustomMealsLoadedState(meals: []);

  @override
  Stream<CustomMealsState> get stream => const Stream.empty();

  @override
  void add(CustomMealsEvent event) {
    if (event is LoadCustomMealsEvent) loads++;
  }
}

RecipeEntity _recipe(int index, {String? name, List<String> tags = const []}) =>
    RecipeEntity(
      id: '$index',
      name: name ?? 'Recipe $index',
      description: null,
      ingredients: const [],
      totalWeightG: 100,
      aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      servingsCount: null,
      tags: tags,
    );

void main() {
  useTestLocator();
  late _Recipes source;
  late _Config config;
  late _CustomMeals meals;
  late RecipesBloc recipes;
  late EnergyUnitProvider energy;
  RouteSettings? opened;

  setUp(() {
    source = _Recipes();
    config = _Config();
    meals = _CustomMeals();
    energy = EnergyUnitProvider();
    opened = null;
    // Subscribe inside the widget test's fake async zone when the page mounts.
    locator.registerLazySingleton<RecipesBloc>(
      () => recipes = RecipesBloc(source),
    );
    locator.registerSingleton<CustomMealsBloc>(meals);
    locator.registerSingleton<GetConfigUsecase>(config);
  });
  tearDown(() async {
    await recipes.close();
    energy.dispose();
  });

  Widget app({bool active = true, bool standalone = false}) =>
      ChangeNotifierProvider.value(
        value: energy,
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: standalone
              ? const RecipesPage()
              : Scaffold(
                  appBar: AppBar(
                    title: Text(l10nEn.libraryLabel),
                    actions: const [LibraryAddMenu()],
                  ),
                  body: IndexedStack(
                    index: active ? 0 : 1,
                    children: [
                      TickerMode(
                        enabled: active,
                        child: RecipesPage(showAppBar: false, isActive: active),
                      ),
                      const Text('Another tab'),
                    ],
                  ),
                ),
          onGenerateRoute: (settings) {
            opened = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Editor')),
                body: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to library'),
                ),
              ),
            );
          },
        ),
      );

  testWidgets('standalone Library keeps Recipes and Custom Meals sections', (
    tester,
  ) async {
    await tester.pumpWidget(app(standalone: true));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text(l10nEn.libraryLabel), findsOneWidget);
    expect(find.text(l10nEn.recipesLabel), findsOneWidget);
    await tester.tap(find.text(l10nEn.settingsCustomMealsLabel));
    await tester.pumpAndSettle();
    expect(find.text(l10nEn.customMealsEmptyLabel), findsOneWidget);
  });

  testWidgets('tab activation refreshes records and units, keeping filters', (
    tester,
  ) async {
    source.recipes = [
      _recipe(1, name: 'Soup', tags: ['Quick']),
      _recipe(2, name: 'Stew', tags: ['Slow']),
    ];
    await tester.pumpWidget(app(active: false));
    await tester.pumpAndSettle();
    expect(source.loads, 0);
    expect(meals.loads, 0);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(source.loads, 1);
    await tester.enterText(find.byType(TextField), 'Soup');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Quick'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(active: false));
    await tester.pumpAndSettle();
    config.imperial = true;
    source.recipes = [
      ...source.recipes,
      _recipe(3, name: 'Soup with rice', tags: ['Quick']),
    ];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(source.loads, 2);
    expect(meals.loads, 2);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Soup',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Quick'))
          .selected,
      isTrue,
    );
    expect(find.text('Soup with rice'), findsOneWidget);
    expect(find.text('Stew'), findsNothing);
    await tester.tap(find.text(l10nEn.settingsCustomMealsLabel));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CustomMealsTab>(find.byType(CustomMealsTab))
          .usesImperialUnits,
      isTrue,
    );
  });

  testWidgets(
    'recipe scroll position survives leaving and refreshing the tab',
    (tester) async {
      source.recipes = List.generate(40, (index) => _recipe(index));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('library-recipes-scroll'));
      await tester.drag(list, const Offset(0, -700));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      await tester.pumpWidget(app(active: false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, offset);
    },
  );

  testWidgets('shared add actions return to Library and reload their lists', (
    tester,
  ) async {
    config.imperial = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final cases = [
      (l10nEn.createRecipeTitle, NavigationOptions.recipeBuilderRoute),
      (l10nEn.newCustomMealLabel, NavigationOptions.editMealRoute),
      (l10nEn.importRecipeLabel, NavigationOptions.importRecipeScannerRoute),
    ];
    for (final (label, route) in cases) {
      final recipeLoads = source.loads;
      final mealLoads = meals.loads;
      await tester.tap(find.bySemanticsIdentifier('library-add-menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(opened!.name, route);
      if (route == NavigationOptions.editMealRoute) {
        final args = opened!.arguments as EditMealScreenArguments;
        expect(args.usesImperialUnits, isTrue);
        expect(args.editOnly, isTrue);
      }
      await tester.tap(find.text('Return to library'));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.libraryLabel), findsOneWidget);
      expect(
        source.loads,
        recipeLoads + (route == NavigationOptions.editMealRoute ? 0 : 1),
      );
      expect(
        meals.loads,
        mealLoads + (route == NavigationOptions.editMealRoute ? 1 : 0),
      );
    }
  });
}
