import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';
import 'package:opennutritracker/core/utils/supported_language.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/off_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// English food requests and generic translation behavior.
void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'ont-test',
      packageName: 'test',
      version: '0.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(AppLocale.reset);

  const chosen = 'de';
  const chosenProduct = 'Brot';

  test('production food requests default to English', () {
    expect(AppLocale.localeName, 'en');
  });

  group('what follows the chosen language', () {
    test('the Open Food Facts word search asks for it under langs', () async {
      AppLocale.select(chosen);
      Uri? requested;
      final dataSource = OFFDataSource(
        clientFactory: () => MockClient((request) async {
          requested ??= request.url;
          return http.Response(
            jsonEncode({'hits': [], 'count': 0, 'page': 1, 'page_size': 100}),
            200,
          );
        }),
      );

      await dataSource.fetchSearchWordResults('brot');

      expect(requested!.queryParameters['langs'], '$chosen,en');
    });

    test('an Open Food Facts product is named in it', () {
      AppLocale.select(chosen);
      final product = OFFProductDTO(
        code: '1',
        product_name: 'Bread',
        product_name_en: 'Bread',
        product_name_fr: 'Pain',
        product_name_de: 'Brot',
        product_name_it: 'Pane',
        brands: null,
        image_front_thumb_url: null,
        image_front_url: null,
        image_ingredients_url: null,
        image_nutrition_url: null,
        image_url: null,
        url: null,
        quantity: null,
        product_quantity: null,
        serving_quantity: null,
        serving_size: null,
        nutriments: null,
      );

      expect(MealEntity.fromOFFProduct(product).name, chosenProduct);
      expect(SupportedLanguage.fromCode(AppLocale.localeName).name, chosen);
    });
  });
}
