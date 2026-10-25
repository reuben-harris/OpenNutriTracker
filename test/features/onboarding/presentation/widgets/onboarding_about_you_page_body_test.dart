import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/onboarding/presentation/widgets/onboarding_about_you_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_sex_selection_entity.dart';

import '../../../../helpers/test_l10n.dart';

/// The adult-equation notice on the birthday page. The calorie goal comes
/// from the IOM 2005 adult equations, so a 13-17 year old is told where the
/// number comes from rather than handed it silently.
void main() {
  final noticeText = l10nEn.onboardingAdultEquationNotice;

  Future<void> pumpFirstPage(WidgetTester tester, {DateTime? birthday}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: OnboardingAboutYouPageBody(
            setPageContent: (_, _, _) {},
            initialBirthday: birthday,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DateTime yearsAgo(int years) {
    final now = DateTime.now();
    return DateTime(now.year - years, now.month, now.day);
  }

  for (final sex in UserSexSelectionEntity.values) {
    testWidgets('${sex.name} selection requires a birthday to continue', (
      tester,
    ) async {
      final birthday = yearsAgo(30);
      bool? active;
      UserSexSelectionEntity? selectedSex;
      DateTime? selectedBirthday;
      Future<void> pump({DateTime? date}) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [S.delegate],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: OnboardingAboutYouPageBody(
                key: ValueKey(date),
                initialBirthday: date,
                setPageContent: (isActive, selection, birthday) {
                  active = isActive;
                  selectedSex = selection;
                  selectedBirthday = birthday;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final label = sex == UserSexSelectionEntity.sexMale
          ? l10nEn.sexMaleLabel
          : l10nEn.sexFemaleLabel;
      await pump();
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.text(l10nEn.sexLabel), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pump();
      expect(active, isFalse);
      await pump(date: birthday);
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pump();
      expect(active, isTrue);
      expect(selectedSex, sex);
      expect(selectedBirthday, birthday);
    });
  }

  testWidgets('no birthday chosen yet shows no notice', (tester) async {
    await pumpFirstPage(tester);

    expect(find.text(noticeText), findsNothing);
  });

  testWidgets('a 15 year old sees the notice', (tester) async {
    await pumpFirstPage(tester, birthday: yearsAgo(15));

    expect(find.text(noticeText), findsOneWidget);
  });

  testWidgets('a 13 year old sees the notice', (tester) async {
    await pumpFirstPage(tester, birthday: yearsAgo(13));

    expect(find.text(noticeText), findsOneWidget);
  });

  testWidgets('an adult does not', (tester) async {
    await pumpFirstPage(tester, birthday: yearsAgo(30));

    expect(find.text(noticeText), findsNothing);
  });

  // 18 still sees it: the IOM equations behind the goal are published for
  // "ages 19 years and older", so an 18-year-old is outside their stated
  // range even though they are legally an adult (#987).
  testWidgets('exactly 18 still sees the notice', (tester) async {
    await pumpFirstPage(tester, birthday: yearsAgo(18));

    expect(find.text(noticeText), findsOneWidget);
  });

  testWidgets('exactly 19 does not', (tester) async {
    await pumpFirstPage(tester, birthday: yearsAgo(19));

    expect(find.text(noticeText), findsNothing);
  });
}
