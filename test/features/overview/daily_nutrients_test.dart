import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import '../../helpers/pump_until.dart';
import '../../helpers/locator_test_setup.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/daily_nutrient_panel.dart';
import '../../helpers/overview_diary_harness.dart';
import 'overview_widgets_test.dart' show app;

void main() {
  useTestLocator();
  testWidgets(
    'Overview keeps selected-day nutrients, visibility and goals without a week selector',
    (tester) async {
      final h = OverviewDiaryHarness();
      final anchor = DateTime(2026, 9, 26);
      final meal = MealEntity(
        code: 'fiber',
        name: 'Fiber',
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        source: MealSourceEntity.custom,
        nutriments: MealNutrimentsEntity(
          energyKcal100: NutrientAmount(100),
          carbohydrates100: NutrientAmount(0),
          fat100: NutrientAmount(0),
          proteins100: NutrientAmount(0),
          sugars100: NutrientAmount(0),
          saturatedFat100: NutrientAmount(0),
          fiber100: NutrientAmount(70),
        ),
      );
      await tester.runAsync(() async {
        await h.initialize();
        await h.configSource.setConfigDayStartOffsetHours(4);
        await h.configSource.setConfigDayStartOffsetMinutes(30);
        await h.configSource.setConfigNutrientPanelVisibility({
          'sodium': false,
        });
        for (final entry in [
          ('before-week', DateTime(2026, 9, 20, 4, 29)),
          ('week-start', DateTime(2026, 9, 20, 4, 30)),
          ('week-end', DateTime(2026, 9, 27, 4, 29)),
          ('after-week', DateTime(2026, 9, 27, 4, 30)),
        ]) {
          await h.intakes.addIntake(
            IntakeEntity(
              id: entry.$1,
              quantity: FoodAmountSelection(
                100,
                FoodAmountOption(unit: 'g', baseUnit: 'g', factor: 1),
              ),
              type: IntakeTypeEntity.breakfast,
              meal: meal,
              dateTime: entry.$2,
            ),
          );
        }
      });
      locator.registerSingleton<GetConfigUsecase>(h.getConfig);
      locator.registerSingleton<GetIntakeUsecase>(h.getIntakes);
      locator.registerSingleton<GetUserUsecase>(h.getUser);
      addTearDown(() async {
        await locator.resetScope();
        await h.dispose();
      });
      final daily = await tester.runAsync(
        () => h.getIntakes.getBreakfastIntakeByDay(
          anchor,
          dayStartOffsetHours: 4,
          dayStartOffsetMinutes: 30,
        ),
      );
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: DailyNutrientPanel(
              intakes: daily!,
              selectedDay: anchor,
              asPercent: true,
              trackedDay: TrackedDayEntity(
                day: anchor,
                calorieGoal: 2000,
                caloriesTracked: 100,
                fibreGoal: 10,
              ),
            ),
          ),
        ),
      );
      await pumpUntil(tester, () => find.text('700%').evaluate().isNotEmpty);
      expect(find.text('700%'), findsOneWidget);
      expect(find.text('sodium'), findsNothing);
      expect(find.text('Week'), findsNothing);
      expect(find.text('Day'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
