import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opennutritracker/core/search/catalogue_preferences.dart';
import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/databases_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'bundled catalogues install and database switches have tight Android bounds',
    (tester) async {
      final temporary = await Directory.systemTemp.createTemp(
        'catalogue-android-',
      );
      final preferences = CataloguePreferences(
        catalogue: SQLiteFoodCatalogue(
          installer: CatalogueInstaller(
            supportDirectory: () async => temporary,
          ),
        ),
        read: () async => {},
        write: (_) async {},
      );
      final semantics = tester.ensureSemantics();
      try {
        await preferences.load();
        expect(
          preferences.sources.map((source) => source.id),
          containsAll(['usda', 'nzfoodfiles']),
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: DatabasesScreen(preferences: preferences),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.bySemanticsIdentifier(
          'database-nzfoodfiles-enabled',
        );
        final bounds = tester.getRect(toggle);
        expect(bounds.height, inInclusiveRange(48, 150));
        expect(bounds.width, greaterThan(200));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(await preferences.enabledSourceIds(), {'usda'});

        // This independent installer also exercises real asset replacement and
        // native SQLite/FTS on Android, without touching any personal Hive boxes.
        final catalogue = SQLiteFoodCatalogue(
          installer: CatalogueInstaller(
            supportDirectory: () async => temporary,
          ),
        );
        final foods = await catalogue.search(
          'rewena',
          sourceIds: {'nzfoodfiles'},
        );
        expect(foods, isNotEmpty);
        expect(
          foods.every((food) => food.code!.startsWith('nzfoodfiles:')),
          isTrue,
        );
        final bread = (await catalogue.getById('nzfoodfiles:A10001'))!;
        expect(bread.catalogueSourceName, 'NZ FOODfiles');
        expect(bread.nutriments.energyKcal100, greaterThan(0));
        expect(bread.portions.first.gramWeight, greaterThan(0));
        expect(await catalogue.search('bread', sourceIds: {}), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await preferences.dispose();
        await temporary.delete(recursive: true);
      }
    },
  );
}
