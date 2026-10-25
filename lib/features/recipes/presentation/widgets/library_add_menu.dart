import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum _LibraryAction {
  newRecipe,
  newCustomMeal,
  importRecipe;

  String get identifier => switch (this) {
    newRecipe => 'library-create-recipe',
    newCustomMeal => 'library-create-custom-meal',
    importRecipe => 'library-import-recipe',
  };
}

/// The same creation actions for the Library tab and its pushed screen.
class LibraryAddMenu extends StatelessWidget {
  const LibraryAddMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      identifier: 'library-add-menu',
      child: PopupMenuButton<_LibraryAction>(
        tooltip: s.addLabel,
        icon: const Icon(Icons.add),
        onSelected: (action) => _onSelected(context, action),
        itemBuilder: (context) => [
          _item(
            _LibraryAction.newRecipe,
            Icons.menu_book_outlined,
            s.createRecipeTitle,
          ),
          _item(
            _LibraryAction.newCustomMeal,
            Icons.restaurant_outlined,
            s.newCustomMealLabel,
          ),
          _item(
            _LibraryAction.importRecipe,
            Icons.qr_code_scanner_outlined,
            s.importRecipeLabel,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_LibraryAction> _item(
    _LibraryAction action,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: action,
    child: Semantics(
      identifier: action.identifier,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: Dimens.spacing12),
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );

  Future<void> _onSelected(BuildContext context, _LibraryAction action) async {
    // Capture the shared blocs before navigating: the menu can unmount while
    // an editor is open, but its saved result must still refresh the library.
    switch (action) {
      case _LibraryAction.newRecipe:
        final recipes = locator<RecipesBloc>();
        await Navigator.of(
          context,
        ).pushNamed(NavigationOptions.recipeBuilderRoute);
        recipes.add(const LoadRecipesEvent());
      case _LibraryAction.newCustomMeal:
        final meals = locator<CustomMealsBloc>();
        final config = await locator<GetConfigUsecase>().getConfig();
        if (!context.mounted) return;
        await Navigator.of(context).pushNamed(
          NavigationOptions.editMealRoute,
          arguments: EditMealScreenArguments(
            DateTime.now(),
            MealEntity.empty(),
            IntakeTypeEntity.breakfast,
            config.usesImperialFoodUnits,
            editOnly: true,
          ),
        );
        meals.add(LoadCustomMealsEvent());
      case _LibraryAction.importRecipe:
        final importedRecipes = locator<RecipesBloc>();
        await Navigator.of(
          context,
        ).pushNamed(NavigationOptions.importRecipeScannerRoute);
        importedRecipes.add(const LoadRecipesEvent());
    }
  }
}
