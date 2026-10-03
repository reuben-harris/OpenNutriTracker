import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/log_water_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DiaryWaterSection extends StatelessWidget {
  final DateTime day;
  final List<WaterIntakeEntity> entries;
  const DiaryWaterSection({
    super.key,
    required this.day,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final total = entries.fold(0, (sum, entry) => sum + entry.amountMl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoSizeText(
                    s.trendsWaterLabel,
                    maxLines: 1,
                    minFontSize: 12,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                if (!largeText) Text('$total ${s.mlLabel}'),
                Semantics(
                  identifier: 'diary-water-add',
                  child: IconButton(
                    tooltip: s.logWaterDialogTitle,
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            ),
            if (largeText)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text('$total ${s.mlLabel}'),
              ),
            Semantics(
              identifier: 'diary-water-entries',
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${entry.amountMl} ${s.mlLabel}'),
                    subtitle: Text(
                      DateFormat.jm(
                        Localizations.localeOf(context).toString(),
                      ).format(entry.dateTime),
                    ),
                    onTap: () => _edit(context, entry),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: s.editWaterAmountLabel,
                          onPressed: () => _edit(context, entry),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: s.dialogDeleteLabel,
                          onPressed: () => _delete(context, entry),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [WaterIntakeEntity? entry]) =>
      showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LogWaterDialog(
          initialAmount: entry?.amountMl,
          onSave: (amount) =>
              locator<CalendarDayBloc>().saveWater(day, amount, entry: entry),
        ),
      );

  Future<void> _delete(BuildContext context, WaterIntakeEntity entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteDialog(),
    );
    if (confirmed != true) return;
    try {
      await locator<CalendarDayBloc>().removeWater(entry);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).waterSaveErrorLabel)),
        );
      }
    }
  }
}
