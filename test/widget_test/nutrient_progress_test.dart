import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/domain/entity/nutrient_goal.dart';
import 'package:opennutritracker/core/domain/entity/nutrients.dart';
import 'package:opennutritracker/core/presentation/widgets/nutrient_amount_row.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final isLimit in [false, true]) {
      testWidgets(
        '$brightness limit=$isLimit keeps status colours across accents',
        (tester) async {
          final dark = brightness == Brightness.dark;
          final neutral = dark
              ? const Color(0xFFA39E94)
              : const Color(0xFF827C73);
          final reached = isLimit
              ? (dark ? const Color(0xFFFF9387) : const Color(0xFFC4453A))
              : (dark ? const Color(0xFF34D08A) : const Color(0xFF0E7A4D));
          for (final accent in [Colors.blue, Colors.purple]) {
            final palette = (dark ? AppPalette.dark : AppPalette.light)
                .withAccent(accent);
            for (final ratio in [0.0, 0.5, 0.8, 0.999, 1.0, 1.2]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData.from(colorScheme: palette.colorScheme),
                  localizationsDelegates: S.localizationsDelegates,
                  supportedLocales: S.supportedLocales,
                  home: Scaffold(
                    body: NutrientAmountRow(
                      nutrient: Nutrients.byKey[NutrientKeys.fiber]!,
                      amount: NutrientAmount(ratio * 10),
                      goal: NutrientGoal(10, isLimit: isLimit),
                      asPercent: true,
                    ),
                  ),
                ),
              );
              final bar = tester.widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              );
              expect(
                bar.color,
                (isLimit ? ratio > 1 : ratio >= 1) ? reached : neutral,
                reason: 'ratio=$ratio, accent=$accent',
              );
              expect(bar.value, ratio.clamp(0.0, 1.0));
              expect(
                find.textContaining('${(ratio * 100).round()}%'),
                findsOneWidget,
              );
            }
          }
        },
      );
    }
  }
}
