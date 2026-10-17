import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_recipe_by_id_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/demo/unsplash_attribution.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_macro_nutrients.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key});
  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late final MealDetailBloc _bloc;
  late MealDetailScreenArguments _args;
  late MealEntity _meal;
  bool _initialized = false, _openingAmount = false;
  bool _reference = false, _basisChosen = false;
  FoodAmountSelection? _selection;
  FoodAmountOption? get _serving => foodAmountOptions(
    _meal,
  ).where((option) => option.unit == 'serving').firstOrNull;

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
    _reference = _serving == null;
    _bloc.add(HydrateMealEvent(_meal));
    _bloc.add(LoadDailyTotalsEvent(_args.day));
    _updatePreview();
  }

  void _updatePreview() {
    final serving = _serving;
    final selection = !_reference && serving != null
        ? FoodAmountSelection(1, serving)
        : defaultFoodAmount(_meal);
    _selection = selection;
    _bloc.add(UpdateKcalEvent(meal: _meal, selection: selection));
  }

  void _replaceMeal(MealEntity meal) {
    if (!mounted) return;
    setState(() {
      _meal = meal;
      if (!_basisChosen || _serving == null) _reference = _serving == null;
    });
    _updatePreview();
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

  Future<void> _openRecipe() async {
    final recipes = locator<GetRecipeByIdUseCase>();
    final id = _meal.code ?? '';
    if (recipes.getById(id) == null) {
      _recipeUnavailable();
      return;
    }
    await Navigator.of(context).pushNamed(
      NavigationOptions.recipeDetailRoute,
      arguments: RecipeDetailArguments(recipeId: id),
    );
    if (!mounted) return;
    final updated = recipes.getById(id);
    if (updated == null) {
      _recipeUnavailable();
    } else {
      _replaceMeal(updated.toMealEntity());
    }
  }

  void _recipeUnavailable() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(S.of(context).diaryRecipeUnavailableMessage)),
  );

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
      final palette = Theme.of(context).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
      final s = S.of(context);
      final n = _meal.nutriments;
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(
          backgroundColor: palette.surface,
          leading: Semantics(
            identifier: 'meal-detail-back',
            child: BackButton(),
          ),
          actions: [
            if ((_meal.source == MealSourceEntity.off ||
                    _meal.isCatalogueFood) &&
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
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  key: const ValueKey('meal-detail-header'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: ImageFullScreen.fullScreenHeroTag,
                      child: FoodImage(
                        meal: _meal,
                        width: 64,
                        height: 64,
                        borderRadius: BorderRadius.circular(14),
                        isRefreshing: state.isRefreshing,
                        refreshIdentifier: 'meal-detail-image-refresh',
                        refreshLabel: s.refreshProductLabel,
                        tapLabel: s.foodImageEnlargeLabel,
                        onTap: () => Navigator.of(context).pushNamed(
                          NavigationOptions.imageFullScreenRoute,
                          arguments: ImageFullScreenArguments(_meal),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            _meal.name ?? '',
                            maxLines: 2,
                            minFontSize: 16,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (_meal.brands?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              _meal.brands!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: palette.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                UnsplashCreditLine(imageUrl: _meal.mainImageUrl),
                const SizedBox(height: 16),
                if (_serving == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      s.servingWeightUnavailableLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Semantics(
                  identifier: 'meal-detail-nutrition-basis',
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        enabled: _serving != null,
                        label: Text(
                          _serving == null
                              ? s.oneServingLabel
                              : s.oneServingWeightLabel(
                                  '${formatFoodAmount(_serving!.factor)} ${_serving!.baseUnit}',
                                ),
                        ),
                      ),
                      ButtonSegment(value: true, label: Text(s.per100gmlLabel)),
                    ],
                    selected: {_reference},
                    onSelectionChanged: (value) => setState(() {
                      _basisChosen = true;
                      _reference = value.single;
                      _updatePreview();
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  key: const ValueKey('meal-detail-macro-summary'),
                  color: palette.surfaceMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth /
                                  MediaQuery.textScalerOf(context).scale(1) >=
                              280
                          ? 4
                          : 2;
                      final summaries = [
                        MealDetailMacroNutrients(
                          typeString: s.energyLabel,
                          value: n.energyKcal100 == null
                              ? null
                              : state.totalKcal,
                          goal: state.dayKcalGoal,
                          color: palette.textStrong,
                          amountLabel: EnergyDisplay.formatWithUnit(
                            context,
                            state.totalKcal,
                          ),
                        ),
                        MealDetailMacroNutrients(
                          typeString: s.carbsLabel,
                          value: n.carbohydrates100 == null
                              ? null
                              : state.totalCarbs,
                          goal: state.dayCarbsGoal,
                          color: palette.carbs,
                        ),
                        MealDetailMacroNutrients(
                          typeString: s.fatLabel,
                          value: n.fat100 == null ? null : state.totalFat,
                          goal: state.dayFatGoal,
                          color: palette.fat,
                        ),
                        MealDetailMacroNutrients(
                          typeString: s.proteinLabel,
                          value: n.proteins100 == null
                              ? null
                              : state.totalProtein,
                          goal: state.dayProteinGoal,
                          color: palette.protein,
                        ),
                      ];
                      return Wrap(
                        runSpacing: 12,
                        children: [
                          for (final summary in summaries)
                            SizedBox(
                              width: constraints.maxWidth / columns,
                              child: summary,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DailyKcalOverview(
                  dayKcalConsumed: state.dayKcalConsumed,
                  dayKcalGoal: state.dayKcalGoal,
                  currentSelectionKcal: n.energyKcal100 == null
                      ? 0
                      : state.totalKcal,
                ),
                const SizedBox(height: 12),
                if (state.isHydrating)
                  const LinearProgressIndicator(minHeight: 2),
                MealDetailNutrimentsTable(
                  product: _meal,
                  baseAmount: _selection?.baseAmount ?? 0,
                  reference: _reference,
                  goals: state.dayNutrientGoals,
                ),
                const SizedBox(height: 12),
                MealInfoButton(
                  meal: _meal,
                  onRecipe: _openRecipe,
                  onCustom: _edit,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Semantics(
              identifier: 'meal-detail-log-food',
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openingAmount ? null : _logFood,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s.logThisFoodLabel),
                ),
              ),
            ),
          ),
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
