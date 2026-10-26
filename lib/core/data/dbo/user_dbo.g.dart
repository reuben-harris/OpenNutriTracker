// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserDBOAdapter extends TypeAdapter<UserDBO> {
  @override
  final typeId = 5;

  @override
  UserDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserDBO(
      birthday: fields[0] as DateTime,
      heightCM: (fields[1] as num).toDouble(),
      weightKG: (fields[2] as num).toDouble(),
      sex: fields[3] as UserSexDBO,
      goal: fields[4] as UserWeightGoalDBO,
      pal: fields[5] as UserPALDBO,
      nutrientPolicies: fields[12] == null
          ? const {}
          : (fields[12] as Map).cast<String, NutrientPolicy>(),
      heightHistory: (fields[10] as List?)?.cast<HeightReading>(),
      lifeStagePeriods: fields[11] == null
          ? const []
          : (fields[11] as List).cast<LifeStagePeriod>(),
      weeklyWeightGoalKg: (fields[6] as num?)?.toDouble(),
      targetWeightKg: (fields[8] as num?)?.toDouble(),
      caloriesTaperEnabled: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserDBO obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.birthday)
      ..writeByte(1)
      ..write(obj.heightCM)
      ..writeByte(2)
      ..write(obj.weightKG)
      ..writeByte(3)
      ..write(obj.sex)
      ..writeByte(4)
      ..write(obj.goal)
      ..writeByte(5)
      ..write(obj.pal)
      ..writeByte(6)
      ..write(obj.weeklyWeightGoalKg)
      ..writeByte(8)
      ..write(obj.targetWeightKg)
      ..writeByte(9)
      ..write(obj.caloriesTaperEnabled)
      ..writeByte(10)
      ..write(obj.heightHistory)
      ..writeByte(11)
      ..write(obj.lifeStagePeriods)
      ..writeByte(12)
      ..write(obj.nutrientPolicies);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDBO _$UserDBOFromJson(Map<String, dynamic> json) => UserDBO(
  birthday: DateTime.parse(json['birthday'] as String),
  heightCM: (json['heightCM'] as num).toDouble(),
  weightKG: (json['weightKG'] as num).toDouble(),
  sex: $enumDecode(_$UserSexDBOEnumMap, json['sex']),
  goal: $enumDecode(_$UserWeightGoalDBOEnumMap, json['goal']),
  pal: $enumDecode(_$UserPALDBOEnumMap, json['pal']),
  nutrientPolicies:
      (json['nutrientPolicies'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, NutrientPolicy.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
  heightHistory: (json['heightHistory'] as List<dynamic>?)
      ?.map((e) => HeightReading.fromJson(e as Map<String, dynamic>))
      .toList(),
  lifeStagePeriods:
      (json['lifeStagePeriods'] as List<dynamic>?)
          ?.map((e) => LifeStagePeriod.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  weeklyWeightGoalKg: (json['weeklyWeightGoalKg'] as num?)?.toDouble(),
  targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
  caloriesTaperEnabled: json['caloriesTaperEnabled'] as bool? ?? false,
);

Map<String, dynamic> _$UserDBOToJson(UserDBO instance) => <String, dynamic>{
  'birthday': instance.birthday.toIso8601String(),
  'heightCM': instance.heightCM,
  'weightKG': instance.weightKG,
  'sex': _$UserSexDBOEnumMap[instance.sex]!,
  'goal': _$UserWeightGoalDBOEnumMap[instance.goal]!,
  'pal': _$UserPALDBOEnumMap[instance.pal]!,
  'weeklyWeightGoalKg': instance.weeklyWeightGoalKg,
  'targetWeightKg': instance.targetWeightKg,
  'caloriesTaperEnabled': instance.caloriesTaperEnabled,
  'heightHistory': instance.heightHistory?.map((e) => e.toJson()).toList(),
  'lifeStagePeriods': instance.lifeStagePeriods.map((e) => e.toJson()).toList(),
  'nutrientPolicies': instance.nutrientPolicies.map(
    (k, e) => MapEntry(k, e.toJson()),
  ),
};

const _$UserSexDBOEnumMap = {
  UserSexDBO.male: 'male',
  UserSexDBO.female: 'female',
};

const _$UserWeightGoalDBOEnumMap = {
  UserWeightGoalDBO.loseWeight: 'loseWeight',
  UserWeightGoalDBO.maintainWeight: 'maintainWeight',
  UserWeightGoalDBO.gainWeight: 'gainWeight',
};

const _$UserPALDBOEnumMap = {
  UserPALDBO.sedentary: 'sedentary',
  UserPALDBO.lowActive: 'lowActive',
  UserPALDBO.active: 'active',
  UserPALDBO.veryActive: 'veryActive',
};
