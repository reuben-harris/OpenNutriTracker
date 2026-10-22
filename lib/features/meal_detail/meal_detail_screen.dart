import 'package:opennutritracker/core/presentation/widgets/item_information_scaffold.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/food_nutrition_information.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as MealDetailScreenArguments;
    return args.mealEntity.source == MealSourceEntity.recipe
        ? RecipeDetailScreen(foodArguments: args)
        : const _FoodInformationScreen();
  }
}

class _FoodInformationScreen extends StatefulWidget {
  const _FoodInformationScreen();
  @override
  State<_FoodInformationScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<_FoodInformationScreen> {
  late final MealDetailBloc _bloc;
  late MealDetailScreenArguments _args;
  late MealEntity _meal;
  bool _initialized = false, _openingAmount = false;
  @override
  void initState() {
    super.initState();
    _bloc = locator<MealDetailBloc>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _args =
        ModalRoute.of(context)!.settings.arguments as MealDetailScreenArguments;
    _meal = _args.mealEntity;
    _bloc.add(HydrateMealEvent(_meal));
  }

  void _replaceMeal(MealEntity meal) {
    if (mounted) setState(() => _meal = meal);
  }

  Future<void> _logFood() async {
    if (_openingAmount) return;
    setState(() => _openingAmount = true);
    try {
      final added = await showFoodAmountSheet(
        context,
        meal: _meal,
        onConfirm: _add,
      );
      if (mounted && added) _finishAdd();
    } finally {
      if (mounted) setState(() => _openingAmount = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).pushNamed<dynamic>(
      NavigationOptions.editMealRoute,
      arguments: EditMealScreenArguments(
        _args.day,
        _meal,
        _args.intakeTypeEntity,
        _args.usesImperialUnits,
        editOnly: _meal.source == MealSourceEntity.custom,
      ),
    );
    if (saved is MealEntity && mounted) _replaceMeal(saved);
  }

  Future<bool> _add(MealEntity meal, FoodAmountSelection selection) async {
    if (_args.onConfirm != null) return _args.onConfirm!(meal, selection);
    return saveFoodAmount(
      context,
      meal: meal,
      selection: selection,
      day: _args.day,
      type: _args.intakeTypeEntity,
      logger: _bloc,
    );
  }

  void _finishAdd() {
    if (_args.onConfirm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).infoAddedIntakeLabel)),
      );
    }
    if (_args.returnAfterAdding) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).popUntil(
      (route) =>
          route.isFirst || route.settings.name == NavigationOptions.mainRoute,
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<MealDetailBloc, MealDetailState>(
    bloc: _bloc,
    listenWhen: (previous, current) =>
        previous.mealRevision != current.mealRevision ||
        previous.refreshStatus != current.refreshStatus,
    listener: (context, state) {
      if (state.isRefreshing) return;
      if (state.refreshStatus != ProductRefreshStatus.failure &&
          state.hydratedMeal != null) {
        _replaceMeal(state.hydratedMeal!);
      }
      if (state.refreshStatus == ProductRefreshStatus.success ||
          state.refreshStatus == ProductRefreshStatus.failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                state.refreshStatus == ProductRefreshStatus.success
                    ? S.of(context).itemUpdatedSnackbar
                    : S.of(context).errorFetchingProductData,
              ),
            ),
          );
      }
    },
    builder: (context, state) {
      final s = S.of(context);
      return ItemInformationScaffold(
        meal: _meal,
        isRefreshing: state.isRefreshing,
        isLoading: state.isLoadingInformation,
        hasLoadingError: state.hasInformationLoadError,
        actions: [
          if ((_meal.source == MealSourceEntity.off || _meal.isCatalogueFood) &&
              (_meal.code?.isNotEmpty ?? false))
            Semantics(
              identifier: 'meal-detail-refresh',
              child: IconButton(
                tooltip: s.refreshProductLabel,
                onPressed: state.isRefreshing
                    ? null
                    : () => _bloc.add(RefreshMealEvent(_meal)),
                icon: state.isRefreshing
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          Semantics(
            identifier: 'meal-detail-edit',
            child: IconButton(
              tooltip: s.editMealLabel,
              onPressed: _edit,
              icon: const Icon(Icons.edit_rounded),
            ),
          ),
        ],

        onLog: _openingAmount ? null : _logFood,
        logIdentifier: 'meal-detail-log-food',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoodNutritionInformation(meal: _meal, day: _args.day, bloc: _bloc),
            MealInfoButton(meal: _meal, onCustom: _edit),
          ],
        ),
      );
    },
  );
}

class MealDetailScreenArguments {
  final MealEntity mealEntity;
  final IntakeTypeEntity intakeTypeEntity;
  final DateTime day;
  final bool usesImperialUnits;
  final Future<bool> Function(MealEntity, FoodAmountSelection)? onConfirm;
  final bool returnAfterAdding;
  MealDetailScreenArguments(
    this.mealEntity,
    this.intakeTypeEntity,
    this.day,
    this.usesImperialUnits, {
    this.onConfirm,
    this.returnAfterAdding = false,
  });
}
