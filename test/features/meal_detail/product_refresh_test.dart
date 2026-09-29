import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_dto.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_bottom_sheet.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';

import '../../helpers/product_refresh_fixture.dart';

void main() {
  late ProductRefreshFixture fixture;
  setUp(() async {
    fixture = ProductRefreshFixture();
    await fixture.open();
  });
  void refreshTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        // Hive's last write future belongs to the widget test's fake async
        // zone. Pump it while closing, rather than awaiting it in tearDown
        // after that zone has stopped advancing.
        var closed = false;
        final closing = fixture.close().then((_) => closed = true);
        await pumpUntil(tester, () => closed);
        await closing;
      }
    });
  }

  Future<void> mount(WidgetTester tester, [MealEntity? meal]) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await fixture.mount(tester, meal ?? refreshMeal());
  }

  TextEditingController quantity(WidgetTester tester) => tester
      .widget<MealDetailBottomSheet>(find.byType(MealDetailBottomSheet))
      .quantityTextController;

  refreshTest('refresh bypasses cache, updates same-name nutrition and totals, '
      'keeps the current serving selection and replaces only its cache entry', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    addTearDown(() {
      if (!response.isCompleted) response.complete(http.Response('{}', 404));
    });
    fixture.respond = (_) => response.future;
    await mount(tester);
    final bloc = fixture.bloc!;
    expect(bloc.state.totalKcal, 30);
    await tester.tap(refreshButton);
    await tester.pump();
    expect(bloc.state.isRefreshing, isTrue);
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNull);
    // A second event, even if enqueued directly, must not overlap.
    bloc.add(RefreshMealEvent(refreshMeal()));
    await tester.pump();
    expect(fixture.requests, hasLength(1));
    expect(fixture.cached.nutriments.energyKcal100, 100);
    // Editing while the request is in flight must be preserved too.
    quantity(tester).text = '2,5';
    await tester.pump();
    response.complete(ProductRefreshFixture.success(serving: 40));
    await pumpUntil(tester, () => !bloc.state.isRefreshing);
    await tester.pumpAndSettle();
    expect(bloc.state.refreshStatus, ProductRefreshStatus.success);
    expect(bloc.state.selectedUnit, 'serving');
    expect(quantity(tester).text, '2,5');
    expect(bloc.state.totalQuantityConverted, '100.0');
    expect(bloc.state.totalKcal, 200);
    expect(bloc.state.totalCarbs, 20);
    expect(bloc.state.totalFat, 10);
    expect(bloc.state.totalProtein, 8);
    expect(bloc.state.dayKcalConsumed, 800);
    expect(find.text('Item updated'), findsOneWidget);
    final displayed = tester
        .widget<MealDetailNutrimentsTable>(
          find.byType(MealDetailNutrimentsTable),
        )
        .product;
    expect(displayed.nutriments.energyKcal100, 200);
    expect(fixture.cached.nutriments.energyKcal100, 200);
    expect(fixture.meals.length, 2);
    expect(
      fixture.cache
          .getDetailedByBarcode('other-product')!
          .nutriments
          .energyKcal100,
      100,
    );
    expect(fixture.requests.single.url.path, contains(refreshBarcode));
    // Same name/code again: equality must not suppress the second refresh.
    fixture.respond = (_) async => ProductRefreshFixture.success(kcal: 300);
    await tester.tap(refreshButton);
    await tester.pump();
    await pumpUntil(tester, () => !bloc.state.isRefreshing);
    expect(bloc.state.mealRevision, 2);
    expect(bloc.state.totalKcal, 225);
    expect(fixture.cached.nutriments.energyKcal100, 300);
    final scanned = await fixture.scanAgain();
    expect(scanned.nutriments.energyKcal100, 300);
    expect(fixture.requests, hasLength(2));
  });

  refreshTest('removed serving falls back to the previous base quantity', (
    tester,
  ) async {
    fixture.respond = (_) async => ProductRefreshFixture.success(serving: null);
    await mount(tester);
    quantity(tester).text = '2';
    await tester.pumpAndSettle();
    await tester.tap(refreshButton);
    await tester.pump();
    await pumpUntil(tester, () => !fixture.bloc!.state.isRefreshing);
    await tester.pumpAndSettle();
    expect(fixture.bloc!.state.selectedUnit, 'g/ml');
    expect(quantity(tester).text, '60.0');
    expect(fixture.bloc!.state.totalKcal, 120);
    expect(tester.takeException(), isNull);
  });

  refreshTest('not-found failure keeps product, selection, totals and cache; '
      'retry succeeds', (tester) async {
    fixture.respond = (_) async => http.Response('{}', 404);
    await mount(tester);
    final cachedBefore = fixture.cached.toJson();
    final timestampsBefore = fixture.timestamps.toMap();
    await tester.tap(refreshButton);
    await tester.pump();
    await pumpUntil(tester, () => !fixture.bloc!.state.isRefreshing);
    expect(find.text('Error while fetching product data'), findsOneWidget);
    expect(fixture.bloc!.state.totalKcal, 30);
    expect(quantity(tester).text, '1');
    expect(fixture.cached.toJson(), cachedBefore);
    expect(fixture.timestamps.toMap(), timestampsBefore);
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNotNull);
    fixture.respond = (_) async => ProductRefreshFixture.success();
    await tester.tap(refreshButton);
    await tester.pump();
    await pumpUntil(tester, () => !fixture.bloc!.state.isRefreshing);
    expect(fixture.bloc!.state.totalKcal, 60);
  });

  refreshTest('custom products have no refresh action', (tester) async {
    await mount(tester, MealEntity.empty());
    expect(refreshButton, findsNothing);
    fixture.bloc!.add(RefreshMealEvent(MealEntity.empty()));
    await tester.pump();
    expect(fixture.requests, isEmpty);
  });
  refreshTest('OFF product without a barcode has no refresh action', (
    tester,
  ) async {
    final meal = MealEntity.fromOFFProduct(
      OFFProductDTO.fromJson(refreshProduct(code: '')),
      detailed: true,
    );
    await mount(tester, meal);
    expect(refreshButton, findsNothing);
    fixture.bloc!.add(RefreshMealEvent(meal));
    await tester.pump();
    expect(fixture.requests, isEmpty);
  });

  refreshTest('raw ounces survive refresh and a removed weight unit '
      'falls back to the equivalent base quantity', (tester) async {
    fixture.respond = (_) async => ProductRefreshFixture.success();
    await mount(tester);
    final bloc = fixture.bloc!;
    final sheet = tester.widget<MealDetailBottomSheet>(
      find.byType(MealDetailBottomSheet),
    );
    quantity(tester).text = '2';
    sheet.onQuantityOrUnitChanged('2', 'oz');
    await tester.pumpAndSettle();
    await tester.tap(refreshButton);
    await tester.pump();
    await pumpUntil(tester, () => !bloc.state.isRefreshing);
    expect(bloc.state.selectedUnit, 'oz');
    expect(quantity(tester).text, '2');
    expect(bloc.state.totalKcal, closeTo(113.398, 0.001));
    fixture.respond = (_) async =>
        ProductRefreshFixture.success(quantity: '300 ml', serving: null);
    await tester.tap(refreshButton);
    await tester.pump();
    await pumpUntil(tester, () => !bloc.state.isRefreshing);
    expect(bloc.state.selectedUnit, 'g/ml');
    expect(double.parse(quantity(tester).text), closeTo(56.699, 0.001));
    expect(bloc.state.totalKcal, closeTo(113.398, 0.001));
    expect(tester.takeException(), isNull);
  });
}
