import 'package:flutter/material.dart';
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

void main() {
  late Catalogue catalogue;
  late Cache cache;
  late Online online;
  int historyReads = 0;
  setUp(() {
    catalogue = Catalogue();
    cache = Cache();
    online = Online();
    historyReads = 0;
    catalogue.results = (_) async => [
      food('usda:1', 'Apple, raw', source: MealSourceEntity.fdc),
    ];
    final engine = FoodSearchEngine(
      catalogue: catalogue,
      cache: cache,
      online: online,
      savedMeals: () async => [
        food('recipe', 'Apple cake', source: MealSourceEntity.recipe),
      ],
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
    await locator.reset();
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

  Finder chip(String source) => find.descendant(
    of: find.byWidgetPredicate(
      (w) =>
          w is Semantics && w.properties.identifier == 'diary-search-$source',
    ),
    matching: find.byType(ChoiceChip),
  );
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue);
  }

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
      await tester.enterText(find.byType(TextField), '');
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
