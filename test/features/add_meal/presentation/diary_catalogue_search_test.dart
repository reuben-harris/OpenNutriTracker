import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

MealEntity _meal(String name, MealSourceEntity source) => MealEntity(
  code: source == MealSourceEntity.fdc ? 'usda:1' : 'product-1',
  name: name,
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: 'g',
  servingSize: null,
  source: source,
  nutriments: MealNutrimentsEntity.empty(),
  detailed: true,
);

class _Config implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      ConfigEntity(true, true, false, AppThemeEntity.system);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Recent implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getRecentIntake() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Products implements SearchProductsUseCase {
  final queries = <String>[];
  @override
  Future<SearchProductsResult> searchOFFProductsByString(
    String query, {
    bool skipRemote = false,
  }) async {
    queries.add(query);
    return SearchProductsResult(
      meals: [_meal('Product apple', MealSourceEntity.off)],
      remoteSourceEmpty: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Catalogue implements FoodCatalogue {
  final queries = <String>[];
  Completer<List<MealEntity>>? pending;
  @override
  Future<List<MealEntity>> search(String query) async {
    queries.add(query);
    return pending != null
        ? pending!.future
        : [_meal('Catalogue apple', MealSourceEntity.fdc)];
  }

  @override
  Future<MealEntity?> getById(String catalogueId) => throw UnimplementedError();
}

void main() {
  late _Catalogue catalogue;
  late _Products products;
  setUp(() {
    catalogue = _Catalogue();
    products = _Products();
    final config = _Config();
    locator.registerSingleton<GetConfigUsecase>(config);
    locator.registerSingleton<FoodCatalogue>(catalogue);
    locator.registerFactory<ProductsBloc>(() => ProductsBloc(products, config));
    locator.registerFactory<AddMealBloc>(() => AddMealBloc(config));
    locator.registerFactory<RecentMealBloc>(
      () => RecentMealBloc(_Recent(), config),
    );
  });
  tearDown(() => locator.reset());

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

  Finder chip(String identifier) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    ),
    matching: find.byType(ChoiceChip),
  );

  testWidgets(
    'All searches Products; Food contains only catalogue and stays selected on clear',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();
      expect(catalogue.queries, isEmpty);
      expect(products.queries, ['apple']);
      expect(find.textContaining('Product apple'), findsOneWidget);
      await tester.tap(chip('diary-search-food'));
      await tester.pumpAndSettle();
      expect(catalogue.queries, ['apple']);
      expect(find.textContaining('Catalogue apple'), findsOneWidget);
      expect(find.textContaining('Product apple'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(chip('diary-search-food')).selected,
        isTrue,
      );
      expect(catalogue.queries, ['apple']);
      expect(find.textContaining('Catalogue apple'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Food to All does not wait for or merge an in-flight catalogue query',
    (tester) async {
      await open(tester);
      await tester.tap(chip('diary-search-food'));
      catalogue.pending = Completer<List<MealEntity>>();
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump();
      expect(catalogue.queries, ['apple']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(chip('diary-search-all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Product apple'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      catalogue.pending!.complete([
        _meal('Catalogue apple', MealSourceEntity.fdc),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Catalogue apple'), findsNothing);
      expect(catalogue.queries, ['apple']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
