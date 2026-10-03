import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_table_calendar.dart';

/// Shared by Diary and Overview; the calendar is opened only when needed.
class SelectedDayHeader extends StatelessWidget {
  const SelectedDayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final selection = locator<SelectedDayCubit>();
    final material = MaterialLocalizations.of(context);
    return BlocBuilder<SelectedDayCubit, SelectedDayState>(
      bloc: selection,
      builder: (context, state) {
        final previous = Semantics(
          identifier: 'selected-day-previous',
          child: IconButton(
            tooltip: material.previousPageTooltip,
            onPressed: state.day == state.firstDay
                ? null
                : () => selection.step(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        );
        final next = Semantics(
          identifier: 'selected-day-next',
          child: IconButton(
            tooltip: material.nextPageTooltip,
            onPressed: state.day == state.lastDay
                ? null
                : () => selection.step(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        );
        final date = Semantics(
          identifier: 'selected-day-calendar',
          container: true,
          child: TextButton(
            onPressed: () => _openCalendar(context, selection),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AutoSizeText(
                    DateFormat.yMMMEd(
                      Localizations.localeOf(context).toString(),
                    ).format(state.day),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    minFontSize: 12,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        );
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: largeText
              ? Column(
                  children: [
                    date,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [previous, const SizedBox(width: 48), next],
                    ),
                  ],
                )
              : Row(
                  children: [
                    previous,
                    Expanded(child: date),
                    next,
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openCalendar(
    BuildContext context,
    SelectedDayCubit selection,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: BlocBuilder<DiaryBloc, DiaryState>(
            bloc: locator<DiaryBloc>(),
            builder: (context, diary) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  identifier: 'selected-day-month-calendar',
                  child: DiaryTableCalendar(
                    trackedDaysMap: diary is DiaryLoadedState
                        ? diary.trackedDayMap
                        : const {},
                    calendarDurationDays: const Duration(days: 365 * 5),
                    currentDate: selection.state.today,
                    selectedDate: selection.state.day,
                    focusedDate: selection.state.day,
                    onDateSelected: (day, _) {
                      selection.select(day);
                      Navigator.pop(context);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                    identifier: 'selected-day-today',
                    child: FilledButton(
                      onPressed: () {
                        selection.returnToToday();
                        Navigator.pop(context);
                      },
                      child: Text(
                        MaterialLocalizations.of(context).currentDateLabel,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
