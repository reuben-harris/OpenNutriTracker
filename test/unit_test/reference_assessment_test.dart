import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_view.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/nutrition/reference_assessment.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';

const a = PublishedReference(
  amount: 10,
  term: 'AI',
  unit: 'mg',
  definition: 'test',
  table: 'test',
);
const u = PublishedReference(
  amount: 20,
  term: 'UL',
  unit: 'mg',
  definition: 'test',
  table: 'test',
  upper: true,
);
void main() {
  test('simultaneous thresholds appear in both filters and once in All', () {
    const both = NutrientReferenceRange(adequacy: a, upper: u);
    expect(NutrientView.adequacy.includes(both), isTrue);
    expect(NutrientView.upper.includes(both), isTrue);
    expect(NutrientView.noGoal.includes(both), isFalse);
    expect(NutrientView.all.threshold(both), a);
    expect(
      NutrientView.all.threshold(const NutrientReferenceRange(upper: u)),
      u,
    );
    expect(
      NutrientView.noGoal.includes(const NutrientReferenceRange()),
      isTrue,
    );
  });
  test('range bounds are inclusive; excess only above upper', () {
    const range = NutrientReferenceRange(adequacy: a, upper: u);
    for (final (amount, state) in [
      (0.0, ReferenceRangeState.below),
      (10.0, ReferenceRangeState.within),
      (20.0, ReferenceRangeState.within),
      (20.1, ReferenceRangeState.above),
    ]) {
      expect(ReferenceAssessment(NutrientAmount(amount), range).state, state);
    }
    expect(
      const ReferenceAssessment(NutrientAmount(15), range).percentage(a),
      1.5,
    );
  });
  test('single thresholds, missing and zero remain distinct', () {
    expect(
      const ReferenceAssessment(
        NutrientAmount(10),
        NutrientReferenceRange(adequacy: a),
      ).state,
      ReferenceRangeState.adequate,
    );
    expect(
      const ReferenceAssessment(
        NutrientAmount(20),
        NutrientReferenceRange(upper: u),
      ).state,
      ReferenceRangeState.belowUpper,
    );
    expect(
      const ReferenceAssessment(
        null,
        NutrientReferenceRange(adequacy: a),
      ).percentage(a),
      isNull,
    );
    expect(
      const ReferenceAssessment(
        NutrientAmount(0),
        NutrientReferenceRange(adequacy: a),
      ).percentage(a),
      0,
    );
  });
  test('zero upper has no percentage and never divides by zero', () {
    const zero = PublishedReference(
      amount: 0,
      term: 'custom-upper',
      unit: 'g',
      definition: 'test',
      table: 'custom',
      upper: true,
    );
    const range = NutrientReferenceRange(upper: zero);
    expect(
      const ReferenceAssessment(NutrientAmount(1), range).percentage(zero),
      isNull,
    );
    expect(
      const ReferenceAssessment(NutrientAmount(0), range).state,
      ReferenceRangeState.belowUpper,
    );
    expect(
      const ReferenceAssessment(NutrientAmount(1), range).state,
      ReferenceRangeState.above,
    );
  });
  test(
    'restricted upper and qualified intake cannot imply a definite assessment',
    () {
      const restricted = PublishedReference(
        amount: 20,
        term: 'UL',
        unit: 'mg',
        definition: 'test',
        table: 'test',
        upper: true,
        scope: IntakeScope.supplements,
      );
      const range = NutrientReferenceRange(upper: restricted);
      expect(
        const ReferenceAssessment(
          NutrientAmount(30),
          range,
        ).percentage(restricted),
        isNull,
      );
      expect(
        const ReferenceAssessment(NutrientAmount(30), range).state,
        ReferenceRangeState.unavailable,
      );
      expect(
        const ReferenceAssessment(
          NutrientAmount(30, qualification: NutrientQualification.lessThan),
          NutrientReferenceRange(upper: u),
        ).state,
        ReferenceRangeState.unavailable,
      );
      expect(NutrientView.all.threshold(range), isNull);
    },
  );
}
