import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:flutter/services.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final urls = <String>[];
  bool succeed = true, throwLaunch = false;
  setUp(() {
    urls.clear();
    succeed = true;
    throwLaunch = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            final args = call.arguments as Map;
            urls.add(args['url'] as String);
            expect(args['useWebView'], false);
            expect(args['useSafariVC'], false);
            if (throwLaunch) throw PlatformException(code: 'launch-failed');
            return succeed;
          }
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  Future<void> mount(
    WidgetTester tester,
    MealSourceEntity source, {
    String? url,
    VoidCallback? onCustom,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: MealInfoButton(
          meal: MealEntity(
            code: 'test',
            name: 'Test',
            url: url,
            mealQuantity: null,
            mealUnit: null,
            servingQuantity: null,
            servingUnit: null,
            servingSize: null,
            nutriments: MealNutrimentsEntity.empty(),
            source: source,
          ),
          onCustom: onCustom ?? () {},
        ),
      ),
    ),
  );
  for (final source in [MealSourceEntity.off, MealSourceEntity.fdc]) {
    testWidgets('$source uses valid source URLs and website fallback', (
      tester,
    ) async {
      for (final url in [
        'https://example.com/product/123',
        '',
        '  ',
        'broken',
        'file:///tmp/photo',
      ]) {
        await mount(tester, source, url: url);
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        expect(
          urls.last,
          url.startsWith('https')
              ? url
              : source == MealSourceEntity.off
              ? OFFConst.offWebsiteUrl
              : FDCConst.fdcWebsiteUrl,
        );
      }
    });
  }
  for (final throws in [false, true]) {
    testWidgets('launch failure shows localized feedback (throws=$throws)', (
      tester,
    ) async {
      succeed = false;
      throwLaunch = throws;
      await mount(tester, MealSourceEntity.off);
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open the food information website.'),
        findsOneWidget,
      );
    });
  }
  testWidgets(
    'recipes have no self-link, custom opens editing, and unknown is plain text',
    (tester) async {
      var custom = 0;
      for (final source in [
        MealSourceEntity.recipe,
        MealSourceEntity.custom,
        MealSourceEntity.unknown,
      ]) {
        await mount(tester, source, onCustom: () => custom++);
        if (source != MealSourceEntity.custom) {
          expect(find.byType(TextButton), findsNothing);
        } else {
          await tester.tap(find.byType(TextButton));
        }
      }
      expect(custom, 1);
      expect(urls, isEmpty);
    },
  );
}
