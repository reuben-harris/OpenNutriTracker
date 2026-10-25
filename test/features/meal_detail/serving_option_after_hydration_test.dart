import '../../helpers/locator_test_setup.dart';
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
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_memory.dart';
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
  useTestLocator();
  final getIt = GetIt.instance;
  late Completer<MealEntity> hydration;
  late _FakeRemoteSearchCacheDataSource cache;
  late List<String> networkLookups;
  final details = <MealDetailBloc>[];

  setUp(() {
    cache = _FakeRemoteSearchCacheDataSource();
    networkLookups = [];
    getIt.registerSingleton<RemoteSearchCacheDataSource>(cache);
    getIt.registerFactory<MealDetailBloc>(() {
      final bloc = MealDetailBloc(
        _FakeAddIntakeUsecase(),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        _FakeGetTrackedDayUsecase(),
        _FakeProductsRepository(() => hydration.future, networkLookups),
        cache,
      );
      details.add(bloc);
      return bloc;
    });
    getIt.registerLazySingleton<GetConfigUsecase>(_FakeGetConfigUsecase.new);
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    if (!hydration.isCompleted) {
      hydration.complete(_full(_seabrookCrispsProduct));
    }
    for (final bloc in details) {
      if (!bloc.isClosed) await bloc.close();
    }
    details.clear();
    await getIt.resetScope();
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    MealEntity meal, {
    FoodAmountPreference? remembered,
    FoodAmountSelection? initial,
    bool hydrate = true,
    bool Function()? isProfileCurrent,
    Future<bool> Function(MealEntity, FoodAmountSelection)? confirm,
    Future<void> Function(MealEntity, FoodAmountSelection)? remember,
  }) async {
    hydration = Completer<MealEntity>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FoodAmountEditor(
            meal: meal,
            remembered: remembered,
            initial: initial,
            hydrate: hydrate,
            isProfileCurrent: isProfileCurrent,
            onConfirm: confirm ?? (_, _) async => false,
            onRemember: remember,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  TextEditingController quantity(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;
  String? selectedUnit(WidgetTester tester) => tester
      .widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      )
      .initialValue;

  testWidgets('hydration makes servings available without selecting them', (
    tester,
  ) async {
    await pumpSheet(tester, _thin(_seabrookCrispsSearchHit));
    expect(quantity(tester).text, '100');
    quantity(tester).selection = const TextSelection.collapsed(offset: 1);
    hydration.complete(_full(_seabrookCrispsProduct));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(
      quantity(tester).selection,
      const TextSelection.collapsed(offset: 1),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      true,
    );
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
    quantity(tester).selection = const TextSelection.collapsed(offset: 1);
    hydration.complete(_full(_seabrookCrispsProduct));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '53');
    expect(
      quantity(tester).selection,
      const TextSelection.collapsed(offset: 1),
    );
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

  testWidgets('cached servings initialize once after a local loading state', (
    tester,
  ) async {
    final local = Completer<MealDBO?>();
    cache.response = local.future;
    FoodAmountSelection? saved;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      remembered: const FoodAmountPreference(2, 'serving', 'g'),
      confirm: (_, selection) async {
        saved = selection;
        return false;
      },
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
    expect(networkLookups, isEmpty);

    local.complete(MealDBO.fromMealEntity(_full(_seabrookCrispsProduct)));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '2');
    expect(
      quantity(tester).selection,
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      true,
    );
    expect(selectedUnit(tester), 'serving:g:31.8');
    expect(networkLookups, isEmpty);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(saved!.amount, 2);
    expect(saved!.baseAmount, closeTo(63.6, 0.0001));
  });

  testWidgets('remembered standard units need no detail cache', (tester) async {
    final local = Completer<MealDBO?>();
    cache.response = local.future;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      hydrate: false,
      remembered: const FoodAmountPreference(0.5, 'kg', 'g'),
    );
    expect(quantity(tester).text, '0.5');
    expect(selectedUnit(tester), 'kg:g:1000.0');
    expect(cache.lookups, 0);
    expect(networkLookups, isEmpty);
  });

  testWidgets('a cache miss does not wait for or switch on network details', (
    tester,
  ) async {
    final local = Completer<MealDBO?>();
    cache.response = local.future;
    FoodAmountSelection? remembered;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      remembered: const FoodAmountPreference(2, 'serving', 'g'),
      remember: (_, selection) async => remembered = selection,
    );
    local.complete(null);
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(selectedUnit(tester), 'g:g:1.0');
    expect(networkLookups, hasLength(1));
    expect(remembered, isNull);
    quantity(tester).selection = const TextSelection.collapsed(offset: 2);
    hydration.complete(_full(_seabrookCrispsProduct));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(
      quantity(tester).selection,
      const TextSelection.collapsed(offset: 2),
    );
    expect(selectedUnit(tester), 'g:g:1.0');
    expect(remembered, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('31.8g'), findsOneWidget);
  });

  testWidgets('failed local lookup falls back to ml without blocking entry', (
    tester,
  ) async {
    final local = Completer<MealDBO?>();
    cache.response = local.future;
    await pumpSheet(
      tester,
      _thin({..._seabrookCrispsSearchHit, 'quantity': '200 ml'}),
      hydrate: false,
      remembered: const FoodAmountPreference(2, 'serving', 'ml'),
    );
    local.completeError(StateError('Cache unavailable'));
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(selectedUnit(tester), 'ml:ml:1.0');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing serving conversion falls back instead of guessing', (
    tester,
  ) async {
    cache.response = Future.value(
      MealDBO.fromMealEntity(_full(_seabrookMultipackProduct)),
    );
    await pumpSheet(
      tester,
      _thin(_seabrookMultipackSearchHit),
      remembered: const FoodAmountPreference(2, 'serving', 'g'),
    );
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '100');
    expect(selectedUnit(tester), 'g:g:1.0');
    expect(networkLookups, isEmpty);
  });

  for (final portionExists in [true, false]) {
    testWidgets(
      'catalogue restores only the exact portion: exists=$portionExists',
      (tester) async {
        final supplied = MealEntity(
          code: 'usda:123',
          name: 'Food',
          url: null,
          mealQuantity: null,
          servingQuantity: null,
          servingUnit: 'g',
          servingSize: null,
          mealUnit: 'g',
          nutriments: _thin(_seabrookCrispsSearchHit).nutriments,
          source: MealSourceEntity.catalogue,
          detailed: true,
        );
        final local = MealEntity(
          code: supplied.code,
          name: supplied.name,
          url: null,
          mealQuantity: null,
          servingQuantity: null,
          servingUnit: 'g',
          servingSize: null,
          mealUnit: 'g',
          nutriments: supplied.nutriments,
          source: supplied.source,
          detailed: true,
          portions: [
            MealPortionEntity(
              id: portionExists ? 'foundation:456' : 'foundation:789',
              label: '1 cup',
              gramWeight: 140,
              localized: false,
            ),
          ],
        );
        final pending = Completer<MealEntity?>();
        getIt.registerSingleton<FoodCatalogue>(_FakeCatalogue(pending.future));
        FoodAmountSelection? saved;
        await pumpSheet(
          tester,
          supplied,
          hydrate: false,
          remembered: const FoodAmountPreference(
            2,
            'portion:foundation:456',
            'g',
          ),
          confirm: (_, selection) async {
            saved = selection;
            return false;
          },
        );
        expect(find.byType(TextField), findsNothing);
        pending.complete(local);
        await tester.pumpAndSettle();
        expect(quantity(tester).text, portionExists ? '2' : '100');
        expect(
          selectedUnit(tester),
          portionExists ? 'portion:foundation:456:g:140.0' : 'g:g:1.0',
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(saved!.baseAmount, portionExists ? 280 : 100);
        expect(cache.lookups, 0);
        expect(networkLookups, isEmpty);
      },
    );
  }

  testWidgets('historical edit snapshot bypasses local and network lookups', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      hydrate: false,
      initial: const FoodAmountSelection(
        2,
        FoodAmountOption(
          unit: 'serving',
          baseUnit: 'g',
          factor: 25,
          label: '25 g',
        ),
      ),
      remembered: const FoodAmountPreference(53, 'g', 'g'),
    );
    expect(quantity(tester).text, '2');
    expect(selectedUnit(tester), 'serving:g:25.0');
    expect(cache.lookups, 0);
    expect(networkLookups, isEmpty);
  });

  testWidgets('late local lookup is ignored after dismissal', (tester) async {
    final local = Completer<MealDBO?>();
    cache.response = local.future;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      remembered: const FoodAmountPreference(2, 'serving', 'g'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    local.complete(MealDBO.fromMealEntity(_full(_seabrookCrispsProduct)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(networkLookups, isEmpty);
  });

  testWidgets('late local lookup is ignored after a profile switch', (
    tester,
  ) async {
    final local = Completer<MealDBO?>();
    cache.response = local.future;
    var current = true;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      remembered: const FoodAmountPreference(2, 'serving', 'g'),
      isProfileCurrent: () => current,
    );
    current = false;
    local.complete(MealDBO.fromMealEntity(_full(_seabrookCrispsProduct)));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(networkLookups, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late hydration preserves the selected serving conversion', (
    tester,
  ) async {
    FoodAmountSelection? saved;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsProduct),
      remembered: const FoodAmountPreference(2, 'serving', 'g'),
      confirm: (_, selection) async {
        saved = selection;
        return false;
      },
    );
    quantity(tester).selection = const TextSelection.collapsed(offset: 0);
    hydration.complete(
      _full({
        ..._seabrookCrispsProduct,
        'serving_quantity': 35,
        'serving_size': '35 g',
      }),
    );
    await tester.pumpAndSettle();
    expect(quantity(tester).text, '2');
    expect(
      quantity(tester).selection,
      const TextSelection.collapsed(offset: 0),
    );
    expect(selectedUnit(tester), 'serving:g:31.8');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(saved!.option.factor, 31.8);
  });

  testWidgets('hydration during confirmation preserves the submitted amount', (
    tester,
  ) async {
    final pending = Completer<bool>();
    FoodAmountSelection? saved;
    await pumpSheet(
      tester,
      _thin(_seabrookCrispsSearchHit),
      confirm: (_, selection) {
        saved = selection;
        return pending.future;
      },
    );
    await tester.enterText(find.byType(TextField), '53');
    quantity(tester).selection = const TextSelection.collapsed(offset: 1);
    await tester.tap(find.text('Add'));
    await tester.pump();
    final selection = quantity(tester).selection;
    hydration.complete(_full(_seabrookCrispsProduct));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(quantity(tester).text, '53');
    expect(quantity(tester).selection, selection);
    expect(selectedUnit(tester), 'g:g:1.0');
    expect(saved!.amount, 53);
    pending.complete(false);
    await tester.pumpAndSettle();
  });
}

class _FakeCatalogue extends Fake implements FoodCatalogue {
  @override
  Future<List<CatalogueSource>> sources() async => const [];
  _FakeCatalogue(this.result);
  final Future<MealEntity?> result;
  @override
  Future<MealEntity?> getById(String id) => result;
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(AppThemeEntity.system);

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
  final List<String> calls;

  _FakeProductsRepository(this.hydrated, this.calls);

  @override
  Future<MealEntity> getOFFProductByBarcode(String barcode) {
    calls.add(barcode);
    return hydrated();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeRemoteSearchCacheDataSource implements RemoteSearchCacheDataSource {
  Future<MealDBO?>? response;
  int lookups = 0;
  @override
  int generation = 0;
  @override
  String get language => 'en';
  @override
  Future<MealDBO?> getDetailedByBarcode(String barcode) {
    ++lookups;
    return response ?? Future.value(null);
  }

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
