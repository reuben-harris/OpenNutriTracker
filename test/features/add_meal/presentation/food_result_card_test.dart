import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import '../../../core/search/food_search_engine_test.dart' show food;

void main() {
  MealEntity result({
    MealSourceEntity source = MealSourceEntity.off,
    String? brand,
  }) => MealEntity(
    code: 'x',
    name: 'Apple',
    brands: brand,
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    nutriments: food('x', 'Apple').nutriments,
    source: source,
    catalogueSourceName: source == MealSourceEntity.catalogue
        ? 'FoodData Central'
        : null,
  );

  Future<void> mount(WidgetTester tester, MealEntity meal) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MealItemCard(
            mealEntity: meal,
            onSelected: (_) {},
            onInfo: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brand in [null, '', '   ']) {
    testWidgets('OFF with brand "$brand" shows italic Unknown Brand', (
      tester,
    ) async {
      await mount(tester, result(brand: brand));
      final fallback = find.byWidgetPredicate(
        (widget) =>
            widget is AutoSizeText &&
            widget.textSpan?.toPlainText() == 'Unknown Brand',
      );
      expect(fallback, findsOneWidget);
      final text = tester.widget<AutoSizeText>(fallback).textSpan as TextSpan;
      expect(text.style?.fontStyle, FontStyle.italic);
      expect(
        tester.getTopLeft(fallback).dy,
        greaterThan(tester.getTopLeft(find.text('Apple')).dy),
      );
      expect(find.text('OFF'), findsNothing);
      expect(find.text('USDA'), findsNothing);
    });
  }

  testWidgets('OFF brand occupies the second line', (tester) async {
    await mount(tester, result(brand: 'Orchard'));
    final brand = find.text('Orchard', findRichText: true);
    expect(brand, findsOneWidget);
    expect(
      tester.getTopLeft(brand).dy,
      greaterThan(tester.getTopLeft(find.text('Apple')).dy),
    );
    expect(find.text('Unknown Brand', findRichText: true), findsNothing);
  });

  testWidgets('FDC shows its datasource in the brand position', (tester) async {
    await mount(
      tester,
      result(source: MealSourceEntity.catalogue, brand: 'Ignored'),
    );
    final source = find.text('FoodData Central', findRichText: true);
    expect(source, findsOneWidget);
    expect(
      tester.getTopLeft(source).dy,
      greaterThan(tester.getTopLeft(find.text('Apple')).dy),
    );
    expect(find.text('Ignored', findRichText: true), findsNothing);
    expect(find.text('OFF'), findsNothing);
    expect(find.text('USDA'), findsNothing);
  });

  testWidgets('tap selects and right swipe reveals Info', (tester) async {
    var selections = 0, info = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: MealItemCard(
              mealEntity: food('x', 'Apple'),
              onSelected: (_) => selections++,
              onInfo: () => info++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apple'));
    expect(selections, 1);
    expect(info, 0);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    await tester.drag(find.text('Apple'), const Offset(150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    expect(info, 1);
    expect(selections, 1);
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'meal-item-select',
      ),
    );
    expect(
      semantics.properties.customSemanticsActions!.keys.single.label,
      'Info',
    );
  });
}
