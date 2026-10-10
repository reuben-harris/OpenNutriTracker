import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/demo/unsplash_attribution.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_macro_nutrients.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_placeholder.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_title_expanded.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/off_disclaimer.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final log = Logger('ItemDetailScreen');
  late MealDetailBloc _mealDetailBloc;
  final _scrollController = ScrollController();
  late MealEntity meal;
  late DateTime _day;
  late IntakeTypeEntity intakeTypeEntity;
  late bool _usesImperialUnits;
  bool _showMicronutrients = false;
  bool _argumentsRead = false;
  ValueChanged<MealEntity>? _onSelected;

  // Scroll distance from expandedHeight down to the collapsed SliverAppBar
  // (toolbar + bottom bar): 268-124 with the DailyKcalOverview bottom bar,
  // 200-56 without it — always 144 either way, so no need to key it off
  // dayKcalGoal.
  static const double _collapseScrollThreshold = 144.0;
  bool _showAppBarTitle = false;

  @override
  void initState() {
    _mealDetailBloc = locator<MealDetailBloc>();
    _loadDetailPreferences();
    _scrollController.addListener(_handleScroll);
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _mealDetailBloc.close();
    super.dispose();
  }

  void _handleScroll() {
    final show = _scrollController.offset >= _collapseScrollThreshold - 4;
    if (show != _showAppBarTitle) {
      setState(() => _showAppBarTitle = show);
    }
  }

  Future<void> _loadDetailPreferences() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!mounted) return;
    setState(() => _showMicronutrients = config.showMicronutrients);
  }

  @override
  void didChangeDependencies() {
    // `ModalRoute.of` re-runs this whenever a route is pushed over or popped
    // off this screen — the unit dropdown's own menu included — so the
    // arguments are read once. Re-reading `meal` on every pass handed the
    // thin search hit back to the sheet the moment the dropdown opened,
    // after hydration had already swapped in the full record: the serving
    // entry the user then tapped was no longer in the rebuilt list and the
    // button went blank (#1216).
    if (!_argumentsRead) {
      final args =
          ModalRoute.of(context)?.settings.arguments
              as MealDetailScreenArguments;
      meal = args.mealEntity;
      _day = args.day;
      intakeTypeEntity = args.intakeTypeEntity;
      _usesImperialUnits = args.usesImperialUnits;
      _onSelected = args.onSelected;
      _argumentsRead = true;

      // Thin OFF search results get hydrated to the full product record
      // (serving fields + micronutrients) once, in the background; the
      // listener in build() swaps the displayed meal in when it arrives.
      _mealDetailBloc.add(HydrateMealEvent(meal));
    }

    _mealDetailBloc.add(LoadDailyTotalsEvent(_day));

    _setReferenceAmount();

    super.didChangeDependencies();
  }

  void _setReferenceAmount() => _mealDetailBloc.add(
    UpdateKcalEvent(
      meal: meal,
      totalQuantity: '100',
      selectedUnit: meal.isLiquid ? 'ml' : 'g',
    ),
  );

  void _onMealHydrated(MealEntity full) {
    setState(() => meal = full);
    _setReferenceAmount();
  }

  Future<void> _logFood() async {
    if (_onSelected != null) {
      _onSelected!(meal);
      return;
    }
    final saved = await logFoodAmount(
      context,
      meal: meal,
      day: _day,
      type: intakeTypeEntity,
    );
    if (saved && mounted) {
      Navigator.of(context).popUntil(
        (route) =>
            route.isFirst || route.settings.name == NavigationOptions.mainRoute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MealDetailBloc, MealDetailState>(
      bloc: _mealDetailBloc,
      listenWhen: (prev, curr) =>
          curr.mealRevision != prev.mealRevision ||
          curr.refreshStatus != prev.refreshStatus,
      listener: (context, state) {
        if (state.refreshStatus == ProductRefreshStatus.loading) return;
        if (state.refreshStatus != ProductRefreshStatus.failure &&
            state.hydratedMeal != null) {
          _onMealHydrated(state.hydratedMeal!);
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
      child: SafeArea(
        child: Scaffold(
          backgroundColor:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppPalette.dark
                      : AppPalette.light)
                  .canvas,
          body: BlocBuilder<MealDetailBloc, MealDetailState>(
            bloc: _mealDetailBloc,
            builder: (context, state) {
              if (state is MealDetailInitial) {
                return _getLoadedContent(
                  context,
                  state.totalQuantityConverted,
                  state.totalKcal,
                  state.totalCarbs,
                  state.totalFat,
                  state.totalProtein,
                  state.selectedUnit,
                  state.dayKcalConsumed,
                  state.dayKcalGoal,
                  state.isHydrating,
                  state.isRefreshing,
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                identifier: 'meal-detail-log',
                child: FilledButton(
                  onPressed: _logFood,
                  child: Text(S.of(context).logThisFoodLabel),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getLoadedContent(
    BuildContext context,
    String totalQuantity,
    double totalKcal,
    double totalCarbs,
    double totalFat,
    double totalProtein,
    String selectedUnit,
    double dayKcalConsumed,
    double dayKcalGoal,
    bool isHydrating,
    bool isRefreshing,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: palette.surface,
          surfaceTintColor: Colors.transparent,
          expandedHeight: dayKcalGoal > 0 ? 268 : 200,
          // The real toolbar title slot, not FlexibleSpaceBar.title: that
          // widget bottom-anchors itself within the whole flexible-space
          // stack (which includes the `bottom` bar's height), so with the
          // DailyKcalOverview bottom bar present it renders underneath that
          // bar instead of in the visible toolbar row.
          title: AnimatedOpacity(
            opacity: _showAppBarTitle ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              meal.name ?? '',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(dayKcalGoal > 0 ? 68 : 0),
            child: DailyKcalOverview(
              dayKcalConsumed: dayKcalConsumed,
              dayKcalGoal: dayKcalGoal,
              currentSelectionKcal: 0,
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: EdgeInsets.only(bottom: dayKcalGoal > 0 ? 68 : 0),
              child: MealTitleExpanded(
                meal: meal,
                usesImperialUnits: _usesImperialUnits,
              ),
            ),
          ),
          actions: [
            if ((meal.source == MealSourceEntity.off || meal.isCatalogueFood) &&
                (meal.code?.isNotEmpty ?? false))
              Semantics(
                identifier: 'meal-detail-refresh',
                child: IconButton(
                  tooltip: S.of(context).refreshProductLabel,
                  onPressed: isRefreshing
                      ? null
                      : () => _mealDetailBloc.add(RefreshMealEvent(meal)),
                  icon: isRefreshing
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
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    NavigationOptions.editMealRoute,
                    arguments: EditMealScreenArguments(
                      _day,
                      meal,
                      intakeTypeEntity,
                      _usesImperialUnits,
                    ),
                  );
                },
                icon: const Icon(Icons.edit_rounded),
              ),
            ),
          ],
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(80),
                child: GestureDetector(
                  child: Hero(
                    tag: ImageFullScreen.fullScreenHeroTag,
                    child: CachedNetworkImage(
                      width: 250,
                      height: 250,
                      cacheManager: locator<CacheManager>(),
                      imageUrl: meal.mainImageUrl ?? "",
                      fit: BoxFit.cover,
                      placeholder: (context, string) => const MealPlaceholder(),
                      errorWidget: (context, url, error) =>
                          const MealPlaceholder(),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      NavigationOptions.imageFullScreenRoute,
                      arguments: ImageFullScreenArguments(
                        meal.mainImageUrl ?? "",
                      ),
                    );
                  },
                ),
              ),
            ),
            UnsplashCreditLine(imageUrl: meal.mainImageUrl),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        meal.nutriments.energyKcal100 == null
                            ? '—'
                            : EnergyDisplay.formatWithUnit(context, totalKcal),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      MealValueUnitText(
                        value: double.parse(totalQuantity),
                        meal: meal,
                        displayUnit: selectedUnit,
                        usesImperialUnits: _usesImperialUnits,
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        prefix: ' / ',
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimens.spacing16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      MealDetailMacroNutrients(
                        typeString: S.of(context).carbsLabel,
                        value: meal.nutriments.carbohydrates100 == null
                            ? null
                            : totalCarbs,
                        color: palette.carbs,
                      ),
                      MealDetailMacroNutrients(
                        typeString: S.of(context).fatLabel,
                        value: meal.nutriments.fat100 == null ? null : totalFat,
                        color: palette.fat,
                      ),
                      MealDetailMacroNutrients(
                        typeString: S.of(context).proteinLabel,
                        value: meal.nutriments.proteins100 == null
                            ? null
                            : totalProtein,
                        color: palette.protein,
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimens.spacing24),
                  Divider(color: palette.border, height: Dimens.hairline),
                  const SizedBox(height: Dimens.spacing24),
                  if (isHydrating)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  MealDetailNutrimentsTable(
                    product: meal,
                    usesImperialUnits: _usesImperialUnits,
                    servingQuantity: meal.servingQuantity,
                    servingUnit: meal.servingUnit,
                    showMicronutrients: _showMicronutrients,
                  ),
                  const SizedBox(height: 32.0),
                  MealInfoButton(url: meal.url, source: meal.source),
                  meal.source == MealSourceEntity.off
                      ? const Column(
                          children: [SizedBox(height: 32), OffDisclaimer()],
                        )
                      : const SizedBox(),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class MealDetailScreenArguments {
  final MealEntity mealEntity;
  final IntakeTypeEntity intakeTypeEntity;
  final DateTime day;
  final bool usesImperialUnits;
  final ValueChanged<MealEntity>? onSelected;

  MealDetailScreenArguments(
    this.mealEntity,
    this.intakeTypeEntity,
    this.day,
    this.usesImperialUnits, {
    this.onSelected,
  });
}
