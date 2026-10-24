import 'package:opennutritracker/core/presentation/widgets/share_qr_dialog.dart';
import 'package:opennutritracker/features/recipes/domain/entity/shared_recipe_payload.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/delete_recipe_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/food_information.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/presentation/widgets/item_information_scaffold.dart';
import 'package:opennutritracker/core/presentation/widgets/user_image_picker_tile.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_search_controller.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/food_search_view.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/food_nutrition_information.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/recipe_ingredients_section.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/recipe_weight_editor.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecipeBuilderArguments {
  final RecipeEntity? existing;
  const RecipeBuilderArguments({this.existing});
}

class RecipeBuilderScreen extends StatefulWidget {
  final RecipeEntity? existing;
  final bool live;
  final MealDetailScreenArguments? loggingArguments;
  const RecipeBuilderScreen({
    super.key,
    this.existing,
    this.live = false,
    this.loggingArguments,
  });

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  late RecipeBuilderBloc _bloc;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _servingsController;
  late TextEditingController _tagsController;

  bool _initialized = false;
  int _tab = 0;
  Timer? _saveTimer;
  bool _leaving = false;
  bool _allowPop = false;
  bool _logging = false;
  RecipeEntity? _existing;

  @override
  void initState() {
    super.initState();
    _bloc = locator<RecipeBuilderBloc>();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _servingsController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      _existing =
          widget.existing ??
          (routeArgs is RecipeBuilderArguments ? routeArgs.existing : null);
      _bloc.add(InitializeBuilderEvent(existing: _existing));
      if (_existing != null) {
        final r = _existing!;
        _nameController.text = r.name;
        _descriptionController.text = r.description ?? '';
        _servingsController.text = r.servingsCount?.toString() ?? '';
        _tagsController.text = r.tags.join(', ');
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    _bloc.close();
    super.dispose();
  }

  InputBorder _fieldBorder(AppPalette palette) {
    return OutlineInputBorder(
      borderRadius: Dimens.borderRadiusS,
      borderSide: BorderSide(color: palette.border, width: Dimens.hairline),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final fieldBorder = _fieldBorder(palette);
    return BlocConsumer<RecipeBuilderBloc, RecipeBuilderState>(
      bloc: _bloc,
      listener: (context, state) {
        if (widget.live) {
          final previous = _lastDraft;
          final current = _draft(state);
          _lastDraft = current;
          if (previous != null && previous != current) {
            _saveTimer?.cancel();
            _saveTimer = Timer(
              const Duration(milliseconds: 400),
              () => _saveLive(),
            );
          }
        }
        if (state.didSave && !widget.live) {
          Navigator.of(context).pop();
          return;
        }
        if (state.saveError != null) {
          _showSaveError(context, state.saveError!);
        }
      },
      builder: (context, state) {
        if (widget.live) return _buildLive(context, state, fieldBorder);
        return PopScope(
          canPop: !_hasUnsavedChanges(state),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldDiscard = await _confirmDiscard(context);
            if (shouldDiscard == true && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: MediaQuery.textScalerOf(
                context,
              ).scale(kToolbarHeight),
              title: Text(
                state.isExistingRecipe
                    ? S.of(context).editRecipeTitle
                    : S.of(context).createRecipeTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (state.isSaving)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  Semantics(
                    identifier: 'recipe-builder-save',
                    child: TextButton.icon(
                      onPressed: () => _bloc.add(const SaveRecipeEvent()),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(S.of(context).recipeSaveLabel),
                    ),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacing16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _overview(context, state, fieldBorder),
                  ),
                ),
                _ingredients(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  RecipeEntity? _lastDraft;

  RecipeEntity _draft(RecipeBuilderState state) => RecipeEntity(
    id: state.id ?? '',
    name: state.name,
    description: state.description,
    ingredients: state.ingredients,
    totalWeightG: state.totalWeightG ?? 0,
    cookedWeightG: state.cookedWeightG,
    aggregatedNutrimentsPer100:
        state.aggregatedNutrimentsPer100 ?? MealNutrimentsEntity.empty(),
    createdAt: _existing?.createdAt ?? DateTime(2000),
    updatedAt: _existing?.updatedAt ?? DateTime(2000),
    servingsCount: state.servingsCount,
    tags: state.tags,
    imagePath: state.imagePath,
  );

  Future<bool> _saveLive() {
    _saveTimer?.cancel();
    final completed = Completer<bool>();
    _bloc.add(
      SaveRecipeEvent(closeAfterSave: false, onCompleted: completed.complete),
    );
    return completed.future;
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final saved = await _saveLive();
    if (saved && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _leaving = false;
    }
  }

  List<Widget> _overview(
    BuildContext context,
    RecipeBuilderState state,
    InputBorder fieldBorder,
  ) => [
    UserImagePickerTile(
      kind: UserImageKind.recipe,
      imagePath: state.imagePath,
      onPickFromGallery: () =>
          _onPickImage(context, source: ImageSource.gallery),
      onTakePhoto: () => _onPickImage(context, source: ImageSource.camera),
      onRemove: () => _onRemoveImage(context),
    ),
    const SizedBox(height: Dimens.spacing16),
    Semantics(
      identifier: 'recipe-name',
      child: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: S.of(context).recipeNameLabel,
          errorText: state.saveError == SaveError.nameRequired
              ? S.of(context).recipeNameRequiredLabel
              : null,
          border: fieldBorder,
          enabledBorder: fieldBorder,
        ),
        onChanged: (v) => _bloc.add(UpdateNameEvent(v)),
      ),
    ),
    const SizedBox(height: Dimens.spacing12),
    Semantics(
      identifier: 'recipe-description',
      child: TextField(
        controller: _descriptionController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: S.of(context).recipeDescriptionLabel,
          border: fieldBorder,
          enabledBorder: fieldBorder,
        ),
        onChanged: (v) => _bloc.add(UpdateDescriptionEvent(v)),
      ),
    ),
    const SizedBox(height: Dimens.spacing12),
    Semantics(
      identifier: 'recipe-servings',
      child: TextField(
        controller: _servingsController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: S.of(context).recipeServingsCountLabel,
          helperText: S.of(context).recipeServingsCountHelper,
          helperMaxLines: 2,
          border: fieldBorder,
          enabledBorder: fieldBorder,
        ),
        onChanged: (v) {
          final parsed = v.trim().isEmpty ? null : int.tryParse(v);
          _bloc.add(UpdateServingsCountEvent(parsed));
        },
      ),
    ),
    const SizedBox(height: Dimens.spacing12),
    Semantics(
      identifier: 'recipe-tags',
      child: TextField(
        controller: _tagsController,
        decoration: InputDecoration(
          labelText: S.of(context).recipeTagsLabel,
          helperText: S.of(context).recipeTagsHelper,
          helperMaxLines: 2,
          border: fieldBorder,
          enabledBorder: fieldBorder,
        ),
        onChanged: (v) {
          final parsed = v
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          _bloc.add(UpdateTagsEvent(parsed));
        },
      ),
    ),
    const SizedBox(height: Dimens.spacing24),
    RecipeWeightEditor(
      mode: state.weightMode,
      fieldBorder: fieldBorder,
      showError: state.saveError == SaveError.invalidTotalWeight,
      totalWeightG: state.totalWeightG,
      cookedWeightG: state.cookedWeightG,
      onModeChanged: (mode) => _bloc.add(UpdateWeightModeEvent(mode)),
      onCookedWeightChanged: (weight) =>
          _bloc.add(UpdateCookedWeightEvent(weight)),
    ),
    const SizedBox(height: Dimens.spacing24),
  ];

  Widget _ingredients(BuildContext context, RecipeBuilderState state) =>
      RecipeIngredientsSection(
        ingredients: state.ingredients,
        onAdd: () => _onAddIngredient(context),
        onScan: () => _scanIngredient(),
        onQuickAdd: () => _quickAddIngredient(),
        onExplode: (index, recipe) =>
            _bloc.add(ExplodeIngredientEvent(index: index, recipe: recipe)),
        onEdit: (index) => _onEditIngredient(context, index),
        onRemove: (index) => _bloc.add(RemoveIngredientEvent(index)),
        onIngredientChanged: (index, food, quantity) => _bloc.add(
          UpdateIngredientEvent(index: index, meal: food, quantity: quantity),
        ),
        onCopy: (index) {
          final ingredient = state.ingredients[index];
          _bloc.add(
            AddIngredientEvent(
              meal: ingredient.snapshotMeal,
              quantity: ingredient.quantity,
            ),
          );
        },
      );

  Widget _buildLive(
    BuildContext context,
    RecipeBuilderState state,
    InputBorder fieldBorder,
  ) {
    final recipe = _draft(state);
    final s = S.of(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ItemInformationScaffold(
        meal: recipe.toMealEntity(),
        contentPadding: EdgeInsets.zero,
        actions: [
          Semantics(
            identifier: 'recipe-share',
            child: IconButton(
              tooltip: s.shareRecipeLabel,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ShareQrDialog(
                  title: s.shareRecipeLabel,
                  code: SharedRecipePayload.fromRecipe(recipe).toJsonString(),
                  fileBaseName: 'recipe_qr',
                ),
              ),
            ),
          ),
          Semantics(
            identifier: 'recipe-copy',
            child: IconButton(
              tooltip: s.duplicateRecipeLabel,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                if (!await _saveLive() || !context.mounted) return;
                await Navigator.of(context).pushNamed(
                  NavigationOptions.recipeBuilderRoute,
                  arguments: RecipeBuilderArguments(
                    existing: recipe.copyWith(
                      id: '',
                      name: '${recipe.name} ${s.duplicateRecipeNameSuffix}',
                      clearImagePath: true,
                    ),
                  ),
                );
              },
            ),
          ),
          Semantics(
            identifier: 'recipe-delete',
            child: IconButton(
              tooltip: s.dialogDeleteLabel,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(context),
            ),
          ),
        ],
        onLog:
            _logging ||
                state.isSaving ||
                state.ingredients.isEmpty ||
                !state.hasValidWeight ||
                state.name.trim().isEmpty
            ? null
            : () => _logRecipe(recipe),
        logIdentifier: 'recipe-log-item',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                identifier: 'recipe-detail-tabs',
                child: LayoutBuilder(
                  builder: (context, constraints) => SegmentedButton<int>(
                    direction:
                        constraints.maxWidth <
                            MediaQuery.textScalerOf(context).scale(320)
                        ? Axis.vertical
                        : Axis.horizontal,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Text(s.recipeNutritionTabLabel),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(s.recipeIngredientsLabel),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text(s.recipeDetailsTabLabel),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) =>
                        setState(() => _tab = selection.single),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.isSaving) const LinearProgressIndicator(minHeight: 2),
            Visibility(
              visible: _tab == 0,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FoodNutritionInformation(
                  meal: recipe.toMealEntity(),
                  day:
                      widget.loggingArguments?.day ??
                      locator<SelectedDayCubit>().state.day,
                ),
              ),
            ),
            Visibility(
              visible: _tab == 1,
              maintainState: true,
              child: _ingredients(context, state),
            ),
            Visibility(
              visible: _tab == 2,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _overview(context, state, fieldBorder),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logRecipe(RecipeEntity recipe) async {
    if (_logging) return;
    setState(() => _logging = true);
    try {
      if (!await _saveLive() || !mounted) return;
      final args = widget.loggingArguments;
      final type = args?.intakeTypeEntity ?? await _pickIntakeType(context);
      if (type == null || !mounted) return;
      final meal = _draft(_bloc.state).toMealEntity();
      final saved = args?.onConfirm != null
          ? await showFoodAmountSheet(
              context,
              meal: meal,
              onConfirm: args!.onConfirm!,
            )
          : await logFoodAmount(
              context,
              meal: meal,
              day: args?.day ?? locator<SelectedDayCubit>().state.day,
              type: type,
            );
      if (saved && mounted && args != null) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (args.returnAfterAdding) {
            Navigator.of(context).pop(true);
          } else {
            Navigator.of(context).popUntil(
              (route) =>
                  route.isFirst ||
                  route.settings.name == NavigationOptions.mainRoute,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).recipeDeleteConfirmTitle),
        content: Text(S.of(context).recipeDeleteConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(context).dialogCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.of(context).dialogDeleteLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _saveTimer?.cancel();
      // Drain an in-flight save before deleting so it cannot recreate the recipe.
      await _saveLive();
      _saveTimer?.cancel();
      await locator<DeleteRecipeUseCase>().delete(_bloc.state.id!);
      if (mounted) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  Future<IntakeTypeEntity?> _pickIntakeType(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return showModalBottomSheet<IntakeTypeEntity>(
      context: context,
      builder: (ctx) {
        Widget tile(IntakeTypeEntity type, String label) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Semantics(
            identifier: 'recipe-log-${type.name}',
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: Dimens.borderRadiusS,
                ),
                child: Icon(type.getIconData(), color: accent, size: 22),
              ),
              title: Text(
                label,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(type),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Dimens.spacing12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: Dimens.spacing8),
              tile(IntakeTypeEntity.breakfast, s.breakfastLabel),
              tile(IntakeTypeEntity.lunch, s.lunchLabel),
              tile(IntakeTypeEntity.dinner, s.dinnerLabel),
              tile(IntakeTypeEntity.snack, s.snackLabel),
            ],
          ),
        );
      },
    );
  }

  bool _hasUnsavedChanges(RecipeBuilderState state) {
    if (state.didSave || state.isSaving) return false;
    return state.weightMode == RecipeWeightMode.custom ||
        state.name.trim().isNotEmpty ||
        (state.description?.trim().isNotEmpty ?? false) ||
        state.ingredients.isNotEmpty ||
        state.servingsCount != null ||
        state.tags.isNotEmpty ||
        state.imagePath != null;
  }

  Future<bool?> _confirmDiscard(BuildContext context) {
    final s = S.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.discardChangesTitle),
        content: Text(s.discardChangesContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.dialogCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.discardChangesConfirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _scanIngredient() async {
    final selected = await Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments.pick(),
    );
    if (selected is MealEntity && mounted) {
      await showFoodAmountSheet(
        context,
        meal: selected,
        onConfirm: _addIngredientAmount,
      );
    }
  }

  Future<void> _quickAddIngredient() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => QuickAddBottomSheet(
      intakeType: IntakeTypeEntity.snack,
      day: DateTime.now(),
      onConfirm: _addIngredientAmount,
    ),
  );

  Future<void> _onAddIngredient(BuildContext context) async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!context.mounted) return;
    final search = FoodSearchController(locator<FoodSearchEngine>());
    try {
      while (true) {
        if (!context.mounted) return;
        final selected = await Navigator.of(context).push<MealEntity>(
          MaterialPageRoute(
            builder: (searchContext) => Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).recipeAddIngredientLabel),
              ),
              body: FoodSearchView(
                controller: search,
                itemBuilder: (_, meal) => MealItemCard(
                  mealEntity: meal,
                  onInfo: () async {
                    final saved = await showFoodInformation(
                      searchContext,
                      meal: meal,
                      day: DateTime.now(),
                      type: IntakeTypeEntity.snack,
                      imperial: config.usesImperialFoodUnits,
                      onConfirm: _addIngredientAmount,
                    );
                    if (saved && searchContext.mounted) {
                      Navigator.of(searchContext).pop();
                    }
                  },
                  onSelected: (food) => Navigator.of(searchContext).pop(food),
                ),
                onBarcodePressed: (barcode) async {
                  final scanned = await Navigator.of(searchContext).pushNamed(
                    NavigationOptions.scannerRoute,
                    arguments: ScannerScreenArguments.pick(
                      initialBarcode: barcode,
                    ),
                  );
                  if (scanned is MealEntity && searchContext.mounted) {
                    Navigator.of(searchContext).pop(scanned);
                  }
                },
              ),
            ),
          ),
        );
        if (selected == null || !context.mounted) return;
        final saved = await showFoodAmountSheet(
          context,
          meal: selected,
          onConfirm: _addIngredientAmount,
        );
        if (saved) return;
      }
    } finally {
      await search.close();
    }
  }

  Future<bool> _addIngredientAmount(
    MealEntity food,
    FoodAmountSelection selection,
  ) async {
    _bloc.add(AddIngredientEvent(meal: food, quantity: selection));
    return true;
  }

  Future<void> _onEditIngredient(BuildContext context, int index) async {
    final ingredient = _bloc.state.ingredients[index];
    await showFoodAmountSheet(
      context,
      meal: ingredient.snapshotMeal,
      editing: true,
      hydrate: false,
      initial: ingredient.quantity,
      onConfirm: (food, selection) async {
        _bloc.add(
          UpdateIngredientEvent(index: index, meal: food, quantity: selection),
        );
        return true;
      },
    );
  }

  Future<void> _onPickImage(
    BuildContext context, {
    required ImageSource source,
  }) async {
    final recipeId = _bloc.state.id;
    if (recipeId == null) return;
    try {
      final picker = ImagePicker();
      // Pick at full resolution — `UserImageStorage.importFrom` re-encodes
      // to WebP at quality 80, bounding the shortest edge at 1024px, so we
      // don't need image_picker's own JPEG compression on top. Doing it in one
      // place keeps the on-disk footprint consistent regardless of which
      // source (camera / gallery) the photo came from.
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;
      final relative = await UserImageStorage.importFrom(
        kind: UserImageKind.recipe,
        ownerId: recipeId,
        sourcePath: picked.path,
      );
      // Bust the in-memory Image.file cache so the new picture shows up
      // immediately instead of redrawing the previous bytes for this path.
      FileImage(File(await UserImageStorage.absolutePath(relative))).evict();
      _bloc.add(UpdateImagePathEvent(relative));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).recipeSaveErrorLabel)),
      );
    }
  }

  Future<void> _onRemoveImage(BuildContext context) async {
    final current = _bloc.state.imagePath;
    if (current == null) return;
    await UserImageStorage.delete(current);
    _bloc.add(const UpdateImagePathEvent(null));
  }

  void _showSaveError(BuildContext context, SaveError error) {
    final s = S.of(context);
    final message = switch (error) {
      SaveError.nameRequired => s.recipeNameRequiredLabel,
      SaveError.needsIngredients => s.recipeNeedsIngredientsLabel,
      SaveError.invalidTotalWeight => s.recipeInvalidTotalWeightLabel,
      SaveError.unknown => s.recipeSaveErrorLabel,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
