import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_recipe_by_id_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_builder_screen.dart';

class RecipeDetailArguments {
  final String recipeId;
  const RecipeDetailArguments({required this.recipeId});
}

class RecipeDetailScreen extends StatefulWidget {
  final MealDetailScreenArguments? foodArguments;
  const RecipeDetailScreen({super.key, this.foodArguments});
  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeEntity? _recipe;
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final id = widget.foodArguments != null
        ? widget.foodArguments!.mealEntity.code
        : (ModalRoute.of(context)!.settings.arguments as RecipeDetailArguments)
              .recipeId;
    _recipe = id == null ? null : locator<GetRecipeByIdUseCase>().getById(id);
    if (_recipe == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).diaryRecipeUnavailableMessage)),
        );
        Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => _recipe == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : RecipeBuilderScreen(
          existing: _recipe,
          live: true,
          loggingArguments: widget.foodArguments,
        );
}
