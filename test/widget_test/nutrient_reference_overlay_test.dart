import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_reference_overlay.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  for (final amount in [
    null,
    const NutrientAmount(0),
    const NutrientAmount(1001),
  ]) {
    testWidgets(
      'accessible overlay preserves $amount and opens the selected source',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final r = ReferenceCatalogue.lookup(
            region: ReferenceRegion.nzAustralia,
            nutrient: 'calcium',
            age: 30,
            sex: UserSexEntity.female,
          );
          final range = NutrientReferenceRange(
            reference: r,
            adequacy: r.values.first,
            upper: r.values.last,
          );
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showNutrientReferenceOverlay(
                      context,
                      nutrient: Nutrients.byKey['calcium']!,
                      amount: amount,
                      range: range,
                      day: DateTime(2025, 1, 3),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('Jan 3, 2025'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('reference-intake-marker')),
            amount == null ? findsNothing : findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('reference-range-graphic')),
            findsOneWidget,
          );
          expect(find.textContaining('RDI: 1000'), findsOneWidget);
          await tester.tap(
            find.byKey(const ValueKey('nutrient-reference-sources')),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SourcesScreen>(find.byType(SourcesScreen))
                .referenceRegion,
            ReferenceRegion.nzAustralia,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('nutrient-reference-close')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(NutrientReferenceOverlay), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'restricted UL is separate without a range or percentage at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const restricted = PublishedReference(
        amount: 350,
        term: 'UL',
        unit: 'mg',
        definition: 'Magnesium',
        table: 'Elements',
        scope: IntakeScope.supplements,
        upper: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: NutrientReferenceOverlay(
            nutrient: Nutrients.byKey['magnesium']!,
            amount: const NutrientAmount(400),
            range: const NutrientReferenceRange(upper: restricted),
            day: DateTime(2026),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reference-range-graphic')),
        findsNothing,
      );
      expect(find.textContaining('Assessment unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
