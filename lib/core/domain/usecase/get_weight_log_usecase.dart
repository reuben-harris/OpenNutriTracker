import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';

class GetWeightLogUsecase {
  final WeightLogRepository _weightLogRepository;

  GetWeightLogUsecase(this._weightLogRepository);

  Future<WeightLogEntity?> latestOnOrBefore(DateTime day) async {
    final entries = await getAllEntries();
    final end = DateTime(day.year, day.month, day.day + 1);
    final eligible = entries.where((e) => e.date.isBefore(end)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return eligible.isEmpty ? null : eligible.first;
  }

  Future<List<WeightLogEntity>> getAllEntries() async {
    return _weightLogRepository.getAllEntries();
  }

  Future<List<WeightLogEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async {
    return _weightLogRepository.getEntriesInRange(from, to);
  }
}
