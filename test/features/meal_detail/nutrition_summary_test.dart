import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_macro_nutrients.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

Widget app(Widget child, {bool kj = false}) => ChangeNotifierProvider(
  key: ValueKey(kj),
  create: (_) => EnergyUnitProvider(usesKilojoules: kj),
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('trace, small numbers, legend and semantics fit enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final food = MealEntity(
      code: 'trace',
      name: 'Natto',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      source: MealSourceEntity.catalogue,
      nutriments: MealNutrimentsEntity.fromCatalogue({
        'vitaminB12100': {
          'value': '0',
          'qualification': 'trace',
          'limit': null,
        },
        'vitaminD100': '0.001',
        'fat100': '0',
      }),
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: MealDetailNutrimentsTable(
              product: food,
              baseAmount: 100,
              reference: true,
              goals: const {'vitamin_b12': 2.4},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Trace*'), findsOneWidget);
    expect(find.textContaining('0.001'), findsOneWidget);
    expect(
      find.text(lookupS(const Locale('en')).nutrientQualificationLegend),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('vitamin B12.*Trace')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  for (final (value, goal, expected, amount) in [
    (20.0, 10.0, '200%', '20.00 g'),
    (0.0, 10.0, '0%', '0.00 g'),
    (null, 10.0, '—', 'No data'),
    (20.0, 0.0, '—', '20.00 g'),
    (20.0, double.nan, '—', '20.00 g'),
  ]) {
    testWidgets('summary displays $value against goal $goal', (tester) async {
      await tester.pumpWidget(
        app(
          MealDetailMacroNutrients(
            typeString: 'Fat',
            value: NutrientAmount.fromNumber(value),
            goal: goal,
            color: Colors.blue,
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text(amount), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(amount)).dy,
        lessThan(tester.getTopLeft(find.text(expected)).dy),
      );
    });
  }
  testWidgets('table scales all nutrients and retains missing versus zero', (
    tester,
  ) async {
    final meal = MealEntity(
      code: 'test',
      name: 'Test',
      url: null,
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      source: MealSourceEntity.custom,
      nutriments: const MealNutrimentsEntity(
        energyKcal100: NutrientAmount(100),
        carbohydrates100: NutrientAmount(0),
        fat100: null,
        proteins100: NutrientAmount(10.123456),
        sugars100: null,
        saturatedFat100: NutrientAmount(0.4),
        transFat100: NutrientAmount(1),
        fiber100: null,
        vitaminB12100: NutrientAmount(4),
      ),
    );
    for (final (reference, energy, vitamin, kj) in [
      (
        false,
        'energy - 30.00 / 1000.00 kcal',
        'vitamin B12 - 1.20 / 2.40 µg',
        false,
      ),
      (
        true,
        'energy - 100.00 / 1000.00 kcal',
        'vitamin B12 - 4.00 / 2.40 µg',
        false,
      ),
      (
        false,
        'energy - 125.52 / 4184.00 kJ',
        'vitamin B12 - 1.20 / 2.40 µg',
        true,
      ),
    ]) {
      await tester.pumpWidget(
        app(
          MealDetailNutrimentsTable(
            product: meal,
            baseAmount: 30,
            reference: reference,
            goals: const {
              'energy': 1000,
              'vitamin_b12': 2.4,
              'carbohydrates': 250,
              'saturated_fat': 10,
            },
          ),
          kj: kj,
        ),
      );
      expect(
        find.text(lookupS(const Locale('en')).nutrientQualificationLegend),
        findsOneWidget,
      );
      expect(find.text(energy), findsOneWidget);
      expect(find.text(vitamin), findsOneWidget);
      expect(
        find.textContaining('carbohydrate - 0.00 / 250.00 g'),
        findsOneWidget,
      );
      expect(find.textContaining('No data'), findsWidgets);
      expect(
        find.text(reference ? 'protein - 10.12 / — g' : 'protein - 3.04 / — g'),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.textContaining('niacin (B3)'), findsOneWidget);
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars, hasLength(24));
      expect(bars[0].value, reference ? 0.1 : 0.03);
      expect(bars[22].value, reference ? 1.0 : 0.5);
      expect(
        find.text(
          reference
              ? 'saturated fat - 0.40 / 10.00 g'
              : 'saturated fat - 0.12 / 10.00 g',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          reference ? 'trans fat - 1.00 / — g' : 'trans fat - 0.30 / — g',
        ),
        findsOneWidget,
      );
      expect(bars[5].value, 0);
      final row = find.byKey(const ValueKey('nutrition-row-trans-fat'));
      final bar = find.descendant(
        of: row,
        matching: find.byType(LinearProgressIndicator),
      );
      Finder label(String key) => find
          .descendant(
            of: find.byKey(ValueKey('nutrition-row-$key')),
            matching: find.byType(Text),
          )
          .first;
      expect(
        tester.getTopLeft(bar).dx,
        tester.getTopLeft(label('trans-fat')).dx,
      );
      expect(tester.getTopRight(bar).dx, tester.getTopRight(row).dx);
      expect(
        tester.getTopLeft(label('trans-fat')).dx,
        tester.getTopLeft(label('fat')).dx + 12,
      );
      expect(
        tester.getTopLeft(label('sugar')).dx,
        tester.getTopLeft(label('carbohydrates')).dx + 12,
      );
      expect(
        tester.getTopLeft(label('vitamin_b12')).dx,
        tester.getTopLeft(label('protein')).dx,
      );
    }
  });
  testWidgets(
    'day preview uses kJ and clamps fills without clamping the projected total',
    (tester) async {
      await tester.pumpWidget(
        app(
          const DailyKcalOverview(
            dayKcalConsumed: 900,
            dayKcalGoal: 1000,
            currentSelectionKcal: 200,
          ),
          kj: true,
        ),
      );
      expect(find.text('Day total: 4602 kJ / 4184 kJ'), findsOneWidget);
      final fills = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((w) => w.widthFactor);
      expect(fills, [1.0, 0.9]);
    },
  );
  testWidgets('day preview hides invalid goals', (tester) async {
    for (final goal in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(
        app(
          DailyKcalOverview(
            dayKcalConsumed: 100,
            dayKcalGoal: goal,
            currentSelectionKcal: 20,
          ),
        ),
      );
      expect(find.byType(FractionallySizedBox), findsNothing);
    }
  });
}
