import 'package:opennutritracker/core/domain/entity/life_stage_period.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/nutrition/references/nz_australia.dart';
import 'package:opennutritracker/core/nutrition/references/us_canada.dart';

enum ReferenceRegion { nzAustralia, usCanada }

enum IntakeScope {
  total,
  supplements,
  synthetic,
  retinol,
  niacinEquivalents,
  totalVitaminK,
  retinolEquivalents,
  tocopherolEquivalents,
  pyridoxine,
  nicotinicAcid,
  nicotinamide,
  combinedFattyAcids,
}

enum ReferenceCalculation { constant, cohort, weightFormula }

class ReferenceSource {
  final ReferenceRegion region;
  final String name, edition, attribution, url;
  const ReferenceSource(
    this.region,
    this.name,
    this.edition,
    this.attribution,
    this.url,
  );
  static const all = [
    ReferenceSource(
      ReferenceRegion.nzAustralia,
      'NZ/Australia',
      '2006, version 1.2 (September 2017)',
      'National Health and Medical Research Council, Australian Government Department of Health and Ageing, New Zealand Ministry of Health. Nutrient Reference Values for Australia and New Zealand.',
      'https://www.nhmrc.gov.au/sites/default/files/images/Nutrient-reference-aus-nz-executive-summary.pdf',
    ),
    ReferenceSource(
      ReferenceRegion.usCanada,
      'US/Canada',
      'DRI tables, including calcium/vitamin D (2011) and sodium/potassium (2019)',
      'Health Canada; National Academies of Sciences, Engineering, and Medicine. Dietary Reference Intakes.',
      'https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables.html',
    ),
  ];
  static ReferenceSource forRegion(ReferenceRegion region) =>
      all.firstWhere((s) => s.region == region);
}

/// Every series has an explicit slot for each published cohort intersecting 13+:
/// male 9–13, 14–18, 19–30, 31–50, 51–70, 71+; female same;
/// pregnancy <=18, 19–30, 31–50; lactation same. NZ pregnancy/lactation
/// begins at 14, so age 13 has an explicit gap rather than an ordinary row.
class ReferenceSeries {
  final String nutrient, unit, definition, table, adequacyTerm;
  final List<double?> adequacy, upper;
  final IntakeScope adequacyScope, upperScope;
  final bool perKg;
  const ReferenceSeries({
    required this.nutrient,
    required this.unit,
    required this.definition,
    required this.table,
    this.adequacyTerm = 'RDA',
    required this.adequacy,
    this.upper = const [],
    this.adequacyScope = IntakeScope.total,
    this.upperScope = IntakeScope.total,
    this.perKg = false,
  });
}

class PublishedReference {
  final double amount;
  final double? rangeEnd;
  final String term, unit, definition, table;
  final IntakeScope scope;
  final bool upper;
  const PublishedReference({
    required this.amount,
    required this.term,
    required this.unit,
    required this.definition,
    required this.table,
    this.scope = IntakeScope.total,
    this.upper = false,
    this.rangeEnd,
  });
  bool get comparable => scope == IntakeScope.total && rangeEnd == null;
  Map<String, dynamic> toJson() => {
    'amount': amount,
    'rangeEnd': rangeEnd,
    'term': term,
    'unit': unit,
    'definition': definition,
    'table': table,
    'scope': scope.name,
    'upper': upper,
  };
  factory PublishedReference.fromJson(Map<String, dynamic> json) =>
      PublishedReference(
        amount: (json['amount'] as num).toDouble(),
        rangeEnd: (json['rangeEnd'] as num?)?.toDouble(),
        term: json['term'] as String,
        unit: json['unit'] as String,
        definition: json['definition'] as String,
        table: json['table'] as String,
        scope: IntakeScope.values.byName(json['scope'] as String),
        upper: json['upper'] as bool,
      );
}

class ReferenceSelection {
  final ReferenceRegion region;
  final int age, minAge;
  final int? maxAge;
  final UserSexEntity sex;
  final LifeStage? stage;
  final List<PublishedReference> values;
  final String? gap;
  final ReferenceCalculation calculation;
  final String? equation;
  final String? savedEdition, savedSourceUrl;
  String get edition => savedEdition ?? source.edition;
  String get sourceUrl => savedSourceUrl ?? source.url;
  const ReferenceSelection({
    required this.region,
    required this.age,
    required this.minAge,
    this.maxAge,
    required this.sex,
    this.stage,
    this.values = const [],
    this.gap,
    this.calculation = ReferenceCalculation.cohort,
    this.equation,
    this.savedEdition,
    this.savedSourceUrl,
  });
  ReferenceSource get source => ReferenceSource.forRegion(region);
  Map<String, dynamic> toJson() => {
    'region': region.name,
    'age': age,
    'minAge': minAge,
    'maxAge': maxAge,
    'sex': sex.name,
    'stage': stage?.name,
    'values': values.map((v) => v.toJson()).toList(),
    'gap': gap,
    'calculation': calculation.name,
    'equation': equation,
    'edition': edition,
    'sourceUrl': sourceUrl,
  };
  factory ReferenceSelection.fromJson(Map<String, dynamic> json) =>
      ReferenceSelection(
        region: ReferenceRegion.values.byName(json['region'] as String),
        age: json['age'] as int,
        minAge: json['minAge'] as int,
        maxAge: json['maxAge'] as int?,
        sex: UserSexEntity.values.byName(json['sex'] as String),
        stage: json['stage'] == null
            ? null
            : LifeStage.values.byName(json['stage'] as String),
        values: (json['values'] as List)
            .map(
              (v) => PublishedReference.fromJson(
                Map<String, dynamic>.from(v as Map),
              ),
            )
            .toList(),
        gap: json['gap'] as String?,
        calculation: ReferenceCalculation.values.byName(
          json['calculation'] as String,
        ),
        equation: json['equation'] as String?,
        savedEdition: json['edition'] as String?,
        savedSourceUrl: json['sourceUrl'] as String?,
      );
}

