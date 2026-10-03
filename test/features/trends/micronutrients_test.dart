import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:opennutritracker/features/trends/presentation/widgets/micronutrients_trend_card.dart';
import '../../helpers/overview_diary_harness.dart';
import '../overview/overview_widgets_test.dart' show app, id;

IntakeEntity intake(String id, DateTime time, {double amount = 100}) =>
    IntakeEntity(
      id: id,
      amount: amount,
      unit: 'g',
      type: IntakeTypeEntity.lunch,
      dateTime: time,
      meal: MealEntity(
        code: 'food',
        name: 'Food',
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        source: MealSourceEntity.custom,
        nutriments: MealNutrimentsEntity(
          energyKcal100: 100,
          carbohydrates100: 1,
          proteins100: 2,
          fat100: 3,
          sugars100: 4,
          saturatedFat100: 1,
          fiber100: 14,
          sodium100: 70,
        ),
      ),
    );

class DelayedHistory extends Fake implements GetIntakeUsecase {
  final first = Completer<List<IntakeEntity>>();
  int calls = 0;
  @override
  Future<List<IntakeEntity>> getIntakesByRange(
    DateTime start,
    DateTime end, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async {
    if (++calls == 1) return first.future;
    return [];
  }
}

void main() {
  group('Trends nutrient storage', () {
    late OverviewDiaryHarness h;
    late TrendsBloc bloc;
    TrendsBloc makeBloc([GetIntakeUsecase? reader]) => TrendsBloc(
      GetTrackedDayUsecase(h.tracked),
      GetWeightLogUsecase(h.weight),
      h.getUser,
      h.getConfig,
      GetWaterIntakeUsecase(h.water),
      reader ?? h.getIntakes,
    );
    Future<TrendsLoaded> load([int range = 7]) async {
      final result = bloc.stream.firstWhere((s) => s is TrendsLoaded);
      bloc.add(LoadTrendsEvent(rangeDays: range));
      return await result as TrendsLoaded;
    }

    setUp(() async {
      DayBoundaryCalc.clock = () => DateTime(2026, 9, 29, 4, 29);
      h = OverviewDiaryHarness();
      await h.initialize();
      await h.configSource.setConfigDayStartOffsetHours(4);
      await h.configSource.setConfigDayStartOffsetMinutes(30);
      await h.configSource.setConfigNutrientPanelVisibility({'sodium': false});
      bloc = makeBloc();
    });
    tearDown(() async {
      await bloc.close();
      await h.dispose();
      DayBoundaryCalc.clock = DateTime.now;
    });
    test(
      'groups portions by logical day, preserves date labels, excludes future and old records',
      () async {
        for (final entry in [
          intake('before', DateTime(2026, 9, 22, 4, 29)),
          intake('start', DateTime(2026, 9, 22, 4, 30), amount: 50),
          intake('date-label', DateTime.utc(2026, 9, 28)),
          intake('end', DateTime(2026, 9, 29, 4, 29), amount: 25),
          intake('future', DateTime(2026, 9, 29, 4, 30)),
        ]) {
          await h.intakes.addIntake(entry);
        }
        final state = await load();
        expect(state.today, DateTime(2026, 9, 28));
        expect(
          state.nutrientsByDay.keys,
          unorderedEquals([DateTime(2026, 9, 22), DateTime(2026, 9, 28)]),
        );
        expect(state.nutrientsByDay[DateTime(2026, 9, 22)]!.fiberG, 7);
        expect(state.nutrientsByDay[DateTime(2026, 9, 28)]!.fiberG, 17.5);
        expect(state.nutrientsByDay[DateTime(2026, 9, 28)]!.sodiumMg, 87.5);
        expect(state.nutrientVisibility['sodium'], false);
        expect(
          (await GetTrackedDayUsecase(
            h.tracked,
          ).getTrackedDaysByRange(DateTime(2026), DateTime(2027))),
          isEmpty,
        );
      },
    );
    test(
      'All includes intake-only history and refresh reflects deletion',
      () async {
        final food = intake('only', DateTime(2026, 9, 1));
        await h.intakes.addIntake(food);
        expect((await load(0)).windowDays, 28);
        await h.intakes.deleteIntake(food);
        final empty = await load(0);
        expect(empty.nutrientsByDay, isEmpty);
        expect(empty.windowDays, 30);
      },
    );
    test('late history response cannot replace a newer range', () async {
      await bloc.close();
      final reader = DelayedHistory();
      bloc = makeBloc(reader);
      bloc.add(const LoadTrendsEvent());
      while (reader.calls == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect((await load(30)).rangeDays, 30);
      reader.first.complete([intake('late', DateTime(2026, 9, 28))]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((bloc.state as TrendsLoaded).rangeDays, 30);
      expect((bloc.state as TrendsLoaded).nutrientsByDay, isEmpty);
    });
  });

  testWidgets(
    'nutrient graph plots portions, zero days, average and switches units',
    (tester) async {
      final today = DateTime(2026, 9, 29);
      final totals = NutrientPanelTotals.fromIntakes([intake('today', today)]);
      await tester.pumpWidget(
        app(
          MicronutrientsTrendCard(
            today: today,
            rangeDays: 7,
            nutrientsByDay: {today: totals},
            visibility: const {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Daily average: 2 g'), findsOneWidget);
      var chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [
        0,
        0,
        0,
        0,
        0,
        0,
        14,
      ]);
      await tester.tap(id('trends-nutrient-selector'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sodium').last);
      await tester.pumpAndSettle();
      expect(find.text('Daily average: 10 mg'), findsOneWidget);
      chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots.last.y, 70);
      expect(find.text('Sep 23'), findsOneWidget);
      expect(find.text('Sep 29'), findsOneWidget);
      await tester.pumpWidget(
        app(
          MicronutrientsTrendCard(
            today: today,
            rangeDays: 30,
            nutrientsByDay: {today: totals},
            visibility: const {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Daily average: 2.3 mg'), findsOneWidget);
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .length,
        30,
      );
    },
  );

  testWidgets('visibility, empty data and long labels fit compact large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: MicronutrientsTrendCard(
              today: DateTime(2026, 9, 29),
              rangeDays: 90,
              nutrientsByDay: const {},
              visibility: {
                for (final key in NutrientPanelKeys.all)
                  key: key == NutrientPanelKeys.saturatedFat,
              },
            ),
          ),
          theme: buildAppTheme(palette),
          scale: 2,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .length,
        90,
      );
      await tester.tap(id('trends-nutrient-selector'));
      await tester.pumpAndSettle();
      expect(find.text('Natrium'), findsNothing);
      expect(tester.takeException(), isNull);
      // Dismiss the dropdown before replacing the tree.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(
      app(
        MicronutrientsTrendCard(
          today: DateTime(2026, 9, 29),
          rangeDays: 7,
          nutrientsByDay: const {},
          visibility: {for (final key in NutrientPanelKeys.all) key: false},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('All nutrients hidden'), findsOneWidget);
  });
}
