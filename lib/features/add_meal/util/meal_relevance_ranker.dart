import 'package:collection/collection.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

double scoreMealRelevance(MealEntity meal, String query) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) return 0.0;

  final nameScore = _textScore(
    meal.scoringName,
    normalizedQuery,
    qualifiers: meal.scoringQualifiers,
  );
  final brandScore = _textScore(meal.brands, normalizedQuery);
  // Brand-only matches (e.g. searching "nestle") still surface the product,
  // but count for less than the same match on the name itself.
  var score = nameScore >= brandScore ? nameScore : brandScore * 0.6;

  // Small, non-decisive tie-breakers so that among near-equal text matches,
  // the more trustworthy/complete result edges ahead.
  if (meal.detailed) score += 0.03;

  return score.clamp(0.0, 1.0);
}

List<MealEntity> rankMealsByRelevance(List<MealEntity> meals, String query) {
  final decorated = [
    for (final meal in meals)
      (meal: meal, score: scoreMealRelevance(meal, query)),
  ];
  mergeSort(decorated, compare: (a, b) => b.score.compareTo(a.score));
  return [for (final entry in decorated) entry.meal];
}

List<MealEntity> mergeAndRankMeals(
  List<MealEntity> a,
  List<MealEntity> b,
  String query,
) {
  final own = <MealEntity>[];
  final rest = <MealEntity>[];
  for (final meal in _deduplicateAcrossSources([...a, ...b])) {
    final isOwn =
        meal.source == MealSourceEntity.custom ||
        meal.source == MealSourceEntity.recipe;
    (isOwn ? own : rest).add(meal);
  }
  final collapsedRest = _collapseNearDuplicates(rest, query);
  return [
    ...rankMealsByRelevance(own, query),
    ...rankMealsByRelevance(collapsedRest, query),
  ];
}

List<MealEntity> _deduplicateAcrossSources(List<MealEntity> meals) {
  final seenKeys = <String>{};
  final uniqueMeals = <MealEntity>[];
  for (final meal in meals) {
    final key = meal.source == MealSourceEntity.fdc
        ? '${meal.source.name}:${meal.code ?? identityHashCode(meal)}'
        : '${meal.source.name}:${meal.code ?? meal.name ?? ''}';
    if (seenKeys.add(key)) uniqueMeals.add(meal);
  }
  return uniqueMeals;
}

List<MealEntity> _collapseNearDuplicates(List<MealEntity> meals, String query) {
  final groupOrder = <String>[];
  final groups = <String, List<MealEntity>>{};
  for (final meal in meals) {
    final key = _nearDuplicateKey(meal);
    if (!groups.containsKey(key)) groupOrder.add(key);
    groups.putIfAbsent(key, () => []).add(meal);
  }
  return [for (final key in groupOrder) _highestScoring(groups[key]!, query)];
}

String _nearDuplicateKey(MealEntity meal) {
  if (meal.source != MealSourceEntity.off) {
    return 'single:${meal.source.name}:${meal.code ?? identityHashCode(meal)}';
  }
  final name = _normalize(meal.name);
  // No name to match on — key on identity instead of an empty string, which
  // would otherwise collapse every unrelated nameless meal into one.
  // meal.code is nullable: fall back to identityHashCode so two distinct
  // nameless meals without codes don't share the same key.
  if (name.isEmpty) {
    return 'noname:${meal.source.name}:${meal.code ?? identityHashCode(meal)}';
  }
  final brand = _normalize(meal.brands);
  return brand.isEmpty ? name : '$name|$brand';
}

MealEntity _highestScoring(List<MealEntity> group, String query) {
  var best = group.first;
  var bestScore = scoreMealRelevance(best, query);
  for (final meal in group.skip(1)) {
    final score = scoreMealRelevance(meal, query);
    if (score > bestScore) {
      best = meal;
      bestScore = score;
    }
  }
  return best;
}

double _textScore(String? text, String normalizedQuery, {String? qualifiers}) {
  final normalizedText = _normalize(text);
  if (normalizedText.isEmpty) return 0.0;
  if (normalizedText == normalizedQuery) return 1.0;

  final queryTokens = _tokenize(normalizedQuery);
  final textTokens = {
    ..._tokenize(normalizedText),
    ..._tokenize(_normalize(qualifiers)).intersection(queryTokens),
  };
  final overlap = _diceCoefficient(textTokens, queryTokens);

  final containsBonus = normalizedText.contains(normalizedQuery) ? 0.2 : 0.0;
  final prefixBonus = normalizedText.startsWith(normalizedQuery) ? 0.15 : 0.0;

  return (overlap + containsBonus + prefixBonus).clamp(0.0, 0.9);
}

String _normalize(String? text) =>
    text?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';

Set<String> _tokenize(String normalizedText) => normalizedText
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((token) => token.isNotEmpty)
    .toSet();

/// 2 * |intersection| / (|a| + |b|), the standard token-set similarity
/// measure — cheap to compute and, unlike edit distance, order-independent
/// so "milk chocolate" and "chocolate milk" score identically.
double _diceCoefficient(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final intersectionSize = a.intersection(b).length;
  return 2 * intersectionSize / (a.length + b.length);
}
