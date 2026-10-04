library;

import 'package:collection/collection.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/util/soft_text_score.dart';

/// Quality tie-breakers, matching the shared ranker so that near-equal text
/// matches resolve the same way in both places.
const _detailedBonus = 0.03;

const noPortionsPenalty = 0.15;

double scoreMealForResolution(MealEntity meal, String query) {
  final queryTokens = tokenize(query);
  if (queryTokens.isEmpty) return 0.0;

  final nameScore = scoreText(
    meal.scoringName,
    queryTokens,
    qualifiers: meal.scoringQualifiers,
  );
  final brandScore = scoreText(meal.brands, queryTokens);
  var score = nameScore >= brandScore ? nameScore : brandScore * 0.6;

  if (meal.detailed) score += _detailedBonus;

  if (meal.source == MealSourceEntity.fdc &&
      meal.portions.isEmpty &&
      !meal.portionsUnavailable) {
    score -= noPortionsPenalty;
  }

  return score.clamp(0.0, 1.0);
}

/// Re-orders [meals] for the resolver, **preserving the own-content tier**
/// that `mergeAndRankMeals` established — the user's own custom meals and
/// recipes stay ahead of remote results regardless of score, and only the
/// order *within* each tier is recomputed.
///
/// Equal scores are broken by the length of the description, then by the
/// number of labelled portions, and then the sort is stable, so what is
/// left of a tie keeps the order the shared ranker left it in — see
/// [_sorted].
List<MealEntity> rankForResolution(List<MealEntity> meals, String query) {
  final own = <MealEntity>[];
  final rest = <MealEntity>[];
  for (final meal in meals) {
    final isOwn =
        meal.source == MealSourceEntity.custom ||
        meal.source == MealSourceEntity.recipe;
    (isOwn ? own : rest).add(meal);
  }
  return [..._sorted(own, query), ..._sorted(rest, query)];
}

List<MealEntity> _sorted(List<MealEntity> meals, String query) {
  // Parallel (meal, score) records rather than a map: MealEntity's Equatable
  // props are just [code, name], so two rows from different sources can
  // compare equal and would collide on a map key.
  final decorated = [
    for (final meal in meals)
      (meal: meal, score: scoreMealForResolution(meal, query)),
  ];
  mergeSort(
    decorated,
    compare: (a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // The name, not the title that was scored. Siblings that reach this key
      // share a title — every "Milk" is "Milk" — so its length says nothing;
      // the description is where they differ, and the shorter one is the
      // less qualified: "Milk, NFS" before "Milk, whole".
      final byLength = (a.meal.name ?? '').length.compareTo(
        (b.meal.name ?? '').length,
      );
      if (byLength != 0) return byLength;
      return b.meal.portions.length.compareTo(a.meal.portions.length);
    },
  );
  return [for (final entry in decorated) entry.meal];
}
