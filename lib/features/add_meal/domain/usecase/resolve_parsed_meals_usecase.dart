import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/util/meal_text_parser.dart';
import 'package:opennutritracker/features/add_meal/util/resolver_relevance.dart';

const kResolutionConfidenceFloor = 0.45;

/// One parsed item and what the food search made of it.
///
/// [candidates] is ranked best-first and may be empty — an item the search
/// could not resolve is returned unresolved rather than dropped, so the
/// review screen can show it and let the user fix or skip it. A silent drop
/// is the one failure mode that loses data without telling anyone.
class ResolvedMealItem {
  final ParsedMealItem parsed;
  final List<MealEntity> candidates;
  final int selectedIndex;

  /// Score of the selected candidate, 0.0-1.0. Zero when unresolved.
  final double confidence;

  const ResolvedMealItem({
    required this.parsed,
    required this.candidates,
    required this.selectedIndex,
    required this.confidence,
  });

  bool get isResolved => candidates.isNotEmpty;

  MealEntity? get selected => isResolved ? candidates[selectedIndex] : null;

  /// True when a match was found but is weak enough that the review screen
  /// should flag it rather than presenting it as settled.
  bool get isLowConfidence =>
      isResolved && confidence < kResolutionConfidenceFloor;

  @override
  String toString() =>
      'ResolvedMealItem(query: ${parsed.query}, candidates: ${candidates.length}, '
      'confidence: ${confidence.toStringAsFixed(2)})';
}

/// Turns the parser's search intents into real food-database entries,
/// reusing the existing search stack rather than adding a new one.
///
/// Both tiers of #599 converge here: the tier-0 parser emits
/// `(query, quantity, unit)` and never a nutrient estimate, and a future
/// model client would emit the same shape plus a fallback macro payload
/// consulted **only** on a database miss. This class deliberately has no
/// fallback path yet — tier 1 is not scoped — but the unresolved item is
/// the seam where one would attach.
class ResolveParsedMealsUseCase {
  final _log = Logger('ResolveParsedMealsUseCase');

  final SearchProductsUseCase _searchProductsUseCase;

  ResolveParsedMealsUseCase(this._searchProductsUseCase);

  /// Resolves items concurrently using product search and its local fallback.
  Future<List<ResolvedMealItem>> resolve(List<ParsedMealItem> items) async {
    if (items.isEmpty) return const [];
    return Future.wait(items.map(_resolveOne));
  }

  /// A source that fails contributes nothing instead of failing the item.
  Future<List<MealEntity>> _search(
    Future<SearchProductsResult> Function() run,
  ) async {
    try {
      return (await run()).meals;
    } catch (e, stackTrace) {
      _log.warning(
        'A food source failed during bulk resolution',
        e,
        stackTrace,
      );
      return const [];
    }
  }

  Future<ResolvedMealItem> _resolveOne(ParsedMealItem item) async {
    final query = item.query;

    final merged = await _search(
      () => _searchProductsUseCase.searchOFFProductsByString(query),
    );

    // Then re-order within those tiers with the inflection-tolerant score.
    // The shared ranker scores `eggs` against `Egg` at exactly 0.0, and
    // this class auto-selects the top candidate, so its ordering alone is
    // not safe to log from. See resolver_relevance.dart.
    final ranked = rankForResolution(merged, query);

    if (ranked.isEmpty) {
      return ResolvedMealItem(
        parsed: item,
        candidates: const [],
        selectedIndex: 0,
        confidence: 0.0,
      );
    }

    return ResolvedMealItem(
      parsed: item,
      candidates: ranked,
      selectedIndex: 0,
      confidence: scoreMealForResolution(ranked.first, query),
    );
  }
}
