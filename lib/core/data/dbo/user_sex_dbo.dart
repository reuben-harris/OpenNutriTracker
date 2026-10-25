import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';

part 'user_sex_dbo.g.dart';

@HiveType(typeId: 6)
enum UserSexDBO {
  @HiveField(0)
  male,
  @HiveField(1)
  female; // Value ID 2 is retired.

  factory UserSexDBO.fromUserSexEntity(UserSexEntity sexEntity) {
    switch (sexEntity) {
      case UserSexEntity.male:
        return UserSexDBO.male;
      case UserSexEntity.female:
        return UserSexDBO.female;
    }
  }
}
