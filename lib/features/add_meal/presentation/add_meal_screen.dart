import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/diary_search_cubit.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/screens/bulk_add_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/default_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_search_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/features/scanner/util/barcode_check_digit.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final ValueNotifier<String> _searchStringListener = ValueNotifier('');

  late AddMealType _mealType;
  late DateTime _day;

  late AddMealBloc _addMealBloc;
  late DiarySearchCubit _search;
  HiveDBProvider? _profiles;
  FoodSearchFilter _source = FoodSearchFilter.all;

  @override
  void initState() {
    _addMealBloc = locator<AddMealBloc>()..add(InitializeAddMealEvent());
    _search = DiarySearchCubit(locator<FoodSearchEngine>());
    if (locator.isRegistered<HiveDBProvider>()) {
      _profiles = locator<HiveDBProvider>()..addListener(_onContextChanged);
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _searchStringListener.dispose();
    _addMealBloc.close();
    _profiles?.removeListener(_onContextChanged);
    _search.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return Scaffold(
      // Let the keyboard overlay the results rather than compress the body.
      // In landscape the space above the keyboard is shorter than the pinned
      // search bar + tab bar, which otherwise overflows (issue #165 testing).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_mealType.getTypeName(context)),
        actions: [
          Semantics(
            identifier: 'add-meal-quick-add',
            child: TextButton(
              onPressed: _onQuickAddPressed,
              child: Text(S.of(context).quickAddCardLabel),
            ),
          ),
          BlocBuilder<AddMealBloc, AddMealState>(
            bloc: _addMealBloc,
            builder: (BuildContext context, AddMealState state) {
              if (state is AddMealLoadedState) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      identifier: 'add-meal-bulk-add',
                      child: IconButton(
                        onPressed: () =>
                            _onBulkAddPressed(state.usesImperialUnits),
                        icon: const Icon(Icons.playlist_add),
                        tooltip: S.of(context).bulkAddTitle,
                      ),
                    ),
                    Semantics(
                      identifier: 'add-meal-custom-add',
                      child: IconButton(
                        onPressed: () =>
                            _onCustomAddButtonPressed(state.usesImperialUnits),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing16),
          child: Column(
            children: [
              const SizedBox(height: Dimens.spacing8),
              MealSearchBar(
                searchStringListener: _searchStringListener,
                onSearchSubmit: _onSearchSubmit,
                onSearchChanged: _onSearchChanged,
                onBarcodePressed: _onBarcodeIconPressed,
                showSubmitButton: false,
              ),
              const SizedBox(height: Dimens.spacing12),
              _buildSourceChips(context, palette),
              const SizedBox(height: Dimens.spacing12),
              Expanded(
                child: BlocBuilder<AddMealBloc, AddMealState>(
                  bloc: _addMealBloc,
                  builder: (context, _) => _buildResults(context, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onContextChanged() => _search.resetContext();

  void _onSearchSubmit(String inputText) {
    FocusManager.instance.primaryFocus?.unfocus();
    final trimmed = inputText.trim();
    if ((_source == FoodSearchFilter.all ||
            _source == FoodSearchFilter.products) &&
        isValidBarcodeCheckDigit(trimmed)) {
      _search.search('', _source);
      Navigator.of(context).pushNamed(
        NavigationOptions.scannerRoute,
        arguments: ScannerScreenArguments(
          _day,
          _mealType.getIntakeType(),
          initialBarcode: trimmed,
        ),
      );
      return;
    }
    _search.search(inputText, _source, submit: true);
  }

  void _onSearchChanged(String inputText) => _search.search(inputText, _source);
  void _selectSource(FoodSearchFilter source) {
    setState(() => _source = source);
    _search.search(_searchStringListener.value, source);
  }

  Widget _buildSourceChips(BuildContext context, AppPalette palette) {
    Widget chip(FoodSearchFilter source, String label) => Padding(
      padding: const EdgeInsets.only(right: Dimens.spacing8),
      child: Semantics(
        identifier: 'diary-search-${source.name}',
        child: ChoiceChip(
          label: Text(label),
          selected: _source == source,
          showCheckmark: false,
          onSelected: (_) => _selectSource(source),
        ),
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(FoodSearchFilter.all, S.of(context).allItemsLabel),
            chip(FoodSearchFilter.recent, S.of(context).recentlyAddedLabel),
            chip(FoodSearchFilter.products, S.of(context).searchProductsPage),
            chip(FoodSearchFilter.food, S.of(context).searchFoodPage),
          ],
        ),
      ),
    );
  }

  Widget _resultsHeader(BuildContext context, AppPalette palette) => Container(
    padding: const EdgeInsets.symmetric(vertical: Dimens.spacing4),
    alignment: Alignment.centerLeft,
    child: Text(
      S.of(context).searchResultsLabel,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.textMuted,
      ),
    ),
  );

  bool get _usesImperial =>
      _addMealBloc.state is AddMealLoadedState &&
      (_addMealBloc.state as AddMealLoadedState).usesImperialUnits;

  Widget _buildResults(
    BuildContext context,
    AppPalette palette,
  ) => BlocBuilder<DiarySearchCubit, FoodSearchSnapshot>(
    bloc: _search,
    builder: (context, state) {
      final idle =
          state.request.filter != FoodSearchFilter.recent &&
          foodSearchMatch(state.request.query) == null;
      return Column(
        children: [
          _resultsHeader(context, palette),
          if (state.pending.isNotEmpty)
            Semantics(
              identifier: 'diary-search-pending',
              child: const LinearProgressIndicator(),
            ),
          Expanded(
            child: idle
                ? const DefaultsResultsWidget()
                : state.meals.isEmpty
                ? (state.pending.isNotEmpty
                      ? const SizedBox()
                      : state.failures.isNotEmpty
                      ? const SizedBox()
                      : state.request.filter == FoodSearchFilter.recent &&
                            state.request.query.trim().isEmpty
                      ? EmptyHint(
                          icon: Icons.history_rounded,
                          title: S.of(context).noMealsRecentlyAddedLabel,
                        )
                      : NoResultsWidget(
                          onScanBarcode: _onBarcodeIconPressed,
                          onCreateCustomFood: () =>
                              _onCustomAddButtonPressed(_usesImperial),
                        ))
                : Semantics(
                    identifier: state.request.filter == FoodSearchFilter.food
                        ? 'diary-food-results'
                        : 'diary-search-results',
                    label: S.of(context).searchResultsLabel,
                    child: ListView.builder(
                      key: ValueKey(
                        '${state.request.filter.name}:${state.request.query}',
                      ),
                      itemCount: state.meals.length,
                      findChildIndexCallback: (key) {
                        final index = state.meals.indexWhere(
                          (meal) => ValueKey(foodIdentity(meal)) == key,
                        );
                        return index < 0 ? null : index;
                      },
                      itemBuilder: (context, index) => MealItemCard(
                        key: ValueKey(foodIdentity(state.meals[index])),
                        day: _day,
                        mealEntity: state.meals[index],
                        addMealType: _mealType,
                        usesImperialUnits: _usesImperial,
                      ),
                    ),
                  ),
          ),
          if (state.failures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacing8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.failures.containsKey(FoodSearchSource.online) ? OFFConst.offSourceName : S.of(context).searchResultsLabel}: ${S.of(context).errorFetchingProductData}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    identifier: 'diary-search-retry',
                    child: TextButton(
                      onPressed: _search.retry,
                      child: Text(S.of(context).retryLabel),
                    ),
                  ),
                ],
              ),
            ),
          if (state.hasMore &&
              !state.failures.containsKey(FoodSearchSource.online))
            Semantics(
              identifier: 'diary-search-load-more',
              child: TextButton(
                onPressed: state.pending.contains(FoodSearchSource.online)
                    ? null
                    : _search.loadMore,
                child: Text(S.of(context).loadMoreLabel),
              ),
            ),
        ],
      );
    },
  );

  void _onBarcodeIconPressed() {
    Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments(_day, _mealType.getIntakeType()),
    );
  }

  void _onBulkAddPressed(bool usesImperialUnits) {
    Navigator.of(context).pushNamed(
      NavigationOptions.bulkAddRoute,
      arguments: BulkAddScreenArguments(
        _mealType.getIntakeType(),
        _day,
        usesImperialUnits,
      ),
    );
  }

  void _onQuickAddPressed() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          QuickAddBottomSheet(intakeType: _mealType.getIntakeType(), day: _day),
    );
  }

  void _onCustomAddButtonPressed(bool usesImperialUnits) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).createCustomDialogTitle),
          content: Text(S.of(context).createCustomDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // close dialog
              child: Text(S.of(context).dialogCancelLabel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _openEditMealScreen(usesImperialUnits);
              },
              child: Text(S.of(context).buttonYesLabel),
            ),
          ],
        );
      },
    );
  }

  void _openEditMealScreen(bool usesImperialUnits) {
    Navigator.of(context).pushNamed(
      NavigationOptions.editMealRoute,
      arguments: EditMealScreenArguments(
        _day,
        MealEntity.empty(),
        _mealType.getIntakeType(),
        usesImperialUnits,
      ),
    );
  }
}

class AddMealScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  AddMealScreenArguments(this.mealType, this.day);
}
