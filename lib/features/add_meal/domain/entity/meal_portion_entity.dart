import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/meal_portion_dbo.dart';

class MealPortionEntity extends Equatable {
  const MealPortionEntity({
    required this.id,
    required this.label,
    required this.gramWeight,
    required this.localized,
    this.englishLabel,
  });

  /// Dataset and source row ID, independent of weight and presentation.
  final String id;

  /// As published, count and all — "1 cup", "1 Tasse", "1 cup, cooked".
  final String label;

  final String? englishLabel;

  final double gramWeight;

  /// True when [label] came from a translation a human verified.
  final bool localized;

  factory MealPortionEntity.fromDBO(MealPortionDBO portion) =>
      MealPortionEntity(
        id: portion.id,
        label: portion.label,
        englishLabel: portion.englishLabel,
        gramWeight: portion.gramWeight,
        localized: portion.localized,
      );

  @override
  List<Object?> get props => [id, label, gramWeight, localized, englishLabel];
}
