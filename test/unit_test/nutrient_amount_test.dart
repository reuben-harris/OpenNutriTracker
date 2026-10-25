import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_totals.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/core/utils/nutrient_amount_formatter.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_nutriments_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/home/domain/entity/shared_meal_payload.dart';
import 'package:opennutritracker/features/recipes/domain/entity/shared_recipe_payload.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

const trace = NutrientAmount(0, qualification: NutrientQualification.trace);
MealEntity meal(NutrientAmount amount) => MealEntity(
  code: 'qualified',
  name: 'Qualified food',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: null,
  servingSize: null,
  source: MealSourceEntity.custom,
  nutriments: MealNutrimentsEntity(
    energyKcal100: amount,
    carbohydrates100: amount,
    fat100: amount,
    proteins100: amount,
    sugars100: amount,
    saturatedFat100: amount,
    fiber100: amount,
    vitaminB12100: amount,
  ),
);
IntakeEntity intake(NutrientAmount amount) => IntakeEntity(
  id: 'intake',
  meal: meal(amount),
  type: IntakeTypeEntity.breakfast,
  dateTime: DateTime(2026),
  quantity: FoodAmountSelection(
    100,
    FoodAmountOption.standard(FoodAmountUnit.g),
  ),
);

void main() {
  final s = lookupS(const Locale('en'));
  test('OFF numbers, modifiers, missing and small measurements differ', () {
    final n = MealNutrimentsEntity.fromOffNutriments(
      OFFProductNutrimentsDTO.fromJson({
        'fat_100g': 0,
        'fat_modifier': '~',
        'carbohydrates_100g': 0.5,
        'carbohydrates_modifier': '<',
        'proteins_100g': 0,
        'proteins_modifier': 'trace',
        'vitamin-b12_100g': 1e-9,
      }),
    );
    expect(formatNutrientAmount(n.fat100, s), '≈0*');
    expect(n.carbohydrates100!.qualification, NutrientQualification.lessThan);
    expect(n.proteins100, trace);
    expect(n.energyKcal100, isNull);
    expect(formatNutrientAmount(n.vitaminB12100, s, unit: 'µg'), '0.001 µg');
    expect(NutrientAmount.fromSource(null, modifier: '~'), isNull);
    expect(formatNutrientAmount(const NutrientAmount(0), s), '0.00');
  });
  test('partial coverage is retained without adding display wording', () {
    const amount = NutrientAmount(1.25, isPartial: true);
    expect(formatNutrientAmount(amount, s, unit: 'g'), '1.25 g');
    expect(formatNutrientPercentage(amount, 2.5), '50%');
    expect(amount.isPartial, isTrue);
    expect(
      formatNutrientAmount(
        const NutrientAmount(
          1.25,
          qualification: NutrientQualification.approximate,
          isPartial: true,
        ),
        s,
        unit: 'g',
      ),
      '≈1.25 g*',
    );
  });
  test('OFF amino acids retain normalized grams, zero and qualifications', () {
    final n = MealNutrimentsEntity.fromOffNutriments(
      OFFProductNutrimentsDTO.fromJson({
        'proteins_100g': 20,
        'l-leucine_100g': '0.0012300',
        'l-leucine_unit': 'mg',
        'l-leucine_modifier': '<',
        'l-cysteine_100g': 0,
        'l-glutamine_100g': 1.25,
      }),
    );
    expect(n.leucine100!.value, 0.00123);
    expect(n.leucine100!.qualification, NutrientQualification.lessThan);
    expect(n.cysteine100, const NutrientAmount(0));
    expect(n.cystine100, isNull);
    expect(n.histidine100, isNull);
    expect(n.glutamine100, const NutrientAmount(1.25));
    expect(n.proteins100, const NutrientAmount(20));
  });
  test(
    'scaling retains contribution and separate limit; unknown limits stay distinct',
    () {
      const amount = NutrientAmount(
        0.25,
        qualification: NutrientQualification.lessThan,
        limit: 0.5,
      );
      final scaled = amount.scale(0.3);
      expect(scaled.value, 0.075);
      expect(scaled.limit, 0.15);
      expect(scaled.qualification, amount.qualification);
      expect(formatNutrientPercentage(scaled, 1), '8%*');
      for (final q in [
        NutrientQualification.belowDetection,
        NutrientQualification.belowQuantification,
        NutrientQualification.belowDetectionOrQuantification,
      ]) {
        expect(
          formatNutrientAmount(NutrientAmount(0, qualification: q), s),
          contains('limit'),
        );
      }
    },
  );
  test(
    'totals preserve trace only, numeric plus trace, and mixed qualifications',
    () {
      NutrientAmount sum(List<NutrientAmount> amounts) {
        final acc = NutrientAccumulator();
        for (final a in amounts) {
          acc.add(a);
        }
        return acc.total!;
      }

      expect(sum([trace, const NutrientAmount(0)]), trace);
      final total = sum([const NutrientAmount(2), trace]);
      expect(formatNutrientAmount(total, s, unit: 'µg'), '2 µg*');
      final bounded = sum([
        const NutrientAmount(1),
        NutrientAmount.fromSource('<0.5')!,
      ]);
      expect(bounded.value, 1.5);
      expect(bounded.qualification, NutrientQualification.aggregate);
      expect(
        sum([bounded, trace]).scale(0.5).qualification,
        NutrientQualification.aggregate,
      );
      expect((NutrientAccumulator()..add(null)).total, isNull);
    },
  );
  test(
    'recipe normalization, nesting and daily averaging retain qualification',
    () {
      final compute = ComputeRecipeNutritionUseCase();
      RecipeIngredientEntity ingredient(MealEntity m) => RecipeIngredientEntity(
        snapshotMeal: m,
        quantity: FoodAmountSelection(
          100,
          FoodAmountOption.standard(FoodAmountUnit.g),
        ),
      );
      final first = compute.compute([
        ingredient(meal(trace)),
        ingredient(meal(const NutrientAmount(2))),
      ], cookedWeightG: 100);
      expect(first.perHundredG.vitaminB12100!.value, 2);
      expect(
        first.perHundredG.vitaminB12100!.qualification,
        NutrientQualification.aggregate,
      );
      final nested = compute.compute([
        ingredient(meal(first.perHundredG.vitaminB12100!)),
      ]);
      expect(nested.perHundredG.vitaminB12100!.isQualified, isTrue);
      final daily = NutrientTotals.fromIntakes([
        intake(trace),
        intake(const NutrientAmount(2)),
      ], weekly: true);
      expect(daily.amounts['vitaminB12100']?.value, closeTo(2 / 7, 1e-12));
      expect(daily.amounts['vitaminB12100']?.isQualified, isTrue);
    },
  );
  test(
    'Hive, backups, copying, CSV and QR retain precision and qualification',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'qualified-nutrients-',
      );
      Hive.init(directory.path);
      Hive.registerAdapters();
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      const amount = NutrientAmount(
        0.00000123456789,
        qualification: NutrientQualification.lessThan,
        limit: 0.00000234567891,
      );
      final original = IntakeDBO.fromIntakeEntity(intake(amount));
      final box = await Hive.openBox<IntakeDBO>('qualified');
      await box.put('entry', original);
      await box.close();
      final reopened = await Hive.openBox<IntakeDBO>('qualified');
      expect(reopened.get('entry')!.meal.nutriments.vitaminB12100, amount);
      final json = IntakeDBO.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      final csv = CsvDataExporter.parseIntakesFromCsv(
        CsvDataExporter.intakesToCsv([original]),
      ).single;
      for (final restored in [json, csv]) {
        final copied = IntakeDBO.fromIntakeEntity(
          IntakeEntity.fromIntakeDBO(restored),
        );
        expect(copied.meal.nutriments.vitaminB12100, amount);
      }
      final shared = SharedMealItem.fromIntakeEntity(intake(amount));
      expect(
        SharedMealItem.fromArray(
          jsonDecode(jsonEncode(shared.toArray())) as List,
        ).energyKcal100,
        amount,
      );
      final ingredient = SharedRecipeIngredient.fromIngredient(
        RecipeIngredientEntity(
          snapshotMeal: meal(amount),
          quantity: FoodAmountSelection(
            100,
            FoodAmountOption.standard(FoodAmountUnit.g),
          ),
        ),
      );
      expect(
        SharedRecipeIngredient.fromArray(
          jsonDecode(jsonEncode(ingredient.toArray())) as List,
        ).energyKcal100,
        amount,
      );
    },
  );
  test('cache refresh replaces complete nutrient objects', () {
    final merged = mergeFoodPayloads(
      {
        'nutriments': {
          'fat100': trace.toJson(),
          'vitaminB12100': trace.toJson(),
        },
      },
      {
        'nutriments': {
          'fat100': const NutrientAmount(1).toJson(),
          'vitaminB12100': null,
        },
      },
    );
    final n = MealNutrimentsDBO.fromJson(
      merged['nutriments'] as Map<String, dynamic>,
    );
    expect(n.fat100!.isQualified, isFalse);
    expect(n.vitaminB12100, trace);
  });
  test('plausibility checks skip qualified bounds', () {
    final n = MealNutrimentsEntity.fromCatalogue({
      'carbohydrates100': '1',
      'sugars100': {'value': '30', 'qualification': 'lessThan', 'limit': null},
    });
    expect(isNutrimentsConsistent(n), isTrue);
    expect(atwaterEnergyRelativeError(meal(trace).nutriments), isNull);
  });
}
