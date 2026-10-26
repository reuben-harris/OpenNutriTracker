import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum HistoryRange {
  days30(30),
  days60(60),
  days180(180),
  days365(365),
  all(null);

  final int? days;
  const HistoryRange(this.days);
  bool contains(DateTime date, DateTime today) =>
      days == null ||
      !date.isBefore(
        DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: days! - 1)),
      );
}

class HistoryRangeSelector extends StatelessWidget {
  final String identifier;
  final HistoryRange selected;
  final ValueChanged<HistoryRange> onChanged;
  const HistoryRangeSelector({
    super.key,
    required this.identifier,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Semantics(
          identifier: identifier,
          child: SegmentedButton<HistoryRange>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final range in HistoryRange.values)
                ButtonSegment(
                  value: range,
                  label: Text(
                    range.days == null
                        ? S.of(context).allItemsLabel
                        : '${range.days}d',
                  ),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (value) => onChanged(value.first),
          ),
        ),
      ),
    ),
  );
}

class HistoryEntries extends StatelessWidget {
  final String identifier;
  final String emptyLabel;
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;
  const HistoryEntries({
    super.key,
    required this.identifier,
    required this.emptyLabel,
    required this.count,
    required this.itemBuilder,
    this.header,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    label: emptyLabel,
    child: count == 0 && header == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyLabel, textAlign: TextAlign.center),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: count + (header == null ? 0 : 1),
            separatorBuilder: (_, index) => index == 0 && header != null
                ? const SizedBox.shrink()
                : const Divider(height: 1),
            itemBuilder: (context, index) => header != null && index == 0
                ? header!
                : itemBuilder(context, index - (header == null ? 0 : 1)),
          ),
  );
}

class HistoryDateField extends StatelessWidget {
  final String identifier;
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const HistoryDateField({
    super.key,
    required this.identifier,
    required this.label,
    required this.date,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(
        DateFormat.yMMMd(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(date),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
    ),
  );
}
