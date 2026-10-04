import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_clipboard_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_copy_cubit.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_copy.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_transfer_style.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DiaryPastePreview extends StatelessWidget {
  final DateTime day;
  final AddMealType group;
  final bool usesImperialUnits;
  const DiaryPastePreview({
    super.key,
    required this.day,
    required this.group,
    required this.usesImperialUnits,
  });

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DiaryClipboardCubit, List<IntakeEntity>>(
    bloc: locator<DiaryClipboardCubit>(),
    builder: (context, entries) {
      if (entries.isEmpty) return const SizedBox.shrink();
      final first = entries.first;
      final multiple = entries.length > 1;
      final s = S.of(context);
      final palette = Theme.of(context).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
      return BlocBuilder<DiaryCopyCubit, bool>(
        bloc: locator<DiaryCopyCubit>(),
        builder: (context, busy) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Semantics(
            identifier: 'diary-${group.getIntakeType().name}-paste',
            label: s.diaryPasteLabel(group.getTypeName(context)),
            child: CustomPaint(
              foregroundPainter: const DiaryDottedBorder(diaryCopyColor),
              child: Material(
                color: diaryCopyColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: busy
                      ? null
                      : () => copyDiaryEntries(context, entries, day, group),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (multiple)
                          const SizedBox.square(
                            dimension: IntakeCard.thumbSize,
                            child: Icon(
                              Icons.collections_rounded,
                              color: diaryCopyColor,
                              size: 28,
                            ),
                          )
                        else
                          Opacity(
                            opacity: 0.45,
                            child: IntakeThumbnail(
                              intake: first,
                              palette: palette,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: multiple
                              ? Text(
                                  s.diaryClipboardCountLabel(entries.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(color: palette.textMuted),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      first.meal.name ?? '?',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(color: palette.textMuted),
                                    ),
                                    MealValueUnitText(
                                      value: first.amount,
                                      meal: first.meal,
                                      usesImperialUnits: usesImperialUnits,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: palette.textMuted),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _nutritionSummary(context, entries, palette),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _nutritionSummary(
    BuildContext context,
    List<IntakeEntity> entries,
    AppPalette palette,
  ) {
    final totals = entries.fold(
      (kcal: 0.0, carbs: 0.0, fat: 0.0, protein: 0.0),
      (sum, entry) => (
        kcal: sum.kcal + entry.totalKcal,
        carbs: sum.carbs + entry.totalCarbsGram,
        fat: sum.fat + entry.totalFatsGram,
        protein: sum.protein + entry.totalProteinsGram,
      ),
    );
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AutoSizeText(
          EnergyDisplay.formatWithUnit(context, totals.kcal),
          maxLines: 1,
          minFontSize: 8,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: palette.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        AutoSizeText(
          '${totals.carbs.toStringAsFixed(0)} ${s.carbsLabelShort} '
          '${totals.fat.toStringAsFixed(0)} ${s.fatLabelShort} '
          '${totals.protein.toStringAsFixed(0)} ${s.proteinLabelShort}',
          maxLines: 1,
          minFontSize: 8,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}
