import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/core/utils/supported_language.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_word_response_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

class OffFoodSearchPage {
  const OffFoodSearchPage(this.meals, {required this.hasMore});
  final List<MealEntity> meals;
  final bool hasMore;
}

class OffFoodSearchCall {
  OffFoodSearchCall(this.result, this.cancel);
  final Future<OffFoodSearchPage> result;
  final void Function() cancel;
}

/// A single cancellable Search-a-licious request. No classic fallback or retry.
class OffFoodSearchSource {
  OffFoodSearchSource({
    http.Client Function()? clientFactory,
    Future<String> Function()? userAgent,
    this.timeout = const Duration(seconds: 8),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _userAgent = userAgent ?? AppConst.getUserAgentString;
  final http.Client Function() _clientFactory;
  final Future<String> Function() _userAgent;
  final Duration timeout;
  static const pageSize = 10;

  OffFoodSearchCall search(
    String query, {
    required String language,
    int page = 1,
  }) {
    final client = _clientFactory();
    var cancelled = false;
    void cancel() {
      cancelled = true;
      client.close();
    }

    Future<OffFoodSearchPage> fetch() async {
      try {
        final agent = await _userAgent();
        if (cancelled) throw StateError('Search cancelled');
        final lang = SupportedLanguage.fromCode(language);
        final response = await client
            .get(
              OFFConst.getOffWordSearchUrl(
                query,
                langs: lang.name == 'en' ? 'en' : '${lang.name},en',
                page: page,
                pageSize: pageSize,
                relevanceOnly: true,
              ),
              headers: {'User-Agent': agent},
            )
            .timeout(timeout);
        if (response.statusCode != 200) {
          throw http.ClientException('OFF HTTP ${response.statusCode}');
        }
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['hits'] is! List ||
            json['timed_out'] == true ||
            json.containsKey('errors')) {
          throw const FormatException('Incomplete OFF search response');
        }
        final result = OFFWordResponseDTO.fromJson(json);
        final meals =
            [
                  for (final dto in result.products)
                    MealEntity.fromOFFProduct(dto, language: lang),
                ]
                .where(
                  (m) =>
                      (m.code?.isNotEmpty ?? false) &&
                      validateNutriments(m.nutriments).isConsistent,
                )
                .toList();
        final pages = int.tryParse('${json['page_count']}');
        final count = int.tryParse('${json['count']}');
        final hasMore = pages != null
            ? page < pages
            : count != null
            ? page * pageSize < count
            : result.products.length == pageSize;
        return OffFoodSearchPage(meals, hasMore: hasMore);
      } finally {
        client.close();
      }
    }

    return OffFoodSearchCall(fetch(), cancel);
  }
}
