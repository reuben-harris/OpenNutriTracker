import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/data_source/water_intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/weight_log_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_water_intake_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import '../fixture/user_entity_fixtures.dart';
import 'fake_hive_db_provider.dart';
import 'hive_test_setup.dart';

/// Real storage and use cases so date, mutation, and persistence tests exercise
/// the same paths as the app, with only the platform box provider substituted.
class OverviewDiaryHarness {
  late Directory directory;
  late FakeHiveDBProvider db;
  late ConfigDataSource configSource;
  late ConfigRepository config;
  late IntakeRepository intakes;
  late TrackedDayRepository tracked;
  late UserActivityRepository activities;
  late WaterIntakeRepository water;
  late WeightLogRepository weight;
  late UserRepository user;
  late GetIntakeUsecase getIntakes;
  late GetConfigUsecase getConfig;
  late GetUserUsecase getUser;
  late GetKcalGoalUsecase kcal;
  late SelectedDayCubit selection;
  HomeBloc? home;
  CalendarDayBloc? calendar;

  Future<void> initialize() async {
    registerHiveAdaptersOnce();
    directory = await Directory.systemTemp.createTemp('overview-diary-test');
    Hive.init(directory.path);
    db = FakeHiveDBProvider(
      configBox: await Hive.openBox<ConfigDBO>('config'),
      appConfigBox: await Hive.openBox<ConfigDBO>('app'),
      intakeBox: await Hive.openBox<IntakeDBO>('intakes'),
      trackedDayBox: await Hive.openBox<TrackedDayDBO>('days'),
      userActivityBox: await Hive.openBox<UserActivityDBO>('activities'),
      userBox: await Hive.openBox<UserDBO>('user'),
      waterIntakeBox: await Hive.openBox<WaterIntakeDBO>('water'),
      weightLogBox: await Hive.openBox<WeightLogDBO>('weight'),
    );
    configSource = ConfigDataSource(db);
    await configSource.initializeConfig();
    await configSource.setConfigDisclaimer(true);
    config = ConfigRepository(configSource);
    intakes = IntakeRepository(IntakeDataSource(db));
    tracked = TrackedDayRepository(TrackedDayDataSource(db));
    activities = UserActivityRepository(UserActivityDataSource(db));
    water = WaterIntakeRepository(WaterIntakeDataSource(db));
    weight = WeightLogRepository(WeightLogDataSource(db));
    user = UserRepository(UserDataSource(db));
    await user.updateUserData(
      UserEntityFixtures.youngSedentaryMaleWantingToMaintainWeight,
    );
    getConfig = GetConfigUsecase(config);
    getIntakes = GetIntakeUsecase(intakes);
    getUser = GetUserUsecase(user);
    kcal = GetKcalGoalUsecase(user, config, activities);
    selection = SelectedDayCubit(getConfig);
    await selection.initialize();
  }

  HomeBloc createHome({GetIntakeUsecase? intakeReader}) => home = HomeBloc(
    getConfig,
    intakeReader ?? getIntakes,
    GetUserActivityUsecase(activities),
    kcal,
    GetMacroGoalUsecase(config),
    getUser,
    GetWaterIntakeUsecase(water),
    GetTrackedDayUsecase(tracked),
    GetWeightLogUsecase(weight),
    selection,
  );

  CalendarDayBloc createCalendar({GetIntakeUsecase? intakeReader}) =>
      calendar = CalendarDayBloc(
        GetUserActivityUsecase(activities),
        intakeReader ?? getIntakes,
        DeleteIntakeUsecase(intakes),
        DeleteUserActivityUsecase(activities, config),
        GetTrackedDayUsecase(tracked),
        AddTrackedDayUsecase(tracked),
        UpdateIntakeUsecase(intakes),
        UpdateUserActivityUsecase(activities, getUser),
        getConfig,
        AddConfigUsecase(config),
        selection: selection,
        getWater: GetWaterIntakeUsecase(water),
        addWater: AddWaterIntakeUsecase(water),
        updateWater: UpdateWaterIntakeUsecase(water),
        deleteWater: DeleteWaterIntakeUsecase(water),
      );

  Future<void> dispose() async {
    await home?.close();
    await calendar?.close();
    await selection.close();
    await Hive.close();
    await directory.delete(recursive: true);
  }
}
