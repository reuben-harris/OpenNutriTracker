import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/off_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/sp_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_dto.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'hive_test_setup.dart';

const refreshBarcode = '9339687336005';

Map<String, dynamic> refreshProduct({
  double kcal = 100,
  double? serving = 30,
  String quantity = '300 g',
  String code = refreshBarcode,
}) => {
  'code': code,
  'product_name': 'Refresh test product',
  'product_name_en': 'Refresh test product',
  'quantity': quantity,
  'serving_quantity': ?serving,
  if (serving != null) 'serving_size': '$serving g',
  'nutriments': {
    'energy-kcal_100g': kcal,
    'carbohydrates_100g': kcal / 10,
    'fat_100g': kcal / 20,
    'proteins_100g': kcal / 25,
    'sugars_100g': 2,
    'saturated-fat_100g': 1,
    'fiber_100g': 3,
  },
};

MealEntity refreshMeal({double kcal = 100, bool detailed = true}) =>
    MealEntity.fromOFFProduct(
      OFFProductDTO.fromJson(refreshProduct(kcal: kcal)),
      detailed: detailed,
    );

/// Real OFF parsing, repository and on-disk Hive cache; only HTTP is controlled.
/// Shared by host widget tests and the Android integration test.
class ProductRefreshFixture {
  late Directory directory;
  late Box<MealDBO> meals;
  late Box<int> timestamps;
  late RemoteSearchCacheDataSource cache;
  late ProductsRepository repository;
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request)? respond;
  MealDetailBloc? bloc;

  Future<void> open() async {
    PackageInfo.setMockInitialValues(
      appName: 'OpenNutriTracker',
      packageName: 'refresh.test',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    directory = await Directory.systemTemp.createTemp('off-refresh-');
    registerHiveAdaptersOnce();
    meals = await Hive.openBox<MealDBO>('meals', path: directory.path);
    timestamps = await Hive.openBox<int>('timestamps', path: directory.path);
    cache = RemoteSearchCacheDataSource(meals, timestamps);
    await cache.cache(MealDBO.fromMealEntity(refreshMeal()));
    // A second entry proves refresh does not clear the whole cache.
    await cache.cache(
      MealDBO.fromMealEntity(
        MealEntity.fromOFFProduct(
          OFFProductDTO.fromJson(refreshProduct(code: 'other-product')),
          detailed: true,
        ),
      ),
    );
    repository = ProductsRepository(
      OFFDataSource(
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          return respond!(request);
        }),
      ),
      _UnusedBackend(),
    );
  }

  MealDetailBloc createBloc() => MealDetailBloc(
    _NoIntakeWrites(),
    _NoTrackedDayWrites(),
    _UnusedKcalGoal(),
    _UnusedMacroGoal(),
    _DailyTotals(),
    repository,
    cache,
  );

  Future<void> mount(WidgetTester tester, MealEntity meal) async {
    final locator = GetIt.instance;
    bloc = createBloc();
    locator.registerFactory<MealDetailBloc>(() => bloc!);
    locator.registerSingleton<GetConfigUsecase>(_Config());
    locator.registerSingleton<CacheManager>(_Images());
    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: MealDetailScreenArguments(
                meal,
                IntakeTypeEntity.snack,
                DateTime(2026, 9, 29),
                false,
              ),
            ),
            builder: (_) => const MealDetailScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close() async {
    await GetIt.instance.reset();
    await meals.close();
    await timestamps.close();
    await directory.delete(recursive: true);
  }

  Future<MealEntity> scanAgain() => SearchProductByBarcodeUseCase(
    repository,
    _NoCustomMeals(),
    cache,
  ).searchProductByBarcode(refreshBarcode);

  MealDBO get cached => cache.getDetailedByBarcode(refreshBarcode)!;

  static http.Response success({
    double kcal = 200,
    double? serving = 30,
    String quantity = '300 g',
  }) => http.Response(
    jsonEncode({
      'status': 1,
      'status_verbose': 'product found',
      'product': refreshProduct(
        kcal: kcal,
        serving: serving,
        quantity: quantity,
      ),
    }),
    200,
  );
}

Finder get refreshButton => find.byWidgetPredicate(
  (w) => w is IconButton && w.tooltip == 'Refresh from Open Food Facts',
);

Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'refresh should finish');
  await tester.pump();
}

class _NoIntakeWrites extends Fake implements AddIntakeUsecase {}

class _NoTrackedDayWrites extends Fake implements AddTrackedDayUsecase {}

class _UnusedKcalGoal extends Fake implements GetKcalGoalUsecase {}

class _UnusedMacroGoal extends Fake implements GetMacroGoalUsecase {}

class _UnusedBackend extends Fake implements SpFoodDataSource {}

class _DailyTotals extends Fake implements GetTrackedDayUsecase {
  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async =>
      TrackedDayEntity(
        day: day,
        calorieGoal: 2200,
        caloriesTracked: 800,
        carbsGoal: 250,
        carbsTracked: 100,
        fatGoal: 70,
        fatTracked: 30,
        proteinGoal: 120,
        proteinTracked: 50,
      );
}

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);
}

class _Images extends Fake implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream<FileResponse>.empty();
}

class _NoCustomMeals extends Fake implements CustomMealDataSource {
  @override
  List<MealDBO> getAllCustomMeals() => [];
}
