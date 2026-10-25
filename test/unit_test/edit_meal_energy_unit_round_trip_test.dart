import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../helpers/locator_test_setup.dart';
import '../helpers/test_l10n.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(AppThemeEntity.system);
}

class _Preferences extends Fake implements ConfigRepository {
  CustomMealFormMode mode = CustomMealFormMode.simple;
  @override
  Future<String?> getCustomMealFormMode() async => mode.name;
}

class _CustomMeals extends Fake implements CustomMealDataSource {
  MealDBO? saved;
  @override
  Future<void> saveCustomMeal(MealDBO meal) async => saved = meal;
}

void main() {
  useTestLocator();
  late _CustomMeals meals;
  late _Preferences preferences;
  late EnergyUnitProvider units;
  MealEntity? returned;

  setUp(() {
    meals = _CustomMeals();
    preferences = _Preferences();
    returned = null;
    locator.registerFactory<EditMealBloc>(
      () => EditMealBloc(_Config(), meals, preferences),
    );
  });

  Finder getEnergy() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.decoration?.labelText ?? '').startsWith(l10nEn.mealEnergyLabel),
  );

  Finder control(String identifier) => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.identifier == identifier,
  );
  Finder field(String identifier) => find.descendant(
    of: control(identifier),
    matching: find.byType(TextField),
  );

  Future<void> open(WidgetTester tester, {required bool kj}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    units = EnergyUnitProvider(usesKilojoules: kj);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: units,
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<MealEntity>(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        arguments: EditMealScreenArguments(
                          DateTime(2026, 9, 29),
                          const MealEntity(
                            code: 'custom-food',
                            name: 'Energy test',
                            url: null,
                            mealQuantity: '100',
                            mealUnit: 'g',
                            servingQuantity: 100,
                            servingUnit: 'g',
                            servingSize: null,
                            source: MealSourceEntity.custom,
                            nutriments: MealNutrimentsEntity(
                              energyKcal100: NutrientAmount(250),
                              carbohydrates100: null,
                              fat100: null,
                              proteins100: null,
                              sugars100: null,
                              saturatedFat100: null,
                              fiber100: null,
                            ),
                          ),
                          IntakeTypeEntity.snack,
                          false,
                          editOnly: true,
                        ),
                      ),
                      builder: (_) => const EditMealScreen(),
                    ),
                  );
                },
                child: const Text('Edit food'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit food'));
    await tester.pumpAndSettle();
  }

  for (final (name, mode, kj, typed, expected)
      in <(String, CustomMealFormMode, bool, String, double?)>[
        ('simple kJ conversion', CustomMealFormMode.simple, true, '2000', 478),
        (
          'advanced kJ conversion',
          CustomMealFormMode.advanced,
          true,
          '2000',
          478,
        ),
        (
          'kcal remains unchanged',
          CustomMealFormMode.simple,
          false,
          '250',
          250,
        ),
        ('zero remains known', CustomMealFormMode.simple, true, '0', 0),
        ('blank remains unknown', CustomMealFormMode.simple, true, '', null),
      ]) {
    testWidgets(name, (tester) async {
      preferences.mode = mode;
      await open(tester, kj: kj);
      await tester.enterText(getEnergy(), typed);
      await tester.tap(
        find.widgetWithText(FilledButton, l10nEn.buttonSaveLabel),
      );
      await tester.pumpAndSettle();
      expect(meals.saved, isNotNull);
      expect(meals.saved!.nutriments.energyKcal100?.value, expected);
      expect(returned!.nutriments.energyKcal100?.value, expected);
      expect(find.byType(EditMealScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      units.dispose();
    });
  }

  testWidgets('simple form retains all four editable energy and macro fields', (
    tester,
  ) async {
    await open(tester, kj: false);
    for (final (id, value) in [
      ('energy', '150'),
      ('carbohydrates', '20'),
      ('fat', '3'),
      ('protein', '10'),
    ]) {
      await tester.enterText(field('edit-meal-$id'), value);
    }
    await tester.tap(find.widgetWithText(FilledButton, l10nEn.buttonSaveLabel));
    await tester.pumpAndSettle();
    final saved = meals.saved!.nutriments;
    expect(saved.energyKcal100, const NutrientAmount(150));
    expect(saved.carbohydrates100, const NutrientAmount(20));
    expect(saved.fat100, const NutrientAmount(3));
    expect(saved.proteins100, const NutrientAmount(10));
    await tester.pumpWidget(const SizedBox());
    units.dispose();
  });

  testWidgets(
    'advanced quantity and total controls scale a precise qualified nutrient',
    (tester) async {
      preferences.mode = CustomMealFormMode.advanced;
      await open(tester, kj: false);
      expect(control('edit-meal-unit-selector'), findsOneWidget);
      await tester.enterText(field('edit-meal-quantity'), '200');
      await tester.enterText(field('edit-meal-serving-quantity'), '50');
      await tester.enterText(field('edit-meal-base-quantity'), '50');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: control('edit-meal-nutrients-mode'),
          matching: find.text(l10nEn.mealNutrientsTotalLabel),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        control('edit-meal-selenium'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field('edit-meal-selenium'), '<0.00123456789');
      await tester.tap(
        find.widgetWithText(FilledButton, l10nEn.buttonSaveLabel),
      );
      await tester.pumpAndSettle();
      final saved = meals.saved!;
      expect(saved.mealQuantity, '200');
      expect(saved.servingQuantity, 50);
      expect(
        saved.nutriments.selenium100!.value,
        closeTo(0.000617283945, 1e-15),
      );
      expect(
        saved.nutriments.selenium100!.qualification,
        NutrientQualification.lessThan,
      );
      await tester.pumpWidget(const SizedBox());
      units.dispose();
    },
  );

  testWidgets(
    'advanced form rejects an invalid nutrient instead of saving it as missing',
    (tester) async {
      preferences.mode = CustomMealFormMode.advanced;
      await open(tester, kj: false);
      await tester.scrollUntilVisible(
        control('edit-meal-selenium'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field('edit-meal-selenium'), 'invalid');
      await tester.tap(
        find.widgetWithText(FilledButton, l10nEn.buttonSaveLabel),
      );
      await tester.pumpAndSettle();
      expect(meals.saved, isNull);
      expect(find.text(l10nEn.nutrientInvalidAmountLabel), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      units.dispose();
    },
  );

  testWidgets(
    'stored kcal displays in kJ and survives unit changes without saving',
    (tester) async {
      await open(tester, kj: true);
      expect(tester.widget<TextField>(getEnergy()).controller!.text, '1046.0');
      units.updateUsesKilojoules(false);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(getEnergy()).controller!.text, '250.0');
      units.updateUsesKilojoules(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(getEnergy()).controller!.text, '1046.0');
      expect(meals.saved, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(returned, isNull);
      expect(meals.saved, isNull);
      await tester.pumpWidget(const SizedBox());
      units.dispose();
    },
  );
}
