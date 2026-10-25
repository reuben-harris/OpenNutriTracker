import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/selected_day_header.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/activity_detail/presentation/bloc/activity_detail_bloc.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/run_ai_endpoint_probe_usecase.dart';
import 'package:opennutritracker/features/diary/diary_page.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/home/home_page.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/profile/profile_page.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/settings_screen.dart';
import 'package:opennutritracker/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:opennutritracker/features/trends/presentation/trends_page.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../helpers/locator_test_setup.dart';
import '../../helpers/test_l10n.dart';

// Keep unrelated data screens loading: these tests exercise the real shell,
// tab lifecycle and headers without storage, health imports or chart fixtures.
class _BlocStub<E, TState> extends Fake implements Bloc<E, TState> {
  _BlocStub(this.state);

  @override
  final TState state;

  @override
  Stream<TState> get stream => const Stream.empty();

  final List<E> events = [];

  @override
  void add(E event) => events.add(event);
}

class _HomeBloc extends _BlocStub<HomeEvent, HomeState> implements HomeBloc {
  _HomeBloc() : super(HomeLoadingState());
}

class _DiaryBloc extends _BlocStub<DiaryEvent, DiaryState>
    implements DiaryBloc {
  _DiaryBloc() : super(DiaryLoadingState());
}

class _ProfileBloc extends _BlocStub<ProfileEvent, ProfileState>
    implements ProfileBloc {
  _ProfileBloc() : super(ProfileLoadingState());
}

class _TrendsBloc extends _BlocStub<TrendsEvent, TrendsState>
    implements TrendsBloc {
  _TrendsBloc() : super(const TrendsLoading());
}

class _RecipesBloc extends _BlocStub<RecipesEvent, RecipesState>
    implements RecipesBloc {
  _RecipesBloc() : super(const RecipesLoaded([]));
}

class _MealsBloc extends _BlocStub<CustomMealsEvent, CustomMealsState>
    implements CustomMealsBloc {
  _MealsBloc() : super(CustomMealsLoadedState(meals: []));
}

class _SettingsBloc extends _BlocStub<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _SettingsBloc()
    : super(const SettingsLoadedState('1.0.0', AppThemeEntity.system, false));
}

class _CalendarBloc extends _BlocStub<CalendarDayEvent, CalendarDayState>
    implements CalendarDayBloc {
  _CalendarBloc() : super(CalendarDayLoading());
}

class _ActivityBloc extends Fake implements ActivityDetailBloc {}

class _ProbeRunner extends Fake implements AiEndpointProbeRunner {}

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, AppThemeEntity.system);
}

class _Workouts extends Fake implements ImportWorkoutsUsecase {
  @override
  Future<int> importIfDue() async => 0;
}

class _Credentials extends Fake implements AiCredentialStorage {
  int reads = 0;

  @override
  Future<AiAssistSummary> readSummary() async {
    reads++;
    return const AiAssistSummary(
      provider: AiProvider.anthropic,
      configured: false,
      enabled: false,
    );
  }
}

