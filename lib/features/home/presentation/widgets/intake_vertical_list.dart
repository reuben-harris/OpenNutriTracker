import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/create_recipe_from_diary.dart';
import 'package:opennutritracker/core/presentation/widgets/food_section_header.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_copy.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_paste_preview.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_transfer_style.dart';
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
import 'package:opennutritracker/features/home/presentation/widgets/diary_intake_row.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';
import 'package:opennutritracker/features/home/presentation/screens/import_meal_scanner_screen.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum DiaryMealAction {
  copyDay,
  copyClipboard,
  createRecipe,
  delete,
  share,
  import,
}

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
  bool _creatingRecipe = false;
  NutrientPanelTotals get totals =>
      NutrientPanelTotals.fromIntakes(widget.intakeList);
  bool get hasQualifications => [
    totals.energyKcal,
    totals.carbsG,
    totals.fatG,
    totals.proteinG,
  ].any((a) => a?.isQualified ?? false);

  // #150: only show a header when we have something to say — either some
  // food was logged, or a recommended target exists so the section can read
  // "0 / 600 kcal" before anything is logged.
  bool get _hasMealKcalTarget =>
      widget.mealKcalTarget != null && widget.mealKcalTarget! > 0;

  bool get _shouldShowHeaderSummary =>
      widget.intakeList.isNotEmpty || _hasMealKcalTarget;

  String _buildHeaderSummary(BuildContext context) {
    final n = totals;
    final energy = widget.intakeList.isEmpty
        ? const NutrientAmount(0)
        : n.energyKcal;
    final consumed = formatNutrientAmount(
      EnergyDisplay.convertAmount(context, energy),
      S.of(context),
      decimals: 0,
    );
    final kcalLine = _hasMealKcalTarget
        ? S
              .of(context)
              .diaryMealKcalConsumedOfTarget(
                consumed,
                EnergyDisplay.formatValue(context, widget.mealKcalTarget!),
              )
        : EnergyDisplay.formatAmount(context, energy);
    if (widget.showMealMacros && widget.intakeList.isNotEmpty) {
      return '$kcalLine\n'
          '${formatNutrientAmount(n.carbsG, S.of(context), decimals: 0)} ${S.of(context).carbsLabelShort}  '
          '${formatNutrientAmount(n.fatG, S.of(context), decimals: 0)} ${S.of(context).fatLabelShort}  '
          '${formatNutrientAmount(n.proteinG, S.of(context), decimals: 0)} ${S.of(context).proteinLabelShort}';
    }
    return kcalLine;
  }

  @override
  Widget build(BuildContext context) {
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
                  FoodSectionHeader(
                    title: widget.title,
                    icon: widget.listIcon,
                    summary: _shouldShowHeaderSummary
                        ? _buildHeaderSummary(context)
                        : null,
                    summarySemantics: hasQualifications
                        ? '${_buildHeaderSummary(context)}. ${S.of(context).nutrientQualifiedTotalLabel}'
                        : null,
                    actions: [
                      if (widget.onSortTypeChanged != null &&
                          widget.intakeList.isNotEmpty)
                        FoodSectionSortMenu(
                          identifier: 'diary-section-sort-menu',
                          value: widget.sortType ?? DiarySortType.timeAdded,
                          onChanged: widget.onSortTypeChanged!,
                        ),
                      _buildMenu(context),
                    ],
                  ),

                  for (final entry in widget.intakeList)
                    Semantics(
                      key: ValueKey(entry.id),
                      identifier: 'diary-intake-${entry.id}',
                      label: entry.meal.name ?? '?',
                      child: LongPressDraggable<IntakeEntity>(
                        data: entry,
                        onDragStarted: () {
                          SwipeRevealScope.maybeOf(context)?.close();
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
                              usesImperialUnits: widget.usesImperialUnits,
                            ),
                          ),
                        ),
                        child: DiaryIntakeRow(
                          key: ValueKey(entry.id),
                          intake: entry,
                          onDelete: () => widget.onDeleteIntakeCallback(
                            entry,
                            widget.trackedDayEntity,
                          ),
                          onItemTapped: widget.onItemTappedCallback,
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
                    usesImperialUnits: widget.usesImperialUnits,
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
              value: DiaryMealAction.createRecipe,
              child: Semantics(
                identifier: 'diary-create-recipe',
                child: Text(s.createRecipeTitle),
              ),
            ),
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
    SwipeRevealScope.maybeOf(context)?.close();
    final source = snapshotDiaryEntries(widget.intakeList);
    final day = widget.day;
    final group = widget.addMealType;
    final today = locator<SelectedDayCubit>().state.today;
    switch (action) {
      case DiaryMealAction.createRecipe:
        if (_creatingRecipe) return;
        _creatingRecipe = true;
        try {
          await createRecipeFromDiary(
            context,
            groupName: widget.title,
            entries: source,
          );
        } finally {
          _creatingRecipe = false;
        }
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
          chooseSource: isToday,
          chooseDestination: !isToday,
          loadSource: isToday
              ? (sourceType) async {
                  final config = await locator<GetConfigUsecase>().getConfig();
                  return locator<IntakeRepository>().getIntakeByDateAndType(
                    sourceType,
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
