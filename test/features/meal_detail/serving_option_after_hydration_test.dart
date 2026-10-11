import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_dto.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/generated/l10n.dart';

// #1216: "Seabrook sea salted crisps" opened from the search list shows
// "N/A" in the unit dropdown, and when the user picks the 31.8 g serving
// entry the selection vanishes.
//
// The shapes below are what Open Food Facts returned on 2026-09-18 for the
// two records that query surfaces: the Search-a-licious hit is the thin
// projection the app lists (no serving_*, no product_quantity — see
// `OFFConst._searchReturnFields`), and the v2 product record is what
// hydration swaps in once the detail screen is open.

/// Search-a-licious hit for 0080457761112. No `quantity`, so the entity's
/// `mealUnit` is null and the dropdown opens on "N/A (g/ml)".
const _seabrookCrispsSearchHit = <String, dynamic>{
  'code': '0080457761112',
  'brands': ['seabrook'],
  'product_name': 'Seabrook sea salted crisps',
  'product_name_en': 'Seabrook sea salted crisps',
  'countries_tags': ['en:united-kingdom'],
  'popularity_key': 12,
  'nutriments': {
    'carbohydrates_100g': 55.9,
    'energy-kcal_100g': 514,
    'energy-kj_100g': 2130,
    'fat_100g': 28.9,
    'proteins_100g': 5.7,
    'salt_100g': 1.32,
    'saturated-fat_100g': 2.8,
    'sodium_100g': 0.528,
    'sugars_100g': 0.4,
  },
};

/// v2 product record for 0080457761112: serving 31.8 g, no package quantity.
const _seabrookCrispsProduct = <String, dynamic>{
  'code': '0080457761112',
  'brands': 'seabrook',
  'product_name': 'Seabrook sea salted crisps',
  'product_name_en': 'Seabrook sea salted crisps',
  'serving_quantity': 31.8,
  'serving_quantity_unit': 'g',
  'serving_size': '31.8g',
  'nutriments': {
    'carbohydrates_100g': 55.9,
    'carbohydrates_serving': 17.8,
    'energy-kcal_100g': 514,
    'energy-kcal_serving': 163,
    'fat_100g': 28.9,
    'fat_serving': 9.19,
    'proteins_100g': 5.7,
    'proteins_serving': 1.81,
    'salt_100g': 1.32,
    'saturated-fat_100g': 2.8,
    'sodium_100g': 0.528,
    'sugars_100g': 0.4,
  },
};

/// Search-a-licious hit for 5016451062110, the multipack. It carries a
/// `quantity` of "6 x 25g", so the thin entity already reads as solid.
const _seabrookMultipackSearchHit = <String, dynamic>{
  'code': '5016451062110',
  'brands': ['Seabrook'],
  'quantity': '6 x 25g',
  'product_name': 'Seabrook sea salt',
  'product_name_en': 'Seabrook sea salt',
  'countries_tags': ['en:united-kingdom'],
  'popularity_key': 22950000024,
  'nutriments': {
    'carbohydrates_100g': 52.6,
    'energy-kcal_100g': 500,
    'fat_100g': 30.4,
    'proteins_100g': 5.9,
    'salt_100g': 1.3,
    'saturated-fat_100g': 2.7,
    'sodium_100g': 0.52,
    'sugars_100g': 0.2,
  },
};

/// v2 product record for 5016451062110: a package quantity but no serving,
/// and a different product name from the search index.
const _seabrookMultipackProduct = <String, dynamic>{
  'code': '5016451062110',
  'brands': 'Seabrook',
  'product_name': 'SEA SALTED POTATO CRISPS',
  'product_name_en': 'SEA SALTED POTATO CRISPS',
  'product_quantity': 150,
  'quantity': '6 x 25g',
  'nutriments': {
    'carbohydrates_100g': 52.6,
    'energy-kcal_100g': 500,
    'fat_100g': 30.4,
    'proteins_100g': 5.9,
    'salt_100g': 1.3,
    'saturated-fat_100g': 2.7,
    'sodium_100g': 0.52,
    'sugars_100g': 0.2,
  },
};

MealEntity _thin(Map<String, dynamic> hit) =>
    MealEntity.fromOFFProduct(OFFProductDTO.fromJson(hit));

MealEntity _full(Map<String, dynamic> product) =>
    MealEntity.fromOFFProduct(OFFProductDTO.fromJson(product), detailed: true);

void main() {
  final getIt = GetIt.instance;
  late Completer<MealEntity> hydration;

  setUp(() {
    getIt.registerLazySingleton<MealDetailBloc>(
      () => MealDetailBloc(
        _FakeAddIntakeUsecase(),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        _FakeGetTrackedDayUsecase(),
        _FakeProductsRepository(() => hydration.future),
        _FakeRemoteSearchCacheDataSource(),
      ),
    );
    getIt.registerLazySingleton<GetConfigUsecase>(_FakeGetConfigUsecase.new);
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpSheet(WidgetTester tester, MealEntity meal) async {
    hydration = Completer<MealEntity>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FoodAmountSheet(meal: meal, onConfirm: (_, _) async => false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  TextEditingController quantity(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;
  testWidgets('hydration makes servings available without selecting them', (
    tester,
  ) async {
    await pumpSheet(tester, _thin(_seabrookCrispsSearchHit));
    expect(quantity(tester).text, '100');
    hydration.complete(_full(_seabrookCrispsProduct));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(find.text('g'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('31.8g').last);
    await tester.pumpAndSettle();
    expect(find.text('31.8g'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();
    expect(find.text('g'), findsOneWidget);
  });
  testWidgets('late hydration preserves typed amount and chosen conversion', (
    tester,
  ) async {
    await pumpSheet(tester, _thin(_seabrookCrispsSearchHit));
    await tester.enterText(find.byType(TextField), '53');
    hydration.complete(_full(_seabrookCrispsProduct));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '53');
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(
      dropdown.initialValue,
      const FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1).identity,
    );
  });
  testWidgets('package size without a serving keeps a gram default', (
    tester,
  ) async {
    await pumpSheet(tester, _thin(_seabrookMultipackSearchHit));
    hydration.complete(_full(_seabrookMultipackProduct));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(find.text('g'), findsOneWidget);
  });
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddTrackedDayUsecase implements AddTrackedDayUsecase {
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

/// Hydration answers with whatever future the test hands it, so a test can
/// hold the full record back until the screen has rendered the thin one.
class _FakeProductsRepository implements ProductsRepository {
  final Future<MealEntity> Function() hydrated;

  _FakeProductsRepository(this.hydrated);

  @override
  Future<MealEntity> getOFFProductByBarcode(String barcode) => hydrated();

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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeHomeBloc implements HomeBloc {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeDiaryBloc implements DiaryBloc {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCalendarDayBloc implements CalendarDayBloc {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

/// The screen renders a [CachedNetworkImage] for the product photo; an
/// empty stream sends it straight to its placeholder.
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
