import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';

enum DiaryCopyResult { copied, cancelled, busy, empty, failed }

/// Serializes whole batches, including destination dialogs, across meal groups.
class DiaryCopyCubit extends Cubit<bool> {
  final MealDetailBloc _logger;
  final GetIntakeUsecase _intakes;
  final GetConfigUsecase _config;
  final AddTrackedDayUsecase _tracked;
  final VoidCallback _refresh;
  final _log = Logger('DiaryCopyCubit');
  Completer<void>? _completion;
  Completer<void>? _cancel;
  int _generation = 0;

  DiaryCopyCubit(
    this._logger,
    this._intakes,
    this._config,
    this._tracked,
    this._refresh,
  ) : super(false);

  Future<void> get idle => _completion?.future ?? Future<void>.value();

  /// Cancels dialogs/between-entry work and finishes any current write before
  /// profile boxes can be switched or reset.
  Future<void> cancelAndWait() async {
    _generation++;
    if (_cancel != null && !_cancel!.isCompleted) _cancel!.complete();
    await _completion?.future;
  }

  Future<DiaryCopyResult> copy(
    BuildContext context,
    List<IntakeEntity> entries,
    DateTime destinationDay,
    IntakeTypeEntity initialType, {
    Future<IntakeTypeEntity?> Function()? selectDestination,
    Future<List<IntakeEntity>> Function()? loadSource,
  }) async {
    if (state) return DiaryCopyResult.busy;
    final day = DateTime(
      destinationDay.year,
      destinationDay.month,
      destinationDay.day,
    );
    final generation = _generation;
    _completion = Completer<void>();
    _cancel = Completer<void>();
    emit(true);
    var wrote = false;
    try {
      final source = snapshotDiaryEntries(
        loadSource == null ? entries : await loadSource(),
      );
      if (generation != _generation || !context.mounted) {
        return DiaryCopyResult.cancelled;
      }
      if (source.isEmpty) return DiaryCopyResult.empty;
      final type = selectDestination == null
          ? initialType
          : await Future.any([
              selectDestination(),
              _cancel!.future.then<IntakeTypeEntity?>((_) => null),
            ]);
      if (type == null || generation != _generation || !context.mounted) {
        return DiaryCopyResult.cancelled;
      }
      for (final entry in source) {
        if (generation != _generation) return DiaryCopyResult.cancelled;
        wrote = true;
        await _logger.addIntake(
          context,
          entry.unit,
          entry.amount.toString(),
          type,
          entry.meal,
          day,
          copiedFrom: entry,
        );
      }
      return DiaryCopyResult.copied;
    } catch (error, stack) {
      _log.warning(
        'Diary copy stopped; retaining already saved entries',
        error,
        stack,
      );
      if (wrote) {
        try {
          // An intake may have saved before its cached totals failed. Restore
          // those totals from storage instead of retrying (and duplicating it).
          final config = await _config.getConfig();
          final entries = await _intakes.getIntakesByRange(
            day,
            day,
            dayStartOffsetHours: config.dayStartOffsetHours,
            dayStartOffsetMinutes: config.dayStartOffsetMinutes,
          );
          await _tracked.reconcileDayTracked(
            day,
            entries.fold<double>(0, (sum, e) => sum + e.totalKcal),
            entries.fold<double>(0, (sum, e) => sum + e.totalCarbsGram),
            entries.fold<double>(0, (sum, e) => sum + e.totalFatsGram),
            entries.fold<double>(0, (sum, e) => sum + e.totalProteinsGram),
          );
        } catch (error, stack) {
          _log.warning('Could not reconcile partial diary copy', error, stack);
        }
      }
      return DiaryCopyResult.failed;
    } finally {
      if (wrote) _refresh();
      emit(false);
      _completion!.complete();
      _completion = null;
      _cancel = null;
    }
  }
}
