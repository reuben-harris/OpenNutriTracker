import 'package:opennutritracker/core/domain/usecase/refresh_diary_intake_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/presentation/bloc/selected_day_cubit.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/recipe_swipe_scope.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Entry swipes reveal Info on the right and Refresh on the left.
class ExplodableIntakeRow extends StatefulWidget {
  final IntakeEntity intake;
  final bool usesImperialUnits;
  final Function(BuildContext, IntakeEntity)? onItemLongPressed;
  final Function(BuildContext, IntakeEntity, bool)? onItemTapped;
  final VoidCallback? onLeftSwipe;

  const ExplodableIntakeRow({
    super.key,
    required this.intake,
    required this.usesImperialUnits,
    this.onItemLongPressed,
    this.onItemTapped,
    this.onLeftSwipe,
  });

  @override
  State<ExplodableIntakeRow> createState() => _ExplodableIntakeRowState();
}

class _ExplodableIntakeRowState extends State<ExplodableIntakeRow>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 104.0;
  // The recognizer consumes touch slop before updates begin. A short deliberate
  // right swipe should still leave Info revealed when the finger is lifted.
  static const _infoRevealThreshold = 32.0;
  late final AnimationController _slide;
  RecipeSwipeController? _group;
  bool _busy = false;

  double _startOffset = 0;
  bool get _isRecipe => widget.intake.meal.source == MealSourceEntity.recipe;

  double get _offset => _slide.value;

  void _onSlide() => setState(() {});

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      lowerBound: -_actionWidth,
      upperBound: _actionWidth,
      value: 0,
      duration: const Duration(milliseconds: 200),
    )..addListener(_onSlide);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = RecipeSwipeScope.maybeOf(context);
    if (group != _group) {
      _group?.release(_close);
      _group = group;
      _slide.value = 0;
    }
  }

  @override
  void didUpdateWidget(ExplodableIntakeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intake.id != widget.intake.id ||
        oldWidget.intake.dateTime != widget.intake.dateTime ||
        oldWidget.intake.meal.source != widget.intake.meal.source) {
      _group?.release(_close);
      _slide.value = 0;
    }
  }

  @override
  void dispose() {
    _group?.release(_close);
    _slide.dispose();
    super.dispose();
  }

  void _settle(double target) {
    if (target == 0) _group?.release(_close);
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = target;
    } else {
      _slide.animateTo(target, curve: Curves.easeOut);
    }
  }

  void _close() {
    if (_offset != 0 || _slide.isAnimating) _settle(0);
  }

  @override
  Widget build(BuildContext context) {
    final card = IntakeCard(
      key: ValueKey('card-${widget.intake.id}'),
      intake: widget.intake,
      isRefreshing: _busy,
      onItemLongPressed: widget.onItemLongPressed,
      onItemTapped: (context, intake, imperial) {
        if (_offset != 0) {
          _close();
        } else {
          if (intake.meal.isQuickAdd) {
            _openQuickAdd();
          } else {
            widget.onItemTapped?.call(context, intake, imperial);
          }
        }
      },
      firstListElement: false,
      usesImperialUnits: widget.usesImperialUnits,
    );

    final color = Theme.of(context).colorScheme.primary;
    final actionEnabled = _offset == -_actionWidth && !_slide.isAnimating;
    return TapRegion(
      onTapOutside: (_) => _close(),
      child: Semantics(
        identifier: 'diary-intake-swipe',
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _busy
              ? null
              : (_) {
                  _startOffset = _offset;
                  _slide.stop();
                  _group?.open(_close);
                },
          onHorizontalDragUpdate: _busy
              ? null
              : (details) {
                  _slide.value = (_offset + details.delta.dx).clamp(
                    -_actionWidth,
                    _actionWidth,
                  );
                },
          onHorizontalDragEnd: _busy
              ? null
              : (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (_startOffset != 0 && velocity * _startOffset < 0) {
                    _settle(0);
                  } else if (velocity > 250 ||
                      (velocity >= -250 && _offset >= _infoRevealThreshold)) {
                    _settle(_actionWidth);
                  } else if ((velocity < -250 ||
                      (velocity <= 250 && _offset < -_actionWidth / 2))) {
                    _settle(-_actionWidth);
                  } else {
                    _settle(0);
                  }
                },
          onHorizontalDragCancel: _busy ? null : _close,
          child: ClipRect(
            child: Stack(
              children: [
                if (_offset <= 0)
                  Positioned(
                    right: Dimens.spacing16,
                    top: Dimens.spacing4,
                    bottom: Dimens.spacing4,
                    child: SizedBox(
                      width: _actionWidth,
                      child: IgnorePointer(
                        ignoring: !actionEnabled || _busy,
                        child: ExcludeSemantics(
                          excluding: !actionEnabled,
                          child: Semantics(
                            identifier: 'diary-intake-refresh',
                            child: Material(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                Dimens.radiusM,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  Dimens.radiusM,
                                ),
                                onTap: _busy ? null : _onRefresh,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      S.of(context).diaryRefreshLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_offset >= 0)
                  Positioned(
                    left: Dimens.spacing16,
                    top: Dimens.spacing4,
                    bottom: Dimens.spacing4,
                    child: SizedBox(
                      width: _actionWidth,
                      child: IgnorePointer(
                        ignoring:
                            _offset != _actionWidth ||
                            _slide.isAnimating ||
                            _busy,
                        child: ExcludeSemantics(
                          excluding:
                              _offset != _actionWidth || _slide.isAnimating,
                          child: Semantics(
                            identifier: 'diary-intake-info',
                            child: Material(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                Dimens.radiusM,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  Dimens.radiusM,
                                ),
                                onTap: _onInfo,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      S.of(context).diaryInfoLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Transform.translate(offset: Offset(_offset, 0), child: card),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onInfo() {
    _close();
    final intake = widget.intake;
    if (_isRecipe) {
      final recipeId = intake.meal.code;
      if (recipeId == null ||
          locator<RecipeRepository>().getRecipeById(recipeId) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).diaryRecipeUnavailableMessage)),
        );
        return;
      }
      Navigator.of(context).pushNamed(
        NavigationOptions.recipeDetailRoute,
        arguments: RecipeDetailArguments(recipeId: recipeId),
      );
    } else {
      Navigator.of(context).pushNamed(
        NavigationOptions.mealDetailRoute,
        arguments: MealDetailScreenArguments(
          intake.meal,
          intake.type,
          locator<SelectedDayCubit>().state.day,
          widget.usesImperialUnits,
        ),
      );
    }
  }

  void _openQuickAdd() {
    _close();
    final intake = widget.intake;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddBottomSheet(
        intakeType: intake.type,
        day: intake.dateTime,
        editingIntake: intake,
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_busy) return;
    if (widget.intake.meal.isQuickAdd) {
      _openQuickAdd();
      return;
    }
    _close();
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        locator<RefreshDiaryIntakeUsecase>().refresh(widget.intake.id),
        Future<IntakeEntity?>.delayed(
          const Duration(milliseconds: 500),
          () => null,
        ),
      ]);
      final updated = results.first;
      if (updated == null) return;
      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).diaryRefreshSuccess)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is DiarySourceUnavailable
                  ? S.of(context).diaryRefreshUnavailable
                  : S.of(context).diaryRefreshFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
