import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/utils/calc/dri_reference.dart';

class DailyNutrientReferences {
  DailyNutrientReferences._();

  /// Adult RDA/AI references, not tolerable upper intake levels.
  /// https://ods.od.nih.gov/healthinformation/nutrientrecommendations.aspx
  /// Values use the registry's exact nutrient basis (RAE, DFE, alpha-tocopherol).
  /// Niacin is preformed niacin, not niacin equivalents; omega totals and K1
  /// are not silently treated as ALA/LA or total vitamin K.
  static Map<String, NutrientGoal> resolve({
    TrackedDayEntity? trackedDay,
    UserEntity? user,
  }) {
    final female = user?.sex == UserSexEntity.female;
    final age = user?.age ?? 30;
    double sex(double male, double femaleAmount) => user == null
        ? (male + femaleAmount) / 2
        : female
        ? femaleAmount
        : male;
    final amounts = <String, double>{
      NutrientKeys.fiber: 30,
      NutrientKeys.sodium: 2300,
      NutrientKeys.saturatedFat: 20,
      NutrientKeys.addedSugars: 50,
      NutrientKeys.calcium: 1000,
      NutrientKeys.iron: sex(8, 18),
      NutrientKeys.potassium: sex(3400, 2600),
      NutrientKeys.magnesium: sex(400, 310),
      NutrientKeys.vitaminD: 15,
      NutrientKeys.vitaminB12: 2.4,
      NutrientKeys.vitaminA: sex(900, 700),
      NutrientKeys.vitaminC: sex(90, 75),
      NutrientKeys.vitaminB6: age > 50 ? sex(1.7, 1.5) : 1.3,
      NutrientKeys.zinc: sex(11, 8),
      NutrientKeys.phosphorus: 700,
      NutrientKeys.thiamin: sex(1.2, 1.1),
      NutrientKeys.riboflavin: sex(1.3, 1.1),
      NutrientKeys.pantothenicAcid: 5,
      NutrientKeys.biotin: 30,
      NutrientKeys.folateDfe: 400,
      NutrientKeys.vitaminE: 15,
      NutrientKeys.copper: 0.9,
      NutrientKeys.manganese: sex(2.3, 1.8),
      NutrientKeys.selenium: 55,
      NutrientKeys.iodine: 150,
      NutrientKeys.choline: sex(550, 425),
      NutrientKeys.alphaLinolenicAcid: sex(1.6, 1.1),
      NutrientKeys.linoleicAcid: age > 50 ? sex(14, 11) : sex(17, 12),
    };
    if (user != null) {
      for (final nutrient in Nutrients.additional) {
        final dri = getReferenceFor(nutrient: nutrient.key, user: user);
        if (dri != null) amounts[nutrient.key] = dri.amount;
      }
    }
    return {
      for (final entry in amounts.entries)
        entry.key: NutrientGoal(
          entry.value,
          isLimit:
              Nutrients.byKey[entry.key]!.goalKind == NutrientGoalKind.limit,
        ),
      ...?trackedDay?.nutrientGoals,
    };
  }
}
