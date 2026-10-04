import 'dart:async';

import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_drag_targets.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_transfer_style.dart';
import 'package:opennutritracker/features/home/presentation/widgets/recipe_swipe_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_activity_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_dialog.dart';
import 'package:opennutritracker/core/utils/calc/met_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/activity_detail/presentation/bloc/activity_detail_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/day_info_widget.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_water_section.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late DiaryBloc _diaryBloc;
  late CalendarDayBloc _calendarDayBloc;
  late ActivityDetailBloc _activityDetailBloc;

  final _scrollController = ScrollController();
  final _viewportKey = GlobalKey();
  Timer? _edgeScrollTimer;
  Offset? _dragPosition;
  double _dateSwipeDistance = 0;
  IntakeEntity? _draggedEntry;
  bool get _dragging => _draggedEntry != null;

  @override
  void dispose() {
    _edgeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onIntakeDrag(IntakeEntity? entry) {
    final dragging = entry != null;
    if (!mounted) return;
    if (!dragging) {
      _edgeScrollTimer?.cancel();
      _edgeScrollTimer = null;
      _dragPosition = null;
    }
    setState(() => _draggedEntry = entry);
  }

  void _onIntakeDragUpdate(DragUpdateDetails details) {
    _dragPosition = details.globalPosition;
    _edgeScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final position = _dragPosition;
      final box = _viewportKey.currentContext?.findRenderObject();
      if (position == null ||
          box is! RenderBox ||
          !_scrollController.hasClients) {
        return;
      }
      final y = box.globalToLocal(position).dy;
      const edge = 72.0;
      final bottom = box.size.height - 84;
      final speed = y < edge
          ? -12 * ((edge - y) / edge).clamp(0.0, 1.0)
          : y > bottom - edge
          ? 12 * ((y - bottom + edge) / edge).clamp(0.0, 1.0)
          : 0.0;
      if (speed == 0) return;
      final scroll = _scrollController.position;
      final next = (scroll.pixels + speed).clamp(
        scroll.minScrollExtent,
        scroll.maxScrollExtent,
      );
      if (next != scroll.pixels) _scrollController.jumpTo(next);
    });
  }

  Future<void> _deleteDraggedEntry(IntakeEntity entry) async {
    final day = _selectedDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteDialog(),
    );
    if (confirmed != true || !mounted) return;
    await _calendarDayBloc.deleteIntakeItem(context, entry, day);
    _diaryBloc.add(const LoadDiaryYearEvent());
    _calendarDayBloc.add(RefreshCalendarDayEvent());
    _diaryBloc.updateHomePage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
      );
    }
  }

  DateTime get _selectedDate => locator<SelectedDayCubit>().state.day;

  @override
  void initState() {
    _diaryBloc = locator<DiaryBloc>();
    _calendarDayBloc = locator<CalendarDayBloc>();
    _activityDetailBloc = locator<ActivityDetailBloc>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SelectedDayCubit, SelectedDayState>(
      bloc: locator<SelectedDayCubit>(),
      listenWhen: (previous, next) => previous.day != next.day,
      listener: (_, _) {
        RecipeSwipeScope.maybeOf(context)?.close();
        if (_dragging) _onIntakeDrag(null);
      },
      child: BlocBuilder<DiaryClipboardCubit, List<IntakeEntity>>(
        bloc: locator<DiaryClipboardCubit>(),
        builder: (context, entries) => Stack(
          children: [
            BlocBuilder<DiaryBloc, DiaryState>(
              bloc: _diaryBloc,
              builder: (context, state) {
                if (state is DiaryInitial) {
                  _diaryBloc.add(const LoadDiaryYearEvent());
                } else if (state is DiaryLoadingState) {
                  return _getLoadingContent();
                } else if (state is DiaryLoadedState) {
                  return _getLoadedContent(
                    context,
                    state.trackedDayMap,
                    state.usesImperialUnits,
                    state.showMealMacros,
                    state.showActivityTracking,
                  );
                }
                return const SizedBox();
              },
            ),
            if (_dragging)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: DiaryDragTargets(
                  onDelete: _deleteDraggedEntry,
                  onCopy: (entry) =>
                      locator<DiaryClipboardCubit>().copy([entry]),
                ),
              ),
            if (!_dragging && entries.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: Semantics(
                    identifier: 'diary-clear-clipboard',
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: diaryCopyButtonColor,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: Dimens.borderRadiusL,
                        ),
                      ),
                      tooltip: S.of(context).diaryClearClipboardLabel,
                      onPressed: locator<DiaryClipboardCubit>().clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getLoadingContent() =>
      const Center(child: CircularProgressIndicator());

  Widget _getLoadedContent(
    BuildContext context,
    Map<String, TrackedDayEntity> trackedDaysMap,
    bool usesImperialUnits,
    bool showMealMacros,
    bool showActivityTracking,
  ) {
    return ListView(
      key: _viewportKey,
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dateSwipeDistance = 0,
          onHorizontalDragUpdate: (details) =>
              _dateSwipeDistance += details.delta.dx,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (_dateSwipeDistance.abs() >= 60 || velocity.abs() >= 250) {
              final direction = velocity.abs() >= 250
                  ? velocity
                  : _dateSwipeDistance;
              locator<SelectedDayCubit>().step(direction < 0 ? 1 : -1);
            }
            _dateSwipeDistance = 0;
          },
          onHorizontalDragCancel: () => _dateSwipeDistance = 0,
          child: BlocBuilder<CalendarDayBloc, CalendarDayState>(
            bloc: _calendarDayBloc,
            builder: (context, state) {
              if (state is CalendarDayInitial) {
                _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
              } else if (state is CalendarDayLoading) {
                return _getLoadingContent();
              } else if (state is CalendarDayLoaded) {
                if (state.day != _selectedDate) return _getLoadingContent();
                return Column(
                  children: [
                    DayInfoWidget(
                      trackedDayEntity: state.trackedDayEntity,
                      selectedDay: _selectedDate,
                      userActivities: state.userActivityList,
                      breakfastIntake: state.breakfastIntakeList,
                      lunchIntake: state.lunchIntakeList,
                      dinnerIntake: state.dinnerIntakeList,
                      snackIntake: state.snackIntakeList,
                      onDeleteIntake: _onDeleteIntakeItem,
                      onDeleteActivity: _onDeleteActivityItem,
                      draggingType: _draggedEntry?.type,
                      onIntakeDrag: _onIntakeDrag,
                      onIntakeDragUpdate: _onIntakeDragUpdate,
                      onCopyActivity: _onCopyActivityItem,
                      onEditIntake: _onEditIntakeItem,
                      onEditActivity: _onEditActivityItem,
                      usesImperialUnits: usesImperialUnits,
                      showMealMacros: showMealMacros,
                      showActivityTracking: showActivityTracking,
                      breakfastKcalTarget: state.breakfastKcalTarget,
                      lunchKcalTarget: state.lunchKcalTarget,
                      dinnerKcalTarget: state.dinnerKcalTarget,
                      snackKcalTarget: state.snackKcalTarget,
                      breakfastSharePct: state.breakfastSharePct,
                      lunchSharePct: state.lunchSharePct,
                      dinnerSharePct: state.dinnerSharePct,
                      snackSharePct: state.snackSharePct,
                      diarySortPreferences: state.diarySortPreferences,
                    ),
                    DiaryWaterSection(
                      day: state.day!,
                      entries: state.waterEntries,
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }

  void _onDeleteIntakeItem(
    IntakeEntity intakeEntity,
    TrackedDayEntity? trackedDayEntity,
  ) async {
    await _calendarDayBloc.deleteIntakeItem(
      context,
      intakeEntity,
      _selectedDate,
    );
    _diaryBloc.add(const LoadDiaryYearEvent());
    _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
    _diaryBloc.updateHomePage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
      );
    }
  }

  void _onDeleteActivityItem(
    UserActivityEntity userActivityEntity,
    TrackedDayEntity? trackedDayEntity,
  ) async {
    await _calendarDayBloc.deleteUserActivityItem(
      context,
      userActivityEntity,
      _selectedDate,
    );
    _diaryBloc.add(const LoadDiaryYearEvent());
    _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
    _diaryBloc.updateHomePage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
      );
    }
  }

  void _onCopyActivityItem(
    UserActivityEntity userActivityEntity,
    TrackedDayEntity? trackedDayEntity,
  ) async {
    final activity = userActivityEntity.physicalActivityEntity;
    if (activity.isCustom) {
      // Custom activities (#70) store the user-entered kcal directly — the
      // MET formula would just return zero for them, so we pass the saved
      // kcal figure through unchanged so a copied entry keeps its calories.
      final kcal = userActivityEntity.userKcal ?? userActivityEntity.burnedKcal;
      await _activityDetailBloc.persistActivity(
        kcal.toString(),
        kcal,
        activity,
        locator<SelectedDayCubit>().state.today,
      );
    } else {
      final user = await locator<GetUserUsecase>().getUserData();
      final burnedKcal = METCalc.getTotalBurnedKcal(
        user,
        activity,
        userActivityEntity.duration,
      );
      await _activityDetailBloc.persistActivity(
        userActivityEntity.duration.toString(),
        burnedKcal,
        activity,
        locator<SelectedDayCubit>().state.today,
      );
    }
    _diaryBloc.updateHomePage();
  }

  void _onEditIntakeItem(
    BuildContext context,
    IntakeEntity intakeEntity,
    bool usesImperialUnits,
  ) async {
    final day = _selectedDate;
    final changeIntakeAmount = await showDialog<double>(
      context: context,
      builder: (context) => EditDialog(
        intakeEntity: intakeEntity,
        usesImperialUnits: usesImperialUnits,
      ),
    );
    if (changeIntakeAmount != null) {
      await _calendarDayBloc.updateIntakeItem(intakeEntity.id, {
        'amount': changeIntakeAmount,
      }, day);
      _diaryBloc.add(const LoadDiaryYearEvent());
      _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
      _diaryBloc.updateHomePage();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
        );
      }
    }
  }

  void _onEditActivityItem(
    BuildContext context,
    UserActivityEntity activityEntity,
  ) async {
    final day = _selectedDate;
    final newDuration = await showDialog<double>(
      context: context,
      builder: (context) => EditActivityDialog(activityEntity: activityEntity),
    );
    if (newDuration != null) {
      await _calendarDayBloc.updateUserActivityItem(
        activityEntity,
        newDuration,
        day,
      );
      _diaryBloc.add(const LoadDiaryYearEvent());
      _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
      _diaryBloc.updateHomePage();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
        );
      }
    }
  }
}
