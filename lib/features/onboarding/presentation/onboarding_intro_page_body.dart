import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/app_banner_version.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/core/utils/url_const.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingIntroPageBody extends StatefulWidget {
  const OnboardingIntroPageBody({
    super.key,
    required this.setPageContent,
    this.initialAcceptedPolicy = false,
  });

  final ValueChanged<bool> setPageContent;
  final bool initialAcceptedPolicy;

  @override
  State<OnboardingIntroPageBody> createState() =>
      _OnboardingIntroPageBodyState();
}

class _OnboardingIntroPageBodyState extends State<OnboardingIntroPageBody> {
  late bool _acceptedPolicy = widget.initialAcceptedPolicy;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppConst.getVersionNumber(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          // Scroll so the controls still fit on shorter
          // viewports (e.g. the 800×600 surface used by widget tests).
          return SingleChildScrollView(
            child: Column(
              children: [
                AppBannerVersion(versionNumber: snapshot.requireData),
                const SizedBox(height: 32.0),
                Text(
                  S.of(context).appDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32.0),
                Text(
                  S.of(context).onboardingIntroDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                ListTile(
                  onTap: () => _togglePolicy(),
                  title: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      text: S.of(context).readLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: ' ${S.of(context).privacyPolicyLabel}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchUrl();
                            },
                        ),
                      ],
                    ),
                  ),
                  leading: Semantics(
                    identifier: 'onboarding-checkbox-privacy',
                    child: Checkbox(
                      value: _acceptedPolicy,
                      onChanged: (value) {
                        if (value != null) {
                          _togglePolicy();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                TextButton.icon(
                  onPressed: () => _openSources(context),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(S.of(context).onboardingIntroSourcesLinkLabel),
                ),
              ],
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  void _togglePolicy() {
    setState(() {
      _acceptedPolicy = !_acceptedPolicy;
      widget.setPageContent(_acceptedPolicy);
    });
  }

  void _openSources(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SourcesScreen()));
  }

  Future<void> _launchUrl() async {
    // Read the locale before the await; the context must not be touched
    // afterwards without a mounted check.
    final policy = URLConst.privacyPolicyFor(
      Localizations.localeOf(context).languageCode,
    );

    // A device with no browser is the case worth reporting: this link is the
    // only way to read the policy the checkbox below asks you to accept, and
    // silently doing nothing reads as a broken tap.
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(policy),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      // No activity able to handle the intent — a failure to open, not a crash.
      opened = false;
    }

    if (opened || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context).errorOpeningBrowser)));
  }
}
