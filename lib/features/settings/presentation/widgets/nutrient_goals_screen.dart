import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_policy.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/nutrition/nutrient_goal_resolver.dart';
import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_reference_details.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_builder.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_visibility_controls.dart';
import 'package:opennutritracker/core/utils/locator.dart';
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

class _Draft {
  NutrientPolicy policy;
  final TextEditingController target, upper;
  _Draft(this.policy)
    : target = TextEditingController(text: policy.target?.toString() ?? ''),
      upper = TextEditingController(text: policy.upper?.toString() ?? '');
  NutrientPolicy get value => NutrientPolicy(
    source: policy.source,
    autoAdjust: policy.autoAdjust,
    adequacyMode: policy.adequacyMode,
    upperMode: policy.upperMode,
    target: double.tryParse(target.text.trim()),
    upper: double.tryParse(upper.text.trim()),
    frozenReference: policy.frozenReference,
    frozenOn: policy.frozenOn,
  );
  String get signature =>
      jsonEncode([policy.toJson(), target.text, upper.text]);
  void restore(NutrientPolicy value) {
    policy = value;
    target.text = value.target?.toString() ?? '';
    upper.text = value.upper?.toString() ?? '';
  }

  void dispose() {
    target.dispose();
    upper.dispose();
  }
}

class _NutrientGoalsScreenState extends State<NutrientGoalsScreen> {
  final _drafts = <String, _Draft>{};
  Map<String, String> _saved = {};
  final _scroll = ScrollController();
  UserEntity? _user;
  List<WeightLogEntity> _weights = [];
  NutrientDefinition _selected = Nutrients.byKey[NutrientKeys.fiber]!;
  bool _loaded = false,
      _saving = false,
      _loadFailed = false,
      _leaveDialogOpen = false,
      _allowLeave = false;
  late DateTime _today;
  bool get _dirty =>
      _loaded && _drafts.entries.any((e) => e.value.signature != _saved[e.key]);
  _Draft get _draft => _drafts[_selected.key]!;
  NutrientReferenceRange _resolve(String key, NutrientPolicy policy) =>
      NutrientGoalResolver.resolveOne(
        nutrient: key,
        policy: policy.valid
            ? policy
            : policy.copyWith(
                adequacyMode: ThresholdMode.reference,
                upperMode: ThresholdMode.reference,
              ),
        user: _user,
        day: _today,
        weights: _weights,
      );
  ReferenceSelection _preview(String key, ReferenceRegion region) =>
      NutrientGoalResolver.reference(
        nutrient: key,
        policy: NutrientPolicy(source: region.name),
        user: _user!,
        day: _today,
        weights: _weights,
      );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await widget.profileBloc.getUser();
      final config = locator.isRegistered<GetConfigUsecase>()
          ? await locator<GetConfigUsecase>().getConfig()
          : null;
      _today = DayBoundaryCalc.currentLogicalDayLabel(
        config?.dayStartOffsetHours ?? 0,
        config?.dayStartOffsetMinutes ?? 0,
      );
      final weights = locator.isRegistered<GetWeightLogUsecase>()
          ? await locator<GetWeightLogUsecase>().getAllEntries()
          : <WeightLogEntity>[];
      if (!mounted) return;
      _user = user;
      _weights = weights;
      for (final n in Nutrients.additional) {
        _drafts[n.key] = _Draft(
          user.nutrientPolicies[n.key] ?? const NutrientPolicy(),
        );
      }
      _remember();
      setState(() => _loaded = true);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _remember() {
    _saved = {for (final e in _drafts.entries) e.key: e.value.signature};
  }

