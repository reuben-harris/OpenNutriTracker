import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/domain/usecase/get_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import '../helpers/overview_diary_harness.dart';

// Run with TZ=Pacific/Auckland to exercise both DST transitions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final date in [DateTime(2026, 9, 26), DateTime(2026, 4, 4)]) {
    test(
      'logical water boundary spans local dates across DST near $date',
      () async {
        final h = OverviewDiaryHarness();
        await h.initialize();
        addTearDown(h.dispose);
        final from = DayBoundaryCalc.boundaryOf(date, 270);
        final next = DateTime(date.year, date.month, date.day + 1);
        final to = DayBoundaryCalc.boundaryOf(next, 270);
        final lastMinute = DateTime(next.year, next.month, next.day, 4, 29);
        expect(DayBoundaryCalc.logicalDayOfMinutes(lastMinute, 270), date);
        await h.water.addEntry(
          WaterIntakeEntity(id: 'start', dateTime: from, amountMl: 100),
        );
        await h.water.addEntry(
          WaterIntakeEntity(id: 'end', dateTime: lastMinute, amountMl: 200),
        );
        await h.water.addEntry(
          WaterIntakeEntity(id: 'next', dateTime: to, amountMl: 300),
        );
        final entries = await GetWaterIntakeUsecase(
          h.water,
        ).getEntriesForDay(date, dayStartOffsetTotalMinutes: 270);
        expect(entries.map((e) => e.id), unorderedEquals(['start', 'end']));
        if (from.timeZoneOffset != to.timeZoneOffset) {
          expect(to.difference(from).inHours, date.month == 9 ? 23 : 25);
        }
        expect(
          DayBoundaryCalc.timestampInDay(date, 270, now: lastMinute),
          lastMinute,
        );
      },
    );
  }
}
