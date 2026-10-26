import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';

class NutrientReferenceRange {
  final ReferenceSelection? reference;
  final PublishedReference? adequacy, upper;
  final String? unavailable;
  final bool frozen;
  final DateTime? frozenOn;
  const NutrientReferenceRange({
    this.reference,
    this.adequacy,
    this.upper,
    this.unavailable,
    this.frozen = false,
    this.frozenOn,
  });
  bool get hasGoal => adequacy != null || upper != null;
  PublishedReference? get primary => adequacy ?? upper;
  bool get contradictory =>
      adequacy != null &&
      upper != null &&
      adequacy!.comparable &&
      upper!.comparable &&
      adequacy!.amount > upper!.amount &&
      (adequacy!.term == 'custom-target' || upper!.term == 'custom-upper');
}

class NutrientGoalResolver {
  static ReferenceSelection reference({
    required String nutrient,
    required NutrientPolicy policy,
    required UserEntity user,
    required DateTime day,
    Iterable<WeightLogEntity> weights = const [],
  }) {
    final date = DateTime(day.year, day.month, day.day);
    final eligible =
        weights
            .where(
              (w) => !DateTime(
                w.date.year,
                w.date.month,
                w.date.day,
              ).isAfter(date),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return ReferenceCatalogue.lookup(
      region: policy.region,
      nutrient: nutrient,
      age: user.ageOn(date),
      sex: user.sex,
      stage: user.lifeStageOn(date),
      weightKg: eligible.firstOrNull?.weightKg,
    );
  }

  static NutrientPolicy freeze({
    required String nutrient,
    required NutrientPolicy policy,
    required UserEntity user,
    required DateTime today,
    Iterable<WeightLogEntity> weights = const [],
  }) => policy.copyWith(
    autoAdjust: false,
    frozen: reference(
      nutrient: nutrient,
      policy: policy,
      user: user,
      day: today,
      weights: weights,
    ),
    frozenOn: DateTime(today.year, today.month, today.day),
  );

  static Map<String, NutrientReferenceRange> resolve({
    UserEntity? user,
    required DateTime day,
    Iterable<WeightLogEntity> weights = const [],
    Map<String, NutrientPolicy>? policies,
  }) => {
    for (final nutrient in Nutrients.additional)
      nutrient.key: resolveOne(
        nutrient: nutrient.key,
        policy:
            policies?[nutrient.key] ??
            user?.nutrientPolicies[nutrient.key] ??
            const NutrientPolicy(),
        user: user,
        day: day,
        weights: weights,
      ),
  };
  static NutrientReferenceRange resolveOne({
    required String nutrient,
    required NutrientPolicy policy,
    UserEntity? user,
    required DateTime day,
    Iterable<WeightLogEntity> weights = const [],
  }) {
    if (!policy.valid) {
      return const NutrientReferenceRange(unavailable: 'policy');
    }
    final selected = !policy.autoAdjust
        ? policy.frozenReference == null
              ? null
              : ReferenceSelection.fromJson(policy.frozenReference!)
        : user == null
        ? null
        : reference(
            nutrient: nutrient,
            policy: policy,
            user: user,
            day: day,
            weights: weights,
          );
    PublishedReference? threshold(
      ThresholdMode mode,
      bool upper,
      double? custom,
    ) => switch (mode) {
      ThresholdMode.unset => null,
      ThresholdMode.custom => PublishedReference(
        amount: custom!,
        term: upper ? 'custom-upper' : 'custom-target',
        unit: Nutrients.byKey[nutrient]!.unit,
        definition: nutrient,
        table: 'custom',
        upper: upper,
      ),
      ThresholdMode.reference =>
        selected?.values.where((r) => r.upper == upper).firstOrNull,
    };
    return NutrientReferenceRange(
      reference: selected,
      adequacy: threshold(policy.adequacyMode, false, policy.target),
      upper: threshold(policy.upperMode, true, policy.upper),
      unavailable:
          selected?.gap ??
          (selected == null
              ? (policy.autoAdjust ? 'profile' : 'frozen')
              : null),
      frozen: !policy.autoAdjust,
      frozenOn: policy.frozenOn,
    );
  }
}
