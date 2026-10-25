import 'dart:io' show Platform;
import 'dart:math' show max;

import 'package:health/health.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:opennutritracker/core/data/data_source/health/external_workout.dart';
import 'package:opennutritracker/core/data/data_source/health/health_connect_workout_reader.dart';
import 'package:opennutritracker/core/data/data_source/health/health_service.dart';

/// Which platform's health store rules apply.
///
/// Injected into [HealthPackageService] rather than read from [Platform] at
/// every branch, because the two platforms now diverge in what they read and
/// a host test is neither of them.
enum HealthTargetPlatform {
  android,
  ios,
  unsupported;

  static HealthTargetPlatform get current {
    if (Platform.isAndroid) return HealthTargetPlatform.android;
    if (Platform.isIOS) return HealthTargetPlatform.ios;
    return HealthTargetPlatform.unsupported;
  }
}

/// [HealthService] backed by the `health` plugin — Health Connect on
/// Android, HealthKit on iOS.
///
/// Deliberately free of business logic: it asks for the data types the
/// feature needs, hands back plain [ExternalWorkout] records, and leaves
/// every decision about what to do with them to the import use case.
///
/// Android sessions are read through [HealthConnectWorkoutReader] because
/// the plugin also queries distance and steps, which this feature does not
/// use or request permission for. HealthKit reads the workout directly.
class HealthPackageService implements HealthService {
  /// Workouts, on every platform that has a health store. On Android this is
  /// requested (it is what grants READ_EXERCISE) but read through
  /// [HealthConnectWorkoutReader] rather than the plugin.
  static const _workoutType = HealthDataType.WORKOUT;

  /// Health Connect sessions carry no energy of their own — apps write
  /// separate TOTAL_CALORIES_BURNED records — so the calorie read is what
  /// gives an imported workout its kcal. HealthKit puts the total on the
  /// workout itself, so asking for this on iOS would add a permission row the
  /// feature never uses.
  static const _androidEnergyType = HealthDataType.TOTAL_CALORIES_BURNED;

  List<HealthDataType> get _readTypes => [
    _workoutType,
    if (_platform == HealthTargetPlatform.android) _androidEnergyType,
  ];

  static final _log = Logger('HealthPackageService');
  final Health _health;
  final HealthConnectWorkoutReader _workoutReader;
  final HealthTargetPlatform _platform;

  HealthPackageService(
    this._health, {
    HealthConnectWorkoutReader? workoutReader,
    HealthTargetPlatform? platform,
  }) : _workoutReader = workoutReader ?? HealthConnectWorkoutReader(),
       _platform = platform ?? HealthTargetPlatform.current;

  /// Builds a configured service. [Health.configure] resolves the device id
  /// and has to run before any query, so it happens here rather than lazily
  /// on the first import.
  static Future<HealthPackageService> create() async {
    final health = Health();
    await health.configure();
    return HealthPackageService(health);
  }

  @override
  Future<bool> isAvailable() async {
    if (_platform == HealthTargetPlatform.unsupported) return false;
    return await _health.isHealthConnectAvailable();
  }

  @override
  Future<bool> requestPermissions() async {
    final granted = await _health.requestAuthorization(
      _readTypes,
      permissions: List.filled(_readTypes.length, HealthDataAccess.READ),
    );
    if (!granted) return false;
    // Android answers the request with "was anything at all granted", so a
    // user who ticked calories and left exercise unticked would switch the
    // feature on with nothing importable behind it. Re-check the types a
    // workout read actually needs. hasPermissions answers null where the
    // platform will not say (iOS never reports read grants) — same rule as
    // [readWorkouts], only a definite refusal counts.
    final hasWorkoutPermissions = await _health.hasPermissions(
      _readTypes,
      permissions: List.filled(_readTypes.length, HealthDataAccess.READ),
    );
    return hasWorkoutPermissions != false;
  }

  @override
  Future<List<ExternalWorkout>> readWorkouts({
    required DateTime from,
    required DateTime to,
  }) async {
    // The plugin swallows a SecurityException from a partially-revoked grant
    // and answers with an empty list, which upstream would file as "nothing
    // new" and advance the watermark. Check first and fail loudly instead.
    // hasPermissions answers null where the platform will not say (iOS never
    // reports read grants); only a definite refusal aborts.
    final hasPermissions = await _health.hasPermissions(
      _readTypes,
      permissions: List.filled(_readTypes.length, HealthDataAccess.READ),
    );
    if (hasPermissions == false) {
      throw StateError(
        'Missing health read permissions for a workout import; '
        'needed: $_readTypes',
      );
    }
    if (_platform == HealthTargetPlatform.android) {
      return await _readAndroidWorkouts(from: from, to: to);
    }
    final points = await _health.getHealthDataFromTypes(
      types: const [_workoutType],
      startTime: from,
      endTime: to,
    );
    final workouts = <ExternalWorkout>[];
    for (final point in points) {
      final value = point.value;
      if (value is! WorkoutHealthValue) {
        // The platform answered a WORKOUT query with something that isn't a
        // workout — worth knowing about, not worth failing the import over.
        _log.warning(
          'Skipping health point ${point.uuid}: expected a workout value, '
          'got ${value.runtimeType}',
        );
        continue;
      }
      workouts.add(
        ExternalWorkout(
          id: point.uuid,
          start: point.dateFrom,
          end: point.dateTo,
          activityTypeName: value.workoutActivityType.name,
          // A HealthKit workout carries its own total.
          energyBurnedKcal: _energyInKcal(
            value.totalEnergyBurned,
            value.totalEnergyBurnedUnit,
          ),
          sourceAppName: point.sourceName,
        ),
      );
    }
    return workouts;
  }

