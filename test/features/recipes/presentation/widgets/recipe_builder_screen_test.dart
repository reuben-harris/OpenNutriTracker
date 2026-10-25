import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import '../../../../helpers/locator_test_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_builder_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/food_nutrition_information.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/recipe_weight_editor.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../../fixture/diary_entry_fixtures.dart';

class _Recipes implements RecipeRepository {
  final saved = <RecipeEntity>[];
  @override
  Future<void> saveRecipe(RecipeEntity recipe) async {
    saved.add(recipe);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  useTestLocator();
  testWidgets(
    'weight sits below tags, nutrition preview is absent, and errors require saving',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Recipes();
      final compute = ComputeRecipeNutritionUseCase();
      final bloc = RecipeBuilderBloc(compute, SaveRecipeUseCase(repo, compute));
      locator.registerFactory<RecipeBuilderBloc>(() => bloc);
      locator.registerSingleton<GetConfigUsecase>(_Config());
      addTearDown(() => locator.resetScope());
      final recipe = diaryEntry(recipe: true).recipeSnapshot!;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EnergyUnitProvider(),
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: RouteSettings(
                arguments: RecipeBuilderArguments(existing: recipe),
              ),
              builder: (_) => const RecipeBuilderScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(RecipeWeightEditor)).dy,
        greaterThan(tester.getTopLeft(find.text('Tags')).dy),
      );
      expect(
        tester.getTopLeft(find.byType(RecipeWeightEditor)).dy,
        lessThan(tester.getTopLeft(find.text('Ingredients')).dy),
      );
      expect(find.byType(FoodNutritionInformation), findsNothing);
      await tester.tap(find.text('Cooked weight'));
      await tester.pumpAndSettle();
      final cookedField = find.descendant(
        of: find.byType(RecipeWeightEditor),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(cookedField).decoration!.errorText,
        isNull,
      );
      await tester.tap(find.text('Save Recipe'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(cookedField).decoration!.errorText,
        isNotNull,
      );
      expect(repo.saved, isEmpty);
      await tester.enterText(cookedField, '150,125');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(cookedField).decoration!.errorText,
        isNull,
      );
      await tester.tap(find.text('Save Recipe'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.cookedWeightG, 150.125);
      expect(repo.saved.single.totalWeightG, 150.125);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Config implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      ConfigEntity(true, true, AppThemeEntity.system);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
