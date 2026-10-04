import 'package:equatable/equatable.dart';

class MealPortionEntity extends Equatable {
  const MealPortionEntity({
    required this.label,
    required this.gramWeight,
    required this.localized,
    this.englishLabel,
  });

  /// As published, count and all — "1 cup", "1 Tasse", "1 cup, cooked".
  final String label;

  final String? englishLabel;

  final double gramWeight;

  /// True when [label] came from a translation a human verified.
  final bool localized;

  @override
  List<Object?> get props => [label, gramWeight, localized, englishLabel];
}