  /// Workouts from Health Connect, read outside the plugin.
  ///
  /// A session record carries no energy, so the calorie records for the whole
  /// window are read once and attributed per workout by
  /// [androidWorkoutEnergyKcal] — which is also why the plugin's own totals
  /// were never used here even when they were available.
  Future<List<ExternalWorkout>> _readAndroidWorkouts({
    required DateTime from,
    required DateTime to,
  }) async {
    final sessions = await _workoutReader.readExerciseSessions(
      from: from,
      to: to,
    );
    if (sessions.isEmpty) return const <ExternalWorkout>[];
    final calorieRecords = await _health.getHealthDataFromTypes(
      types: const [_androidEnergyType],
      startTime: from,
      endTime: to,
    );
    return [
      for (final session in sessions)
        ExternalWorkout(
          id: session.id,
          start: session.start,
          end: session.end,
          activityTypeName: session.activityTypeName,
          energyBurnedKcal: androidWorkoutEnergyKcal(
            start: session.start,
            end: session.end,
            sourceName: session.sourceAppName ?? '',
            calorieRecords: calorieRecords,
          ),
          sourceAppName: session.sourceAppName,
        ),
    ];
  }

  /// Energy attributable to one Android workout session.
  ///
  /// A Health Connect session record carries no calories of its own; apps
  /// write separate TOTAL_CALORIES_BURNED records, and the plugin fills a
  /// workout's total by summing every such record overlapping the session
  /// window regardless of who wrote it. Alongside an all-day calorie stream
  /// (Fitbit and Google Fit write basal+activity in 15-minute buckets —
  /// energy the calorie goal already models) that inflates a real workout by
  /// whatever the background stream put into the same window. Only the
  /// records the session's own writer produced are the workout's energy, so
  /// the sum is per-source: [sourceName]'s own records when it wrote any,
  /// otherwise the largest single-source sum in the window (some setups
  /// track sessions in one app and calories in another) — never the
  /// cross-source total.
  ///
  /// A record belongs to the window when it STARTS inside it ([start]
  /// inclusive, [end] exclusive) — the same startTime-based semantics Health
  /// Connect's own between() filter applies.
  @visibleForTesting
  static double? androidWorkoutEnergyKcal({
    required DateTime start,
    required DateTime end,
    required String sourceName,
    required List<HealthDataPoint> calorieRecords,
  }) {
    final kcalBySource = <String, double>{};
    for (final record in calorieRecords) {
      if (record.dateFrom.isBefore(start) || !record.dateFrom.isBefore(end)) {
        continue;
      }
      final value = record.value;
      if (value is! NumericHealthValue) continue;
      final kcal = _energyInKcal(value.numericValue, record.unit);
      if (kcal == null) continue;
      kcalBySource.update(
        record.sourceName,
        (sum) => sum + kcal,
        ifAbsent: () => kcal,
      );
    }
    final ownKcal = kcalBySource[sourceName] ?? 0;
    if (ownKcal > 0) return ownKcal;
    final largestKcal = kcalBySource.values.fold(0.0, max);
    return largestKcal > 0 ? largestKcal : null;
  }

  /// Both platform bridges report workout energy in kilocalories, but the
  /// unit travels with the value, so honour it rather than assuming. An
  /// energy unit we can't convert is dropped: a workout with no usable
  /// figure is skipped upstream, which is safer than importing a number that
  /// is off by a factor of four thousand.
  static double? _energyInKcal(num? energy, HealthDataUnit? unit) {
    if (energy == null) return null;
    switch (unit) {
      case null:
      case HealthDataUnit.KILOCALORIE:
      case HealthDataUnit.LARGE_CALORIE:
        return energy.toDouble();
      case HealthDataUnit.SMALL_CALORIE:
        return energy / 1000;
      case HealthDataUnit.JOULE:
        return energy / 4184;
      default:
        _log.warning('Dropping workout energy in unsupported unit $unit');
        return null;
    }
  }
}
