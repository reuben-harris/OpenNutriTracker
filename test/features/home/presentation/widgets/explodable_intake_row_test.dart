import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/refresh_diary_intake_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/home/presentation/widgets/explodable_intake_row.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/features/home/presentation/widgets/recipe_swipe_scope.dart';

IntakeEntity recipeIntake({
  bool old = false,
  String id = 'intake-1',
  bool recipe = true,
}) {
  const nutrients = MealNutrimentsEntity(
    energyKcal100: 100,
    carbohydrates100: 10,
    fat100: 2,
    proteins100: 3,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  );
  const ingredient = MealEntity(
    code: 'oats',
    name: 'Oats',
    brands: null,
    thumbnailImageUrl: null,
    mainImageUrl: null,
    url: null,
    mealQuantity: '100',
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: nutrients,
    source: MealSourceEntity.custom,
  );
  final snapshot = RecipeEntity(
    id: 'recipe-1',
    name: 'Morning oats',
    description: null,
    ingredients: const [
      RecipeIngredientEntity(
        snapshotMeal: ingredient,
        amount: 100,
        unit: 'g',
        convertedAmountG: 100,
      ),
    ],
    totalWeightG: 100,
    aggregatedNutrimentsPer100: nutrients,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    servingsCount: null,
  );
  return IntakeEntity(
    id: id,
    unit: 'g',
    amount: 100,
    type: IntakeTypeEntity.breakfast,
    meal: recipe ? snapshot.toMealEntity() : ingredient,
    dateTime: DateTime(2026, 9, 26, 8),
    recipeSnapshot: old || !recipe ? null : snapshot,
  );
}

