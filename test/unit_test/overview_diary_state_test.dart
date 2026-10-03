import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_water_intake_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import '../fixture/meal_entity_fixtures.dart';
import '../helpers/overview_diary_harness.dart';

class DelayedIntakes extends GetIntakeUsecase {
  final DateTime delayedDay;
  final entered = Completer<void>();
  final release = Completer<void>();
  DelayedIntakes(super.repository, this.delayedDay);
  @override
  Future<List<IntakeEntity>> getBreakfastIntakeByDay(
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async {
    if (day == delayedDay) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return super.getBreakfastIntakeByDay(
      day,
      dayStartOffsetHours: dayStartOffsetHours,
      dayStartOffsetMinutes: dayStartOffsetMinutes,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OverviewDiaryHarness h;
  var now = DateTime(2026, 9, 29, 12);
  final today = DateTime(2026, 9, 29);
  final past = DateTime(2026, 9, 20);
  setUp(() async {
    now = DateTime(2026, 9, 29, 12);
    DayBoundaryCalc.clock = () => now;
    h = OverviewDiaryHarness();
    await h.initialize();
  });
  tearDown(() async {
    await h.dispose();
    DayBoundaryCalc.clock = DateTime.now;
  });

  Future<HomeLoadedState> reload() {
    final future = h.home!.stream
        .firstWhere((s) => s is HomeLoadedState)
        .then((s) => s as HomeLoadedState);
    h.home!.add(const LoadItemsEvent());
    return future;
  }

  test(
    'shared selection supports future dates, reset and conditional resume',
    () async {
      await h.configSource.setConfigDayStartOffsetHours(4);
      await h.configSource.setConfigDayStartOffsetMinutes(30);
      now = DateTime(2026, 9, 29, 3);
      await h.selection.initialize(reset: true);
      expect(h.selection.state.day, DateTime(2026, 9, 28));
      now = DateTime(2026, 9, 29, 5);
      await h.selection.initialize();
      expect(h.selection.state.day, today);
      h.selection.select(past);
      now = DateTime(2026, 9, 30, 5);
      await h.selection.initialize();
      expect(h.selection.state.day, past);
      h.selection.returnToToday();
      h.selection.step(1);
      expect(h.selection.state.day, DateTime(2026, 10, 1));
      h.selection.select(h.selection.state.lastDay);
      h.selection.step(1);
      expect(h.selection.state.day, h.selection.state.lastDay);
      await h.selection.initialize(reset: true);
      expect(h.selection.state.day, DateTime(2026, 9, 30));
    },
  );

  test('shell reload preserves selection; profile switch resets it', () async {
    var profile = 'one';
    final selection = SelectedDayCubit(
      h.getConfig,
      activeProfileId: () => profile,
    );
    addTearDown(selection.close);
    await selection.initialize();
    selection.select(past);
    await selection.initialize();
    expect(selection.state.day, past);
    profile = 'two';
    await selection.initialize();
    expect(selection.state.day, today);
    selection.select(selection.state.firstDay);
    now = DateTime(2026, 9, 30, 12);
    await selection.initialize();
    expect(selection.state.day, selection.state.firstDay);
  });

  test(
    'saved historical goals, actual intakes and last recorded weight',
    () async {
      await h.tracked.addNewTrackedDay(past, 1234, 90, 40, 80);
      await h.weight.addEntry(
        WeightLogEntity(date: DateTime(2026, 9, 19), weightKg: 71),
      );
      await h.weight.addEntry(WeightLogEntity(date: today, weightKg: 75));
      final intake = IntakeEntity(
        id: 'lunch',
        unit: 'g',
        amount: 100,
        type: IntakeTypeEntity.lunch,
        meal: MealEntityFixtures.mealOne,
        dateTime: past,
      );
      await h.intakes.addIntake(intake);
      h.selection.select(past);
      h.createHome();
      final state = await reload();
      expect(state.day, past);
      expect(state.totalKcalDaily, 1234);
      expect(state.totalCarbsGoal, 90);
      expect(state.totalKcalSupplied, intake.totalKcal);
      expect(state.weight?.weightKg, 71);
      expect(state.weight?.date, DateTime(2026, 9, 19));
      await h.intakes.deleteIntake(intake);
      expect((await reload()).totalKcalSupplied, 0);
    },
  );

  test(
    'empty day uses destination activities and creates no tracked day',
    () async {
      h.selection.select(past);
      await h.activities.addUserActivity(
        UserActivityEntity(
          'past',
          20,
          250,
          past,
          PhysicalActivityEntity.customNamed('Walk'),
        ),
      );
      await h.activities.addUserActivity(
        UserActivityEntity(
          'today',
          20,
          900,
          today,
          PhysicalActivityEntity.customNamed('Run'),
        ),
      );
      h.createHome();
      final state = await reload();
      expect(
        state.totalKcalDaily,
        await h.kcal.getKcalGoal(totalKcalActivitiesParam: 250),
      );
      expect(state.totalKcalBurned, 250);
      expect(state.totalKcalSupplied, 0);
      expect(state.weight, isNull);
      expect(await h.tracked.hasTrackedDay(past), isFalse);
    },
  );

  for (final home in [true, false]) {
    test(
      '${home ? 'Overview' : 'Diary'} discards a late previous-day response',
      () async {
        h.selection.select(past);
        final delayed = DelayedIntakes(h.intakes, past);
        final stream = home
            ? h.createHome(intakeReader: delayed).stream
            : h.createCalendar(intakeReader: delayed).stream;
        final emittedDays = <DateTime?>[];
        final subscription = stream.listen((state) {
          if (state is HomeLoadedState) emittedDays.add(state.day);
          if (state is CalendarDayLoaded) emittedDays.add(state.day);
        });
        if (home) h.home!.add(const LoadItemsEvent());
        if (!home) h.calendar!.add(LoadCalendarDayEvent(past));
        await delayed.entered.future;
        final completed = stream.firstWhere(
          (s) => s is HomeLoadedState || s is CalendarDayLoaded,
        );
        h.selection.select(today);
        await completed;
        delayed.release.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(emittedDays, [today]);
        await subscription.cancel();
      },
    );
  }

  for (final day in [
    DateTime(2026, 9, 20),
    DateTime(2026, 9, 29),
    DateTime(2026, 10, 2),
  ]) {
    test('water add/edit/delete uses selected logical day $day', () async {
      await h.configSource.setConfigDayStartOffsetHours(4);
      await h.configSource.setConfigDayStartOffsetMinutes(30);
      now = DateTime(2026, 9, 29, 2, 15);
      h.selection.select(day);
      h.createCalendar();
      await h.calendar!.saveWater(day, 250);
      final reader = GetWaterIntakeUsecase(h.water);
      var entries = await reader.getEntriesForDay(
        day,
        dayStartOffsetTotalMinutes: 270,
      );
      expect(
        entries.single.dateTime,
        DateTime(day.year, day.month, day.day + 1, 2, 15),
      );
      final original = entries.single;
      await h.calendar!.saveWater(day, 337, entry: original);
      entries = await reader.getEntriesForDay(
        day,
        dayStartOffsetTotalMinutes: 270,
      );
      expect(entries.single.id, original.id);
      expect(entries.single.dateTime, original.dateTime);
      expect(entries.single.amountMl, 337);
      expect(
        await reader.getEntriesForDay(
          DateTime(day.year, day.month, day.day + 1),
          dayStartOffsetTotalMinutes: 270,
        ),
        isEmpty,
      );
      await h.calendar!.removeWater(entries.single);
      expect(await reader.getAllEntries(), isEmpty);
      expect(await h.tracked.hasTrackedDay(day), isFalse);
    });
  }
}
