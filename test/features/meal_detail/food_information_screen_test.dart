import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 100,
  carbohydrates100: 10,
  fat100: 5,
  proteins100: 5,
  sugars100: 2,
  saturatedFat100: 1,
  fiber100: 1,
);

MealEntity _solidWithServing() => MealEntity(
  code: 'raw-units-test-solid',
  name: 'Solid product',
  url: null,
  mealQuantity: '100',
  mealUnit: 'g',
  servingQuantity: 30,
  servingUnit: 'g',
  servingSize: '30 g',
  nutriments: _nutriments,
  source: MealSourceEntity.custom,
);

double _maxScrollOffset(WidgetTester tester) {
  final states = tester.stateList<ScrollableState>(find.byType(Scrollable));
  return states.fold<double>(0, (m, s) => math.max(m, s.position.pixels));
}

void main() {
  final getIt = GetIt.instance;
  MealDetailBloc? bloc;
  MealEntity? hydratedFor;
  late bool imperialFoodUnits;
  late _FakeCatalogue catalogue;
  late List<IntakeEntity> logged;

  setUp(() {
    bloc = null;
    hydratedFor = null;
    imperialFoodUnits = false;
    catalogue = _FakeCatalogue();
    logged = [];
    getIt.registerFactory<MealDetailBloc>(
      () => bloc = MealDetailBloc(
        _FakeAddIntakeUsecase(logged),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        _FakeGetTrackedDayUsecase(),
        _FakeProductsRepository(() => hydratedFor),
        _FakeRemoteSearchCacheDataSource(),
        catalogue: catalogue,
      ),
    );
    getIt.registerLazySingleton<GetConfigUsecase>(
      () => _FakeGetConfigUsecase(() => imperialFoodUnits),
    );
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpMealDetail(WidgetTester tester, MealEntity meal) async {
    // 600x800 leaves the CustomScrollView with a real maxScrollExtent, so
    // the scroll-offset assertion below can actually fail if the race guard
    // regresses. A taller viewport clamps `animateTo` to 0 and the test
    // passes vacuously.
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    Route<void> routeFor(RouteSettings settings) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const MealDetailScreen(),
      );
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          initialRoute: NavigationOptions.mealDetailRoute,
          onGenerateInitialRoutes: (_) => [
            routeFor(
              RouteSettings(
                name: NavigationOptions.mealDetailRoute,
                arguments: MealDetailScreenArguments(
                  meal,
                  IntakeTypeEntity.breakfast,
                  DateTime(2026, 9, 14),
                  imperialFoodUnits,
                ),
              ),
            ),
          ],
          onGenerateRoute: routeFor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'information uses a fixed nutrition reference and offers logging',
    (tester) async {
      await pumpMealDetail(tester, _solidWithServing());
      expect(bloc!.state.selectedUnit, 'g');
      expect(bloc!.state.totalQuantityConverted, '100.0');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Log this food'), findsOneWidget);
      expect(_maxScrollOffset(tester), 0);
    },
  );
  for (final imperial in [false, true]) {
    testWidgets('logging starts in grams with imperial=$imperial', (
      tester,
    ) async {
      imperialFoodUnits = imperial;
      await pumpMealDetail(tester, _solidWithServing());
      await tester.tap(find.text('Log this food'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '100');
      expect(field.focusNode!.hasFocus, true);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, 'g:g:1.0');
      await tester.tap(find.bySemanticsIdentifier('food-amount-cancel'));
      await tester.pumpAndSettle();
      expect(logged, isEmpty);
    });
  }
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  final bool Function() imperialProvider;
  _FakeGetConfigUsecase(this.imperialProvider);

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(
      true,
      true,
      false,
      AppThemeEntity.system,
      usesImperialFoodUnits: imperialProvider(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  _FakeAddIntakeUsecase(this.logged);
  final List<IntakeEntity> logged;
  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    logged.add(intakeEntity);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddTrackedDayUsecase implements AddTrackedDayUsecase {
  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double kcal) async {}

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetKcalGoalUsecase implements GetKcalGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetMacroGoalUsecase implements GetMacroGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetTrackedDayUsecase implements GetTrackedDayUsecase {
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

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeProductsRepository implements ProductsRepository {
  final MealEntity? Function() hydratedProvider;

  _FakeProductsRepository(this.hydratedProvider);

  @override
  Future<MealEntity> getOFFProductByBarcode(String barcode) async {
    final hydrated = hydratedProvider();
    if (hydrated == null) {
      throw StateError('No hydrated product configured for barcode $barcode');
    }
    return hydrated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeRemoteSearchCacheDataSource implements RemoteSearchCacheDataSource {
  @override
  int get generation => 0;
  @override
  String get language => 'en';

  @override
  Future<MealDBO?> getDetailedByBarcode(String barcode) async => null;

  @override
  Future<void> cache(MealDBO meal, {int? generation, String? language}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetIntakeUsecase implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getBreakfastIntakeByDay(
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeHomeBloc implements HomeBloc {
  @override
  void add(HomeEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeDiaryBloc implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCalendarDayBloc implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCacheManager implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream<FileResponse>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCatalogue implements FoodCatalogue {
  final ids = <String>[];
  final meal = MealEntity(
    code: 'usda:123',
    name: 'Catalogue food',
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    nutriments: _nutriments,
    source: MealSourceEntity.fdc,
    detailed: true,
    portions: [
      MealPortionEntity(
        id: 'test:0',
        label: '1 cup',
        englishLabel: '1 cup',
        gramWeight: 140,
        localized: false,
      ),
    ],
  );
  @override
  Future<MealEntity?> getById(String id) async {
    ids.add(id);
    return meal;
  }

  @override
  Future<List<MealEntity>> search(String query) => throw UnimplementedError();
}
