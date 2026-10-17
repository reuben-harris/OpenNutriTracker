import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_recipe_by_id_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/food_section_actions.dart';
import 'package:opennutritracker/core/presentation/widgets/explode_recipe_dialog.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/food_amount_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_card_geometry.dart';
import 'package:opennutritracker/core/presentation/widgets/food_section_header.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/food_amount/food_information.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_sort_type.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecipeIngredientsSection extends StatefulWidget {
  final List<RecipeIngredientEntity> ingredients;
  final VoidCallback onAdd, onScan, onQuickAdd;
  final void Function(int, RecipeEntity) onExplode;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onCopy;
  final void Function(int, FoodAmountSelection) onQuantityChanged;
  const RecipeIngredientsSection({
    super.key,
    required this.ingredients,
    required this.onAdd,
    required this.onScan,
    required this.onQuickAdd,
    required this.onExplode,
    required this.onEdit,
    required this.onRemove,
    required this.onCopy,
    required this.onQuantityChanged,
  });
  @override
  State<RecipeIngredientsSection> createState() =>
      _RecipeIngredientsSectionState();
}

class _RecipeIngredientsSectionState extends State<RecipeIngredientsSection> {
  DiarySortType _sort = DiarySortType.timeAdded;
  bool _imperial = false;
  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (mounted) setState(() => _imperial = config.usesImperialFoodUnits);
  }

  double _sortValue(RecipeIngredientEntity ingredient) {
    final n = ingredient.snapshotMeal.nutriments;
    final value = switch (_sort) {
      DiarySortType.timeAdded => 0.0,
      DiarySortType.kcal => n.energyKcal100 ?? 0,
      DiarySortType.carbs => n.carbohydrates100 ?? 0,
      DiarySortType.protein => n.proteins100 ?? 0,
      DiarySortType.fat => n.fat100 ?? 0,
    };
    return value * ingredient.quantity.baseAmount / 100;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final indices = List.generate(widget.ingredients.length, (i) => i);
    if (_sort != DiarySortType.timeAdded) {
      indices.sort((a, b) {
        final order = _sortValue(
          widget.ingredients[b],
        ).compareTo(_sortValue(widget.ingredients[a]));
        return order == 0 ? a.compareTo(b) : order;
      });
    }
    return Semantics(
      identifier: 'recipe-ingredients-group',
      label: s.recipeIngredientsLabel,
      child: SwipeRevealScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoodSectionHeader(
              title: s.recipeIngredientsLabel,
              icon: Icons.restaurant_rounded,
              actions: [
                FoodSectionSortMenu(
                  identifier: 'recipe-ingredients-sort',
                  value: _sort,
                  onChanged: (sort) => setState(() => _sort = sort),
                ),
              ],
            ),
            if (indices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.recipeNoIngredientsLabel),
              ),
            for (final index in indices) _row(context, index),
            FoodSectionActions(
              scanIdentifier: 'recipe-scan-ingredient',
              addIdentifier: 'recipe-add-ingredient',
              quickAddIdentifier: 'recipe-quick-add-ingredient',
              onScan: widget.onScan,
              onAdd: widget.onAdd,
              onQuickAdd: widget.onQuickAdd,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index) {
    final ingredient = widget.ingredients[index];
    final s = S.of(context);
    return Semantics(
      key: ObjectKey(ingredient),
      identifier: 'recipe-ingredient-$index',
      label: ingredient.snapshotMeal.name ?? '?',
      child: SwipeReveal(
        resetKey: ingredient,
        actionInsets: FoodCardGeometry.margin,
        actionRadius: FoodCardGeometry.radius,
        leftAction: SwipeRevealAction(
          icon: Icons.info_outline_rounded,
          label: s.diaryInfoLabel,
          semanticsIdentifier: 'recipe-ingredient-info',
          animateClose: false,
          onTap: () => showFoodInformation(
            context,
            meal: ingredient.snapshotMeal,
            day: DateTime.now(),
            type: IntakeTypeEntity.snack,
            imperial: _imperial,
            onConfirm: (_, selection) async {
              widget.onQuantityChanged(index, selection);
              return true;
            },
          ),
        ),
        rightActionWidth: 64,
        rightActions: [
          SwipeRevealAction(
            icon: Icons.copy_rounded,
            label: s.copyActionLabel,
            semanticsIdentifier: 'recipe-ingredient-copy',
            onTap: () => widget.onCopy(index),
          ),
          if (ingredient.snapshotMeal.source == MealSourceEntity.recipe)
            SwipeRevealAction(
              icon: Icons.call_split_rounded,
              label: s.explodeRecipeLabel,
              semanticsIdentifier: 'recipe-ingredient-explode',
              onTap: () async {
                final nested = locator<GetRecipeByIdUseCase>().getById(
                  ingredient.snapshotMeal.code ?? '',
                );
                if (nested == null ||
                    !nested.totalWeightG.isFinite ||
                    nested.totalWeightG <= 0 ||
                    nested.ingredients.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.diaryRecipeUnavailableMessage)),
                  );
                  return;
                }
                if (await confirmRecipeExplosion(context) == true && mounted) {
                  widget.onExplode(index, nested);
                }
              },
            ),
          SwipeRevealAction(
            icon: Icons.delete_rounded,
            label: s.dialogDeleteLabel,
            color: Theme.of(context).colorScheme.error,
            semanticsIdentifier: 'recipe-ingredient-delete',
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => const DeleteDialog(),
              );
              if (confirmed == true && mounted) widget.onRemove(index);
            },
          ),
        ],
        child: FoodAmountCard(
          meal: ingredient.snapshotMeal,
          quantity: ingredient.quantity,
          usesImperialUnits: _imperial,
          onTap: () => widget.onEdit(index),
        ),
      ),
    );
  }
}
