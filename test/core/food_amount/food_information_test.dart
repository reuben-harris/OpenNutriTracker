import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/food_amount/food_information.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../search/food_search_engine_test.dart' show food;

void main() {
  for (final logFood in [true, false]) {
    testWidgets(
      'swiped Info opens the app route and returns ${logFood ? 'the selected food' : 'null on back'}',
      (tester) async {
        final meal = food('123', 'Apple');
        final full = food('123', 'Apple, full record', detailed: true);
        final day = DateTime(2026, 10, 11);
        MealDetailScreenArguments? arguments;
        MealEntity? selected;
        var returned = false;
        var logged = 0;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            // MaterialApp.routes creates the same untyped routes as the app.
            routes: {
              NavigationOptions.mealDetailRoute: (context) {
                arguments =
                    ModalRoute.of(context)!.settings.arguments
                        as MealDetailScreenArguments;
                return Scaffold(
                  body: Text(arguments!.mealEntity.name!),
                  bottomNavigationBar: FilledButton(
                    onPressed: () => arguments!.onSelected!(full),
                    child: const Text('Log this food'),
                  ),
                );
              },
            },
            home: Scaffold(
              body: Builder(
                builder: (context) => MealItemCard(
                  mealEntity: meal,
                  onSelected: (_) => logged++,
                  onInfo: () async {
                    selected = await showFoodInformation(
                      context,
                      meal: meal,
                      day: day,
                      type: IntakeTypeEntity.lunch,
                      imperial: true,
                    );
                    returned = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.drag(find.text('Apple'), const Offset(150, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Info'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Log this food'), findsOneWidget);
        expect(arguments!.mealEntity, same(meal));
        expect(arguments!.day, day);
        expect(arguments!.intakeTypeEntity, IntakeTypeEntity.lunch);
        expect(arguments!.usesImperialUnits, true);
        if (logFood) {
          await tester.tap(find.text('Log this food'));
        } else {
          navigator.currentState!.pop();
        }
        await tester.pumpAndSettle();
        expect(returned, true);
        expect(selected, logFood ? same(full) : isNull);
        expect(logged, 0);
      },
    );
  }
}
