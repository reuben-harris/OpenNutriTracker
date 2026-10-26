import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum NutrientView {
  adequacy,
  upper,
  noGoal,
  all;

  String label(S s) => switch (this) {
    adequacy => s.nutrientAdequacy,
    upper => s.nutrientUpperLevels,
    noGoal => s.nutrientViewNoGoal,
    all => s.nutrientViewAll,
  };
  bool includes(NutrientReferenceRange? range) => switch (this) {
    adequacy => range?.adequacy != null,
    upper => range?.upper != null,
    noGoal => !(range?.hasGoal ?? false),
    all => true,
  };
  PublishedReference? threshold(NutrientReferenceRange? range) =>
      switch (this) {
        adequacy => range?.adequacy,
        upper => range?.upper,
        noGoal => null,
        all =>
          range?.adequacy?.comparable == true
              ? range!.adequacy
              : range?.upper?.comparable == true
              ? range!.upper
              : null,
      };
}
