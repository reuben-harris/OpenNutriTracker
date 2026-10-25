import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/presentation/widgets/disclaimer_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/main_appbar.dart';
import 'package:opennutritracker/core/presentation/widgets/selected_day_header.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/health_rationale_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/diary/diary_page.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/home_page.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';
import 'package:opennutritracker/features/profile/profile_page.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/library_add_menu.dart';
import 'package:opennutritracker/features/settings/settings_screen.dart';
import 'package:opennutritracker/features/trends/presentation/trends_page.dart';
import 'package:opennutritracker/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum _MainDestination {
  diary,
  overview,
  trends,
  library,
  you,
  settings;

  String label(S s) => switch (this) {
    diary => s.diaryLabel,
    overview => s.onboardingOverviewLabel,
    trends => s.trendsLabel,
    library => s.libraryLabel,
    you => s.youLabel,
    settings => s.settingsLabel,
  };

  IconData get icon => switch (this) {
    diary => Icons.book_outlined,
    overview => Icons.pie_chart_outline,
    trends => Icons.insights_outlined,
    library => Icons.menu_book_outlined,
    you => Icons.account_circle_outlined,
    settings => Icons.settings_outlined,
  };

  IconData get selectedIcon => switch (this) {
    diary => Icons.book_rounded,
    overview => Icons.pie_chart_rounded,
    trends => Icons.insights_rounded,
    library => Icons.menu_book_rounded,
    you => Icons.account_circle_rounded,
    settings => Icons.settings_rounded,
  };

  bool get showsSelectedDay => this == diary || this == overview;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  _MainDestination _selectedDestination = _MainDestination.diary;
  bool _ready = false;

  /// Guards against two lifecycle events asking the platform at once. The
  /// platform side clears the flag on read, so a race would not open the
  /// screen twice — but it would spend two channel round trips finding out.
  bool _checkingHealthRationale = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfigDrivenUi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // The activity is singleTop, so Health Connect reaching a process that is
    // already running never rebuilds this screen — a resume is the only signal
    // that an intent arrived.
    if (state == AppLifecycleState.resumed) {
      _resume();
    }
  }

  // The policy-change notice #887 specified is deliberately **not** shown for
  // revision 1. #887's reasoning stands on the record and was not refuted —
  // the corrections name recipients that were always receiving data, so users
  // were under-informed for the whole time rather than recently — but the call
  // was made not to spend a first-launch dialog on it. The mechanism itself is
  // kept, not deleted: `URLConst.policyRevision`, the seeding in
  // `OnboardingBloc.saveOnboardingData` and `PolicyChangeDialog` are all still
  // live and tested, so a future revision that does warrant telling people can
  // restore this by calling the dialog again. What is gone is one call, not
  // the ability to notify.
  Future<void> _loadConfigDrivenUi() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!mounted) return;
    await locator<SelectedDayCubit>().initialize();
    if (!mounted) return;
    setState(() {
      _ready = true;
    });
    _refreshRecords();
    unawaited(_importHealthWorkouts());
    if (!config.hasAcceptedDisclaimer) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (_) => const DisclaimerDialog(),
      );
      if (accepted == true) {
        await locator<AddConfigUsecase>().setConfigDisclaimer(true);
      }
    }
    if (!mounted) return;
    await _maybeOpenHealthRationale();
  }

  /// Opens the health-sync screen when Health Connect asked the app to explain
  /// what it wants health data for (#927).
  ///
  /// Health Connect starts the app rather than rendering anything itself, so
  /// without this the user is dropped on the diary having asked a question
  /// nothing answered. The screen names the data, says what it is used for,
  /// and links the privacy policy.
  Future<void> _maybeOpenHealthRationale() async {
    if (_checkingHealthRationale) return;
    _checkingHealthRationale = true;
    final bool requested;
    try {
      requested = await HealthRationaleService.consumePendingRequest();
    } finally {
      _checkingHealthRationale = false;
    }
    if (!requested || !mounted) return;
    await Navigator.of(context).pushNamed(NavigationOptions.healthSyncRoute);
  }

  Widget _buildPage(_MainDestination destination) => switch (destination) {
    _MainDestination.diary => const DiaryPage(),
    _MainDestination.overview => const HomePage(),
    _MainDestination.trends => const TrendsPage(),
    _MainDestination.library => RecipesPage(
      showAppBar: false,
      isActive: destination == _selectedDestination,
    ),
    _MainDestination.you => const ProfilePage(),
    _MainDestination.settings => SettingsScreen(
      showAppBar: false,
      isActive: destination == _selectedDestination,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final s = S.of(context);
    return Scaffold(
      appBar: MainAppbar(
        title: _selectedDestination.label(s),
        iconData: _selectedDestination.selectedIcon,
        actions: _ready && _selectedDestination == _MainDestination.library
            ? const [LibraryAddMenu()]
            : null,
      ),
      body: Column(
        children: [
          if (_ready && _selectedDestination.showsSelectedDay)
            const SelectedDayHeader(),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _selectedDestination.index,
                    children: [
                      for (final destination in _MainDestination.values)
                        SwipeRevealScope(
                          key: ValueKey(destination),
                          active: destination == _selectedDestination,
                          child: TickerMode(
                            enabled: destination == _selectedDestination,
                            child: _buildPage(destination),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 78,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            for (final destination in _MainDestination.values)
              _NavItem(
                destination: destination,
                selected: destination == _selectedDestination,
                palette: palette,
                onTap: () => _setPage(destination),
              ),
          ],
        ),
      ),
    );
  }

  void _refreshRecords() {
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(
      LoadCalendarDayEvent(locator<SelectedDayCubit>().state.day),
    );
  }

  Future<void> _resume() async {
    await locator<SelectedDayCubit>().initialize();
    if (!mounted || !_ready) return;
    _refreshRecords();
    unawaited(_importHealthWorkouts());
    await _maybeOpenHealthRationale();
  }

  Future<void> _importHealthWorkouts() async {
    final imported = await locator<ImportWorkoutsUsecase>().importIfDue();
    if (imported > 0 && mounted) _refreshRecords();
  }

  void _setPage(_MainDestination destination) {
    if (destination != _selectedDestination) {
      FocusScope.of(context).unfocus();
    }
    if (destination == _MainDestination.overview) {
      locator<HomeBloc>().add(const LoadItemsEvent());
    }
    if (destination == _MainDestination.trends) {
      final trends = locator<TrendsBloc>();
      final state = trends.state;
      trends.add(
        LoadTrendsEvent(rangeDays: state is TrendsLoaded ? state.rangeDays : 7),
      );
    }
    setState(() {
      _selectedDestination = destination;
    });
  }
}

class _NavItem extends StatelessWidget {
  final _MainDestination destination;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : palette.textMuted;
    return Expanded(
      child: Semantics(
        identifier: 'nav-${destination.name}',
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 26,
                ),
                const SizedBox(height: 3),
                AutoSizeText(
                  destination.label(S.of(context)),
                  minFontSize: 6,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
