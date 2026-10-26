// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrient_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NutrientGoalAdapter extends TypeAdapter<NutrientGoal> {
  @override
  final typeId = 26;

  @override
  NutrientGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutrientGoal(
      (fields[0] as num).toDouble(),
      isLimit: fields[1] == null ? false : fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NutrientGoal obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.amount)
      ..writeByte(1)
      ..write(obj.isLimit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutrientGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NutrientGoal _$NutrientGoalFromJson(Map<String, dynamic> json) => NutrientGoal(
  (json['amount'] as num).toDouble(),
  isLimit: json['isLimit'] as bool? ?? false,
);

Map<String, dynamic> _$NutrientGoalToJson(NutrientGoal instance) =>
    <String, dynamic>{'amount': instance.amount, 'isLimit': instance.isLimit};
