import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/life_stage_period.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';

ReferenceSelection lookup(
  String nutrient,
  int age, {
  ReferenceRegion region = ReferenceRegion.usCanada,
  UserSexEntity sex = UserSexEntity.female,
  LifeStage? stage,
}) => ReferenceCatalogue.lookup(
  region: region,
  nutrient: nutrient,
  age: age,
  sex: sex,
  stage: stage,
);
void main() {
  test('independent series cover every cohort with registry units', () {
    for (final region in ReferenceRegion.values) {
      for (final series in ReferenceCatalogue.series(region)) {
        expect(series.adequacy, hasLength(18));
        expect(series.upper.isEmpty || series.upper.length == 18, isTrue);
        expect(series.unit, Nutrients.byKey[series.nutrient]!.unit);
        for (final value in [...series.adequacy, ...series.upper].nonNulls) {
          expect(value.isFinite && value >= 0, isTrue);
        }
      }
      for (final nutrient in Nutrients.additional) {
        for (final age in [13, 14, 18, 19, 30, 31, 50, 51, 70, 71]) {
          final selection = lookup(nutrient.key, age, region: region);
          expect(selection.values.isNotEmpty || selection.gap != null, isTrue);
        }
      }
    }
  });
  test('teen and older rows are exact; no adult substitution', () {
    expect(lookup('iron', 13).values.first.amount, 8);
    expect(lookup('iron', 14).values.first.amount, 15);
    expect(lookup('iron', 19).values.first.amount, 18);
    expect(lookup('iron', 51).values.first.amount, 8);
    expect(
      lookup(
        'calcium',
        71,
        region: ReferenceRegion.nzAustralia,
      ).values.first.amount,
      1300,
    );
    expect(lookup('calcium', 71).values.first.amount, 1200);
  });
  test('published pregnancy rows and explicit gaps', () {
    expect(
      lookup('iron', 13, stage: LifeStage.pregnancy).values.first.amount,
      27,
    );
    expect(
      lookup(
        'iron',
        13,
        region: ReferenceRegion.nzAustralia,
        stage: LifeStage.pregnancy,
      ).gap,
      'cohort',
    );
    expect(lookup('iron', 51, stage: LifeStage.pregnancy).values, isEmpty);
    expect(
      lookup(
        'vitamin_b12',
        20,
        stage: LifeStage.breastfeeding,
      ).values.first.amount,
      2.8,
    );
  });
  test('sodium amendments preserve CDRR and SDT, including age 18', () {
    expect(lookup('sodium', 13).values.last.amount, 1800);
    expect(lookup('sodium', 20).values.map((r) => r.term), ['AI', 'CDRR']);
    expect(
      lookup(
        'sodium',
        17,
        region: ReferenceRegion.nzAustralia,
      ).values.any((r) => r.term == 'UL'),
      isTrue,
    );
    expect(
      lookup(
        'sodium',
        18,
        region: ReferenceRegion.nzAustralia,
      ).values.map((r) => r.term),
      ['AI', 'SDT'],
    );
    expect(
      lookup(
        'sodium',
        18,
        region: ReferenceRegion.nzAustralia,
      ).values.first.rangeEnd,
      920,
    );
  });
  test(
    'restricted ULs and different nutrient definitions cannot assess total intake',
    () {
      expect(
        lookup('magnesium', 30).values.last.scope,
        IntakeScope.supplements,
      );
      expect(lookup('magnesium', 30).values.last.comparable, isFalse);
      expect(lookup('folate_dfe', 30).values.last.comparable, isFalse);
      expect(
        lookup(
          'vitamin_a',
          30,
          region: ReferenceRegion.nzAustralia,
        ).values.first.comparable,
        isFalse,
      );
      expect(
        lookup('niacin', 30).values.first.scope,
        IntakeScope.niacinEquivalents,
      );
      expect(lookup('methionine', 30).gap, 'combined-amino');
      expect(lookup('epa', 30).values, isEmpty);
    },
  );
  test(
    'weight formulas use published coefficients and explicit missing inputs',
    () {
      final missing = lookup('leucine', 30);
      expect(missing.gap, 'weight');
      expect(missing.calculation, ReferenceCalculation.weightFormula);
      final result = ReferenceCatalogue.lookup(
        region: ReferenceRegion.usCanada,
        nutrient: 'leucine',
        age: 30,
        sex: UserSexEntity.female,
        weightKg: 60,
      );
      expect(result.values.single.amount, 2.52);
      expect(result.equation, contains('42.0 × 60.0 ÷ 1000'));
    },
  );
  test('reference provenance serializes without losing qualifiers', () {
    final reference = lookup('magnesium', 18, stage: LifeStage.pregnancy);
    final copy = ReferenceSelection.fromJson(reference.toJson());
    expect(copy.values.last.toJson(), reference.values.last.toJson());
    expect(copy.stage, reference.stage);
    expect(copy.source.edition, contains('2019'));
  });
}
