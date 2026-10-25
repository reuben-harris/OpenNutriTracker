import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/repository/health_import_repository.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/url_const.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/health_disclosure_dialog.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/workout_calorie_credit_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the platform health store is called in front of the user. Both names
/// are product names, so they are deliberately not localized. Lives here
/// because it is a presentation-layer label; the settings row that leads to
/// this screen shows the same name and reads it from here.
String get healthPlatformName =>
    Platform.isIOS ? 'Apple Health' : 'Health Connect';

/// Settings → Health sync: opts into importing finished workouts from Health
/// Connect / Apple Health, and tunes how much of the energy those workouts
/// report is credited toward the daily calorie goal.
///
/// Changing the credit affects future imports only; activities already in
/// the diary keep their saved calories.
class HealthSyncScreen extends StatefulWidget {
  const HealthSyncScreen({super.key});

  @override
  State<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<HealthSyncScreen> {
  final _log = Logger('HealthSyncScreen');

  bool _loading = true;

  /// Whether the device can serve health data. Import controls are disabled
  /// when unavailable; the credit can still be configured in advance.
  bool _isAvailable = false;

  /// True while a platform round trip is in flight, so a second tap cannot
  /// start a competing permission request or import.
  bool _busy = false;

  bool _importEnabled = false;

  double _multiplier = ConfigEntity.defaultHealthWorkoutKcalMultiplier;

  DateTime? _lastImportAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isAvailable = await locator<HealthImportRepository>().isAvailable();
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!mounted) return;
    setState(() {
      _isAvailable = isAvailable;
      _importEnabled = config.healthImportEnabled;
      _multiplier = config.effectiveHealthWorkoutKcalMultiplier;
      _lastImportAt = config.healthLastImportAt;
      _loading = false;
    });
  }

  Future<void> _onAutoImportChanged(bool enabled) async {
    if (!enabled) {
      setState(() => _importEnabled = false);
      await locator<SettingsBloc>().setHealthImportEnabled(false);
      return;
    }

    // The disclosure gates the request rather than merely preceding it (#926):
    // Play's User Data policy wants affirmative consent in the app before the
    // platform is asked, and a dialog the user could dismiss into a permission
    // prompt would not be consent. Anything other than the confirm action —
    // cancel, back, a killed activity — leaves the switch off and asks for
    // nothing.
    //
    // Shown on every opt-in, not once ever. Re-enabling is rare, and a
    // disclosure that only the first user of a device ever saw would be a
    // disclosure to the wrong person on a shared handset.
    if (!await _confirmDisclosure()) return;

    setState(() => _busy = true);
    try {
      final granted = await locator<HealthImportRepository>()
          .requestPermissions();
      if (!mounted) return;
      if (!granted) {
        setState(() => _importEnabled = false);
        _showMessage(
          S.of(context).healthSyncPermissionDeniedLabel(healthPlatformName),
        );
        return;
      }

      await locator<SettingsBloc>().setHealthImportEnabled(true);
      if (!mounted) return;
      setState(() => _importEnabled = true);

      await _runImport(reportCount: false);
    } catch (error, stackTrace) {
      _log.warning('Enabling workout import failed', error, stackTrace);
      if (!mounted) return;
      setState(() => _importEnabled = false);
      _showMessage(
        S.of(context).healthSyncPermissionDeniedLabel(healthPlatformName),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs an import the user is waiting on, and tells them how it went.
  /// [reportCount] is false on the opt-in path, where the switch flipping is
  /// the feedback and a "no new workouts" toast would only read as a failure.
  Future<void> _runImport({bool reportCount = true}) async {
    try {
      final imported = await locator<ImportWorkoutsUsecase>().importNow();
      await _reloadWatermark();
      if (!mounted) return;
      if (reportCount) {
        _showMessage(S.of(context).healthSyncImportedCountLabel(imported));
      }
      if (imported > 0) {
        locator<HomeBloc>().add(const LoadItemsEvent());
        locator<DiaryBloc>().add(const LoadDiaryYearEvent());
        locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
      }
    } catch (error, stackTrace) {
      // Whatever the platform threw, the user's lever is the same one: the
      // read access this app was granted.
      _log.warning('Workout import failed', error, stackTrace);
      if (!mounted) return;
      _showMessage(
        S.of(context).healthSyncPermissionDeniedLabel(healthPlatformName),
      );
    }
  }

  Future<void> _onImportNowPressed() async {
    setState(() => _busy = true);
    try {
      await _runImport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Re-reads the watermark the importer just wrote, so the "last import"
  /// subtitle reflects the run that finished rather than the one before it.
  Future<void> _reloadWatermark() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!mounted) return;
    setState(() => _lastImportAt = config.healthLastImportAt);
  }

  Future<void> _editMultiplier() async {
    final selected = await showDialog<double>(
      context: context,
      builder: (_) =>
          WorkoutCalorieCreditDialog(initialMultiplier: _multiplier),
    );
    if (selected == null || !mounted) return;
    await locator<SettingsBloc>().setHealthWorkoutKcalMultiplier(selected);
    if (mounted) setState(() => _multiplier = selected);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Puts the disclosure up and reports whether the user chose to go on.
  ///
  /// A dismissal returns null, which reads as a refusal — the one direction
  /// this must fail in, since the alternative is asking the platform for
  /// health data on the strength of a stray tap.
  Future<bool> _confirmDisclosure() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const HealthDisclosureDialog(),
    );
    return accepted ?? false;
  }

  /// Opens the policy in the language the app is being read in, matching how
  /// Settings and the onboarding intro do it.
  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse(
      URLConst.privacyPolicyFor(Localizations.localeOf(context).languageCode),
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showMessage(S.of(context).errorOpeningBrowser);
    }
  }

  String _formatLastImport(BuildContext context, DateTime lastImportAt) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(localeTag).add_Hm().format(lastImportAt);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final canEdit = _isAvailable && _importEnabled && !_busy;
    return Scaffold(
      appBar: AppBar(title: Text(healthPlatformName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (!_isAvailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.spacing16,
                      vertical: Dimens.spacing8,
                    ),
                    child: Text(
                      s.healthSyncUnavailableLabel,
                      style: textTheme.bodySmall,
                    ),
                  ),
                Semantics(
                  identifier: 'health-sync-auto-import',
                  child: SwitchListTile(
                    secondary: const Icon(Icons.sync_rounded),
                    title: Text(
                      s.healthSyncAutoImportLabel(healthPlatformName),
                    ),
                    value: _importEnabled,
                    onChanged: _isAvailable && !_busy
                        ? _onAutoImportChanged
                        : null,
                  ),
                ),
                Semantics(
                  identifier: 'health-sync-kcal-multiplier',
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center_rounded),
                    title: Text(
                      s.healthSyncKcalMultiplierLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      s.healthSyncKcalMultiplierValueLabel(
                        (_multiplier * 100).round(),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _busy ? null : _editMultiplier,
                  ),
                ),
                Semantics(
                  identifier: 'health-sync-import-now',
                  child: ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: Text(s.healthSyncImportNowLabel),
                    subtitle: Text(
                      _lastImportAt == null
                          ? s.healthSyncNeverImportedLabel
                          : s.healthSyncLastImportLabel(
                              _formatLastImport(context, _lastImportAt!),
                            ),
                    ),
                    enabled: canEdit,
                    onTap: _onImportNowPressed,
                  ),
                ),
                // Health Connect can send the user straight here to ask what
                // the app wants their data for (#927), and the policy is the
                // rest of that answer. Reachable from settings too, but a
                // reader who arrived from outside the app has no reason to
                // know that, and should not have to go looking.
                Semantics(
                  identifier: 'health-sync-privacy-policy',
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(s.privacyPolicyLabel),
                    onTap: _openPrivacyPolicy,
                  ),
                ),
              ],
            ),
    );
  }
}
