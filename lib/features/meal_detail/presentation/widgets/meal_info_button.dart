import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class MealInfoButton extends StatelessWidget {
  final MealEntity meal;
  final VoidCallback onRecipe, onCustom;
  const MealInfoButton({
    super.key,
    required this.meal,
    required this.onRecipe,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = switch (meal.source) {
      MealSourceEntity.unknown => s.additionalInfoLabelUnknown,
      MealSourceEntity.custom => s.additionalInfoLabelCustom,
      MealSourceEntity.off => s.additionalInfoLabelOFF,
      MealSourceEntity.fdc => s.additionalInfoLabelFDC,
      MealSourceEntity.recipe => s.additionalInfoLabelRecipe,
    };
    if (meal.source == MealSourceEntity.unknown) return Text(label);
    return Semantics(
      identifier: 'meal-detail-information',
      child: TextButton.icon(
        onPressed: switch (meal.source) {
          MealSourceEntity.recipe => onRecipe,
          MealSourceEntity.custom => onCustom,
          _ => () => _launch(context),
        },
        icon: Icon(
          meal.source == MealSourceEntity.custom
              ? Icons.edit_rounded
              : Icons.open_in_new_rounded,
        ),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Future<void> _launch(BuildContext context) async {
    final supplied = Uri.tryParse(meal.url?.trim() ?? '');
    final valid =
        supplied != null &&
        (supplied.scheme == 'http' || supplied.scheme == 'https') &&
        supplied.host.isNotEmpty;
    final uri = valid
        ? supplied
        : Uri.parse(
            meal.source == MealSourceEntity.off
                ? OFFConst.offWebsiteUrl
                : FDCConst.fdcWebsiteUrl,
          );
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Display the same localized failure for platform errors. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).foodSourceLaunchFailedLabel)),
      );
    }
  }
}
