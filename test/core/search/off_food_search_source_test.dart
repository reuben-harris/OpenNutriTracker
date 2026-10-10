import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/search/off_food_search_source.dart';

Map<String, dynamic> product(String code, {Map<String, dynamic>? nutrients}) =>
    {
      'code': code,
      'product_name': 'Orange',
      'product_name_de': 'Orange DE',
      'nutriments':
          nutrients ??
          {
            'energy-kcal_100g': 50,
            'carbohydrates_100g': 10,
            'sugars_100g': 5,
            'fat_100g': 0,
            'proteins_100g': 1,
          },
    };

class Client extends MockClient {
  Client(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test(
    'requests ten, explicit page, language and User-Agent without extra ranking fields',
    () async {
      late http.Request request;
      final client = Client((r) async {
        request = r;
        return http.Response(
          jsonEncode({
            'hits': [product('1')],
            'page_count': 4,
          }),
          200,
        );
      });
      final source = OffFoodSearchSource(
        clientFactory: () => client,
        userAgent: () async => 'ONT test',
      );
      final page = await source
          .search('orange', language: 'de', page: 2)
          .result;
      expect(request.url.host, 'search.openfoodfacts.org');
      expect(request.url.queryParameters['page_size'], '10');
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['langs'], 'de,en');
      expect(request.headers['User-Agent'], 'ONT test');
      expect(
        request.url.queryParameters['fields'],
        isNot(contains('popularity_key')),
      );
      expect(page.meals.single.name, 'Orange DE');
      expect(page.hasMore, isTrue);
      expect(client.closed, isTrue);
    },
  );
  for (final response in [
    http.Response('{}', 503),
    http.Response('invalid', 200),
    http.Response('{"hits":[],"timed_out":true}', 200),
    http.Response('{"products":[]}', 200),
  ]) {
    test(
      'failure makes one request with no fallback: ${response.body}/${response.statusCode}',
      () async {
        var calls = 0;
        final client = Client((_) async {
          calls++;
          return response;
        });
        final source = OffFoodSearchSource(
          clientFactory: () => client,
          userAgent: () async => 'ONT test',
        );
        await expectLater(
          source.search('orange', language: 'en').result,
          throwsA(anything),
        );
        expect(calls, 1);
        expect(client.closed, isTrue);
      },
    );
  }
  test('timeout closes the client without retrying', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final client = Client((_) {
      calls++;
      return pending.future;
    });
    final source = OffFoodSearchSource(
      clientFactory: () => client,
      userAgent: () async => 'ONT test',
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      source.search('orange', language: 'en').result,
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 1);
    expect(client.closed, isTrue);
    pending.complete(http.Response('{"hits":[]}', 200));
  });
  test(
    'upstream pagination survives dropping invalid nutrient records',
    () async {
      final client = Client(
        (_) async => http.Response(
          jsonEncode({
            'hits': [
              product(
                'bad',
                nutrients: {'carbohydrates_100g': 5, 'sugars_100g': 25},
              ),
            ],
            'page_count': 2,
          }),
          200,
        ),
      );
      final source = OffFoodSearchSource(
        clientFactory: () => client,
        userAgent: () async => 'ONT test',
      );
      final page = await source.search('orange', language: 'en').result;
      expect(page.meals, isEmpty);
      expect(page.hasMore, isTrue);
    },
  );
  test('cancellation closes the dedicated request client', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final client = Client((_) {
      started.complete();
      return pending.future;
    });
    final call = OffFoodSearchSource(
      clientFactory: () => client,
      userAgent: () async => 'ONT test',
    ).search('orange', language: 'en');
    await started.future;
    call.cancel();
    expect(client.closed, isTrue);
    pending.complete(http.Response('{"hits":[]}', 200));
    await call.result;
  });
}
