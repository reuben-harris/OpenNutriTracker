// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConfigDBOAdapter extends TypeAdapter<ConfigDBO> {
  @override
  final typeId = 13;

  @override
  ConfigDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConfigDBO(
        fields[3] as AppThemeDBO,
        usesImperialUnits: fields[4] == null ? false : fields[4] as bool?,
        userKcalAdjustment: (fields[5] as num?)?.toDouble(),
        showActivityTracking: fields[9] as bool?,
        notificationsEnabled: fields[10] as bool?,
        notificationHour: (fields[11] as num?)?.toInt(),
        notificationMinute: (fields[12] as num?)?.toInt(),
        usesKilojoules: fields[16] as bool?,
        mealKcalSharesPct: (fields[17] as Map?)?.cast<String, int>(),
        customMealFormMode: fields[18] as String?,
        dayStartOffsetHours: (fields[19] as num?)?.toInt(),
        diarySortPreferences: (fields[21] as Map?)?.cast<String, int>(),
        nutrientPanelVisibility: (fields[22] as Map?)?.cast<String, bool>(),
        nutrientInfoVisibility: (fields[44] as Map?)?.cast<String, bool>(),
        showMissingNutrientsInInfo: fields[46] as bool?,
        dayStartOffsetMinutes: (fields[23] as num?)?.toInt(),
        dailyWaterGoalMl: (fields[24] as num?)?.toInt(),
        useMaterialYou: fields[20] as bool?,
        accentColor: (fields[26] as num?)?.toInt(),
        scannerPortraitLock: fields[27] as bool?,
        usesImperialFoodUnits: fields[28] as bool?,
        usesImperialHeightUnits: fields[29] as bool?,
        bodyWeightUnitIndex: (fields[30] as num?)?.toInt(),
        healthImportEnabled: fields[33] as bool?,
        healthWorkoutKcalMultiplier: (fields[34] as num?)?.toDouble(),
        healthLastImportAt: fields[35] as DateTime?,
        healthDeletedExternalIds: (fields[36] as List?)?.cast<String>(),
        healthDeletedWorkouts: (fields[38] as Map?)?.cast<String, DateTime>(),
        amountArithmeticEnabled: fields[42] as bool?,
        catalogueSourceOverrides: (fields[43] as Map?)?.cast<String, bool>(),
        overviewMacrosAsPercent: fields[40] as bool?,
        overviewNutrientsWithoutGoal: fields[45] as bool?,
      )
      ..userCarbGoalPct = (fields[6] as num?)?.toDouble()
      ..userProteinGoalPct = (fields[7] as num?)?.toDouble()
      ..userFatGoalPct = (fields[8] as num?)?.toDouble();
  }

  @override
  void write(BinaryWriter writer, ConfigDBO obj) {
    writer
      ..writeByte(35)
      ..writeByte(3)
      ..write(obj.selectedAppTheme)
      ..writeByte(4)
      ..write(obj.usesImperialUnits)
      ..writeByte(5)
      ..write(obj.userKcalAdjustment)
      ..writeByte(6)
      ..write(obj.userCarbGoalPct)
      ..writeByte(7)
      ..write(obj.userProteinGoalPct)
      ..writeByte(8)
      ..write(obj.userFatGoalPct)
      ..writeByte(9)
      ..write(obj.showActivityTracking)
      ..writeByte(10)
      ..write(obj.notificationsEnabled)
      ..writeByte(11)
      ..write(obj.notificationHour)
      ..writeByte(12)
      ..write(obj.notificationMinute)
      ..writeByte(16)
      ..write(obj.usesKilojoules)
      ..writeByte(17)
      ..write(obj.mealKcalSharesPct)
      ..writeByte(18)
      ..write(obj.customMealFormMode)
      ..writeByte(19)
      ..write(obj.dayStartOffsetHours)
      ..writeByte(20)
      ..write(obj.useMaterialYou)
      ..writeByte(21)
      ..write(obj.diarySortPreferences)
      ..writeByte(22)
      ..write(obj.nutrientPanelVisibility)
      ..writeByte(23)
      ..write(obj.dayStartOffsetMinutes)
      ..writeByte(24)
      ..write(obj.dailyWaterGoalMl)
      ..writeByte(26)
      ..write(obj.accentColor)
      ..writeByte(27)
      ..write(obj.scannerPortraitLock)
      ..writeByte(28)
      ..write(obj.usesImperialFoodUnits)
      ..writeByte(29)
      ..write(obj.usesImperialHeightUnits)
      ..writeByte(30)
      ..write(obj.bodyWeightUnitIndex)
      ..writeByte(33)
      ..write(obj.healthImportEnabled)
      ..writeByte(34)
      ..write(obj.healthWorkoutKcalMultiplier)
      ..writeByte(35)
      ..write(obj.healthLastImportAt)
      ..writeByte(36)
      ..write(obj.healthDeletedExternalIds)
      ..writeByte(38)
      ..write(obj.healthDeletedWorkouts)
      ..writeByte(40)
      ..write(obj.overviewMacrosAsPercent)
      ..writeByte(42)
      ..write(obj.amountArithmeticEnabled)
      ..writeByte(43)
      ..write(obj.catalogueSourceOverrides)
      ..writeByte(44)
      ..write(obj.nutrientInfoVisibility)
      ..writeByte(45)
      ..write(obj.overviewNutrientsWithoutGoal)
      ..writeByte(46)
      ..write(obj.showMissingNutrientsInInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigDBO _$ConfigDBOFromJson(Map<String, dynamic> json) =>
    ConfigDBO(
        $enumDecode(_$AppThemeDBOEnumMap, json['selectedAppTheme']),
        usesImperialUnits: json['usesImperialUnits'] as bool? ?? false,
        userKcalAdjustment: (json['userKcalAdjustment'] as num?)?.toDouble(),
        showActivityTracking: json['showActivityTracking'] as bool?,
        notificationsEnabled: json['notificationsEnabled'] as bool?,
        notificationHour: (json['notificationHour'] as num?)?.toInt(),
        notificationMinute: (json['notificationMinute'] as num?)?.toInt(),
        usesKilojoules: json['usesKilojoules'] as bool?,
        mealKcalSharesPct: (json['mealKcalSharesPct'] as Map<String, dynamic>?)
            ?.map((k, e) => MapEntry(k, (e as num).toInt())),
        customMealFormMode: json['customMealFormMode'] as String?,
        dayStartOffsetHours: (json['dayStartOffsetHours'] as num?)?.toInt(),
        diarySortPreferences:
            (json['diarySortPreferences'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, (e as num).toInt()),
            ),
        nutrientPanelVisibility:
            (json['nutrientPanelVisibility'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as bool),
            ),
        nutrientInfoVisibility:
            (json['nutrientInfoVisibility'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as bool),
            ),
        showMissingNutrientsInInfo: json['showMissingNutrientsInInfo'] as bool?,
        dayStartOffsetMinutes: (json['dayStartOffsetMinutes'] as num?)?.toInt(),
        dailyWaterGoalMl: (json['dailyWaterGoalMl'] as num?)?.toInt(),
        useMaterialYou: json['useMaterialYou'] as bool?,
        accentColor: (json['accentColor'] as num?)?.toInt(),
        scannerPortraitLock: json['scannerPortraitLock'] as bool?,
        usesImperialFoodUnits: json['usesImperialFoodUnits'] as bool?,
        usesImperialHeightUnits: json['usesImperialHeightUnits'] as bool?,
        bodyWeightUnitIndex: (json['bodyWeightUnitIndex'] as num?)?.toInt(),
        healthImportEnabled: json['healthImportEnabled'] as bool?,
        healthWorkoutKcalMultiplier:
            (json['healthWorkoutKcalMultiplier'] as num?)?.toDouble(),
        healthLastImportAt: json['healthLastImportAt'] == null
            ? null
            : DateTime.parse(json['healthLastImportAt'] as String),
        healthDeletedExternalIds:
            (json['healthDeletedExternalIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList(),
        healthDeletedWorkouts:
            (json['healthDeletedWorkouts'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, DateTime.parse(e as String)),
            ),
        amountArithmeticEnabled: json['amountArithmeticEnabled'] as bool?,
        catalogueSourceOverrides:
            (json['catalogueSourceOverrides'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as bool),
            ),
        overviewMacrosAsPercent: json['overviewMacrosAsPercent'] as bool?,
        overviewNutrientsWithoutGoal:
            json['overviewNutrientsWithoutGoal'] as bool?,
      )
      ..userCarbGoalPct = (json['userCarbGoalPct'] as num?)?.toDouble()
      ..userProteinGoalPct = (json['userProteinGoalPct'] as num?)?.toDouble()
      ..userFatGoalPct = (json['userFatGoalPct'] as num?)?.toDouble();

Map<String, dynamic> _$ConfigDBOToJson(ConfigDBO instance) => <String, dynamic>{
  'selectedAppTheme': _$AppThemeDBOEnumMap[instance.selectedAppTheme]!,
  'usesImperialUnits': instance.usesImperialUnits,
  'userKcalAdjustment': instance.userKcalAdjustment,
  'userCarbGoalPct': instance.userCarbGoalPct,
  'userProteinGoalPct': instance.userProteinGoalPct,
  'userFatGoalPct': instance.userFatGoalPct,
  'showActivityTracking': instance.showActivityTracking,
  'notificationsEnabled': instance.notificationsEnabled,
  'notificationHour': instance.notificationHour,
  'notificationMinute': instance.notificationMinute,
  'usesKilojoules': instance.usesKilojoules,
  'mealKcalSharesPct': instance.mealKcalSharesPct,
  'customMealFormMode': instance.customMealFormMode,
  'dayStartOffsetHours': instance.dayStartOffsetHours,
  'nutrientPanelVisibility': instance.nutrientPanelVisibility,
  'diarySortPreferences': instance.diarySortPreferences,
  'dayStartOffsetMinutes': instance.dayStartOffsetMinutes,
  'dailyWaterGoalMl': instance.dailyWaterGoalMl,
  'useMaterialYou': instance.useMaterialYou,
  'accentColor': instance.accentColor,
  'scannerPortraitLock': instance.scannerPortraitLock,
  'usesImperialFoodUnits': instance.usesImperialFoodUnits,
  'usesImperialHeightUnits': instance.usesImperialHeightUnits,
  'bodyWeightUnitIndex': instance.bodyWeightUnitIndex,
  'healthImportEnabled': instance.healthImportEnabled,
  'healthWorkoutKcalMultiplier': instance.healthWorkoutKcalMultiplier,
  'healthLastImportAt': instance.healthLastImportAt?.toIso8601String(),
  'healthDeletedExternalIds': instance.healthDeletedExternalIds,
  'healthDeletedWorkouts': instance.healthDeletedWorkouts?.map(
    (k, e) => MapEntry(k, e.toIso8601String()),
  ),
  'overviewMacrosAsPercent': instance.overviewMacrosAsPercent,
  'amountArithmeticEnabled': instance.amountArithmeticEnabled,
  'catalogueSourceOverrides': instance.catalogueSourceOverrides,
  'nutrientInfoVisibility': instance.nutrientInfoVisibility,
  'overviewNutrientsWithoutGoal': instance.overviewNutrientsWithoutGoal,
  'showMissingNutrientsInInfo': instance.showMissingNutrientsInInfo,
};

const _$AppThemeDBOEnumMap = {
  AppThemeDBO.light: 'light',
  AppThemeDBO.dark: 'dark',
  AppThemeDBO.system: 'system',
};
