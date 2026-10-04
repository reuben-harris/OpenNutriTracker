import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_copy.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_paste_preview.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_transfer_style.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_profiles_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_to_profile_sheet.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_all_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/presentation/widgets/share_qr_dialog.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_sort_type.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/meal_section_actions.dart';
import 'package:opennutritracker/features/home/domain/entity/shared_meal_payload.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/explodable_intake_row.dart';
import 'package:opennutritracker/features/home/presentation/widgets/recipe_swipe_scope.dart';
import 'package:opennutritracker/features/home/presentation/screens/import_meal_scanner_screen.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum DiaryMealAction { copyDay, copyClipboard, delete, share, import }

class IntakeVerticalList extends StatefulWidget {
  final DateTime day;
  final String title;
  final IconData listIcon;
  final AddMealType addMealType;
  final List<IntakeEntity> intakeList;
  final bool usesImperialUnits;
  final bool showMealMacros;
  final Function(IntakeEntity intake, TrackedDayEntity? trackedDayEntity)
  onDeleteIntakeCallback;
  final IntakeTypeEntity? draggingType;
  final ValueChanged<IntakeEntity?>? onItemDragCallback;
  final ValueChanged<DragUpdateDetails>? onItemDragUpdate;
  final Function(BuildContext, IntakeEntity, bool)? onItemTappedCallback;
  final TrackedDayEntity? trackedDayEntity;
  // #150: optional recommended kcal target for this meal section. When
  // supplied and > 0, the section header shows "consumed / target kcal" so
  // someone scanning the day can see at a glance whether breakfast (or any
  // other meal) sat inside the share they had planned for it.
  final double? mealKcalTarget;

  /// Current sort applied to [intakeList]. When non-null (and
  /// [onSortTypeChanged] is also provided), a small sort menu is rendered in
  /// the section header. Callers are responsible for sorting [intakeList]
  /// before it reaches the widget — this field only drives the menu's
  /// highlighted selection.
  final DiarySortType? sortType;

  /// Called when the user picks a new sort option from the section header.
  /// When null, the sort menu is hidden.
  final ValueChanged<DiarySortType>? onSortTypeChanged;

  const IntakeVerticalList({
    super.key,
    required this.day,
    required this.title,
    required this.listIcon,
    required this.addMealType,
    required this.intakeList,
    required this.usesImperialUnits,
    this.showMealMacros = true,
    required this.onDeleteIntakeCallback,
    this.draggingType,
    this.onItemDragCallback,
    this.onItemDragUpdate,
    this.onItemTappedCallback,
    this.trackedDayEntity,
    this.mealKcalTarget,
    this.sortType,
    this.onSortTypeChanged,
  });

  @override
  State<IntakeVerticalList> createState() => _IntakeVerticalListState();
}

class _IntakeVerticalListState extends State<IntakeVerticalList> {
  double get totalKcal {
    return widget.intakeList.fold(
      0,
      (previousValue, element) => previousValue + element.totalKcal,
    );
  }

  double get totalCarbsGram {
    return widget.intakeList.fold(
      0,
      (previousValue, element) => previousValue + element.totalCarbsGram,
    );
  }

  double get totalFatsGram {
    return widget.intakeList.fold(
      0,
      (previousValue, element) => previousValue + element.totalFatsGram,
    );
  }

  double get totalProteinsGram {
    return widget.intakeList.fold(
      0,
      (previousValue, element) => previousValue + element.totalProteinsGram,
    );
  }

  // #150: only show a header when we have something to say — either some
  // food was logged, or a recommended target exists so the section can read
  // "0 / 600 kcal" before anything is logged.
  bool get _hasMealKcalTarget =>
      widget.mealKcalTarget != null && widget.mealKcalTarget! > 0;

  bool get _shouldShowHeaderSummary =>
      widget.intakeList.isNotEmpty || _hasMealKcalTarget;

