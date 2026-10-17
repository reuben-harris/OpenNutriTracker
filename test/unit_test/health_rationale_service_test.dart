import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:opennutritracker/core/utils/health_rationale_service.dart';

// #927: Health Connect asks the app to explain what it wants health data for
// by starting it with one of two intents. The manifest declared both and
// `MainActivity` ignored them, so the question was answered by dropping the
// user on the diary. The channel tests pin the Dart contract; the manifest
// tests pin the halves that live outside Dart and cannot fail a compile.

const _channel = MethodChannel('com.opennutritracker/health_rationale');

/// The two actions, spelled exactly as Android delivers them. Duplicated here
/// on purpose — a test that read them from the source it checks would agree
/// with any typo.
const _rationaleAction = 'androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE';
const _permissionUsageAction = 'android.intent.action.VIEW_PERMISSION_USAGE';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void handleWith(Future<Object?>? Function(MethodCall)? handler) {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return handler == null ? null : await handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  group('HealthRationaleService', () {
    test('reports a pending request', () async {
      handleWith((_) async => true);

      expect(await HealthRationaleService.consumePendingRequest(), isTrue);
      expect(calls.single.method, 'consumePendingRequest');
    });

    test('reports nothing pending on an ordinary launch', () async {
      handleWith((_) async => false);

      expect(await HealthRationaleService.consumePendingRequest(), isFalse);
    });

    // A null would mean the platform answered without a value. Opening the
    // screen on that would put people on a settings page they never asked
    // for, so the ambiguous answer has to read as "no".
    test('treats a null answer as nothing pending', () async {
      handleWith((_) async => null);

      expect(await HealthRationaleService.consumePendingRequest(), isFalse);
    });

    // iOS, desktop and every widget test: no native side is registered. The
    // call must answer rather than throw into whatever is driving it.
    test('answers no on a platform with no native side', () async {
      expect(await HealthRationaleService.consumePendingRequest(), isFalse);
    });

    test('answers no when the platform side fails', () async {
      handleWith((_) async => throw PlatformException(code: 'error'));

      expect(await HealthRationaleService.consumePendingRequest(), isFalse);
    });
  });

  group('Android rationale entry points', () {
    final manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    const android = 'http://schemas.android.com/apk/res/android';
    final activity = manifest
        .findAllElements('activity')
        .singleWhere(
          (e) => e.getAttribute('name', namespace: android) == '.MainActivity',
        );
    final alias = manifest
        .findAllElements('activity-alias')
        .singleWhere(
          (e) => e
              .findAllElements('action')
              .any(
                (action) =>
                    action.getAttribute('name', namespace: android) ==
                    _permissionUsageAction,
              ),
        );

    test('the main activity exposes the rationale intent', () {
      expect(activity.getAttribute('exported', namespace: android), 'true');
      expect(
        activity.getAttribute('launchMode', namespace: android),
        'singleTop',
      );
      expect(
        activity
            .findElements('intent-filter')
            .any(
              (filter) => filter
                  .findElements('action')
                  .any(
                    (action) =>
                        action.getAttribute('name', namespace: android) ==
                        _rationaleAction,
                  ),
            ),
        isTrue,
      );
    });

    test(
      'the permission-usage alias targets MainActivity and stays guarded',
      () {
        expect(
          alias.getAttribute('targetActivity', namespace: android),
          '.MainActivity',
        );
        expect(alias.getAttribute('exported', namespace: android), 'true');
        expect(
          alias.getAttribute('permission', namespace: android),
          'android.permission.START_VIEW_PERMISSION_USAGE',
        );
        final filter = alias.findElements('intent-filter').single;
        expect(
          filter
              .findElements('category')
              .map((e) => e.getAttribute('name', namespace: android)),
          contains('android.intent.category.HEALTH_PERMISSIONS'),
        );
      },
    );
  });
}
