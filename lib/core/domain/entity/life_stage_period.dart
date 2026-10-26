import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'life_stage_period.g.dart';

@HiveType(typeId: 29)
enum LifeStage {
  @HiveField(0)
  pregnancy,
  @HiveField(1)
  breastfeeding,
}

/// Calendar days, with both endpoints included. Null end means ongoing.
@HiveType(typeId: 28)
@JsonSerializable()
class LifeStagePeriod {
  @HiveField(0)
  final LifeStage stage;
  @HiveField(1)
  final DateTime start;
  @HiveField(2)
  final DateTime? end;
  LifeStagePeriod({required this.stage, required DateTime start, DateTime? end})
    : start = DateTime(start.year, start.month, start.day),
      end = end == null ? null : DateTime(end.year, end.month, end.day) {
    if (this.end != null && this.end!.isBefore(this.start)) {
      throw ArgumentError('End must be on or after start');
    }
  }
  bool contains(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(start) && (end == null || !date.isAfter(end!));
  }

  bool overlaps(LifeStagePeriod other) =>
      (end == null || !other.start.isAfter(end!)) &&
      (other.end == null || !start.isAfter(other.end!));
  static List<LifeStagePeriod> validated(Iterable<LifeStagePeriod> periods) {
    final sorted = periods.toList()..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].overlaps(sorted[i])) {
        throw ArgumentError('Life-stage periods overlap');
      }
    }
    return sorted;
  }

  factory LifeStagePeriod.fromJson(Map<String, dynamic> json) =>
      _$LifeStagePeriodFromJson(json);
  Map<String, dynamic> toJson() => _$LifeStagePeriodToJson(this);
}
