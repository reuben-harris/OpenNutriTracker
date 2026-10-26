import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_sex_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'fake_hive_db_provider.dart';

class MemoryUserRepository extends UserRepository {
  MemoryUserRepository() : super(UserDataSource(FakeHiveDBProvider()));
  UserDBO body = UserDBO(
    birthday: DateTime(1990),
    heightCM: 170,
    weightKG: 70,
    sex: UserSexDBO.female,
    goal: UserWeightGoalDBO.maintainWeight,
    pal: UserPALDBO.sedentary,
  );
  @override
  Future<UserDBO> getUserDBO() async => body;
  @override
  Future<void> restoreUserData(UserDBO user) async {
    body = user;
  }
}
