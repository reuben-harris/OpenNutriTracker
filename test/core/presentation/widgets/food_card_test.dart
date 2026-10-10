import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/food_thumbnail.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import '../../search/food_search_engine_test.dart' show food;
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'diary and search share geometry at 320px, $brightness, scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final meal = MealEntity(
            code: 'usda:1',
            name: 'An unusually long food name that needs room to fit safely',
            url: null,
            mealQuantity: null,
            mealUnit: 'g',
            servingQuantity: null,
            servingUnit: 'g',
            servingSize: null,
            nutriments: const MealNutrimentsEntity(
              energyKcal100: 200,
              carbohydrates100: 20,
              fat100: 10,
              proteins100: 5,
              sugars100: null,
              saturatedFat100: null,
              fiber100: null,
            ),
            source: MealSourceEntity.fdc,
          );
          final day = DateTime(2026, 10, 1);
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => EnergyUnitProvider(),
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                localizationsDelegates: S.localizationsDelegates,
                supportedLocales: S.supportedLocales,
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: ListView(
                      children: [
                        IntakeCard(
                          key: const ValueKey('diary'),
                          intake: IntakeEntity(
                            id: 'intake',
                            meal: meal,
                            amount: 100,
                            unit: 'g',
                            type: IntakeTypeEntity.breakfast,
                            dateTime: day,
                          ),
                          usesImperialUnits: false,
                        ),
                        MealItemCard(
                          key: const ValueKey('search'),
                          mealEntity: meal,
                          onSelected: (_) {},
                          onInfo: () {},
                        ),
                        MealItemCard(
                          key: const ValueKey('next'),
                          mealEntity: food(
                            'usda:2',
                            'Pear',
                            source: MealSourceEntity.fdc,
                          ),
                          onSelected: (_) {},
                          onInfo: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final cards = find.byType(AppCard);
          final thumbs = find.byType(FoodThumbnail);
          expect(cards, findsNWidgets(3));
          for (var i = 0; i < 3; i++) {
            final card = tester.getRect(cards.at(i));
            final thumb = tester.getRect(thumbs.at(i));
            expect(card.left, 16);
            expect(card.right, 304);
            expect(card.height, greaterThanOrEqualTo(76));
            expect(thumb.width, closeTo(52, 0.000001));
            expect(thumb.height, closeTo(52, 0.000001));
            // AppCard's border surrounds the shared 12px content padding.
            final borderWidth =
                tester.widget<AppCard>(cards.at(i)).borderColor == null
                ? 1.0
                : 1.5;
            expect(thumb.left - card.left - borderWidth, 12);
            expect(tester.widget<AppCard>(cards.at(i)).borderRadius, 20);
            final clip = find.descendant(
              of: thumbs.at(i),
              matching: find.byType(ClipRRect),
            );
            expect(
              tester.widget<ClipRRect>(clip).borderRadius,
              BorderRadius.circular(14),
            );
            if (i > 0) {
              expect(card.top - tester.getRect(cards.at(i - 1)).bottom, 8);
            }
          }
          expect(
            tester.getRect(cards.at(0)).height,
            closeTo(tester.getRect(cards.at(1)).height, 0.000001),
          );
          if (scale == 1) {
            expect(tester.getRect(cards.at(1)).height, 78);
          }
          expect(
            tester.getRect(cards.at(1)).height,
            closeTo(tester.getRect(cards.at(2)).height, 0.000001),
          );
          expect(find.byIcon(Icons.add_rounded), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
