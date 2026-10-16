import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/default_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_search_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/scanner/util/barcode_check_digit.dart';
import 'package:opennutritracker/generated/l10n.dart';

import 'package:opennutritracker/features/add_meal/presentation/bloc/food_search_controller.dart';

class FoodSearchView extends StatefulWidget {
  final FoodSearchController? controller;
  final Widget Function(BuildContext, MealEntity) itemBuilder;
  final void Function(String?)? onBarcodePressed;
  final VoidCallback? onCreateCustomFood;
  const FoodSearchView({
    super.key,
    this.controller,
    required this.itemBuilder,
    this.onBarcodePressed,
    this.onCreateCustomFood,
  });
  @override
  State<FoodSearchView> createState() => _FoodSearchViewState();
}

class _FoodSearchViewState extends State<FoodSearchView> {
  late final FoodSearchController _search;
  HiveDBProvider? _profiles;
  ValueNotifier<String> get _searchStringListener => _search.query;
  FoodSearchFilter get _source => _search.state.request.filter;
  @override
  void initState() {
    super.initState();
    _search =
        widget.controller ?? FoodSearchController(locator<FoodSearchEngine>());
    if (locator.isRegistered<HiveDBProvider>()) {
      _profiles = locator<HiveDBProvider>()..addListener(_onContextChanged);
    }
  }

  void _onContextChanged() => _search.resetContext();
  @override
  void dispose() {
    _profiles?.removeListener(_onContextChanged);
    if (widget.controller == null) _search.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return BlocBuilder<FoodSearchController, FoodSearchSnapshot>(
      bloc: _search,
      builder: (context, state) => SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: Dimens.spacing8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing16),
              child: MealSearchBar(
                searchStringListener: _searchStringListener,
                onSearchSubmit: _onSearchSubmit,
                onSearchChanged: _onSearchChanged,
                onBarcodePressed: widget.onBarcodePressed == null
                    ? null
                    : () => widget.onBarcodePressed!(null),
                showSubmitButton: false,
                showClearButton: true,
              ),
            ),
            const SizedBox(height: Dimens.spacing12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing16),
              child: _buildSourceChips(context, palette),
            ),
            const SizedBox(height: Dimens.spacing12),
            Expanded(
              child: SwipeRevealScope(child: _buildResults(context, palette)),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchSubmit(String inputText) {
    FocusManager.instance.primaryFocus?.unfocus();
    final trimmed = inputText.trim();
    if ((_source == FoodSearchFilter.all ||
            _source == FoodSearchFilter.products) &&
        isValidBarcodeCheckDigit(trimmed)) {
      widget.onBarcodePressed?.call(trimmed);
      return;
    }
    _search.search(inputText, _source, submit: true);
  }

  void _onSearchChanged(String inputText) => _search.search(inputText, _source);
  void _selectSource(FoodSearchFilter source) {
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
            chip(FoodSearchFilter.recipes, S.of(context).recipesLabel),
          ],
        ),
      ),
    );
  }

  Widget _resultsHeader(BuildContext context, AppPalette palette) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Dimens.spacing16,
      vertical: Dimens.spacing4,
    ),
    alignment: Alignment.centerLeft,
    child: Text(
      S.of(context).searchResultsLabel,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.textMuted,
      ),
    ),
  );

  Widget _buildResults(
    BuildContext context,
    AppPalette palette,
  ) => BlocBuilder<FoodSearchController, FoodSearchSnapshot>(
    bloc: _search,
    builder: (context, state) {
      final recipesOnly = state.request.filter == FoodSearchFilter.recipes;
      final hasQuery = foodSearchMatch(state.request.query) != null;
      final idle =
          state.request.filter != FoodSearchFilter.recent &&
          !recipesOnly &&
          !hasQuery;
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
                      : recipesOnly && !hasQuery
                      ? EmptyHint(
                          icon: Icons.menu_book_rounded,
                          title: S.of(context).recipesEmptyLabel,
                        )
                      : NoResultsWidget(
                          onScanBarcode: recipesOnly
                              ? null
                              : () => widget.onBarcodePressed?.call(null),
                          onCreateCustomFood: recipesOnly
                              ? null
                              : widget.onCreateCustomFood,
                        ))
                : Semantics(
                    identifier: switch (state.request.filter) {
                      FoodSearchFilter.food => 'diary-food-results',
                      FoodSearchFilter.recipes => 'diary-recipes-results',
                      _ => 'diary-search-results',
                    },
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
                      itemBuilder: (context, index) =>
                          widget.itemBuilder(context, state.meals[index]),
                      controller: _search.scroll,
                    ),
                  ),
          ),
          if (state.failures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.spacing16,
                vertical: Dimens.spacing8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      recipesOnly
                          ? S.of(context).recipesLoadErrorLabel
                          : '${state.failures.containsKey(FoodSearchSource.online) ? OFFConst.offSourceName : S.of(context).searchResultsLabel}: ${S.of(context).errorFetchingProductData}',
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
}
