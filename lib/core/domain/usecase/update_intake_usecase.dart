import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';

class UpdateIntakeUsecase {
  final IntakeRepository _intakeRepository;

  UpdateIntakeUsecase(this._intakeRepository);

  Future<IntakeEntity?> moveIntakeToType(
    String intakeId,
    IntakeTypeEntity targetType,
  ) => _intakeRepository.moveIntakeToType(intakeId, targetType);

  Future<IntakeEntity?> updateIntake(
    String intakeId,
    Map<String, dynamic> intakeFields,
  ) async {
    return await _intakeRepository.updateIntake(intakeId, intakeFields);
  }
}
