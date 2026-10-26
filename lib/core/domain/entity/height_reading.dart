import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'height_reading.g.dart';

@HiveType(typeId: 27)
@JsonSerializable()
class HeightReading {
  @HiveField(0)
  final DateTime date;
  @HiveField(1)
  final double centimetres;

  HeightReading({required DateTime date, required this.centimetres})
    : date = DateTime(date.year, date.month, date.day) {
    if (!centimetres.isFinite || centimetres <= 0) {
      throw ArgumentError.value(centimetres, 'centimetres');
    }
  }

  factory HeightReading.fromJson(Map<String, dynamic> json) =>
      _$HeightReadingFromJson(json);
  Map<String, dynamic> toJson() => _$HeightReadingToJson(this);
}
