import 'package:flutter/services.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/food_amount/food_amount_sheet.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/activity_detail/activity_detail_screen.dart';
import 'package:opennutritracker/features/activity_detail/presentation/bloc/activity_detail_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../core/search/food_search_engine_test.dart' show food;
import '../fixture/physical_activity_entity_fixtures.dart';
import '../fixture/user_entity_fixtures.dart';
import '../helpers/locator_test_setup.dart';

class _ActivityBloc extends Cubit<ActivityDetailState>
    implements ActivityDetailBloc {
  _ActivityBloc()
    : super(
        ActivityDetailLoadedState(
          0,
          UserEntityFixtures.youngSedentaryMaleWantingToMaintainWeight,
          0,
        ),
      );
  String? submitted;
  @override
  double getTotalKcalBurned(
    UserEntity user,
    PhysicalActivityEntity activity,
    double duration,
  ) => duration * 8;
  @override
  Future<void> persistActivity(
    String quantity,
    double kcal,
    PhysicalActivityEntity activity,
    DateTime day,
  ) async {
    submitted = quantity;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Home extends Fake implements HomeBloc {
  @override
  void add(HomeEvent event) {}
}

class _Diary extends Fake implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}
}

class _Calendar extends Fake implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}
}

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, AppThemeEntity.system);
}

void main() {
  useTestLocator();
  const height = 800.0;
  const bottomInset = 48.0;

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    RouteFactory? route,
  }) async {
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('fonts/Nunito.ttf'));
    await font.load();
    tester.view.physicalSize = const Size(400, height);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: bottomInset);
    tester.view.viewPadding = const FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          theme: buildAppTheme(AppPalette.light),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: route == null ? home : null,
          onGenerateRoute: route,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectUsable(WidgetTester tester, Finder action) {
    final bounds = tester.getRect(action);
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(bounds.bottom, lessThanOrEqualTo(height - bottomInset));
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('meal Add clears the navigation inset and confirms the amount', (
    tester,
  ) async {
    locator.registerSingleton<GetConfigUsecase>(_Config());
    FoodAmountSelection? saved;
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFoodAmountSheet(
              context,
              meal: food('meal', 'Test meal'),
              hydrate: false,
              onConfirm: (_, amount) async {
                saved = amount;
                return true;
              },
            ),
            child: const Text('Choose amount'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose amount'));
    await tester.pumpAndSettle();
    final add = find.widgetWithText(FilledButton, 'Add');
    expectUsable(tester, add);
    await tester.enterText(find.byType(TextField), '53');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(saved!.amount, 53);
    expect(saved!.baseAmount, 53);
    expect(find.byType(FoodAmountEditor), findsNothing);
  });

  testWidgets(
    'activity Add clears the navigation inset and submits entered minutes',
    (tester) async {
      final bloc = _ActivityBloc();
      addTearDown(bloc.close);
      locator.registerSingleton<ActivityDetailBloc>(bloc);
      locator.registerSingleton<HomeBloc>(_Home());
      locator.registerSingleton<DiaryBloc>(_Diary());
      locator.registerSingleton<CalendarDayBloc>(_Calendar());
      await mount(
        tester,
        const SizedBox(),
        route: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: ActivityDetailScreenArguments(
              PhysicalActivityFixtures.moderateBicycling,
              DateTime(2026, 9, 29),
            ),
          ),
          builder: (_) => const ActivityDetailScreen(),
        ),
      );
      final add = find.widgetWithText(ElevatedButton, 'Add');
      expectUsable(tester, add);
      await tester.enterText(find.byType(TextFormField), '35');
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(bloc.submitted, '35');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
