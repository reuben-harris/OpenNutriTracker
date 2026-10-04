import 'package:collection/collection.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/visible_intakes.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class IntakeDataSource {
  final log = Logger('IntakeDataSource');
  final HiveDBProvider _db;

  IntakeDataSource(this._db);

  Box<IntakeDBO> get _intakeBox => _db.intakeBox;

  Iterable<IntakeDBO> get _visibleIntakes => visibleIntakes(_intakeBox.values);

  Future<void> addIntake(IntakeDBO intakeDBO) async {
    log.fine('Adding new intake item to db');
    await _intakeBox.add(intakeDBO);
  }

  Future<void> addAllIntakes(List<IntakeDBO> intakeDBOList) async {
    log.fine('Adding new intake items to db');
    await _intakeBox.addAll(intakeDBOList);
  }

  Future<void> deleteIntakeFromId(String intakeId) async {
    log.fine('Deleting intake item from db');
    final toDelete = _intakeBox.values
        .where((dbo) => dbo.id == intakeId)
        .toList();
    for (final element in toDelete) {
      await element.delete();
    }
  }

  Future<IntakeDBO?> updateIntake(
    String intakeId,
    Map<String, dynamic> fields,
  ) async {
    log.fine(
      'Updating intake $intakeId with fields ${fields.toString()} in db',
    );
    var intakeObject = _intakeBox.values.indexed
        .where((indexedDbo) => indexedDbo.$2.id == intakeId)
        .firstOrNull;
    if (intakeObject == null) {
      log.fine('Cannot update intake $intakeId as it is non existent');
      return null;
    }
    final box = _intakeBox;
    intakeObject.$2.amount = fields['amount'] ?? intakeObject.$2.amount;
    intakeObject.$2.unit = fields['unit'] ?? intakeObject.$2.unit;
    if (fields.containsKey('meal')) intakeObject.$2.meal = fields['meal'];
    if (fields.containsKey('recipeSnapshot')) {
      intakeObject.$2.recipeSnapshot = fields['recipeSnapshot'];
    }
    await _intakeBox.putAt(intakeObject.$1, intakeObject.$2);
    await _reconcileDay(box, intakeObject.$2.dateTime);
    return box.getAt(intakeObject.$1);
  }

  Future<void> _reconcileDay(Box<IntakeDBO> box, DateTime moment) async {
    final config = ConfigEntity.fromConfigDBO(
      await ConfigDataSource(_db).getConfig(),
    );
    if (!identical(box, _intakeBox)) return;
    final offset = config.dayStartOffsetTotalMinutes;
    final wallDay = DateTime(moment.year, moment.month, moment.day);
    final day =
        DayBoundaryCalc.isMomentInLogicalDayMinutes(wallDay, moment, offset)
        ? wallDay
        : DateTime(moment.year, moment.month, moment.day - 1);
    var kcal = 0.0, carbs = 0.0, fat = 0.0, protein = 0.0;
    for (final dbo in visibleIntakes(box.values)) {
      if (!DayBoundaryCalc.isMomentInLogicalDayMinutes(
        day,
        dbo.dateTime,
        offset,
      )) {
        continue;
      }
      final intake = IntakeEntity.fromIntakeDBO(dbo);
      kcal += intake.totalKcal;
      carbs += intake.totalCarbsGram;
      fat += intake.totalFatsGram;
      protein += intake.totalProteinsGram;
    }
    await TrackedDayDataSource(
      _db,
    ).reconcileCaloriesAndMacrosTracked(day, kcal, carbs, fat, protein);
  }

  Future<IntakeDBO?> getIntakeById(String intakeId) async {
    return _visibleIntakes.firstWhereOrNull((intake) => intake.id == intakeId);
  }

  Future<IntakeDBO?> moveIntakeToType(
    String intakeId,
    IntakeTypeDBO targetType,
  ) async {
    final intake = await getIntakeById(intakeId);
    if (intake == null || intake.type == targetType) return intake;
    intake.type = targetType;
    await intake.save();
    return intake;
  }

  Future<List<IntakeDBO>> getAllIntakes() async {
    return _visibleIntakes.toList();
  }

  /// Intakes of [intakeType] filed under the calendar day [day].
  ///
  /// [day] is a day label — the date the user is looking at — not a
  /// moment in time. #139: when a non-zero day-start offset is
  /// configured, an entry logged before that time rolls into the
  /// previous day; the label itself must stay put (#586). The follow-up
  /// to #139 adds a minutes companion, which composes additively into a
  /// single total-minutes value here. A zero total offset reduces to the
  /// original wall-clock-day behaviour.
  Future<List<IntakeDBO>> getAllIntakesByDate(
    IntakeTypeDBO intakeType,
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async {
    final totalMinutes = DayBoundaryCalc.totalMinutesOf(
      dayStartOffsetHours,
      dayStartOffsetMinutes,
    );
    return _visibleIntakes
        .where(
          (intake) =>
              DayBoundaryCalc.isMomentInLogicalDayMinutes(
                day,
                intake.dateTime,
                totalMinutes,
              ) &&
              intake.type == intakeType,
        )
        .toList();
  }

  Future<List<IntakeDBO>> getRecentlyAddedIntake({int number = 100000}) async {
    final intakeList = _visibleIntakes.toList();

    //  sort list by date (newest first) and filter unique intake
    intakeList.sort((a, b) => (-1) * a.dateTime.compareTo(b.dateTime));

    final filterCodes = <String>{};
    final uniqueIntake = intakeList
        .where(
          (intake) =>
              filterCodes.add(intake.meal.code ?? intake.meal.name ?? ""),
        )
        .toList();

    // Surface custom meals before remote-sourced results.
    final custom = uniqueIntake
        .where((i) => i.meal.source == MealSourceDBO.custom)
        .toList();
    final others = uniqueIntake
        .where((i) => i.meal.source != MealSourceDBO.custom)
        .toList();
    return [...custom, ...others].take(number).toList();
  }

  Future<List<IntakeDBO>> getCustomMealIntakes() async {
    return _visibleIntakes
        .where((dbo) => dbo.meal.source == MealSourceDBO.custom)
        .toList();
  }

  /// Replace the denormalised [MealDBO] snapshot on every intake whose
  /// `(meal.code ?? meal.name)` matches [fromMealKey] *and* whose meal source
  /// is custom. Used by the custom-meal merge flow: callers compute the
  /// kcal/macro deltas before invoking this and apply them to TrackedDay
  /// totals separately.
  ///
  /// Returns the list of `(oldIntake, newIntake)` pairs that were rewritten,
  /// so the caller can recompute totals from the diff.
  Future<List<(IntakeDBO, IntakeDBO)>> remapCustomMealOnIntakes({
    required String fromMealKey,
    required MealDBO toMeal,
  }) async {
    final rewrites = <(IntakeDBO, IntakeDBO)>[];
    final entries = _intakeBox.toMap().entries.toList();
    for (final entry in entries) {
      final dbo = entry.value;
      if (dbo.meal.source != MealSourceDBO.custom) continue;
      final key = dbo.meal.code ?? dbo.meal.name;
      if (key != fromMealKey) continue;
      final updated = IntakeDBO(
        id: dbo.id,
        unit: dbo.unit,
        amount: dbo.amount,
        type: dbo.type,
        meal: toMeal,
        dateTime: dbo.dateTime,
        recipeSnapshot: dbo.recipeSnapshot,
        conversionParentId: dbo.conversionParentId,
      );
      await _intakeBox.put(entry.key, updated);
      rewrites.add((dbo, updated));
    }
    return rewrites;
  }
}
