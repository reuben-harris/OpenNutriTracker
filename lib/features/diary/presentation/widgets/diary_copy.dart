import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_copy_cubit.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<void> copyDiaryEntries(
  BuildContext context,
  List<IntakeEntity> entries,
  DateTime day,
  AddMealType group, {
  bool chooseSource = false,
  bool chooseDestination = false,
  Future<List<IntakeEntity>> Function(IntakeTypeEntity)? loadSource,
}) async {
  assert(!chooseSource || !chooseDestination);
  Future<IntakeTypeEntity?> selectMealType(
    CopyDirection direction, {
    Set<IntakeTypeEntity>? availableSources,
  }) async {
    final selected = await showDialog<AddMealType>(
      context: context,
      builder: (_) => CopyDialog(
        initialValue: group,
        direction: direction,
        availableSources: availableSources
            ?.map(AddMealExtension.fromIntakeTypeEntity)
            .toSet(),
      ),
    );
    return selected?.getIntakeType();
  }

  final result = await locator<DiaryCopyCubit>().copy(
    context,
    entries,
    day,
    group.getIntakeType(),
    loadSource: loadSource,
    selectSource: chooseSource
        ? (available) =>
              selectMealType(CopyDirection.from, availableSources: available)
        : null,
    selectDestination: chooseDestination
        ? () => selectMealType(CopyDirection.to)
        : null,
  );
  if (!context.mounted) return;
  final s = S.of(context);
  final message = switch (result) {
    DiaryCopyResult.failed => s.diaryCopyFailedMessage,
    DiaryCopyResult.empty => s.diaryYesterdayEmptyMessage(
      group.getTypeName(context),
    ),
    DiaryCopyResult.busy => s.diaryCopyBusyMessage,
    _ => null,
  };
  if (message != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
