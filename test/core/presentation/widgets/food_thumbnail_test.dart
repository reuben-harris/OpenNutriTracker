import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/food_thumbnail.dart';
import 'package:opennutritracker/core/utils/food_image_loader.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../utils/food_image_loader_test.dart' show imageMeal;

class _Loader extends Fake implements FoodImageLoader {
  final streams = <String, StreamController<FoodImageLoad>>{};
  final cancelled = <String>[];

  StreamController<FoodImageLoad> forUrl(String url) => streams.putIfAbsent(
    url,
    () => StreamController<FoodImageLoad>(
      sync: true,
      onCancel: () => cancelled.add(url),
    ),
  );

  @override
  Stream<FoodImageLoad> load(MealEntity meal) =>
      forUrl(meal.thumbnailImageUrl!).stream;
}

void main() {
  late _Loader loader;
  late Directory directory;
  late File file;
  setUp(() async {
    loader = _Loader();
    directory = await Directory.systemTemp.createTemp('food-thumbnail-');
    file = await File('${directory.path}/image.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
      ),
    );
  });
  tearDown(() async {
    for (final stream in loader.streams.values) {
      await stream.close();
    }
    await directory.delete(recursive: true);
  });

  Widget app({String? url = 'first', bool refreshing = false}) => MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: Center(
        child: FoodThumbnail(
          meal: imageMeal(thumbnail: url),
          imageLoader: loader,
          isRefreshing: refreshing,
        ),
      ),
    ),
  );
  Finder getProgress() => find.byType(CircularProgressIndicator);
  Finder getBlur() => find.byType(ImageFiltered);

  testWidgets(
    'cache lookup keeps fallback sharp, cache image appears without progress',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(getProgress(), findsNothing);
      expect(getBlur(), findsNothing);
      loader.forUrl('first').add(FoodImageLoad.complete(file));
      await tester.pump();
      expect(getProgress(), findsNothing);
      expect(getBlur(), findsNothing);
      expect(tester.widget<Image>(find.byType(Image)).image, FileImage(file));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only unresolved downloading shows blur and centered progress after 200ms',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app());
      loader.forUrl('first').add(const FoodImageLoad.downloading());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 199));
      expect(getBlur(), findsNothing);
      expect(getProgress(), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(getBlur(), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(getProgress(), findsOneWidget);
      expect(
        tester.getCenter(getProgress()),
        tester.getCenter(find.byType(FoodThumbnail)),
      );
      expect(find.semantics.byLabel('Loading image'), findsOneWidget);
      loader.forUrl('first').add(FoodImageLoad.complete(file));
      await tester.pump();
      expect(getProgress(), findsNothing);
      expect(getBlur(), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );

  testWidgets('fast download has no feedback or minimum duration', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    loader.forUrl('first').add(const FoodImageLoad.downloading());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    loader.forUrl('first').add(FoodImageLoad.complete(file));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(getProgress(), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(getProgress(), findsNothing);
    expect(getBlur(), findsNothing);
  });

  testWidgets('failure and empty completion clear feedback to sharp fallback', (
    tester,
  ) async {
    for (final error in [false, true]) {
      final url = '$error';
      await tester.pumpWidget(app(url: url));
      loader.forUrl(url).add(const FoodImageLoad.downloading());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(getProgress(), findsOneWidget);
      if (error) {
        loader.forUrl(url).addError(StateError('download failed'));
      } else {
        loader.forUrl(url).add(const FoodImageLoad.complete(null));
      }
      await tester.pump();
      expect(getProgress(), findsNothing);
      expect(getBlur(), findsNothing);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    }
  });

  testWidgets(
    'explicit refresh immediately blurs ready image and preserves diary semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app());
      loader.forUrl('first').add(FoodImageLoad.complete(file));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(refreshing: true));
      expect(getProgress(), findsOneWidget);
      expect(getBlur(), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).image, FileImage(file));
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.getSemanticsData().identifier ==
              'diary-intake-refresh-progress',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(app());
      expect(getProgress(), findsNothing);
      expect(getBlur(), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'removing image sources during refresh clears the retained image',
    (tester) async {
      await tester.pumpWidget(app());
      loader.forUrl('first').add(FoodImageLoad.complete(file));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(url: null, refreshing: true));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(getProgress(), findsOneWidget);
      await tester.pumpWidget(app(url: null));
      expect(find.byType(Image), findsNothing);
      expect(getProgress(), findsNothing);
      expect(getBlur(), findsNothing);
    },
  );

  testWidgets(
    'replacement cancels stale load and starts a fresh feedback timer',
    (tester) async {
      await tester.pumpWidget(app());
      loader.forUrl('first').add(const FoodImageLoad.downloading());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(app(url: 'second'));
      expect(loader.cancelled, contains('first'));
      loader.forUrl('first').add(FoodImageLoad.complete(file));
      loader.forUrl('second').add(const FoodImageLoad.downloading());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 199));
      expect(find.byType(Image), findsNothing);
      expect(getProgress(), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(getProgress(), findsOneWidget);
      loader.forUrl('second').add(const FoodImageLoad.complete(null));
      await tester.pump();
      expect(getProgress(), findsNothing);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('disposal cancels subscriptions and pending feedback safely', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    loader.forUrl('first').add(const FoodImageLoad.downloading());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    expect(loader.cancelled, contains('first'));
    loader.forUrl('first').add(FoodImageLoad.complete(file));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a decoding failure uses the shared fallback', (tester) async {
    await tester.pumpWidget(app());
    final invalid = await tester.runAsync(
      () => File('${directory.path}/invalid').writeAsString('bad image'),
    );
    loader.forUrl('first').add(FoodImageLoad.complete(invalid));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 20 && find.byIcon(Icons.restaurant_rounded).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
