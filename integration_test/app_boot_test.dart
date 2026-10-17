import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:opennutritracker/features/onboarding/onboarding_screen.dart';
import 'package:opennutritracker/features/onboarding/presentation/onboarding_intro_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart' as app;

/// Real first-run startup exercises native storage, notifications and routing.
/// Run on a cleared develop install; app.main registers the locator once.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install boots cleanly into a fully-rendered onboarding intro',
    (WidgetTester tester) async {
      final caught = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        caught.add(details);
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await app.main();
      await tester.pumpAndSettle();

      // Boot health.
      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'app should reach a MaterialApp',
      );
      expect(
        caught,
        isEmpty,
        reason:
            'no Flutter errors should fire during boot, got: '
            '${caught.map((e) => e.exception).toList()}',
      );

      // Routing: with no user data, the first screen is onboarding.
      expect(
        find.byType(OnboardingScreen),
        findsOneWidget,
        reason: 'with no user data, the first screen should be onboarding',
      );

      // Bloc state: IntroductionScreen mounts only after the bloc reaches
      // OnboardingLoadedState.
      expect(
        find.byType(IntroductionScreen),
        findsOneWidget,
        reason: 'OnboardingBloc should transition into loaded state',
      );

      // The resolved locale's description reaches the intro page body.
      final introContext = tester.element(find.byType(OnboardingIntroPageBody));
      final localizedDescription = S.of(introContext).appDescription;
      expect(
        localizedDescription,
        isNotEmpty,
        reason:
            'appDescription should be translated for '
            '${S.of(introContext).localeName}',
      );
      expect(
        find.text(localizedDescription),
        findsOneWidget,
        reason: 'the localised appDescription should render on the intro page',
      );
    },
  );
}
