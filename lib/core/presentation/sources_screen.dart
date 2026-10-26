import 'package:opennutritracker/core/nutrition/references/reference_catalogue.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/url_const.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Surfaces the peer-reviewed sources behind every health/medical
/// calculation OpenNutriTracker shows. Reachable from the Home dashboard,
/// workout calorie credit, both sex-selection screens,
/// and the onboarding introduction — so anyone scanning the app for citations
/// (Apple's reviewers included) can find them within one tap.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, this.catalogue, this.referenceRegion});
  final FoodCatalogue? catalogue;
  final ReferenceRegion? referenceRegion;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  late Future<List<CatalogueSource>> _catalogueSources;

  Future<List<CatalogueSource>> _loadSources() =>
      widget.catalogue?.sources() ??
      (locator.isRegistered<FoodCatalogue>()
          ? locator<FoodCatalogue>().sources()
          : Future.value(const []));

  @override
  void initState() {
    super.initState();
    _catalogueSources = _loadSources();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final referenceSources = ReferenceSource.all.toList()
      ..sort(
        (a, b) => a.region == widget.referenceRegion
            ? -1
            : b.region == widget.referenceRegion
            ? 1
            : 0,
      );
    final entries = <_SourceEntry>[
      for (final source in referenceSources)
        _SourceEntry(
          title: '${l10n.sourcesNutrientReferenceTitle} — ${source.name}',
          description:
              '${source.edition}\n${l10n.regionalReferenceDescription}',
          sources: [
            _SourceLink(
              citation: source.attribution,
              url: source.url,
              identifier: 'source-nutrient-${source.region.name}',
            ),
          ],
        ),
      _SourceEntry(
        title: l10n.sourcesEnergyTitle,
        description: l10n.sourcesEnergyDescription,
        sources: const [
          _SourceLink(
            citation:
                'Institute of Medicine (2005). Dietary Reference Intakes for '
                'Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, '
                'Protein, and Amino Acids. National Academies Press.',
            url: URLConst.sourceEnergyIomDriURL,
          ),
        ],
      ),
      _SourceEntry(
        title: l10n.sourcesMacrosTitle,
        description: l10n.sourcesMacrosDescription,
        sources: const [
          _SourceLink(
            citation:
                'World Health Organization (2003). Diet, Nutrition and the '
                'Prevention of Chronic Diseases. WHO Technical Report '
                'Series 916.',
            url: URLConst.sourceMacrosWhoTrs916URL,
          ),
        ],
      ),
      _SourceEntry(
        title: l10n.sourcesActivityTitle,
        description: l10n.sourcesActivityDescription,
        sources: const [
          _SourceLink(
            citation:
                'Herrmann SD, et al. (2024). 2024 Adult Compendium of '
                'Physical Activities. Journal of Sport and Health Science.',
            url: URLConst.sourceActivityCompendium2024URL,
          ),
        ],
      ),
      _SourceEntry(
        title: l10n.sourcesEnergyCompensationTitle,
        description: l10n.sourcesEnergyCompensationDescription,
        sources: const [
          _SourceLink(
            citation:
                'Careau V, et al. (2021). Energy compensation and adiposity '
                'in humans. Current Biology, 31(20):4659–4666.e2.',
            url: URLConst.sourceEnergyCompensationCareau2021URL,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSourcesLabel)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.spacing16,
          vertical: Dimens.spacing16,
        ),
        children: [
          Text(
            l10n.sourcesScreenIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Dimens.spacing16),
          FutureBuilder<List<CatalogueSource>>(
            future: _catalogueSources,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorDialog(
                  errorText: l10n.catalogueLoadFailedLabel,
                  onRefreshPressed: () => setState(() {
                    _catalogueSources = _loadSources();
                  }),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Semantics(
                identifier: 'catalogue-reference-list',
                child: Column(
                  children: [
                    for (final source in snapshot.data!)
                      _SourceCard(
                        entry: _SourceEntry(
                          title: source.name,
                          description: l10n.catalogueReleasesLabel(
                            source.releaseSummary,
                          ),
                          sources: [
                            _SourceLink(
                              citation: source.attribution,
                              url: source.website,
                              identifier: 'source-${source.id}-website',
                            ),
                            _SourceLink(
                              citation: source.termsRequired
                                  ? l10n.catalogueTermsNotice
                                  : l10n.catalogueTermsLabel,
                              url: source.termsUrl,
                              label: l10n.catalogueTermsLabel,
                              identifier: 'source-${source.id}-terms',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          ...entries.map((entry) => _SourceCard(entry: entry)),
        ],
      ),
    );
  }
}

class _SourceEntry {
  final String title;
  final String description;
  final List<_SourceLink> sources;

  const _SourceEntry({
    required this.title,
    required this.description,
    required this.sources,
  });
}

class _SourceLink {
  // Paper citations stay in English by academic convention — the journal,
  // authors, and title are the canonical record regardless of the user's
  // app language.
  final String citation;
  final String url;
  final String? label;
  final String? identifier;

  const _SourceLink({
    required this.citation,
    required this.url,
    this.label,
    this.identifier,
  });
}

class _SourceCard extends StatelessWidget {
  final _SourceEntry entry;

  const _SourceCard({required this.entry});

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final l10n = S.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorOpeningBrowser)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.spacing12),
      child: AppCard(
        padding: const EdgeInsets.all(Dimens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: Dimens.spacing8),
            Text(entry.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Dimens.spacing12),
            ...entry.sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: Dimens.spacing4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.citation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Semantics(
                        identifier: source.identifier,
                        child: TextButton.icon(
                          onPressed: () => _launch(context, source.url),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            source.label ??
                                S.of(context).sourcesOpenSourceLabel,
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimens.spacing8,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