  String _buildHeaderSummary(BuildContext context) {
    final consumed = EnergyDisplay.formatValue(context, totalKcal);
    final kcalLine = _hasMealKcalTarget
        ? S
              .of(context)
              .diaryMealKcalConsumedOfTarget(
                consumed,
                EnergyDisplay.formatValue(context, widget.mealKcalTarget!),
              )
        : EnergyDisplay.formatWithUnit(context, totalKcal);
    if (widget.showMealMacros && widget.intakeList.isNotEmpty) {
      return '$kcalLine\n'
          '${totalCarbsGram.toInt()} ${S.of(context).carbsLabelShort}  '
          '${totalFatsGram.toInt()} ${S.of(context).fatLabelShort}  '
          '${totalProteinsGram.toInt()} ${S.of(context).proteinLabelShort}';
    }
    return kcalLine;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;
    final accepts =
        widget.draggingType != null &&
        widget.draggingType != widget.addMealType.getIntakeType();
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DragTarget<IntakeEntity>(
          onWillAcceptWithDetails: (details) =>
              details.data.type != widget.addMealType.getIntakeType(),
          onAcceptWithDetails: (details) => _onItemDropped(details.data),
          builder: (context, candidates, rejected) => Semantics(
            identifier:
                'diary-${widget.addMealType.getIntakeType().name}-group',
            label: widget.title,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? diaryCopyColor.withValues(alpha: 0.26)
                    : accepts
                    ? diaryCopyColor.withValues(alpha: 0.09)
                    : Colors.transparent,
                border: Border.all(
                  color: accepts || candidates.isNotEmpty
                      ? diaryCopyColor
                      : Colors.transparent,
                ),
                borderRadius: Dimens.borderRadiusM,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: Dimens.borderRadiusS,
                          ),
                          child: Icon(widget.listIcon, size: 20, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AutoSizeText(
                            widget.title,
                            maxLines: 1,
                            minFontSize: 14,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge?.copyWith(
                              color: palette.textStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_shouldShowHeaderSummary)
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              _buildHeaderSummary(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium?.copyWith(
                                color: palette.textMuted,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        if (widget.onSortTypeChanged != null &&
                            widget.intakeList.isNotEmpty)
                          _buildSortMenu(context),
                        _buildMenu(context),
                      ],
                    ),
                  ),
                  for (final entry in widget.intakeList)
                    Semantics(
                      key: ValueKey(entry.id),
                      identifier: 'diary-intake-${entry.id}',
                      label: entry.meal.name ?? '?',
                      child: LongPressDraggable<IntakeEntity>(
                        data: entry,
                        onDragStarted: () {
                          RecipeSwipeScope.maybeOf(context)?.close();
                          widget.onItemDragCallback?.call(entry);
                        },
                        onDragUpdate: widget.onItemDragUpdate,
                        onDragEnd: (_) => widget.onItemDragCallback?.call(null),
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Opacity(
                              opacity: 0.85,
                              child: IntakeCard(
                                key: ValueKey('fb-${entry.id}'),
                                intake: entry,
                                firstListElement: false,
                                usesImperialUnits: widget.usesImperialUnits,
                              ),
                            ),
                          ),
                        ),
                        // Keep the exact row dimensions, including enlarged text.
                        childWhenDragging: ExcludeSemantics(
                          child: Opacity(
                            opacity: 0.35,
                            child: IntakeCard(
                              key: ValueKey('placeholder-${entry.id}'),
                              intake: entry,
                              firstListElement: false,
                              usesImperialUnits: widget.usesImperialUnits,
                            ),
                          ),
                        ),
                        child: ExplodableIntakeRow(
                          key: ValueKey(entry.id),
                          intake: entry,
                          onItemTapped: widget.onItemTappedCallback,
                          onLeftSwipe: () =>
                              locator<SelectedDayCubit>().step(1),
                          usesImperialUnits: widget.usesImperialUnits,
                        ),
                      ),
                    ),
                  DiaryPastePreview(
                    day: widget.day,
                    group: widget.addMealType,
                    usesImperialUnits: widget.usesImperialUnits,
                  ),
                  MealSectionActions(
                    day: widget.day,
                    mealType: widget.addMealType,
                  ),
                  // The actions already contribute 4 px, matching the header's 20 px.
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final today = locator<SelectedDayCubit>().state.today;
    final isToday = DateUtils.isSameDay(widget.day, today);
    final hasEntries = widget.intakeList.isNotEmpty;
    final s = S.of(context);
    return Semantics(
      identifier: 'intake-section-menu',
      container: true,
      child: PopupMenuButton<DiaryMealAction>(
        icon: Icon(
          Icons.more_vert_rounded,
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppPalette.dark
                      : AppPalette.light)
                  .textMuted,
        ),
        shape: Dimens.shapeM,
        onSelected: (action) => _onMenuAction(context, action),
        itemBuilder: (_) => [
          if (isToday || hasEntries)
            PopupMenuItem(
              value: DiaryMealAction.copyDay,
              child: Semantics(
                identifier: isToday
                    ? 'diary-copy-from-yesterday'
                    : 'diary-copy-to-today',
                child: Text(
                  isToday
                      ? s.diaryCopyFromYesterdayLabel
                      : s.diaryCopyToTodayLabel,
                ),
              ),
            ),
          if (hasEntries) ...[
            PopupMenuItem(
              value: DiaryMealAction.copyClipboard,
              child: Semantics(
                identifier: 'diary-copy-to-clipboard',
                child: Text(s.diaryCopyToClipboardLabel),
              ),
            ),
            PopupMenuItem(
              value: DiaryMealAction.delete,
              child: Text(s.deleteAllLabel),
            ),
            PopupMenuItem(
              value: DiaryMealAction.share,
              child: Text(s.shareMealLabel),
            ),
          ],
          PopupMenuItem(
            value: DiaryMealAction.import,
            child: Text(s.importMealLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenuAction(
    BuildContext context,
    DiaryMealAction action,
  ) async {
    RecipeSwipeScope.maybeOf(context)?.close();
    final source = snapshotDiaryEntries(widget.intakeList);
    final day = widget.day;
    final group = widget.addMealType;
    final today = locator<SelectedDayCubit>().state.today;
    switch (action) {
      case DiaryMealAction.copyClipboard:
        locator<DiaryClipboardCubit>().copy(source);
      case DiaryMealAction.copyDay:
        final isToday = DateUtils.isSameDay(day, today);
        final yesterday = DateTime(today.year, today.month, today.day - 1);
        await copyDiaryEntries(
          context,
          source,
          today,
          group,
          chooseDestination: true,
          loadSource: isToday
              ? () async {
                  final config = await locator<GetConfigUsecase>().getConfig();
                  return locator<IntakeRepository>().getIntakeByDateAndType(
                    group.getIntakeType(),
                    yesterday,
                    dayStartOffsetHours: config.dayStartOffsetHours,
                    dayStartOffsetMinutes: config.dayStartOffsetMinutes,
                  );
                }
              : null,
        );
      case DiaryMealAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => const DeleteAllDialog(),
        );
        if (confirmed == true) {
          for (final entry in source) {
            widget.onDeleteIntakeCallback(entry, widget.trackedDayEntity);
          }
        }
      case DiaryMealAction.share:
        final code = SharedMealPayload.fromIntakeList(
          source,
          recipeRepository: locator<RecipeRepository>(),
        ).toJsonString();
        final hasOtherProfiles =
            locator<GetProfilesUsecase>().getProfiles().length > 1;
        await showDialog<void>(
          context: context,
          builder: (_) => ShareQrDialog(
            title: S.of(context).shareMealLabel,
            code: code,
            fileBaseName: 'meal_qr',
            onCopyToProfile: hasOtherProfiles
                ? () => showCopyToProfileSheet(context, source)
                : null,
          ),
        );
      case DiaryMealAction.import:
        Navigator.of(context).pushNamed(
          NavigationOptions.importMealScannerRoute,
          arguments: ImportMealScannerArguments(
            group.getIntakeType(),
            group,
            day,
          ),
        );
    }
  }

  Widget _buildSortMenu(BuildContext context) {
    final current = widget.sortType ?? DiarySortType.timeAdded;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return Semantics(
      identifier: 'diary-section-sort-menu',
      child: PopupMenuButton<DiarySortType>(
        tooltip: S.of(context).diarySortByLabel,
        icon: Icon(Icons.sort_rounded, color: palette.textMuted),
        shape: Dimens.shapeM,
        initialValue: current,
        onSelected: (sort) => widget.onSortTypeChanged?.call(sort),
        itemBuilder: (context) => <PopupMenuEntry<DiarySortType>>[
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.timeAdded,
            checked: current == DiarySortType.timeAdded,
            child: Text(S.of(context).diarySortByTime),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.kcal,
            checked: current == DiarySortType.kcal,
            child: Text(S.of(context).diarySortByKcal),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.protein,
            checked: current == DiarySortType.protein,
            child: Text(S.of(context).diarySortByProtein),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.carbs,
            checked: current == DiarySortType.carbs,
            child: Text(S.of(context).diarySortByCarbs),
          ),
          CheckedPopupMenuItem<DiarySortType>(
            value: DiarySortType.fat,
            checked: current == DiarySortType.fat,
            child: Text(S.of(context).diarySortByFat),
          ),
        ],
      ),
    );
  }

  Future<void> _onItemDropped(IntakeEntity entity) async {
    final target = widget.addMealType.getIntakeType();
    if (entity.type == target) return;
    try {
      await locator<UpdateIntakeUsecase>().moveIntakeToType(entity.id, target);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).diaryMoveFailedMessage)),
        );
      }
    }
    // Refresh Home Page
    locator<HomeBloc>().add(const LoadItemsEvent());

    // Refresh Diary Page
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }
}
