import 'package:opennutritracker/core/domain/entity/height_reading.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';

class UserRepository {
  final UserDataSource _userDataSource;

  UserRepository(this._userDataSource);

  Future<void> updateUserData(UserEntity userEntity) async {
    if (userEntity.nutrientPolicies.values.any((p) => !p.valid))
      throw ArgumentError('Invalid nutrient policy');
    final previous = await hasUserData() ? await getUserData() : null;
    if (previous == null || previous.heightCM != userEntity.heightCM) {
      userEntity.recordHeight(
        HeightReading(date: DateTime.now(), centimetres: userEntity.heightCM),
      );
    }
    final userDBO = UserDBO.fromUserEntity(userEntity);
    await _userDataSource.saveUserData(userDBO);
  }

  Future<void> restoreUserData(UserDBO user) {
    UserEntity.fromUserDBO(user); // Validate periods before accepting a backup.
    if (user.nutrientPolicies.values.any((p) => !p.valid))
      throw ArgumentError('Invalid nutrient policy');
    return _userDataSource.saveUserData(user);
  }

  Future<bool> hasUserData() async => await _userDataSource.hasUserData();

  Future<UserEntity> getUserData() async {
    final userDBO = await _userDataSource.getUserData();
    if (userDBO.heightHistory == null) {
      userDBO.heightHistory = [
        HeightReading(date: DateTime.now(), centimetres: userDBO.heightCM),
      ];
      await _userDataSource.saveUserData(userDBO);
    }
    return UserEntity.fromUserDBO(userDBO);
  }

  Future<UserDBO> getUserDBO() async {
    final userDBO = await _userDataSource.getUserData();
    return userDBO;
  }
}
