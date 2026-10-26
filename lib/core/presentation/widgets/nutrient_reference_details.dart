import 'package:flutter/material.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:opennutritracker/generated/l10n.dart';

String referenceTermLabel(String term, S s) => switch (term) {
  'custom-target' => s.nutrientCustomTarget,
  'custom-upper' => s.nutrientCustomUpper,
  _ => term,
};
String referenceUnavailableLabel(String? reason, S s) => switch (reason) {
  'weight' => s.referenceMissingWeight,
  'profile' => s.referenceMissingProfile,
  'cohort' => s.referenceMissingCohort,
  'combined-amino' => s.referenceCombinedAmino,
  'frozen' => s.referenceMissingFrozen,
  'policy' => s.nutrientInvalidAmountLabel,
  _ => s.referenceNotEstablished,
};
String referenceScopeLabel(IntakeScope scope, S s) => switch (scope) {
  IntakeScope.total => s.referenceTotalIntake,
  IntakeScope.supplements => s.referenceSupplements,
  IntakeScope.synthetic => s.referenceSynthetic,
  IntakeScope.retinol => s.referenceRetinol,
  IntakeScope.niacinEquivalents => s.referenceNiacinEquivalents,
  IntakeScope.totalVitaminK => s.referenceTotalVitaminK,
  IntakeScope.retinolEquivalents => s.referenceRetinolEquivalents,
  IntakeScope.tocopherolEquivalents => s.referenceTocopherolEquivalents,
  IntakeScope.pyridoxine => s.referencePyridoxine,
  IntakeScope.nicotinicAcid => s.referenceNicotinicAcid,
  IntakeScope.nicotinamide => s.referenceNicotinamide,
  IntakeScope.combinedFattyAcids => s.referenceCombinedFattyAcids,
};
String referenceAmountLabel(PublishedReference value, S s) =>
    '${referenceTermLabel(value.term, s)}: ${nutrientNumber(value.amount)}${value.rangeEnd == null ? '' : '–${nutrientNumber(value.rangeEnd!)}'} ${value.unit}';

class NutrientReferenceDetails extends StatelessWidget {
  final ReferenceSelection? reference;
  final String? unavailable;
  final bool compact;
  const NutrientReferenceDetails({
    super.key,
    this.reference,
    this.unavailable,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = reference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r != null) ...[
          Text(
            '${r.source.name} · ${r.edition}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!compact)
            Text(
              '${s.ageLabel}: ${r.minAge}–${r.maxAge ?? '∞'} · ${r.sex.getName(context)} · ${r.stage == null
                  ? s.referenceOrdinaryStage
                  : r.stage!.name == 'pregnancy'
                  ? s.pregnancyLabel
                  : s.breastfeedingLabel}',
            ),
          for (final value in r.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    referenceAmountLabel(value, s),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (!compact)
                    Text(
                      '${value.definition} · ${value.table}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (!compact || !value.comparable)
                    Text(
                      '${referenceScopeLabel(value.scope, s)}${value.rangeEnd != null ? ' · ${s.referencePublishedRange}' : ''}${!value.comparable ? ' · ${s.referenceAssessmentUnavailable}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          if (r.calculation == ReferenceCalculation.cohort && !compact)
            Text(s.referenceCohortExplanation),
          if (r.equation != null) SelectableText(r.equation!),
        ],
        if (unavailable != null || r?.gap != null || r == null)
          Text(referenceUnavailableLabel(unavailable ?? r?.gap, s)),
      ],
    );
  }
}
