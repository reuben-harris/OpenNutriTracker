import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/section_group.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/onboarding/presentation/widgets/onboarding_other_options_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

/// The "Other options" page groups its settings the way Profile and Settings
/// do, and keeps the long database list collapsed behind a summary.
void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeModeProvider>(
        create: (_) => ThemeModeProvider(appTheme: AppThemeEntity.system),
        child: MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: OnboardingOtherOptionsPageBody(
              setPageContent: (_, _, _, _) {},
              initialTheme: AppThemeEntity.system,
              initialDailyReminderEnabled: false,
              initialUseMaterialYou: true,
              initialAccentColor: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sections are grouped the way the rest of the app groups them', (
    tester,
  ) async {
    await pumpPage(tester);

    // Theme (with accent) and notifications.
    expect(find.byType(SectionHeader), findsNWidgets(2));
    expect(find.byType(SectionGroup), findsNWidgets(2));
  });
}
