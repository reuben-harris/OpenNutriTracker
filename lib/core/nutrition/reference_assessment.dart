import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';

enum ReferenceRangeState {
  unavailable,
  below,
  within,
  above,
  adequate,
  belowUpper,
}

class ReferenceAssessment {
  final NutrientAmount? intake;
  final NutrientReferenceRange range;
  const ReferenceAssessment(this.intake, this.range);
  double? percentage(PublishedReference? threshold) =>
      intake?.isFinite == true &&
          threshold?.comparable == true &&
          threshold!.amount > 0
      ? intake!.calculationValue / threshold.amount
      : null;
  ReferenceRangeState get state {
    if (intake?.isFinite != true || intake!.isQualified || intake!.isPartial) {
      return ReferenceRangeState.unavailable;
    }
    final a = range.adequacy?.comparable == true ? range.adequacy : null;
    final u = range.upper?.comparable == true ? range.upper : null;
    final amount = intake!.calculationValue;
    if (u != null && amount > u.amount) return ReferenceRangeState.above;
    if (a != null && amount < a.amount) return ReferenceRangeState.below;
    if (a != null && u != null) return ReferenceRangeState.within;
    if (a != null) return ReferenceRangeState.adequate;
    if (u != null) return ReferenceRangeState.belowUpper;
    return ReferenceRangeState.unavailable;
  }
}
