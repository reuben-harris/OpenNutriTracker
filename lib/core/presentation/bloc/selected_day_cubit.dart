import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';

class SelectedDayState extends Equatable {
  final DateTime day;
  final DateTime today;
  final bool initialized;

  const SelectedDayState(this.day, this.today, {this.initialized = true});

  bool get isToday => day == today;
  DateTime get firstDay =>
      DateTime(today.year, today.month, today.day - 365 * 5);
  DateTime get lastDay =>
      DateTime(today.year, today.month, today.day + 365 * 5);

  @override
  List<Object> get props => [day, today, initialized];
}

/// A calendar date, never a timestamp. All daily surfaces share this selection.
class SelectedDayCubit extends Cubit<SelectedDayState> {
  final GetConfigUsecase _getConfig;
  final String Function()? _activeProfileId;
  String? _profileId;
  int _generation = 0;

  SelectedDayCubit(this._getConfig, {String Function()? activeProfileId})
    : _activeProfileId = activeProfileId,
      super(
        SelectedDayState(
          DayBoundaryCalc.currentLogicalDayMinutes(0),
          DayBoundaryCalc.currentLogicalDayMinutes(0),
          initialized: false,
        ),
      );

  Future<void> initialize({bool reset = false}) async {
    final generation = ++_generation;
    final profileId = _activeProfileId?.call();
    final config = await _getConfig.getConfig();
    if (isClosed || generation != _generation) return;
    final today = DayBoundaryCalc.currentLogicalDayMinutes(
      config.dayStartOffsetTotalMinutes,
    );
    final changedProfile = profileId != _profileId;
    _profileId = profileId;
    var day = reset || changedProfile || !state.initialized || state.isToday
        ? today
        : state.day;
    final range = SelectedDayState(day, today);
    if (day.isBefore(range.firstDay)) day = range.firstDay;
    if (day.isAfter(range.lastDay)) day = range.lastDay;
    emit(SelectedDayState(day, today));
  }

  void select(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(state.firstDay) || day.isAfter(state.lastDay)) return;
    emit(SelectedDayState(day, state.today));
  }

  void step(int days) =>
      select(DateTime(state.day.year, state.day.month, state.day.day + days));

  void returnToToday() => select(state.today);
}
