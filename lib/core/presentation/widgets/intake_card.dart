import 'package:opennutritracker/core/presentation/widgets/food_amount_card.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';

/// A logged intake, rendered as a full-width row: a rounded thumbnail, the meal
/// name and amount, and the energy on the trailing edge. Replaces the old
/// 120x120 tile so a day's meals read as a clean scannable list.
class IntakeCard extends StatelessWidget {
  final IntakeEntity intake;
  final Function(BuildContext, IntakeEntity)? onItemLongPressed;
  final Function(BuildContext, IntakeEntity, bool)? onItemTapped;
  final bool usesImperialUnits;
  final bool isRefreshing;

  const IntakeCard({
    required super.key,
    required this.intake,
    this.onItemLongPressed,
    this.onItemTapped,
    required this.usesImperialUnits,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) => FoodAmountCard(
    meal: intake.meal,
    quantity: intake.quantity,
    usesImperialUnits: usesImperialUnits,
    isRefreshing: isRefreshing,
    isIncomplete: intake.isIncomplete,
    onTap: onItemTapped == null
        ? null
        : () => onTappedItem(context, usesImperialUnits),
    onLongPress: onItemLongPressed == null
        ? null
        : () => onLongPressedItem(context),
  );

  void onLongPressedItem(BuildContext context) {
    onItemLongPressed?.call(context, intake);
  }

  void onTappedItem(BuildContext context, bool usesImperialUnits) {
    onItemTapped?.call(context, intake, usesImperialUnits);
  }
}
