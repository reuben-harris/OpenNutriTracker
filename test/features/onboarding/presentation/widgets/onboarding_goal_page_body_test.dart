import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_goal_selection_entity.dart';
import 'package:opennutritracker/features/onboarding/presentation/widgets/onboarding_goal_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../../helpers/test_l10n.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    UserGoalSelectionEntity? initialGoal,
    void Function(bool, UserGoalSelectionEntity?)? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: OnboardingGoalPageBody(
            initialGoal: initialGoal,
            setButtonContent: (active, goal) => onSelected?.call(active, goal),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new profile must choose its goal without advice', (
    tester,
  ) async {
    bool? active;
    await pumpPage(tester, onSelected: (value, _) => active = value);

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips, hasLength(3));
    expect(chips.every((chip) => !chip.selected), isTrue);
    expect(active, isNull);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.text('Suggested'), findsNothing);
  });

  for (final (goal, identifier, label) in [
    (UserGoalSelectionEntity.loseWeight, 'lose', l10nEn.goalLoseWeight),
    (
      UserGoalSelectionEntity.maintainWeight,
      'maintain',
      l10nEn.goalMaintainWeight,
    ),
    (UserGoalSelectionEntity.gainWeigh, 'gain', l10nEn.goalGainWeight),
  ]) {
    testWidgets('selecting $identifier enables continuing with that goal', (
      tester,
    ) async {
      bool? active;
      UserGoalSelectionEntity? reported;
      await pumpPage(
        tester,
        onSelected: (value, selected) {
          active = value;
          reported = selected;
        },
      );

      await tester.tap(
        find.bySemanticsIdentifier('onboarding-goal-$identifier'),
      );
      await tester.pump();

      expect(active, isTrue);
      expect(reported, goal);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((chip) => chip.selected),
        hasLength(1),
      );
    });

    testWidgets('restores the previously selected $identifier goal', (
      tester,
    ) async {
      await pumpPage(tester, initialGoal: goal);

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
            .selected,
        isTrue,
      );
    });
  }
}
