import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/search/catalogue_preferences.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/databases_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/fake_food_catalogue.dart';

void main() {
  late FakeFoodCatalogue catalogue;
  late CataloguePreferences preferences;
  late Map<String, bool> stored;
  bool failWrite = false;
  setUp(() {
    failWrite = false;
    stored = {};
    catalogue = FakeFoodCatalogue([
      catalogueSource('usda', 'FoodData Central'),
      catalogueSource('other', 'Another database', termsRequired: true),
    ]);
    preferences = CataloguePreferences(
      catalogue: catalogue,
      read: () async => stored,
      write: (next) async {
        if (failWrite) throw StateError('save failed');
        stored = Map.from(next);
      },
    );
  });
  tearDown(() => preferences.dispose());

  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'accessible database switches persist and permit every database off',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, DatabasesScreen(preferences: preferences));
      expect(find.text('Databases'), findsOneWidget);
      expect(find.text('Releases: 2024'), findsNWidgets(2));
      final usda = find.bySemanticsIdentifier('database-usda-enabled');
      expect(tester.getRect(usda).height, inInclusiveRange(48, 150));
      await tester.tap(usda);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('database-other-enabled'));
      await tester.pumpAndSettle();
      expect(stored, {'usda': false, 'other': false});
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((tile) => !tile.value),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('failed saves retain the switch and show feedback', (
    tester,
  ) async {
    await mount(tester, DatabasesScreen(preferences: preferences));
    failWrite = true;
    await tester.tap(find.text('FoodData Central'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isTrue,
    );
    expect(
      find.text('Could not save display preference. Please try again.'),
      findsOneWidget,
    );
    expect(stored, isEmpty);
  });

  testWidgets('failed loads can be retried', (tester) async {
    var fail = true;
    catalogue.loadSources = () async {
      if (fail) throw StateError('read failed');
      return catalogue.sourceList;
    };
    await mount(tester, DatabasesScreen(preferences: preferences));
    expect(find.text('Could not load food databases.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNWidgets(2));
  });

  testWidgets(
    'sources and references presents database credits and applicable terms',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final urls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'launch') {
              urls.add((call.arguments as Map)['url'] as String);
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await mount(tester, SourcesScreen(catalogue: catalogue));
      expect(find.text('FoodData Central publisher'), findsOneWidget);
      expect(find.text('Another database publisher'), findsOneWidget);
      expect(
        find.text(
          'Use of this data is subject to the publisher’s terms of use.',
        ),
        findsOneWidget,
      );
      final terms = find.bySemanticsIdentifier('source-other-terms');
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(urls, ['https://example.org/other/terms']);
      expect(tester.takeException(), isNull);
    },
  );
}
