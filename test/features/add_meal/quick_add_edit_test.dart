import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';

class _Home extends Fake implements HomeBloc {
  @override
  void add(HomeEvent event) {}
}

class _Diary extends Fake implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}
}

class _Calendar extends Fake implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}
}

MealEntity quick({double? kcal = 123.456789, double? carbs}) => MealEntity(
  code: 'quick',
  name: 'Quick food',
  url: null,
  mealQuantity: '100',
  mealUnit: 'gml',
  servingQuantity: null,
  servingUnit: 'gml',
  servingSize: '',
  source: MealSourceEntity.custom,
  isQuickAdd: true,
  nutriments: MealNutrimentsEntity(
    energyKcal100: kcal,
    carbohydrates100: carbs,
    fat100: null,
    proteins100: null,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);

class _MealDetail extends Fake implements MealDetailBloc {
  int calls = 0;
  MealEntity? meal;
  String? amount;
  @override
  Future<void> addIntake(
    BuildContext context,
    String unit,
    String amountText,
    IntakeTypeEntity type,
    MealEntity source,
    DateTime day, {
    IntakeEntity? copiedFrom,
  }) async {
    calls++;
    meal = source;
    amount = amountText;
  }
}

void main() {
  late Directory dir;
  late IntakeRepository repo;
  late FakeHiveDBProvider db;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('quick-edit');
    Hive.init(dir.path);
    registerHiveAdaptersOnce();
    db = FakeHiveDBProvider(
      intakeBox: await Hive.openBox<IntakeDBO>('intakes'),
      customMealBox: await Hive.openBox<MealDBO>('custom'),
      configBox: await Hive.openBox<ConfigDBO>('config'),
      trackedDayBox: await Hive.openBox<TrackedDayDBO>('days'),
    );
    repo = IntakeRepository(IntakeDataSource(db));
    locator.registerSingleton<HiveDBProvider>(db);
    locator.registerSingleton<UpdateIntakeUsecase>(UpdateIntakeUsecase(repo));
    locator.registerSingleton<CustomMealDataSource>(CustomMealDataSource(db));
    locator.registerSingleton<HomeBloc>(_Home());
    locator.registerSingleton<DiaryBloc>(_Diary());
    locator.registerSingleton<CalendarDayBloc>(_Calendar());
  });
  tearDown(() async {
    await locator.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Future<void> mount(
    WidgetTester tester, {
    MealEntity? meal,
    IntakeEntity? edit,
    bool kj = false,
  }) => tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => EnergyUnitProvider(usesKilojoules: kj),
      child: MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: const Scaffold(),
        initialRoute: '/sheet',
        routes: {
          '/sheet': (_) => Scaffold(
            body: QuickAddBottomSheet(
              intakeType: IntakeTypeEntity.snack,
              day: DateTime(2026, 10, 4),
              initialMeal: meal,
              editingIntake: edit,
            ),
          ),
        },
      ),
    ),
  );
  Finder field(int index) => find.byType(TextField).at(index);
  for (final nutrients in [
    quick(kcal: null),
    quick(kcal: 0, carbs: 0),
    quick(kcal: null, carbs: 12),
    quick(),
  ]) {
    testWidgets(
      'partial or explicit zero prefill allows Add: ${nutrients.nutriments}',
      (tester) async {
        await mount(tester, meal: nutrients);
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(
          tester.widget<TextField>(field(1)).controller!.text,
          nutrients.nutriments.energyKcal100?.toString() ?? '',
        );
        expect(tester.widget<TextField>(field(3)).controller!.text, '');
      },
    );
  }
  testWidgets('new name-only entry enables Add, missing name disables it', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(field(0), 'Unknown lunch');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'optional weight changes preserve entered nutrition totals and can be cleared',
    (tester) async {
      final intake = IntakeEntity(
        id: 'occurrence',
        unit: 'g',
        amount: 100,
        type: IntakeTypeEntity.lunch,
        dateTime: DateTime(2025, 1, 1),
        meal: quick(),
      );
      await tester.runAsync(() => repo.addIntake(intake));
      await mount(tester, edit: intake);
      await tester.pumpAndSettle();
      await tester.enterText(field(5), '2');
      tester
          .widget<DropdownButton<FoodAmountUnit>>(
            find.byType(DropdownButton<FoodAmountUnit>),
          )
          .onChanged!(FoodAmountUnit.kg);
      await tester.pump();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Save changes'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final weighted = (await repo.getIntakeById('occurrence'))!;
      expect(weighted.amount, 2000);
      expect(weighted.meal.mealUnit, 'g');
      expect(weighted.meal.servingUnit, 'kg');
      expect(weighted.totalKcal, closeTo(intake.totalKcal, 1e-12));
      expect(weighted.meal.hasQuickAddWeight, true);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, edit: weighted);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(5)).controller!.text, '2.0');
      await tester.enterText(field(5), '');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Save changes'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final cleared = (await repo.getIntakeById('occurrence'))!;
      expect(cleared.meal.hasQuickAddWeight, false);
      expect(cleared.amount, 100);
      expect(cleared.totalKcal, closeTo(intake.totalKcal, 1e-12));
    },
  );
  testWidgets('Recent Quick Add logs immediately using the saved definition', (
    tester,
  ) async {
    final detail = _MealDetail();
    locator.registerSingleton<MealDetailBloc>(detail);
    await tester.runAsync(
      () => CustomMealDataSource(
        db,
      ).saveCustomMeal(MealDBO.fromMealEntity(quick(kcal: 250))),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        routes: {'main': (_) => const Scaffold()},
        home: Scaffold(
          body: MealItemCard(
            day: DateTime(2026, 10, 4),
            mealEntity: quick(),
            addMealType: AddMealType.breakfastType,
            usesImperialUnits: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(detail.calls, 1);
    expect(detail.meal!.nutriments.energyKcal100, 250);
    expect(detail.amount, '100');
    expect(find.byType(QuickAddBottomSheet), findsNothing);
  });
  for (final kj in [false, true]) {
    testWidgets(
      'editing retains occurrence and exact untouched values, kj=$kj',
      (tester) async {
        final intake = IntakeEntity(
          id: 'occurrence',
          unit: 'g',
          amount: 100,
          type: IntakeTypeEntity.lunch,
          dateTime: DateTime(2025, 1, 1, 12),
          meal: quick(),
        );
        await tester.runAsync(() async {
          await repo.addIntake(intake);
          await repo.addIntake(
            IntakeEntity(
              id: 'other',
              unit: 'g',
              amount: 100,
              type: intake.type,
              dateTime: intake.dateTime,
              meal: intake.meal,
            ),
          );
        });
        await mount(tester, edit: intake, kj: kj);
        await tester.pumpAndSettle();
        if (kj) {
          expect(
            double.parse(tester.widget<TextField>(field(1)).controller!.text),
            UnitCalc.kcalToKj(123.456789),
          );
        }
        await tester.enterText(field(0), 'Renamed quick');
        await tester.enterText(field(2), '0');
        await tester.ensureVisible(find.text('Save changes'));
        await tester.runAsync(() async {
          await tester.tap(find.text('Save changes'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump(const Duration(milliseconds: 300));
        final updated = (await repo.getIntakeById('occurrence'))!;
        expect(updated.id, intake.id);
        expect(updated.dateTime, intake.dateTime);
        expect(updated.type, intake.type);
        expect(updated.amount, intake.amount);
        expect(updated.meal.nutriments.energyKcal100, 123.456789);
        expect(updated.meal.nutriments.carbohydrates100, 0);
        expect(updated.meal.nutriments.fat100, isNull);
        expect(db.customMealBox.values.single.name, 'Renamed quick');
        expect((await repo.getIntakeById('other'))!.meal.name, 'Quick food');
      },
    );
  }
}
