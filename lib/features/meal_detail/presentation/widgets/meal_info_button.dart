import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class MealInfoButton extends StatelessWidget {
  final MealEntity meal;
  final VoidCallback onCustom;
  const MealInfoButton({super.key, required this.meal, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    if (meal.source == MealSourceEntity.recipe) return const SizedBox.shrink();
    final s = S.of(context);
    final label = switch (meal.source) {
      MealSourceEntity.unknown => s.additionalInfoLabelUnknown,
      MealSourceEntity.custom => s.additionalInfoLabelCustom,
      MealSourceEntity.off => s.additionalInfoLabelOFF,
      MealSourceEntity.catalogue => s.additionalInfoLabelCatalogue(
        meal.catalogueSourceName ?? s.foodSourceCatalogueLabel,
      ),
      MealSourceEntity.recipe => s.additionalInfoLabelRecipe,
    };
    if (meal.source == MealSourceEntity.unknown) return Text(label);
    return Semantics(
      identifier: 'meal-detail-information',
      child: TextButton.icon(
        onPressed: switch (meal.source) {
          MealSourceEntity.recipe => null,
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
    if (!valid && meal.source == MealSourceEntity.catalogue) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SourcesScreen()));
      return;
    }
    final uri = valid ? supplied : Uri.parse(OFFConst.offWebsiteUrl);
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