  @override
  void dispose() {
    for (final d in _drafts.values) {
      d.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _changeSource(ReferenceRegion region) {
    var policy = _draft.policy.copyWith(region: region);
    if (!policy.autoAdjust) {
      policy = NutrientGoalResolver.freeze(
        nutrient: _selected.key,
        policy: policy,
        user: _user!,
        today: _today,
        weights: _weights,
      );
    }
    setState(() => _draft.policy = policy);
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(S.of(dialog).dialogCancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(S.of(dialog).buttonResetLabel),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _reset() async {
    final s = S.of(context);
    final source = await showModalBottomSheet<ReferenceRegion>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .85,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s.nutrientResetSource,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final region in ReferenceRegion.values)
                Semantics(
                  identifier:
                      'nutrient-source-${region == ReferenceRegion.nzAustralia ? 'nz-australia' : 'us-canada'}',
                  child: Card(
                    child: InkWell(
                      onTap: () => Navigator.pop(sheet, region),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              ReferenceSource.forRegion(region).name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            NutrientReferenceDetails(
                              reference: _preview(_selected.key, region),
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final confirmed = await _confirm(
      s.nutrientGoalResetTitle(_selected.label(s)),
      s.nutrientRestoreConfirm,
    );
    if (!confirmed || !mounted) return;
    setState(() => _draft.restore(NutrientPolicy(source: source.name)));
  }

  Future<void> _resetAll() async {
    final s = S.of(context);
    if (!await _confirm(
          s.nutrientGoalsResetAllTitle,
          s.nutrientGoalsResetAllContent,
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      for (final draft in _drafts.values) {
        draft.restore(NutrientPolicy(source: draft.policy.source));
      }
    });
  }

  Future<bool> _save() async {
    if (_saving || !_loaded) return false;
    for (final n in Nutrients.additional) {
      final policy = _drafts[n.key]!.value;
      if (!policy.valid || _resolve(n.key, policy).contradictory) {
        setState(() => _selected = n);
        _scroll.jumpTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !policy.valid
                  ? S.of(context).nutrientPositiveTarget
                  : S.of(context).nutrientContradictory,
            ),
          ),
        );
        return false;
      }
    }
    setState(() => _saving = true);
    try {
      await widget.profileBloc.setNutrientPolicies({
        for (final e in _drafts.entries) e.key: e.value.value,
      });
      if (!mounted) return true;
      widget.settingsBloc.add(LoadSettingsEvent());
      widget.homeBloc.add(const LoadItemsEvent());
      widget.diaryBloc.add(const LoadDiaryYearEvent());
      widget.calendarDayBloc.add(RefreshCalendarDayEvent());
      _remember();
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

  void _leave() {
    setState(() => _allowLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _saveAndLeave() async {
    if (await _save() && mounted) _leave();
  }

  Future<void> _confirmLeave() async {
    if (_leaveDialogOpen || _saving) return;
    FocusScope.of(context).unfocus();
    _leaveDialogOpen = true;
    try {
      final s = S.of(context);
      final action = await showDialog<_LeaveAction>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(s.unsavedChangesTitle),
          content: Text(s.unsavedChangesContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, _LeaveAction.discard),
              child: Text(s.discardAndLeaveLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(s.dialogCancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, _LeaveAction.save),
              child: Text(s.saveAndLeaveLabel),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == _LeaveAction.discard) _leave();
      if (action == _LeaveAction.save) await _saveAndLeave();
    } finally {
      _leaveDialogOpen = false;
    }
  }

  Widget _threshold(bool upper) {
    final s = S.of(context);
    final d = _draft;
    final mode = upper ? d.policy.upperMode : d.policy.adequacyMode;
    final id = upper ? 'upper' : 'adequacy';
    final value = _resolve(_selected.key, d.value);
    final reference = upper ? value.upper : value.adequacy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            upper ? s.nutrientUpperLevels : s.nutrientAdequacy,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Semantics(
            identifier: 'nutrient-$id-mode',
            child: DropdownButtonFormField<ThresholdMode>(
              key: ValueKey('${_selected.key}-$id-$mode'),
              initialValue: mode,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: ThresholdMode.reference,
                  child: Text(s.nutrientFollowReference),
                ),
                DropdownMenuItem(
                  value: ThresholdMode.custom,
                  child: Text(
                    upper ? s.nutrientCustomUpper : s.nutrientCustomTarget,
                  ),
                ),
                DropdownMenuItem(
                  value: ThresholdMode.unset,
                  child: Text(s.nutrientUnset),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (next) => setState(
                      () => d.policy = upper
                          ? d.policy.copyWith(upperMode: next)
                          : d.policy.copyWith(adequacyMode: next),
                    ),
            ),
          ),
          if (mode == ThresholdMode.custom)
            Semantics(
              identifier: 'nutrient-$id-amount',
              child: TextField(
                controller: upper ? d.upper : d.target,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: upper
                      ? s.nutrientCustomUpper
                      : s.nutrientCustomTarget,
                  suffixText: _selected.unit,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (mode == ThresholdMode.reference)
            Text(
              reference == null
                  ? referenceUnavailableLabel(value.unavailable, s)
                  : referenceAmountLabel(reference, s),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: _allowLeave || !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: AutoSizeText(
            s.settingsNutrientGoalsLabel,
            maxLines: 2,
            minFontSize: 12,
          ),
          actions: [
            Semantics(
              identifier: 'nutrient-goals-sources',
              child: IconButton(
                tooltip: s.sourcesIconTooltip,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SourcesScreen(
                      referenceRegion: _loaded ? _draft.policy.region : null,
                    ),
                  ),
                ),
                icon: const Icon(Icons.info_outline),
              ),
            ),
            Semantics(
              identifier: 'nutrient-goals-reset',
              child: IconButton(
                tooltip: s.nutrientGoalsResetAllLabel,
                onPressed: _saving || !_loaded ? null : _resetAll,
                icon: const Icon(Icons.restore),
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
                    : const Icon(Icons.check),
              ),
            ),
          ],
        ),
        body: _loadFailed
            ? Center(
                child: Semantics(
                  identifier: 'nutrient-goals-retry',
                  child: TextButton(
                    onPressed: () {
                      setState(() => _loadFailed = false);
                      _load();
                    },
                    child: Text(s.retryLabel),
                  ),
                ),
              )
            : !_loaded
            ? const Center(child: CircularProgressIndicator())
            : NutrientVisibilityBuilder(
                builder: (context, config) => Semantics(
                  identifier: 'nutrient-goals-detail',
                  label: s.settingsNutrientGoalsLabel,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) => Semantics(
                          identifier: 'nutrient-selector',
                          child: DropdownMenu<NutrientDefinition>(
                            key: ValueKey(_selected.key),
                            initialSelection: _selected,
                            width: constraints.maxWidth,
                            enableFilter: true,
                            enableSearch: true,
                            requestFocusOnTap: true,
                            label: Text(s.nutrientSearch),
                            dropdownMenuEntries: [
                              for (final n in Nutrients.additional)
                                DropdownMenuEntry(value: n, label: n.label(s)),
                            ],
                            onSelected: _saving
                                ? null
                                : (n) {
                                    if (n != null) {
                                      setState(() => _selected = n);
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(s.settingsNutrientGoalsHint),
                      const SizedBox(height: 16),
                      AutoSizeText(
                        _selected.label(s),
                        maxLines: 2,
                        minFontSize: 14,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Semantics(
                        identifier: 'nutrient-reference-source',
                        child: DropdownButtonFormField<ReferenceRegion>(
                          key: ValueKey(
                            '${_selected.key}-${_draft.policy.source}',
                          ),
                          initialValue: _draft.policy.region,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.nutrientSource,
                          ),
                          items: [
                            for (final r in ReferenceRegion.values)
                              DropdownMenuItem(
                                value: r,
                                child: Text(ReferenceSource.forRegion(r).name),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (r) {
                                  if (r != null) _changeSource(r);
                                },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.nutrientPublishedReferences,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      NutrientReferenceDetails(
                        reference: _resolve(
                          _selected.key,
                          _draft.value,
                        ).reference,
                        unavailable: _resolve(
                          _selected.key,
                          _draft.value,
                        ).unavailable,
                      ),
                      if (ReferenceCatalogue.series(
                            _draft.policy.region,
                          ).any((row) => row.nutrient == _selected.key) ||
                          _draft.policy.frozenReference != null ||
                          _resolve(
                                _selected.key,
                                _draft.value,
                              ).reference?.calculation ==
                              ReferenceCalculation.weightFormula)
                        Semantics(
                          identifier: 'nutrient-auto-adjust',
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.nutrientAutoAdjust),
                            subtitle: Text(s.nutrientAutoAdjustHelp),
                            value: _draft.policy.autoAdjust,
                            onChanged: _saving
                                ? null
                                : (enabled) => setState(
                                    () => _draft.policy = enabled
                                        ? _draft.policy.copyWith(
                                            autoAdjust: true,
                                          )
                                        : NutrientGoalResolver.freeze(
                                            nutrient: _selected.key,
                                            policy: _draft.policy,
                                            user: _user!,
                                            today: _today,
                                            weights: _weights,
                                          ),
                                  ),
                          ),
                        ),
                      if (!_draft.policy.autoAdjust)
                        Text(
                          '${s.referenceFrozen}: ${_draft.policy.frozenOn?.toIso8601String().split('T').first ?? '—'}',
                        ),
                      const Divider(),
                      Text(
                        s.nutrientActiveThresholds,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _threshold(false),
                      _threshold(true),
                      Semantics(
                        identifier: 'nutrient-goal-reset',
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _reset,
                          icon: const Icon(Icons.restore),
                          label: Text(s.nutrientUseDefaultLabel),
                        ),
                      ),
                      const Divider(),
                      Text(s.nutrientVisibilityImmediate),
                      Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          for (final label in [
                            s.nutrientVisibilityDailyLabel,
                            s.nutrientVisibilityInfoLabel,
                          ])
                            SizedBox(
                              width: 64,
                              child: Text(label, textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                      NutrientVisibilityControls(
                        nutrient: _selected,
                        config: config,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
