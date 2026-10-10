import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';

import '../helpers/product_refresh_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProductRefreshFixture fixture;
  late MealDetailBloc bloc;
  setUp(() async {
    fixture = ProductRefreshFixture();
    await fixture.open();
    bloc = fixture.createBloc();
  });
  tearDown(() async {
    await bloc.close();
    await fixture.close();
  });

  for (final failOldHydration in [false, true]) {
    test(
      'late hydration (failure=$failOldHydration) cannot overwrite refresh',
      () async {
        await fixture.cache.clear();
        final older = Completer<http.Response>();
        final started = Completer<void>();
        fixture.respond = (_) {
          if (fixture.requests.length == 1) {
            started.complete();
            return older.future;
          }
          return Future.value(ProductRefreshFixture.success(kcal: 300));
        };
        bloc.add(HydrateMealEvent(refreshMeal(detailed: false)));
        await started.future;
        final refreshed = bloc.stream.firstWhere(
          (s) => s.refreshStatus == ProductRefreshStatus.success,
        );
        bloc.add(RefreshMealEvent(refreshMeal(detailed: false)));
        await refreshed;
        older.complete(
          failOldHydration
              ? http.Response('{}', 404)
              : ProductRefreshFixture.success(kcal: 100),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(bloc.state.hydratedMeal!.nutriments.energyKcal100, 300);
        expect((await fixture.cached).nutriments.energyKcal100, 300);
        expect(bloc.state.isHydrating, isFalse);
        expect(bloc.state.mealRevision, 1);
        expect(fixture.requests, hasLength(2));
      },
    );
  }

  for (final entry in {
    'malformed JSON': http.Response('invalid JSON', 200),
    'HTTP 503': http.Response('{}', 503),
    'HTTP 200 with not-found status': http.Response(
      jsonEncode({
        'status': 0,
        'status_verbose': 'product not found',
        'product': refreshProduct(),
      }),
      200,
    ),
  }.entries) {
    test('${entry.key} leaves the cache intact', () async {
      fixture.respond = (_) async => entry.value;
      final original = jsonEncode((await fixture.cached).toJson());
      final failed = bloc.stream.firstWhere(
        (s) => s.refreshStatus == ProductRefreshStatus.failure,
      );
      bloc.add(RefreshMealEvent(refreshMeal()));
      await failed;
      expect(jsonEncode((await fixture.cached).toJson()), original);
      expect(bloc.state.hydratedMeal, isNull);
    });
  }

  test(
    'closing the detail page while refreshing does not publish late data',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      fixture.respond = (_) {
        started.complete();
        return response.future;
      };
      bloc.add(RefreshMealEvent(refreshMeal()));
      await started.future;
      final closing = bloc.close();
      response.complete(ProductRefreshFixture.success());
      await closing;
      expect((await fixture.cached).nutriments.energyKcal100, 100);
    },
  );
}
