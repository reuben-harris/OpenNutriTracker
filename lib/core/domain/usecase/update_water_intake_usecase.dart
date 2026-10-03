import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';

class UpdateWaterIntakeUsecase {
  final WaterIntakeRepository _repository;
  UpdateWaterIntakeUsecase(this._repository);

  Future<void> updateAmount(WaterIntakeEntity entry, int amountMl) async {
    if (amountMl <= 0) throw ArgumentError.value(amountMl, 'amountMl');
    await _repository.addEntry(
      WaterIntakeEntity(
        id: entry.id,
        dateTime: entry.dateTime,
        amountMl: amountMl,
      ),
    );
  }
}
