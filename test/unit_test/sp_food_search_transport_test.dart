import 'package:opennutritracker/core/utils/app_locale.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/sp_food_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/hive_test_setup.dart';

/// Records every request the Supabase client makes and answers each one with
/// an empty PostgREST result set.
class _RecordingClient extends http.BaseClient {
  final sent = <http.Request>[];
  List<Map<String, dynamic>> rows = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    sent.add(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(rows))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

/// `_readMerged` reads both the shared app config and the active profile's
/// own, so both getters have to answer.
class _TestHiveDBProvider extends HiveDBProvider {
  final Box<ConfigDBO> shared;
  final Box<ConfigDBO> profile;
  _TestHiveDBProvider(this.shared, this.profile);

  @override
  Box<ConfigDBO> get appConfigBox => shared;

  @override
  Box<ConfigDBO> get configBox => profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingClient http_;
  late Box<ConfigDBO> appConfigBox;
  late Box<ConfigDBO> profileConfigBox;

  setUp(() async {
    Hive.init('.');
    registerHiveAdaptersOnce();
    final tag = DateTime.now().microsecondsSinceEpoch;
    appConfigBox = await Hive.openBox<ConfigDBO>('sp_transport_app_$tag');
    profileConfigBox = await Hive.openBox<ConfigDBO>('sp_transport_cfg_$tag');

    http_ = _RecordingClient();
    if (locator.isRegistered<SupabaseClient>()) {
      locator.unregister<SupabaseClient>();
    }
    if (locator.isRegistered<ConfigDataSource>()) {
      locator.unregister<ConfigDataSource>();
    }
    locator.registerSingleton<SupabaseClient>(
      SupabaseClient('http://backend.invalid', 'test-key', httpClient: http_),
    );
    locator.registerSingleton<ConfigDataSource>(
      ConfigDataSource(_TestHiveDBProvider(appConfigBox, profileConfigBox)),
    );
  });

  tearDown(() async {
    AppLocale.reset();
    locator.unregister<SupabaseClient>();
    locator.unregister<ConfigDataSource>();
    await Hive.deleteFromDisk();
  });

  test(
    'refresh lookup posts exact food ID and verifies database provenance',
    () async {
      AppLocale.select('en');
      http_.rows = [
        {
          'food_id': 42,
          'source': 'bls',
          'source_code': 'B001',
          'name': 'Food',
          'energy_kcal_per_100g': null,
        },
      ];
      final result = await SpFoodDataSource().fetchFoodById(42, 'bls');
      expect(result?.foodId, 42);
      expect(result?.source, 'bls');
      expect(http_.sent.single.method, 'POST');
      expect(http_.sent.single.url.path, '/rest/v1/rpc/food_summary_by_ids');
      expect(jsonDecode(http_.sent.single.body), {
        'ids': [42],
        'sources': ['bls'],
      });
      http_.rows = [
        {'food_id': 42, 'source': 'fdc_sr_legacy', 'name': 'Wrong database'},
      ];
      expect(await SpFoodDataSource().fetchFoodById(42, 'bls'), isNull);
      http_.rows = [
        {'food_id': 43, 'source': 'bls', 'name': 'Wrong food'},
      ];
      expect(await SpFoodDataSource().fetchFoodById(42, 'bls'), isNull);
    },
  );

  // A term that cannot occur by accident in a URL, so a substring match on it
  // is a real signal rather than a coincidence.
  const term = 'zzsearchtermzz';

  test('a search term never reaches the URL', () async {
    // The point of #882. PostgREST issues a table query as a GET, so
    // `.textSearch(...)` put the term in the query string — and the Supabase
    // gateway log keeps that URL beside the caller's IP, city, postal code,
    // ISP and TLS fingerprint. Asserting on the wire rather than on which
    // method was called is deliberate: the property that matters is where the
    // term ends up, not how the client was configured to put it there.
    await SpFoodDataSource().fetchSearchWordResults(term);

    expect(http_.sent, isNotEmpty, reason: 'no request was made at all');
    for (final request in http_.sent) {
      expect(
        request.url.toString(),
        isNot(contains(term)),
        reason: 'term found in URL: ${request.url}',
      );
      expect(
        Uri.decodeFull(request.url.toString()),
        isNot(contains(term)),
        reason: 'term found percent-encoded in URL: ${request.url}',
      );
    }
  });

  test(
    'every backend call is a POST to an rpc endpoint with no query',
    () async {
      // A filter chained onto an RPC still travels in the query string, so
      // "we switched to rpc" is not on its own enough — the URL has to stay
      // bare. This is what would fail if someone reintroduced `.limit()` or
      // `.inFilter()` on one of these calls.
      await SpFoodDataSource().fetchSearchWordResults(term);

      for (final request in http_.sent) {
        expect(request.method, 'POST', reason: '${request.url}');
        expect(
          request.url.path,
          startsWith('/rest/v1/rpc/'),
          reason: '${request.url}',
        );
        expect(request.url.query, isEmpty, reason: '${request.url}');
      }
    },
  );

  test('the term travels in the request body instead', () async {
    // The other half: it has to still be sent, or the search is broken
    // rather than private.
    await SpFoodDataSource().fetchSearchWordResults(term);

    final bodies = http_.sent.map((r) => jsonDecode(r.body) as Map).toList();
    expect(bodies, isNotEmpty);
    expect(
      bodies.any((b) => b['term'] == term),
      isTrue,
      reason: 'no request body carried the term: $bodies',
    );
  });
}