class ReferenceCatalogue {
  static List<ReferenceSeries> series(ReferenceRegion region) =>
      switch (region) {
        ReferenceRegion.nzAustralia => nzAustraliaReferences,
        ReferenceRegion.usCanada => usCanadaReferences,
      };
  static ReferenceSelection lookup({
    required ReferenceRegion region,
    required String nutrient,
    required int age,
    required UserSexEntity sex,
    LifeStage? stage,
    double? weightKg,
  }) {
    final band = age <= 13
        ? 0
        : age <= 18
        ? 1
        : age <= 30
        ? 2
        : age <= 50
        ? 3
        : age <= 70
        ? 4
        : 5;
    final min = [9, 14, 19, 31, 51, 71][band];
    final max = [13, 18, 30, 50, 70, null][band];
    final stageMin = region == ReferenceRegion.nzAustralia ? 14 : 13;
    final index = stage == null
        ? band + (sex == UserSexEntity.female ? 6 : 0)
        : 12 +
              (stage == LifeStage.breastfeeding ? 3 : 0) +
              (age <= 18
                  ? 0
                  : age <= 30
                  ? 1
                  : 2);
    final valid =
        age >= 13 &&
        (stage == null ||
            sex == UserSexEntity.female && age >= stageMin && age <= 50);
    final rows = series(region).where((s) => s.nutrient == nutrient);
    final values = <PublishedReference>[];
    String? equation;
    bool missingWeight = false;
    if (valid) {
      for (final row in rows) {
        if (row.adequacyTerm == 'SDT' && age < 15) continue;
        final coefficient = row.adequacy[index];
        if (row.perKg && coefficient != null) {
          equation = '$coefficient mg/kg/day × weight (kg) ÷ 1000 = g/day';
          if (weightKg == null || !weightKg.isFinite || weightKg <= 0) {
            missingWeight = true;
            continue;
          }
          equation =
              '$equation\n$coefficient × $weightKg ÷ 1000 = ${coefficient * weightKg / 1000} g/day';
        }
        final amount = coefficient == null
            ? null
            : row.perKg
            ? coefficient * weightKg! / 1000
            : coefficient;
        if (amount != null)
          values.add(
            PublishedReference(
              amount: amount,
              term: row.adequacyTerm,
              unit: row.unit,
              definition: row.definition,
              table: row.table,
              scope: row.adequacyScope,
            ),
          );
        final upper = row.upper.isEmpty ? null : row.upper[index];
        if (upper != null)
          values.add(
            PublishedReference(
              amount: upper,
              term: 'UL',
              unit: row.unit,
              definition: row.definition,
              table: row.table,
              scope: row.upperScope,
              upper: true,
            ),
          );
      }
      if (nutrient == NutrientKeys.sodium &&
          region == ReferenceRegion.usCanada) {
        values.add(
          PublishedReference(
            amount: age <= 13 ? 1800 : 2300,
            term: 'CDRR',
            unit: 'mg',
            definition: 'Sodium',
            table: 'Elements, table 3 (2019)',
            upper: true,
          ),
        );
      }
      if (nutrient == NutrientKeys.sodium &&
          region == ReferenceRegion.nzAustralia) {
        // 2017 adult amendment applies from 18, including pregnancy/lactation.
        values.removeWhere((r) => r.term == 'UL' && age >= 18);
        values.add(
          PublishedReference(
            amount: age <= 13 ? 400 : 460,
            rangeEnd: age <= 13 ? 800 : 920,
            term: 'AI',
            unit: 'mg',
            definition: 'Sodium',
            table: 'Table 9 (2017 amendment)',
          ),
        );
        if (age >= 18)
          values.add(
            const PublishedReference(
              amount: 2000,
              term: 'SDT',
              unit: 'mg',
              definition: 'Sodium',
              table: 'Table 23 (2017 amendment)',
              upper: true,
            ),
          );
      }
    }
    return ReferenceSelection(
      region: region,
      age: age,
      minAge: stage != null && age <= 18 ? stageMin : min,
      maxAge: stage != null && age <= 18 ? 18 : max,
      sex: sex,
      stage: stage,
      values: values,
      calculation: equation == null
          ? ReferenceCalculation.cohort
          : ReferenceCalculation.weightFormula,
      equation: equation,
      gap: !valid
          ? 'cohort'
          : missingWeight
          ? 'weight'
          : values.isEmpty
          ? ({
                  'methionine',
                  'cysteine',
                  'cystine',
                  'phenylalanine',
                  'tyrosine',
                }.contains(nutrient)
                ? 'combined-amino'
                : 'not-established')
          : null,
    );
  }
}
