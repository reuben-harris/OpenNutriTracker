import '../../../helpers/pump_until.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import '../../../helpers/locator_test_setup.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/core/search/off_food_search_source.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/food_search_view.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_search_controller.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import '../../../core/search/food_search_engine_test.dart'
    show Catalogue, Cache, Online, food;
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class Config implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MealDetails extends Cubit<MealDetailState> implements MealDetailBloc {
  MealDetails() : super(const MealDetailInitial());

  @override
  void add(MealDetailEvent event) {
    if (event is! HydrateMealEvent) throw StateError('Unexpected event');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  useTestLocator();
  late Catalogue catalogue;
  late Cache cache;
  late Online online;
  late Future<List<MealEntity>> Function() recipes;
  int historyReads = 0;
  setUp(() {
    catalogue = Catalogue();
    cache = Cache();
    online = Online();
    historyReads = 0;
    recipes = () async => [
      food('recipe', 'Apple cake', source: MealSourceEntity.recipe),
    ];
    catalogue.results = (_) async => [
      food('usda:1', 'Apple, raw', source: MealSourceEntity.fdc),
    ];
    final engine = FoodSearchEngine(
      catalogue: catalogue,
      cache: cache,
      online: online,
      savedMeals: () async => [],
      savedRecipes: () => recipes(),
      recentMeals: () async {
        historyReads++;
        return [food('old', 'Orange'), food('new', 'Apple')];
      },
      contextIdentity: () => 'test:en',
    );
    locator.registerSingleton<FoodSearchEngine>(engine);
    locator.registerFactory<AddMealBloc>(() => AddMealBloc(Config()));
  });
  tearDown(() async {
    for (final response in online.responses) {
      if (!response.isCompleted) {
        response.complete(const OffFoodSearchPage([], hasMore: false));
      }
    }
    await locator.resetScope();
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: AddMealScreenArguments(
              AddMealType.breakfastType,
              DateTime(2026, 10, 1),
            ),
          ),
          builder: (_) => const AddMealScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  S strings(WidgetTester tester) =>
      S.of(tester.element(find.byType(FoodSearchView)));

  Finder chip(String source) => find.descendant(
    of: find.byWidgetPredicate(
      (w) =>
          w is Semantics && w.properties.identifier == 'diary-search-$source',
    ),
    matching: find.byType(ChoiceChip),
  );
  Future<void> settle(WidgetTester tester, bool Function() done) =>
      pumpUntil(tester, done);

  testWidgets(
    'the final search result and its Add action clear the bottom inset',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      locator.registerSingleton<GetConfigUsecase>(Config());
      recipes = () async => [
        for (var i = 0; i < 30; i++)
          food(
            'recipe:$i',
            'Recipe ${i.toString().padLeft(2, '0')}',
            source: MealSourceEntity.recipe,
          ),
      ];
      String? added;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: FoodSearchView(
              itemBuilder: (context, meal) => MealItemCard(
                key: ValueKey<String>(meal.code!),
                mealEntity: meal,
                onInfo: () {},
                onSelected: (_) => showFoodAmountSheet(
                  context,
                  meal: meal,
                  hydrate: false,
                  onConfirm: (food, quantity) async {
                    added = food.code;
                    expect(quantity.baseAmount, 100);
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(chip('recipes'));
      await tester.tap(chip('recipes'));
      await settle(
        tester,
        () => find.byKey(const ValueKey('recipe:0')).evaluate().isNotEmpty,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recipe:29')),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('recipe:29'));
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(752));
      await tester.tap(last);
      await tester.pumpAndSettle();
      final add = find.widgetWithText(FilledButton, 'Add');
      expect(tester.getRect(add).bottom, lessThanOrEqualTo(752));
      expect(add.hitTestable(), findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(added, 'recipe:29');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('shared ingredient picker returns food without logging', (
    tester,
  ) async {
    MealEntity? selected;
    var barcodeLookups = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FoodSearchView(
            onBarcodePressed: (_) => barcodeLookups++,
            itemBuilder: (context, meal) => ListTile(
              key: ValueKey(meal.code),
              title: Text(meal.name!),
              onTap: () => selected = meal,
            ),
          ),
        ),
      ),
    );
    await tester.tap(chip('recipes'));
    await settle(tester, () => find.text('Apple cake').evaluate().isNotEmpty);
    await tester.tap(find.text('Apple cake'));
    expect(selected?.source, MealSourceEntity.recipe);
    expect(selected?.code, 'recipe');
    await tester.enterText(find.byType(TextField), '3017620422003');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(
      tester,
      () => find.text(strings(tester).noResultsFound).evaluate().isNotEmpty,
    );
    expect(barcodeLookups, 0);
    expect(online.calls, isEmpty);
    // No diary logger is registered: selection belongs to the caller.
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'selecting a recipe in meal search opens the existing amount sheet',
    (tester) async {
      locator.registerSingleton<GetConfigUsecase>(Config());
      locator.registerFactory<MealDetailBloc>(MealDetails.new);
      await open(tester);
      await tester.tap(chip('recipes'));
      await settle(
        tester,
        () => find.textContaining('Apple cake').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Apple cake'));
      await tester.pumpAndSettle();
      final editor = tester.widget<FoodAmountEditor>(
        find.byType(FoodAmountEditor),
      );
      expect(editor.meal.source, MealSourceEntity.recipe);
      expect(editor.meal.code, 'recipe');
      expect(online.calls, isEmpty);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.identifier == 'food-amount-cancel',
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final filter in [FoodSearchFilter.food, FoodSearchFilter.recipes]) {
    testWidgets(
      'reopening a picker restores its query, $filter and scroll position',
      (tester) async {
        catalogue.results = (query) async => [
          for (var i = 0; i < 50; i++)
            food('usda:$i', '$query $i', source: MealSourceEntity.fdc),
        ];
        recipes = () async => [
          for (var i = 0; i < 50; i++)
            food('recipe:$i', 'apple pear $i', source: MealSourceEntity.recipe),
        ];
        final controller = FoodSearchController(locator<FoodSearchEngine>());
        Future<void> mountPicker() async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: const [S.delegate],
              supportedLocales: S.supportedLocales,
              home: Scaffold(
                body: FoodSearchView(
                  controller: controller,
                  itemBuilder: (_, meal) => ListTile(title: Text(meal.name!)),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        try {
          controller.search('apple', filter);
          await mountPicker();
          await settle(tester, () => controller.state.meals.length == 50);
          await tester.pump(const Duration(milliseconds: 300));
          controller.scroll.jumpTo(400);
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
          await mountPicker();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'apple',
          );
          expect(tester.widget<ChoiceChip>(chip(filter.name)).selected, true);
          expect(controller.scroll.offset, 400);
          controller.search('pear', filter);
          await settle(tester, () => controller.state.pending.isEmpty);
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller.scroll.offset, 0);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(controller.close);
        }
      },
    );
  }
  testWidgets(
    'Recipes browses immediately, keeps query on switching and rejects late OFF results',
    (tester) async {
      await open(tester);
      await tester.tap(chip('recipes'));
      await settle(
        tester,
        () => find.textContaining('Apple cake').evaluate().isNotEmpty,
      );
      expect(historyReads, 0);
      expect(catalogue.queries, isEmpty);
      expect(cache.queries, isEmpty);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == 'diary-recipes-results',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'apple');
      await settle(
        tester,
        () => find.textContaining('Apple cake').evaluate().isNotEmpty,
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 550));
      expect(online.calls, isEmpty);
      await tester.tap(chip('all'));
      await tester.pump(const Duration(milliseconds: 550));
      expect(online.calls, [('apple', 1)]);
      await tester.tap(chip('recipes'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'apple',
      );
      expect(online.cancelled, 1);
      online.responses.single.complete(
        OffFoodSearchPage([food('off', 'Apple juice')], hasMore: false),
      );
      await settle(
        tester,
        () => find.textContaining('Apple cake').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Apple juice'), findsNothing);
      await tester.enterText(find.byType(TextField), 'pear');
      await settle(
        tester,
        () => find.text(strings(tester).noResultsFound).evaluate().isNotEmpty,
      );
      expect(find.text(strings(tester).noResultsScanBarcode), findsNothing);
      expect(
        find.text(strings(tester).noResultsCreateCustomFood),
        findsNothing,
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.identifier == 'meal-search-clear',
        ),
      );
      await settle(
        tester,
        () => find.textContaining('Apple cake').evaluate().isNotEmpty,
      );
      expect(tester.widget<ChoiceChip>(chip('recipes')).selected, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Recipes shows loading, a recipe error with retry, and an empty library',
    (tester) async {
      final gate = Completer<List<MealEntity>>();
      recipes = () => gate.future;
      await open(tester);
      await tester.tap(chip('recipes'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(strings(tester).recipesEmptyLabel), findsNothing);
      gate.completeError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(find.text(strings(tester).recipesLoadErrorLabel), findsOneWidget);
      expect(find.text(strings(tester).recipesEmptyLabel), findsNothing);
      recipes = () async => [];
      await tester.tap(find.text(strings(tester).retryLabel));
      await tester.pumpAndSettle();
      expect(find.text(strings(tester).recipesEmptyLabel), findsOneWidget);
      expect(find.text(strings(tester).recipesLoadErrorLabel), findsNothing);
      expect(find.text(strings(tester).noResultsScanBarcode), findsNothing);
      expect(
        find.text(strings(tester).noResultsCreateCustomFood),
        findsNothing,
      );
      expect(online.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Recipes chip scrolls into view on a narrow screen with tight semantics',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await open(tester);
        await tester.ensureVisible(chip('recipes'));
        await tester.tap(chip('recipes'));
        await settle(
          tester,
          () => find.textContaining('Apple cake').evaluate().isNotEmpty,
        );
        final chipRect = tester.getRect(chip('recipes'));
        final node = tester.getSemantics(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'diary-search-recipes',
          ),
        );
        expect(node.identifier, 'diary-search-recipes');
        expect(node.rect.size, chipRect.size);
        expect(chipRect.left, greaterThanOrEqualTo(0));
        expect(chipRect.right, lessThanOrEqualTo(360));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'All opens blank, includes catalogue and saved recipes before OFF, and has no submit button',
    (tester) async {
      await open(tester);
      expect(tester.widget<ChoiceChip>(chip('all')).selected, isTrue);
      expect(historyReads, 0);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.identifier == 'meal-search-submit',
        ),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), 'apple');
      await settle(
        tester,
        () => find.textContaining('Apple cake').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Apple'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 550));
      expect(online.calls, [('apple', 1)]);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(online.calls.length, 1);
      online.responses.single.complete(
        OffFoodSearchPage([food('off', 'Apple juice')], hasMore: false),
      );
      await settle(
        tester,
        () => find.textContaining('Apple juice').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Food is catalogue-only, keeps selected filter on clearing and cancels old online results',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump(const Duration(milliseconds: 550));
      await tester.tap(chip('food'));
      await tester.pump();
      online.responses.single.complete(
        OffFoodSearchPage([food('off', 'Apple juice')], hasMore: false),
      );
      await settle(
        tester,
        () => find.textContaining('Apple').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Apple juice'), findsNothing);
      expect(find.textContaining('Apple cake'), findsNothing);
      expect(online.cancelled, 1);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.identifier == 'meal-search-clear',
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip('food')).selected, isTrue);
      expect(find.textContaining('Apple'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Recent reuses history while typing instead of querying it on each edit',
    (tester) async {
      await open(tester);
      await tester.tap(chip('recent'));
      await tester.pump();
      await settle(
        tester,
        () => find.textContaining('Orange').evaluate().isNotEmpty,
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();
      await settle(
        tester,
        () =>
            find.textContaining('Apple').evaluate().isNotEmpty &&
            find.textContaining('Orange').evaluate().isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump();
      await settle(
        tester,
        () => find.textContaining('Apple').evaluate().isNotEmpty,
      );
      expect(historyReads, 1);
      expect(online.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
