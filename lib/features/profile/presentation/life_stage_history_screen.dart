import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/life_stage_period.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/history_layout.dart';
import 'package:opennutritracker/generated/l10n.dart';

String lifeStageLabel(LifeStage stage, S s) =>
    stage == LifeStage.pregnancy ? s.pregnancyLabel : s.breastfeedingLabel;

class LifeStageHistoryScreen extends StatefulWidget {
  const LifeStageHistoryScreen({super.key});
  @override
  State<LifeStageHistoryScreen> createState() => _LifeStageHistoryScreenState();
}

class _LifeStageHistoryScreenState extends State<LifeStageHistoryScreen> {
  final _repository = locator<UserRepository>();
  UserEntity? _user;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _repository.getUserData();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _edit([LifeStagePeriod? existing]) async {
    final result = await showDialog<LifeStagePeriod>(
      context: context,
      builder: (_) => _PeriodDialog(
        existing: existing,
        others: _user!.lifeStagePeriods.where((p) => p != existing).toList(),
      ),
    );
    if (result == null) return;
    _user!.lifeStagePeriods = [
      ..._user!.lifeStagePeriods.where((p) => p != existing),
      result,
    ];
    await _repository.updateUserData(_user!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final entries = _user?.lifeStagePeriods.reversed.toList() ?? [];
    final enabled = _user?.sex == UserSexEntity.female;
    return Scaffold(
      appBar: AppBar(title: Text(s.lifeStageHistoryTitle)),
      floatingActionButton: enabled
          ? Semantics(
              identifier: 'life-stage-history-add',
              child: FloatingActionButton.extended(
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: Text(s.weightHistoryAddEntry),
              ),
            )
          : null,
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(s.lifeStageExplanation),
                ),
                Expanded(
                  child: HistoryEntries(
                    identifier: 'life-stage-history-entries',
                    emptyLabel: s.lifeStageEmpty,
                    count: entries.length,
                    itemBuilder: (context, index) {
                      final period = entries[index];
                      return ListTile(
                        leading: const Icon(Icons.timeline),
                        title: Text(lifeStageLabel(period.stage, s)),
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(period.start)} – ${period.end == null ? s.lifeStageOngoing : DateFormat.yMMMd().format(period.end!)}',
                        ),
                        onTap: enabled ? () => _edit(period) : null,
                        trailing: Semantics(
                          identifier: 'life-stage-delete-$index',
                          child: IconButton(
                            tooltip: s.historyDeleteLabel,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: !enabled
                                ? null
                                : () async {
                                    _user!.lifeStagePeriods = _user!
                                        .lifeStagePeriods
                                        .where((p) => p != period)
                                        .toList();
                                    await _repository.updateUserData(_user!);
                                    await _load();
                                  },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _PeriodDialog extends StatefulWidget {
  final LifeStagePeriod? existing;
  final List<LifeStagePeriod> others;
  const _PeriodDialog({this.existing, required this.others});
  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late LifeStage _stage = widget.existing?.stage ?? LifeStage.pregnancy;
  late DateTime _start = widget.existing?.start ?? DateTime.now();
  late DateTime? _end = widget.existing?.end;
  bool get _valid {
    try {
      final period = LifeStagePeriod(stage: _stage, start: _start, end: _end);
      return !widget.others.any(period.overlaps);
    } on ArgumentError {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.lifeStageHistoryTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              identifier: 'life-stage-type',
              child: DropdownButtonFormField<LifeStage>(
                initialValue: _stage,
                isExpanded: true,
                items: [
                  for (final stage in LifeStage.values)
                    DropdownMenuItem(
                      value: stage,
                      child: Text(lifeStageLabel(stage, s)),
                    ),
                ],
                onChanged: (stage) => setState(() => _stage = stage!),
              ),
            ),
            HistoryDateField(
              identifier: 'life-stage-start',
              label: s.lifeStageStart,
              date: _start,
              onChanged: (date) => setState(() => _start = date),
            ),
            Semantics(
              identifier: 'life-stage-ongoing',
              child: SwitchListTile(
                title: Text(s.lifeStageOngoing),
                value: _end == null,
                onChanged: (ongoing) =>
                    setState(() => _end = ongoing ? null : DateTime.now()),
              ),
            ),
            if (_end != null)
              HistoryDateField(
                identifier: 'life-stage-end',
                label: s.lifeStageEnd,
                date: _end!,
                onChanged: (date) => setState(() => _end = date),
              ),
            if (!_valid)
              Text(
                s.lifeStageInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.dialogCancelLabel),
        ),
        TextButton(
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  LifeStagePeriod(stage: _stage, start: _start, end: _end),
                )
              : null,
          child: Text(s.dialogOKLabel),
        ),
      ],
    );
  }
}
