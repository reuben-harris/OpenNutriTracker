import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_group_header.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class NutrientGoalsScreen extends StatefulWidget {
  final SettingsBloc settingsBloc;
  final ProfileBloc profileBloc;
  final DiaryBloc diaryBloc;
  final CalendarDayBloc calendarDayBloc;
  final HomeBloc homeBloc;
  const NutrientGoalsScreen({
    super.key,
    required this.settingsBloc,
    required this.profileBloc,
    required this.diaryBloc,
    required this.calendarDayBloc,
    required this.homeBloc,
  });
  @override
  State<NutrientGoalsScreen> createState() => _NutrientGoalsScreenState();
}

enum _LeaveAction { discard, save }

class _NutrientGoalsScreenState extends State<NutrientGoalsScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final n in Nutrients.additional) n.key: TextEditingController(),
  };
  final _limits = <String, bool>{};
  Map<String, NutrientGoal> _defaults = {};
  Map<String, String> _savedTexts = {};
  Map<String, bool> _savedLimits = {};
  bool _loaded = false, _saving = false, _loadFailed = false;
  bool _leaveDialogOpen = false;
  late final DateTime _day = DateTime.now();

  bool get _dirty =>
      _loaded &&
      Nutrients.additional.any(
        (n) =>
            _controllers[n.key]!.text != _savedTexts[n.key] ||
            _limits[n.key] != _savedLimits[n.key],
      );

  String _amountText(double amount) =>
      amount.toString().replaceFirst(RegExp(r'\.0$'), '');

  void _rememberSavedValues() {
    _savedTexts = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
    _savedLimits = Map.of(_limits);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await widget.profileBloc.getUser();

      if (!mounted) return;
      _defaults = {
        for (final entry in NutrientGoalResolver.resolve(
          user: user,
          day: _day,
        ).entries)
          if (entry.value.primary?.comparable == true)
            entry.key: NutrientGoal(
              entry.value.primary!.amount,
              isLimit: entry.value.primary!.upper,
            ),
      };
      for (final n in Nutrients.additional) {
        final policy = user.nutrientPolicies[n.key];
        final goal = policy?.adequacyMode == ThresholdMode.custom
            ? NutrientGoal(policy!.target!)
            : policy?.upperMode == ThresholdMode.custom
            ? NutrientGoal(policy!.upper!, isLimit: true)
            : null;
        _controllers[n.key]!.text = goal == null
            ? ''
            : _amountText(goal.amount);
        _limits[n.key] = goal?.isLimit ?? n.goalKind == NutrientGoalKind.limit;
      }
      _rememberSavedValues();
      setState(() => _loaded = true);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmReset([NutrientDefinition? nutrient]) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          nutrient == null
              ? s.nutrientGoalsResetAllTitle
              : s.nutrientGoalResetTitle(nutrient.label(s)),
        ),
        content: Text(
          nutrient == null
              ? s.nutrientGoalsResetAllContent
              : s.nutrientGoalResetContent,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.dialogCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.buttonResetLabel),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    FocusScope.of(context).unfocus();
    setState(() {
      for (final n in nutrient == null ? Nutrients.additional : [nutrient]) {
        _controllers[n.key]!.clear();
        _limits[n.key] = n.goalKind == NutrientGoalKind.limit;
      }
    });
  }

  String? _amountError(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.trim());
    return value != null && value.isFinite && value >= 0
        ? null
        : S.of(context).nutrientInvalidAmountLabel;
  }

  Future<bool> _save() async {
    if (_saving || !_loaded) return false;
    final validForm = _form.currentState?.validate() ?? false;
    // A scrolled-out field may be unmounted, but its value must still validate.
    final validAmounts = _controllers.values.every(
      (c) => _amountError(c.text) == null,
    );
    if (!validForm || !validAmounts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).nutrientInvalidAmountLabel)),
      );
      return false;
    }
    setState(() => _saving = true);
    try {
      final user = await widget.profileBloc.getUser();
      final goals = Map<String, NutrientPolicy>.of(user.nutrientPolicies);
      for (final n in Nutrients.additional) {
        final value = double.tryParse(_controllers[n.key]!.text.trim());
        if (value != null) {
          goals[n.key] = (goals[n.key] ?? const NutrientPolicy()).copyWith(
            adequacyMode: _limits[n.key]!
                ? ThresholdMode.reference
                : ThresholdMode.custom,
            upperMode: _limits[n.key]!
                ? ThresholdMode.custom
                : ThresholdMode.reference,
            target: value,
            upper: value,
          );
        } else {
          goals[n.key] = const NutrientPolicy();
        }
      }
      await widget.profileBloc.setNutrientPolicies(goals);
      if (!mounted) return true;
      widget.settingsBloc.add(LoadSettingsEvent());
      widget.homeBloc.add(const LoadItemsEvent());
      widget.diaryBloc.add(const LoadDiaryYearEvent());
      widget.calendarDayBloc.add(RefreshCalendarDayEvent());
      _rememberSavedValues();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).nutrientSettingsSaveFailedLabel),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndLeave() async {
    if (await _save() && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    if (_leaveDialogOpen || _saving) return;
    FocusScope.of(context).unfocus();
    _leaveDialogOpen = true;
    try {
      final s = S.of(context);
      final action = await showDialog<_LeaveAction>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(s.unsavedChangesTitle),
          content: Text(s.unsavedChangesContent),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveAction.discard),
              child: Text(s.discardAndLeaveLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.dialogCancelLabel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveAction.save),
              child: Text(s.saveAndLeaveLabel),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == _LeaveAction.discard) {
        Navigator.of(context).pop();
      } else if (action == _LeaveAction.save) {
        await _saveAndLeave();
      }
    } finally {
      _leaveDialogOpen = false;
    }
  }

  Widget _goalRow(NutrientDefinition n) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final controller = _controllers[n.key]!;
    final reference = _defaults[n.key];
    final id = n.key.replaceAll('_', '-');
    final inputStyle = theme.textTheme.bodyMedium?.copyWith(height: 1);
    final decoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(minHeight: 48),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            n.label(s),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final kindWidth = MediaQuery.textScalerOf(
                context,
              ).scale(96).clamp(96.0, constraints.maxWidth / 2);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      identifier: 'nutrient-goal-$id',
                      label: n.label(s),
                      child: TextFormField(
                        controller: controller,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: inputStyle,
                        decoration: decoration.copyWith(
                          suffixText: n.unit,
                          hintText: reference == null
                              ? '—'
                              : _amountText(reference.amount),
                        ),
                        validator: _amountError,
                        onChanged: (text) => setState(() {
                          if (text.trim().isEmpty) {
                            _limits[n.key] =
                                n.goalKind == NutrientGoalKind.limit;
                          }
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: kindWidth,
                    child: Semantics(
                      identifier: 'nutrient-goal-kind-$id',
                      label: n.label(s),
                      child: DropdownButtonFormField<bool>(
                        key: ValueKey('${n.key}-${_limits[n.key]}'),
                        initialValue: _limits[n.key],
                        isExpanded: true,
                        decoration: decoration,
                        style: inputStyle,
                        items: [
                          DropdownMenuItem(
                            value: false,
                            child: Text(
                              s.nutrientGoalTargetLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text(
                              s.nutrientGoalLimitLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged:
                            _saving ||
                                (controller.text.trim().isEmpty &&
                                    reference == null)
                            ? null
                            : (value) {
                                if (value == null || value == _limits[n.key]) {
                                  return;
                                }
                                setState(() {
                                  _limits[n.key] = value;
                                  if (controller.text.trim().isEmpty &&
                                      reference != null) {
                                    controller.text = _amountText(
                                      reference.amount,
                                    );
                                  }
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Semantics(
                      identifier: 'nutrient-goal-reset-$id',
                      child: IconButton(
                        tooltip: s.nutrientUseDefaultLabel,
                        onPressed:
                            _saving ||
                                (controller.text.isEmpty &&
                                    _limits[n.key] ==
                                        (n.goalKind == NutrientGoalKind.limit))
                            ? null
                            : () => _confirmReset(n),
                        icon: const Icon(Icons.restore_rounded, size: 20),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: AutoSizeText(
            s.settingsNutrientGoalsLabel,
            maxLines: 2,
            minFontSize: 12,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Semantics(
              identifier: 'nutrient-goals-sources',
              child: IconButton(
                tooltip: s.sourcesIconTooltip,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SourcesScreen(),
                        ),
                      ),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ),
            Semantics(
              identifier: 'nutrient-goals-reset',
              child: IconButton(
                tooltip: s.nutrientGoalsResetAllLabel,
                onPressed: _saving || !_loaded ? null : () => _confirmReset(),
                icon: const Icon(Icons.restore_rounded),
              ),
            ),
            Semantics(
              identifier: 'nutrient-goals-save',
              child: IconButton(
                tooltip: s.buttonSaveLabel,
                onPressed: _saving || !_loaded ? null : _saveAndLeave,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
              ),
            ),
          ],
        ),
        body: _loadFailed
            ? Center(
                child: Semantics(
                  identifier: 'nutrient-goals-retry',
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _loadFailed = false);
                      _load();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(s.retryLabel),
                  ),
                ),
              )
            : !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: Semantics(
                  identifier: 'nutrient-goals-list',
                  label: s.settingsNutrientGoalsLabel,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        s.settingsNutrientGoalsHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final group in Nutrients.additionalGroups) ...[
                        NutrientGroupHeader(group: group),
                        for (final n in Nutrients.additional.where(
                          (n) => n.group == group,
                        ))
                          _goalRow(n),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
