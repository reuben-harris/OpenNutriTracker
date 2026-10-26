import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_amount_row.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_group_header.dart';
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
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import '../../helpers/locator_test_setup.dart';
import '../../helpers/overview_diary_harness.dart';
import '../../helpers/pump_until.dart';

Widget app(Widget child, {bool kj = false}) => ChangeNotifierProvider(
  key: ValueKey(kj),
  create: (_) => EnergyUnitProvider(usesKilojoules: kj),
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> configureInfo(
  WidgetTester tester, {
  bool showMissing = false,
}) async {
  final h = OverviewDiaryHarness();
  await tester.runAsync(() async {
    await h.initialize();
    await h.configSource.setShowMissingNutrientsInInfo(showMissing);
  });
  locator.registerSingleton<GetConfigUsecase>(h.getConfig);
  locator.registerSingleton<AddConfigUsecase>(AddConfigUsecase(h.config));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await locator.resetScope();
    await pumpUntilComplete(
      tester,
      h.dispose(),
      reason: 'closing info settings',
    );
  });
}

void main() {
  useTestLocator();
  for (final (amount, goal, label)
      in <(NutrientAmount?, NutrientGoal?, String)>[
        (null, const NutrientGoal(10), 'No data'),
        (const NutrientAmount(0), const NutrientGoal(10), '0 g'),
        (const NutrientAmount(5), null, '5 g'),
        (const NutrientAmount(5), const NutrientGoal(0), '5 g'),
        (const NutrientAmount(5), const NutrientGoal(double.infinity), '5 g'),
      ]) {
    testWidgets(
      'amount=${amount?.value}, goal=${goal?.amount} always has a determinate empty bar',
      (tester) async {
        await tester.pumpWidget(
          app(
            NutrientAmountRow(
              nutrient: Nutrients.byKey[NutrientKeys.fiber]!,
              amount: amount,
              goal: goal,
            ),
          ),
        );
        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(bar.value, 0);
        expect(find.textContaining(label), findsOneWidget);
      },
    );
  }
  testWidgets(
    'the information table keeps fixed macros within their nutrient groups',
    (tester) async {
      await configureInfo(tester, showMissing: true);
      final meal = MealEntity(
        code: 'empty',
        name: 'Food',
        url: null,
        mealQuantity: '100',
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        nutriments: MealNutrimentsEntity.empty(),
        source: MealSourceEntity.custom,
      );
      await tester.pumpWidget(
        app(
          MealDetailNutrimentsTable(
            product: meal,
            baseAmount: 100,
            reference: true,
          ),
        ),
      );
      await pumpUntil(
        tester,
        () => find.byType(NutrientAmountRow).evaluate().isNotEmpty,
      );
      Finder header(NutrientGroup group) => find.byWidgetPredicate(
        (widget) => widget is NutrientGroupHeader && widget.group == group,
      );
      Finder row(String key) => find.byKey(ValueKey('nutrition-row-$key'));
      for (final (key, group) in [
        ('carbohydrates', NutrientGroup.carbohydrates),
        ('fat', NutrientGroup.lipids),
        ('protein', NutrientGroup.proteins),
      ]) {
        expect(
          tester.getTopLeft(row(key)).dy,
          greaterThan(tester.getTopLeft(header(group)).dy),
        );
      }
      expect(
        tester.getTopLeft(row('energy')).dy,
        lessThan(tester.getTopLeft(header(NutrientGroup.carbohydrates)).dy),
      );
      expect(
        tester.getTopLeft(row('carbohydrates')).dy,
        lessThan(tester.getTopLeft(row('sugar')).dy),
      );
      expect(
        tester.getTopLeft(row('fat')).dy,
        lessThan(tester.getTopLeft(row('saturated_fat')).dy),
      );
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .every((bar) => bar.value == 0),
        isTrue,
      );
    },
  );
  testWidgets('the eye hides missing values while preserving zero and trace', (
    tester,
  ) async {
    await configureInfo(tester);
    final food = MealEntity(
      code: 'eye-toggle',
      name: 'Food',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      source: MealSourceEntity.custom,
      nutriments: MealNutrimentsEntity.fromAmounts({
        'carbohydrates100': const NutrientAmount(0),
        'fat100': const NutrientAmount(1.25, isPartial: true),
        'histidine100': const NutrientAmount(0),
        'cystine100': const NutrientAmount(
          0,
          qualification: NutrientQualification.trace,
        ),
      }),
    );
    await tester.pumpWidget(
      app(
        MealDetailNutrimentsTable(
          product: food,
          baseAmount: 100,
          reference: true,
        ),
      ),
    );
    Finder row(String key) => find.byKey(ValueKey('nutrition-row-$key'));
    await pumpUntil(
      tester,
      () => find.byTooltip('Show nutrients with no data').evaluate().isNotEmpty,
    );
    expect(row('energy'), findsNothing);
    expect(row('cysteine'), findsNothing);
    expect(find.textContaining('No data'), findsNothing);
    expect(row('carbohydrates'), findsOneWidget);
    expect(row('fat'), findsOneWidget);
    expect(row('histidine'), findsOneWidget);
    expect(row('cystine'), findsOneWidget);
    expect(find.byType(NutrientAmountRow), findsNWidgets(4));
    expect(find.textContaining('Trace*'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Show nutrients with no data'));
    await pumpUntil(tester, () => row('energy').evaluate().isNotEmpty);
    expect(row('energy'), findsOneWidget);
    expect(row('cysteine'), findsOneWidget);
    expect(row('histidine'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await pumpUntil(
      tester,
      () =>
          tester.widget<IconButton>(find.byType(IconButton)).onPressed != null,
    );
    await tester.tap(find.byTooltip('Hide nutrients with no data'));
    await pumpUntil(tester, () => row('energy').evaluate().isEmpty);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
  testWidgets(
    'the eye updates other mounted and subsequently opened info tables',
    (tester) async {
      await configureInfo(tester);
      MealEntity food(String code) => MealEntity(
        code: code,
        name: code,
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        source: MealSourceEntity.custom,
        nutriments: MealNutrimentsEntity.empty(),
      );
      Widget table(String code) => MealDetailNutrimentsTable(
        key: ValueKey(code),
        product: food(code),
        baseAmount: 100,
        reference: true,
      );
      await tester.pumpWidget(
        app(Column(children: [table('first'), table('second')])),
      );
      await pumpUntil(
        tester,
        () =>
            find.byTooltip('Show nutrients with no data').evaluate().length ==
            2,
      );
      expect(find.byType(NutrientAmountRow), findsNothing);
      expect(
        find.text('This food has no reported nutrient values.'),
        findsNWidgets(2),
      );
      await tester.tap(find.byTooltip('Show nutrients with no data').first);
      await pumpUntil(
        tester,
        () =>
            find.byTooltip('Hide nutrients with no data').evaluate().length ==
            2,
      );
      expect(
        find.byKey(const ValueKey('nutrition-row-energy')),
        findsNWidgets(2),
      );
      await tester.pumpWidget(app(table('third')));
      await pumpUntil(
        tester,
        () =>
            find.byTooltip('Hide nutrients with no data').evaluate().isNotEmpty,
      );
      expect(
        find.byKey(const ValueKey('nutrition-row-energy')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Hide nutrients with no data'));
      await pumpUntil(
        tester,
        () =>
            find.byTooltip('Show nutrients with no data').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(app(table('fourth')));
      await pumpUntil(
        tester,
        () =>
            find.byTooltip('Show nutrients with no data').evaluate().isNotEmpty,
      );
      expect(find.byType(NutrientAmountRow), findsNothing);
    },
  );
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
              goals: const {'vitamin_b12': NutrientGoal(2.4)},
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('nutrition-row-vitamin_b12')),
    );
    await tester.pump();
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
    await configureInfo(tester, showMissing: true);
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
      (false, '30 kcal / 1000.00 kcal', '1.2 µg / 2.40 µg', false),
      (true, '100 kcal / 1000.00 kcal', '4 µg / 2.40 µg', false),
      (false, '125.52 kJ / 4184.00 kJ', '1.2 µg / 2.40 µg', true),
    ]) {
      await tester.pumpWidget(
        app(
          MealDetailNutrimentsTable(
            product: meal,
            baseAmount: 30,
            reference: reference,
            goals: const {
              'energy': NutrientGoal(1000),
              'vitamin_b12': NutrientGoal(2.4),
              'carbohydrates': NutrientGoal(250),
              'saturated_fat': NutrientGoal(10, isLimit: true),
            },
          ),
          kj: kj,
        ),
      );
      await pumpUntil(
        tester,
        () => find.byType(NutrientAmountRow).evaluate().isNotEmpty,
      );
      expect(find.textContaining(energy), findsOneWidget);
      expect(find.textContaining(vitamin), findsOneWidget);
      expect(find.textContaining('No data'), findsWidgets);
      expect(find.byType(ExpansionTile), findsNothing);
      Finder row(String key) => find.byKey(ValueKey('nutrition-row-$key'));
      LinearProgressIndicator bar(String key) => tester.widget(
        find.descendant(
          of: row(key),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(
        find.byType(LinearProgressIndicator),
        findsNWidgets(Nutrients.all.length),
      );
      expect(bar('energy').value, reference ? 0.1 : 0.03);
      expect(bar('vitamin_b12').value, reference ? 1.0 : 0.5);
      expect(bar('trans_fat').value, 0);
      expect(bar('iodine').value, 0);
      expect(
        find.descendant(
          of: row('iodine'),
          matching: find.textContaining('No data'),
        ),
        findsOneWidget,
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