void main() {
  useTestLocator();
  late _RecipesBloc recipes;
  late _MealsBloc meals;
  late _SettingsBloc settings;
  late _Credentials credentials;
  late SelectedDayCubit selection;
  late DiaryClipboardCubit clipboard;

  setUp(() {
    final config = _Config();
    recipes = _RecipesBloc();
    meals = _MealsBloc();
    settings = _SettingsBloc();
    credentials = _Credentials();
    selection = SelectedDayCubit(config);
    clipboard = DiaryClipboardCubit();
    locator.registerSingleton<GetConfigUsecase>(config);
    locator.registerSingleton<ImportWorkoutsUsecase>(_Workouts());
    locator.registerSingleton<SelectedDayCubit>(selection);
    locator.registerSingleton<DiaryClipboardCubit>(clipboard);
    locator.registerSingleton<HomeBloc>(_HomeBloc());
    locator.registerSingleton<DiaryBloc>(_DiaryBloc());
    locator.registerSingleton<CalendarDayBloc>(_CalendarBloc());
    locator.registerSingleton<ActivityDetailBloc>(_ActivityBloc());
    locator.registerSingleton<ProfileBloc>(_ProfileBloc());
    locator.registerSingleton<TrendsBloc>(_TrendsBloc());
    locator.registerSingleton<RecipesBloc>(recipes);
    locator.registerSingleton<CustomMealsBloc>(meals);
    locator.registerSingleton<SettingsBloc>(settings);
    locator.registerSingleton<AiCredentialStorage>(credentials);
    locator.registerSingleton<AiEndpointProbeRunner>(_ProbeRunner());
  });
  tearDown(() async {
    await selection.close();
    await clipboard.close();
  });

  Future<void> mount(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MainScreen(),
      ),
    );
    // Loading indicators are intentional, so settle only the startup futures.
    await tester.pump();
    await tester.pump();
  }

  Future<void> select(WidgetTester tester, String id) async {
    await tester.tap(find.bySemanticsIdentifier(id));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('six destinations select the matching content and one header', (
    tester,
  ) async {
    await mount(tester);
    final destinations = [
      ('nav-diary', l10nEn.diaryLabel, DiaryPage, true),
      ('nav-overview', l10nEn.onboardingOverviewLabel, HomePage, true),
      ('nav-trends', l10nEn.trendsLabel, TrendsPage, false),
      ('nav-library', l10nEn.libraryLabel, RecipesPage, false),
      ('nav-you', l10nEn.youLabel, ProfilePage, false),
      ('nav-settings', l10nEn.settingsLabel, SettingsScreen, false),
    ];
    final bar = find.byType(BottomAppBar);
    final labels = tester.widgetList<Semantics>(
      find.descendant(
        of: bar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.identifier ?? '').startsWith('nav-'),
        ),
      ),
    );
    expect(
      labels.map((widget) => widget.properties.identifier),
      destinations.map((entry) => entry.$1),
    );
    expect(find.byType(DiaryPage), findsOneWidget);

    for (final (id, label, page, showsDay) in destinations) {
      await select(tester, id);
      expect(find.byType(page), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data,
        label,
      );
      expect(
        find.byType(SelectedDayHeader),
        showsDay ? findsOneWidget : findsNothing,
      );
      expect(
        tester
            .widget<Semantics>(find.bySemanticsIdentifier(id))
            .properties
            .selected,
        isTrue,
      );
      expect(bar, findsOneWidget);
    }
  });

  testWidgets('returning to Library and Settings refreshes their live state', (
    tester,
  ) async {
    await mount(tester);
    expect(recipes.events, isEmpty);
    expect(settings.events, isEmpty);
    expect(credentials.reads, 0);
    await select(tester, 'nav-library');
    expect(recipes.events, hasLength(1));
    expect(meals.events, hasLength(1));
    await select(tester, 'nav-settings');
    expect(settings.events, hasLength(1));
    expect(credentials.reads, 1);
    await select(tester, 'nav-library');
    expect(recipes.events, hasLength(2));
    expect(meals.events, hasLength(2));
    await select(tester, 'nav-settings');
    expect(settings.events, hasLength(2));
    expect(credentials.reads, 2);
  });

  testWidgets(
    'six tabs keep bounded touch targets on a narrow large-text view',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, textScale: 2);
      final bar = tester.getRect(find.byType(BottomAppBar));
      for (final id in [
        'diary',
        'overview',
        'trends',
        'library',
        'you',
        'settings',
      ]) {
        final target = tester.getRect(find.bySemanticsIdentifier('nav-$id'));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        expect(bar.contains(target.center), isTrue);
      }
      await select(tester, 'nav-library');
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('nav-library'),
          matching: find.byIcon(Icons.menu_book_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
