import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';

/// Detached snapshots: later quantity, food and recipe edits cannot change them.
List<IntakeEntity> snapshotDiaryEntries(Iterable<IntakeEntity> entries) =>
    List.unmodifiable(
      entries.map(
        (entry) => IntakeEntity.fromIntakeDBO(
          IntakeDBO.fromJson(
            jsonDecode(jsonEncode(IntakeDBO.fromIntakeEntity(entry).toJson()))
                as Map<String, dynamic>,
          ),
        ),
      ),
    );

/// Session-only clipboard. Each copy replaces it; pasting leaves it available.
class DiaryClipboardCubit extends Cubit<List<IntakeEntity>> {
  DiaryClipboardCubit() : super(const []);

  void copy(Iterable<IntakeEntity> entries) =>
      emit(snapshotDiaryEntries(entries));

  void clear() => emit(const []);
}