Widget _app(
  IntakeEntity intake,
  VoidCallback onDaySwipe, {
  List<IntakeEntity> others = const [],
  VoidCallback? onTap,
  VoidCallback? onOutsideTap,
  bool active = true,
  bool reducedMotion = false,
  GlobalKey<NavigatorState>? navigatorKey,
  RouteFactory? onGenerateRoute,
}) => ChangeNotifierProvider(
  create: (_) => EnergyUnitProvider(),
  child: MaterialApp(
    navigatorKey: navigatorKey,
    onGenerateRoute: onGenerateRoute,
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: RecipeSwipeScope(
          active: active,
          child: GestureDetector(
            onHorizontalDragEnd: (_) => onDaySwipe(),
            child: ListView(
              children: [
                for (final entry in [intake, ...others])
                  Column(
                    key: ValueKey('section-${entry.id}'),
                    children: [
                      ExplodableIntakeRow(
                        key: ValueKey(entry.id),
                        intake: entry,
                        usesImperialUnits: false,
                        onItemTapped: (_, _, _) => onTap?.call(),
                        onLeftSwipe: onDaySwipe,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                TextButton(
                  key: const ValueKey('outside'),
                  onPressed: onOutsideTap ?? () {},
                  child: const Text('Outside'),
                ),
                Container(
                  key: const ValueKey('day-swipe'),
                  height: 1000,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder _row([String id = 'intake-1']) => find.byKey(ValueKey(id));
Finder _card([String id = 'intake-1']) =>
    find.descendant(of: _row(id), matching: find.byType(IntakeCard));
Finder _action([String id = 'intake-1']) =>
    find.descendant(of: _row(id), matching: find.text('Refresh'));

Future<void> _open(WidgetTester tester, [String id = 'intake-1']) async {
  await tester.drag(_card(id), const Offset(-140, 0));
  await tester.pumpAndSettle();
}

class _FailingRefresh extends Fake implements RefreshDiaryIntakeUsecase {
  @override
  Future<IntakeEntity?> refresh(String id) async =>
      throw StateError('network failure');
}

class _UnavailableRefresh extends Fake implements RefreshDiaryIntakeUsecase {
  @override
  Future<IntakeEntity?> refresh(String id) async =>
      throw DiarySourceUnavailable();
}

class _ImmediateRefresh extends Fake implements RefreshDiaryIntakeUsecase {
  @override
  Future<IntakeEntity?> refresh(String id) async => null;
}

class _Config extends Fake implements GetConfigUsecase {}

class _Recipes extends Fake implements RecipeRepository {
  RecipeEntity? recipe;
  @override
  RecipeEntity? getRecipeById(String id) => recipe?.id == id ? recipe : null;
}

void main() {
  testWidgets('refresh progress blurs the thumbnail for at least 500ms', (
    tester,
  ) async {
    locator.registerSingleton<RefreshDiaryIntakeUsecase>(_ImmediateRefresh());
    addTearDown(() => locator.reset());
    await tester.pumpWidget(_app(recipeIntake(recipe: false), () {}));
    await _open(tester);
    await tester.tap(_action());
    await tester.pump(const Duration(milliseconds: 250));
    final thumb = find.byType(IntakeThumbnail);
    expect(
      find.descendant(of: thumb, matching: find.byType(ImageFiltered)),
      findsOneWidget,
    );
    final progress = find.descendant(
      of: thumb,
      matching: find.byType(CircularProgressIndicator),
    );
    expect(progress, findsOneWidget);
    expect(tester.getCenter(progress), tester.getCenter(thumb));
    await tester.pump(const Duration(milliseconds: 200));
    expect(progress, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(progress, findsNothing);
  });
  testWidgets('Quick Add swipe Refresh opens the same editor as tapping', (
    tester,
  ) async {
    final base = recipeIntake(recipe: false);
    final meal = MealEntity(
      code: 'quick',
      name: 'Quick meal',
      url: null,
      mealQuantity: '100',
      mealUnit: 'gml',
      servingQuantity: null,
      servingUnit: 'gml',
      servingSize: '',
      nutriments: base.meal.nutriments,
      source: MealSourceEntity.custom,
      isQuickAdd: true,
    );
    final intake = IntakeEntity(
      id: base.id,
      unit: base.unit,
      amount: base.amount,
      type: base.type,
      dateTime: base.dateTime,
      meal: meal,
    );
    await tester.pumpWidget(_app(intake, () {}));
    await tester.pumpAndSettle();
    await _open(tester);
    expect(find.text('Refresh'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<QuickAddBottomSheet>(find.byType(QuickAddBottomSheet))
          .editingIntake,
      intake,
    );
    expect(find.text('Save changes'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(_card());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<QuickAddBottomSheet>(find.byType(QuickAddBottomSheet))
          .editingIntake,
      intake,
    );
  });
  testWidgets('row swipe wins over day navigation for every food source', (
    tester,
  ) async {
    for (final recipe in [true, false]) {
      var days = 0;
      await tester.pumpWidget(_app(recipeIntake(recipe: recipe), () => days++));
      await tester.pumpAndSettle();
      await _open(tester);
      expect(days, 0);
      expect(_action(), findsOneWidget);
      expect(tester.getTopLeft(_card()).dx, -104);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'old entry keeps Refresh visible and explains unavailable source',
    (tester) async {
      locator.registerSingleton<RefreshDiaryIntakeUsecase>(
        _UnavailableRefresh(),
      );
      addTearDown(() => locator.reset());
      await tester.pumpWidget(_app(recipeIntake(old: true), () {}));
      await _open(tester);
      await tester.tap(_action());
      await tester.pumpAndSettle();
      expect(find.textContaining('source is unavailable'), findsOneWidget);
      expect(tester.getTopLeft(_card()).dx, 0);
    },
  );

  testWidgets('settles smoothly, stays open, and reverses or cancels a drag', (
    tester,
  ) async {
    await tester.pumpWidget(_app(recipeIntake(), () {}));
    await tester.pumpAndSettle();
    final start = tester.getCenter(_card());
    final drag = await tester.startGesture(start);
    await drag.moveBy(const Offset(-25, 0));
    await drag.moveBy(const Offset(-25, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pump();
    final before = tester.getTopLeft(_card()).dx;
    await tester.pump(const Duration(milliseconds: 20));
    final during = tester.getTopLeft(_card()).dx;
    expect(before, lessThan(during));
    expect(during, lessThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card()).dx, 0);

    await _open(tester);
    final opened = tester.getTopLeft(_card()).dx;
    expect(opened, lessThan(0));
    await tester.pump(const Duration(seconds: 10));
    expect(tester.getTopLeft(_card()).dx, opened);
    await tester.drag(_card(), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card()).dx, 0);

    final cancelled = await tester.startGesture(start);
    await cancelled.moveBy(const Offset(-80, 0));
    await cancelled.moveBy(const Offset(-30, 0));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card()).dx, 0);
  });

  testWidgets('card tap closes first and navigates on the next tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_app(recipeIntake(), () {}, onTap: () => taps++));
    await _open(tester);
    await tester.tap(_card());
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(tester.getTopLeft(_card()).dx, 0);
    await tester.tap(_card());
    expect(taps, 1);
  });

  testWidgets('outside tap closes and still activates the outside control', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(recipeIntake(), () {}, onOutsideTap: () => taps++),
    );
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.getTopLeft(_card()).dx, 0);
  });

  testWidgets('scroll starting on the open card closes it', (tester) async {
    await tester.pumpWidget(_app(recipeIntake(), () {}));
    await _open(tester);
    await tester.drag(_card(), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card()).dx, 0);
  });

  testWidgets('only one recipe opens across sections', (tester) async {
    await tester.pumpWidget(
      _app(recipeIntake(), () {}, others: [recipeIntake(id: 'second')]),
    );
    await _open(tester);
    await _open(tester, 'second');
    expect(tester.getTopLeft(_card()).dx, 0);
    expect(tester.getTopLeft(_card('second')).dx, lessThan(0));
  });

  testWidgets('hidden action is absent from semantics and cannot be tapped', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(recipeIntake(), () {}));
    await tester.pumpAndSettle();
    expect(
      find.semantics.byPredicate(
        (node) => node.getSemanticsData().identifier == 'diary-intake-refresh',
      ),
      findsNothing,
    );
    await tester.tapAt(tester.getCenter(_action()));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await _open(tester);
    expect(
      find.semantics.byPredicate(
        (node) => node.getSemanticsData().identifier == 'diary-intake-refresh',
      ),
      findsOneWidget,
    );
    await tester.tap(_card());
    await tester.pumpAndSettle();
    expect(
      find.semantics.byPredicate(
        (node) => node.getSemanticsData().identifier == 'diary-intake-refresh',
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('refresh failure leaves the row closed', (tester) async {
    locator.registerSingleton<RefreshDiaryIntakeUsecase>(_FailingRefresh());
    addTearDown(() => locator.reset());
    await tester.pumpWidget(_app(recipeIntake(), () {}));
    await _open(tester);
    await tester.tap(_action());
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not refresh'), findsOneWidget);
    expect(tester.getTopLeft(_card()).dx, 0);
  });

  testWidgets(
    'ordinary row swipes reveal Refresh, outside swipes navigate days',
    (tester) async {
      var days = 0;
      await tester.pumpWidget(_app(recipeIntake(recipe: false), () => days++));
      await _open(tester);
      expect(days, 0);
      expect(_action(), findsOneWidget);
      await tester.dragFrom(const Offset(300, 350), const Offset(-140, 0));
      expect(days, 1);
    },
  );

  testWidgets('tab changes, navigation and replaced intakes reset the row', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(recipeIntake(), () {}, navigatorKey: navigator),
    );
    await _open(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card()).dx, 0);
    await _open(tester);
    await tester.pumpWidget(
      _app(recipeIntake(), () {}, active: false, navigatorKey: navigator),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card()).dx, 0);
    await tester.pumpWidget(
      _app(recipeIntake(), () {}, navigatorKey: navigator),
    );
    await _open(tester);
    await tester.pumpWidget(
      _app(recipeIntake(id: 'new-day'), () {}, navigatorKey: navigator),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card('new-day')).dx, 0);
  });

  testWidgets(
    'reduced motion closes immediately; disposal during settling is safe',
    (tester) async {
      await tester.pumpWidget(_app(recipeIntake(), () {}, reducedMotion: true));
      await _open(tester);
      await tester.tap(_card());
      await tester.pump();
      expect(tester.getTopLeft(_card()).dx, 0);
      await tester.pumpWidget(_app(recipeIntake(), () {}));
      await _open(tester);
      await tester.tap(_card());
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('short slow right swipes reveal Info on food and recipes', (
    tester,
  ) async {
    var days = 0;
    var taps = 0;
    for (final recipe in [false, true]) {
      await tester.pumpWidget(
        _app(
          recipeIntake(id: '$recipe', recipe: recipe),
          () => days++,
          onTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(
        tester.getCenter(_card('$recipe')),
      );
      for (var step = 0; step < 3; step++) {
        await drag.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_card('$recipe')).dx, 104);
      expect(days, 0);
      expect(taps, 0);
      await tester.tap(_card('$recipe'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_card('$recipe')).dx, 0);
    }
  });

  testWidgets(
    'ordinary right swipe reveals Info and opens existing food detail',
    (tester) async {
      var days = 0;
      var taps = 0;
      RouteSettings? route;
      final selected = SelectedDayCubit(_Config());
      selected.emit(
        SelectedDayState(DateTime(2026, 9, 20), DateTime(2026, 9, 29)),
      );
      locator.registerSingleton<SelectedDayCubit>(selected);
      addTearDown(() async {
        await locator.reset();
        await selected.close();
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          recipeIntake(recipe: false),
          () => days++,
          onTap: () => taps++,
          onGenerateRoute: (settings) {
            route = settings;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Food details')),
            );
          },
        ),
      );
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().identifier == 'diary-intake-info',
        ),
        findsNothing,
      );
      await tester.drag(_card(), const Offset(140, 0));
      await tester.pumpAndSettle();
      expect(days, 0);
      expect(tester.getTopLeft(_card()).dx, 104);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().identifier == 'diary-intake-info',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(route!.name, NavigationOptions.mealDetailRoute);
      final args = route!.arguments as MealDetailScreenArguments;
      expect(args.day, DateTime(2026, 9, 20));
      expect(args.mealEntity.name, 'Oats');
      expect(taps, 0);
      semantics.dispose();
    },
  );

  testWidgets('recipe Info opens saved recipe and explains deleted recipes', (
    tester,
  ) async {
    final intake = recipeIntake();
    final recipes = _Recipes()..recipe = intake.recipeSnapshot;
    locator.registerSingleton<RecipeRepository>(recipes);
    addTearDown(() => locator.reset());
    RouteSettings? route;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        intake,
        () {},
        navigatorKey: navigator,
        onGenerateRoute: (settings) {
          route = settings;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Saved recipe details')),
          );
        },
      ),
    );
    await tester.drag(_card(), const Offset(140, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(route!.name, NavigationOptions.recipeDetailRoute);
    expect((route!.arguments as RecipeDetailArguments).recipeId, 'recipe-1');
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    recipes.recipe = null;
    await tester.drag(_card(), const Offset(140, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(
      find.text('This saved recipe is no longer available.'),
      findsOneWidget,
    );
    expect(tester.getTopLeft(_card()).dx, 0);
  });

  testWidgets(
    'Info and Refresh share one open action and ordinary quantity taps work',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          recipeIntake(recipe: false),
          () {},
          others: [recipeIntake(id: 'second')],
          onTap: () => taps++,
        ),
      );
      await tester.drag(_card(), const Offset(140, 0));
      await tester.pumpAndSettle();
      await _open(tester, 'second');
      expect(tester.getTopLeft(_card()).dx, 0);
      expect(tester.getTopLeft(_card('second')).dx, -104);
      await tester.tap(_card());
      expect(taps, 1);
    },
  );
}
