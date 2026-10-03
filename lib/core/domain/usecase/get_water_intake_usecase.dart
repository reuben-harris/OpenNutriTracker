import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';

/// Reads water intake entries grouped by the configured logical day so the
/// home chip and any future graph view both see the same boundary as the
/// rest of the diary (#139).
class GetWaterIntakeUsecase {
  final WaterIntakeRepository _waterIntakeRepository;

  GetWaterIntakeUsecase(this._waterIntakeRepository);

  Future<List<WaterIntakeEntity>> getEntriesForDay(
    DateTime logicalDayStart, {
    required int dayStartOffsetTotalMinutes,
  }) async {
    final from = DayBoundaryCalc.boundaryOf(
      logicalDayStart,
      dayStartOffsetTotalMinutes,
    );
    final to = DayBoundaryCalc.boundaryOf(
      DateTime(
        logicalDayStart.year,
        logicalDayStart.month,
        logicalDayStart.day + 1,
      ),
      dayStartOffsetTotalMinutes,
    );
    return _waterIntakeRepository.getEntriesInRange(from, to);
  }

  Future<List<WaterIntakeEntity>> getTodayEntries({
    required int dayStartOffsetTotalMinutes,
  }) async {
    final logicalToday = DayBoundaryCalc.currentLogicalDayMinutes(
      dayStartOffsetTotalMinutes,
    );
    return getEntriesForDay(
      logicalToday,
      dayStartOffsetTotalMinutes: dayStartOffsetTotalMinutes,
    );
  }

  Future<List<WaterIntakeEntity>> getAllEntries() async {
    return _waterIntakeRepository.getAllEntries();
  }
}
