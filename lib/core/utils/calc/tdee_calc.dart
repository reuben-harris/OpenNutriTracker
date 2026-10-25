import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/utils/calc/pal_calc.dart';

class TDEECalc {
  /// Returns the total daily energy expenditure (TDEE) of given userEntity
  /// based on 2005 IOM equation
  ///
  /// Institute of Medicine. 2005. Dietary Reference Intakes for Energy,
  /// Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein,
  /// and Amino Acids. (p.204)
  /// Washington, DC: The National Academies Press.
  /// https://doi.org/10.17226/10490.
  /// https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids
  ///
  static double getTDEEKcalIOM2005(UserEntity userEntity) {
    final palValue = PalCalc.getPALValueFromActivityCategory(userEntity);
    switch (userEntity.sex) {
      case UserSexEntity.male:
        return _iom2005MaleReferenceKcal(userEntity, palValue);
      case UserSexEntity.female:
        return _iom2005FemaleReferenceKcal(userEntity, palValue);
    }
  }

  /// Male reference result for the calorie calculation.
  ///
  /// p. 204, verbatim:
  ///   TEE = 864 - (9.72 x age [y]) + PA x (14.2 x weight [kg]
  ///         + 503 x height [m])
  ///
  /// PA multiplies the weight *and* the height term. Dropping the brackets
  /// costs a non-sedentary user 109-489 kcal/day (#987); the brackets are the
  /// whole content of this expression, so keep them. The published-value tests
  /// verify the grouping against the source tables.
  static double _iom2005MaleReferenceKcal(
    UserEntity userEntity,
    double palValue,
  ) {
    final paValue = PalCalc.getPAValueForFormula(
      palValue: palValue,
      isMaleFormula: true,
    );
    return 864 -
        9.72 * userEntity.age +
        paValue *
            (14.2 * userEntity.weightKG + 503 * (userEntity.heightCM / 100));
  }

  /// Female reference result for a given PAL value. See
  /// [_iom2005MaleReferenceKcal] for the bracket placement.
  ///
  /// p. 204, verbatim:
  ///   TEE = 387 - (7.31 x age [y]) + PA x (10.9 x weight [kg]
  ///         + 660.7 x height [m])
  static double _iom2005FemaleReferenceKcal(
    UserEntity userEntity,
    double palValue,
  ) {
    final paValue = PalCalc.getPAValueForFormula(
      palValue: palValue,
      isMaleFormula: false,
    );
    return 387 -
        7.31 * userEntity.age +
        paValue *
            (10.9 * userEntity.weightKG + 660.7 * (userEntity.heightCM / 100));
  }
}
