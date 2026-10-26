import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/height_reading.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/profile/presentation/utils/profile_display_format.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/feet_inches_input.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/history_layout.dart';
import 'package:opennutritracker/generated/l10n.dart';

class HeightHistoryScreen extends StatefulWidget {
  const HeightHistoryScreen({super.key});
  @override
  State<HeightHistoryScreen> createState() => _HeightHistoryScreenState();
}

class _HeightHistoryScreenState extends State<HeightHistoryScreen> {
  final _repository = locator<UserRepository>();
  UserEntity? _user;
  bool _imperial = false;
  HistoryRange _range = HistoryRange.all;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _repository.getUserData();
    final imperial =
        (await locator<ConfigRepository>().getConfig()).usesImperialHeightUnits;
    if (mounted) {
      setState(() {
        _user = user;
        _imperial = imperial;
      });
    }
  }

  Future<void> _edit([HeightReading? existing]) async {
    final reading = await showDialog<HeightReading>(
      context: context,
      builder: (_) => _HeightEntryDialog(
        initial:
            existing ??
            HeightReading(date: DateTime.now(), centimetres: _user!.heightCM),
        imperial: _imperial,
      ),
    );
    if (reading == null) return;
    if (existing != null) {
      _user!.heightHistory.removeWhere((e) => e.date == existing.date);
    }
    _user!.recordHeight(reading);
    await _repository.updateUserData(_user!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final entries =
        _user?.heightHistory
            .where((e) => _range.contains(e.date, DateTime.now()))
            .toList() ??
        [];
    entries.sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(s.heightHistoryTitle)),
      floatingActionButton: Semantics(
        identifier: 'height-history-add',
        child: FloatingActionButton.extended(
          onPressed: _user == null ? null : _edit,
          icon: const Icon(Icons.add),
          label: Text(s.weightHistoryAddEntry),
        ),
      ),
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                HistoryRangeSelector(
                  identifier: 'height-history-range-selector',
                  selected: _range,
                  onChanged: (range) => setState(() => _range = range),
                ),
                Expanded(
                  child: HistoryEntries(
                    identifier: 'height-history-entries',
                    emptyLabel: s.heightHistoryEmpty,
                    count: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Semantics(
                        identifier:
                            'height-history-entry-${entry.date.toIso8601String().split('T').first}',
                        child: ListTile(
                          title: Text(
                            formatHeight(
                              entry.centimetres,
                              _imperial,
                              cmLabel: s.cmLabel,
                              ftLabel: s.ftLabel,
                              inLabel: s.inLabel,
                            ),
                          ),
                          subtitle: Text(DateFormat.yMMMd().format(entry.date)),
                          onTap: () => _edit(entry),
                          trailing: Semantics(
                            identifier:
                                'height-history-delete-${entry.date.toIso8601String().split('T').first}',
                            child: IconButton(
                              tooltip: s.historyDeleteLabel,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                _user!.heightHistory.removeWhere(
                                  (e) => e.date == entry.date,
                                );
                                await _repository.updateUserData(_user!);
                                await _load();
                              },
                            ),
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

class _HeightEntryDialog extends StatefulWidget {
  final HeightReading initial;
  final bool imperial;
  const _HeightEntryDialog({required this.initial, required this.imperial});
  @override
  State<_HeightEntryDialog> createState() => _HeightEntryDialogState();
}

class _HeightEntryDialogState extends State<_HeightEntryDialog> {
  late DateTime _date = widget.initial.date;
  late double? _cm = widget.initial.centimetres;
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.heightHistoryTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HistoryDateField(
              identifier: 'height-history-date',
              label: s.weightHistoryDateLabel,
              date: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            if (widget.imperial)
              FeetInchesInput(
                initialCm: widget.initial.centimetres,
                identifierPrefix: 'height-history',
                onChangedCm: (cm) => setState(() => _cm = cm),
              )
            else
              Semantics(
                identifier: 'height-history-centimetres',
                child: TextFormField(
                  initialValue: _cm.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s.heightLabel,
                    suffixText: s.cmLabel,
                  ),
                  onChanged: (value) =>
                      setState(() => _cm = double.tryParse(value)),
                ),
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
          onPressed: _cm != null && _cm!.isFinite && _cm! > 0
              ? () => Navigator.pop(
                  context,
                  HeightReading(date: _date, centimetres: _cm!),
                )
              : null,
          child: Text(s.dialogOKLabel),
        ),
      ],
    );
  }
}
