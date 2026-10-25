import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/nutrient_visibility_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import '../../helpers/locator_test_setup.dart';
import '../../helpers/overview_diary_harness.dart';
import '../../helpers/pump_until.dart';
import '../../fixture/diary_entry_fixtures.dart';

Widget app(Widget child) => ChangeNotifierProvider(
  create: (_) => EnergyUnitProvider(usesKilojoules: false),
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: child,
  ),
);

Finder control(String column) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.identifier == 'nutrient-visibility-sugar-$column',
);

void main() {
  useTestLocator();
  testWidgets(
    'group checkboxes save once, reflect mixed selections, and keep Daily and Info independent',
    (tester) async {
      final h = OverviewDiaryHarness();
      await tester.runAsync(h.initialize);
      locator.registerSingleton<GetConfigUsecase>(h.getConfig);
      locator.registerSingleton<AddConfigUsecase>(AddConfigUsecase(h.config));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await locator.resetScope();
        await pumpUntilComplete(
          tester,
          h.dispose(),
          reason: 'closing nutrient visibility storage',
        );
      });
      var writes = 0;
      final changes = h.db.appConfigBox.watch().listen((_) => writes++);
      addTearDown(
        () => pumpUntilComplete(
          tester,
          changes.cancel(),
          reason: 'cancelling the visibility write observer',
        ),
      );
      final lipids = Nutrients.additional.where(
        (n) => n.group == NutrientGroup.lipids,
      );
      Finder group(String column) => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier ==
                'nutrient-visibility-group-lipids-$column',
      );
      Checkbox checkbox(String column) => tester.widget(
        find.descendant(of: group(column), matching: find.byType(Checkbox)),
      );
      await tester.pumpWidget(app(const NutrientVisibilityScreen()));
      await pumpUntil(tester, () => group('daily').evaluate().isNotEmpty);
      await tester.ensureVisible(group('daily'));
      await tester.tap(group('daily'));
      await pumpUntil(
        tester,
        () =>
            checkbox('daily').value == false &&
            checkbox('daily').onChanged != null,
      );
      expect(writes, 1);
      var saved = await pumpUntilComplete(
        tester,
        h.getConfig.getConfig(),
        reason: 'reading saved group visibility',
      );
      for (final n in lipids) {
        expect(saved.nutrientPanelVisibility[n.key], isFalse);
        expect(saved.nutrientInfoVisibility[n.key] ?? true, isTrue);
      }
      await pumpUntilComplete(
        tester,
        h.configSource.setNutrientVisibility(
          ['saturated_fat'],
          true,
          info: false,
        ),
        reason: 'saving mixed group visibility',
      );
      await pumpUntil(tester, () => checkbox('daily').value == null);
      await tester.tap(group('daily'));
      await pumpUntil(
        tester,
        () =>
            checkbox('daily').value == true &&
            checkbox('daily').onChanged != null,
      );
      await tester.tap(group('info'));
      await pumpUntil(tester, () => checkbox('info').value == false);
      saved = await pumpUntilComplete(
        tester,
        h.getConfig.getConfig(),
        reason: 'reading saved Daily and Info visibility',
      );
      for (final n in lipids) {
        expect(saved.nutrientPanelVisibility[n.key], isTrue);
        expect(saved.nutrientInfoVisibility[n.key], isFalse);
      }
      expect(saved.nutrientPanelVisibility['fiber'] ?? true, isTrue);
      expect(saved.nutrientInfoVisibility['fiber'] ?? true, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Daily and Info are independent and update loaded information', (
    tester,
  ) async {
    final h = OverviewDiaryHarness();
    await tester.runAsync(h.initialize);
    locator.registerSingleton<GetConfigUsecase>(h.getConfig);
    locator.registerSingleton<AddConfigUsecase>(AddConfigUsecase(h.config));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await locator.resetScope();
      await pumpUntilComplete(
        tester,
        h.dispose(),
        reason: 'closing nutrient visibility storage',
      );
    });
    await tester.pumpWidget(app(const NutrientVisibilityScreen()));
    await pumpUntil(tester, () => control('daily').evaluate().isNotEmpty);
    Checkbox checkbox(String column) => tester.widget(
      find.descendant(of: control(column), matching: find.byType(Checkbox)),
    );
    expect(checkbox('daily').value, isTrue);
    expect(checkbox('info').value, isTrue);
    await tester.tap(control('daily'));
    await pumpUntil(
      tester,
      () =>
          checkbox('daily').value == false &&
          checkbox('info').onChanged != null,
    );
    expect(checkbox('info').value, isTrue);
    await tester.tap(control('info'));
    await pumpUntil(tester, () => checkbox('info').value == false);
    final saved = await pumpUntilComplete(
      tester,
      h.getConfig.getConfig(),
      reason: 'reading saved nutrient visibility',
    );
    expect(saved.nutrientPanelVisibility['sugar'], isFalse);
    expect(saved.nutrientInfoVisibility['sugar'], isFalse);

    final meal = nutrientFood(MealNutrimentsEntity.empty());
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MealDetailNutrimentsTable(
              product: meal,
              baseAmount: 100,
              reference: true,
            ),
          ),
        ),
      ),
    );
    await pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('nutrition-row-energy'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byKey(const ValueKey('nutrition-row-sugar')), findsNothing);
    expect(find.byKey(const ValueKey('nutrition-row-iodine')), findsOneWidget);
    expect(find.textContaining('No data'), findsWidgets);
    await pumpUntilComplete(
      tester,
      h.configSource.setNutrientVisibility(['sugar'], true, info: true),
      reason: 'showing sugar on the loaded information page',
    );
    await pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('nutrition-row-sugar'))
          .evaluate()
          .isNotEmpty,
    );
    expect(
      (await pumpUntilComplete(
        tester,
        h.getConfig.getConfig(),
        reason: 'reading independent Daily visibility',
      )).nutrientPanelVisibility['sugar'],
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'hiding every optional information row retains fixed energy and macros',
    (tester) async {
      final h = OverviewDiaryHarness();
      await tester.runAsync(() async {
        await h.initialize();
        for (final nutrient in Nutrients.additional) {
          await h.configSource.setNutrientVisibility(
            [nutrient.key],
            false,
            info: true,
          );
        }
      });
      locator.registerSingleton<GetConfigUsecase>(h.getConfig);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await locator.resetScope();
        await pumpUntilComplete(
          tester,
          h.dispose(),
          reason: 'closing nutrient visibility storage',
        );
      });
      await tester.pumpWidget(
        app(
          Scaffold(
            body: MealDetailNutrimentsTable(
              product: nutrientFood(MealNutrimentsEntity.empty()),
              baseAmount: 100,
              reference: true,
            ),
          ),
        ),
      );
      await pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('nutrition-row-energy'))
            .evaluate()
            .isNotEmpty,
      );
      for (final nutrient in Nutrients.all) {
        expect(
          find.byKey(ValueKey('nutrition-row-${nutrient.key}')),
          nutrient.core ? findsOneWidget : findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
