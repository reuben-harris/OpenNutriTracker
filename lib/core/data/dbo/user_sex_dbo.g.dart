// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_sex_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSexDBOAdapter extends TypeAdapter<UserSexDBO> {
  @override
  final typeId = 6;

  @override
  UserSexDBO read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserSexDBO.male;
      case 1:
        return UserSexDBO.female;
      default:
        return UserSexDBO.male;
    }
  }

  @override
  void write(BinaryWriter writer, UserSexDBO obj) {
    switch (obj) {
      case UserSexDBO.male:
        writer.writeByte(0);
      case UserSexDBO.female:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSexDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
