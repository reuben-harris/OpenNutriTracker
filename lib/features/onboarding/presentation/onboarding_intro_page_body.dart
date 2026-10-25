import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/app_banner_version.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/generated/l10n.dart';

class OnboardingIntroPageBody extends StatelessWidget {
  const OnboardingIntroPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AppConst.getVersionNumber(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return SingleChildScrollView(
          child: Column(
            children: [
              AppBannerVersion(versionNumber: snapshot.requireData),
              const SizedBox(height: 32),
              Text(
                S.of(context).appDescription,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                S.of(context).onboardingIntroDescription,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Semantics(
                identifier: 'onboarding-sources',
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SourcesScreen()),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(S.of(context).onboardingIntroSourcesLinkLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
