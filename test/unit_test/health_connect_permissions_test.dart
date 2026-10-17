import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/check_health_permissions.dart';

/// Source checks provide feedback without an Android build. The APK build
/// separately validates its packaged manifest with the same XML parser, so
/// transitive AARs and Gradle manifest-merger behavior are covered there.
void main() {
  // Cover the develop flavor and its standard build-type overlays.
  final appManifests =
      const [
            'main',
            'debug',
            'profile',
            'release',
            'develop',
            'developDebug',
            'developProfile',
            'developRelease',
          ]
          .map((s) => File('android/app/src/$s/AndroidManifest.xml'))
          .where((f) => f.existsSync())
          .toList();

  final permissions = appManifests
      .map((f) => healthPermissionsIn(f.readAsStringSync()))
      .toList();

  /// Every `android.permission.health.*` the app's own manifests declare.
  final declared = permissions.expand((p) => p.kept).toSet();

  /// Permissions the app strips from the merged manifest with the standard
  /// manifest-merger marker. A plugin's lower-priority declaration of one of
  /// these never reaches the artifact, so charging the plugin for it would
  /// block the normal remedy for a dependency that asks for too much.
  final removedByApp = permissions.expand((p) => p.removed).toSet();

  /// The same, per plugin, from each plugin's own manifest.
  ///
  /// Gradle merges plugin manifests into the application manifest, so a
  /// plugin declaring `android.permission.health.*` puts it in the APK and in
  /// front of Play's reviewer without it ever appearing in
  /// `android/app/src/main/AndroidManifest.xml`. Reading only the app
  /// manifest cannot see those dependency changes.
  ///
  /// Paths come from `.flutter-plugins-dependencies`, which `flutter pub get`
  /// writes and `.gitignore` excludes. If it is absent the plugin half checks
  /// nothing, so its absence fails a test of its own rather than passing
  /// quietly — a silent pass is the failure mode this file exists to prevent.
  ///
  /// Include build-type overlays as well as each plugin's main manifest.
  final pluginList = File('.flutter-plugins-dependencies');
  final pluginListPresent = pluginList.existsSync();
  final pluginPermissions = <String, Set<String>>{};
  var pluginManifestsRead = 0;
  if (pluginListPresent) {
    final plugins =
        ((jsonDecode(pluginList.readAsStringSync())
                    as Map<String, dynamic>)['plugins']
                as Map<String, dynamic>)['android']
            as List<dynamic>;
    for (final plugin in plugins.cast<Map<String, dynamic>>()) {
      final root = (plugin['path'] as String).replaceAll(RegExp(r'/+$'), '');
      for (final sourceSet in const ['main', 'debug', 'profile', 'release']) {
        final pluginManifest = File(
          '$root/android/src/$sourceSet/AndroidManifest.xml',
        );
        if (!pluginManifest.existsSync()) continue;
        pluginManifestsRead++;
        final found = healthPermissionsIn(
          pluginManifest.readAsStringSync(),
        ).kept..removeAll(removedByApp);
        if (found.isNotEmpty) {
          pluginPermissions
              .putIfAbsent(plugin['name'] as String, () => <String>{})
              .addAll(found);
        }
      }
    }
  }

  test('permission parsing ignores comments and respects XML namespaces', () {
    final parsed = healthPermissionsIn('''<manifest
      xmlns:a="http://schemas.android.com/apk/res/android"
      xmlns:m="http://schemas.android.com/tools">
      <!-- <uses-permission a:name="android.permission.health.READ_STEPS"/> -->
      <uses-permission a:maxSdkVersion="36" a:name="android.permission.health.READ_EXERCISE"/>
      <uses-permission m:node="remove" a:name="android.permission.health.READ_DISTANCE"/>
      <uses-permission a:name="android.permission.INTERNET"/>
    </manifest>''');
    expect(parsed.kept, {'READ_EXERCISE'});
    expect(parsed.removed, {'READ_DISTANCE'});
  });

  group('Health Connect permissions', () {
    test('no health permission is declared beyond those two', () {
      // Catches a new read added here without the declaration form being
      // updated to match. A plugin merging one in never reaches this set —
      // that is the separate plugin test below.
      expect(
        declared,
        {'READ_EXERCISE', 'READ_TOTAL_CALORIES_BURNED'},
        reason:
            'Every declared Health Connect permission has to be justified by '
            'a feature in the Play Console declaration form. Adding one here '
            'without updating that form is what gets an update rejected.',
      );
    });

    test('plugin manifests were actually inspected', () {
      // Not just "the list exists": if the paths in it resolved to nothing,
      // pluginPermissions would be empty and the plugin test below would pass
      // having read no files at all. Assert the work happened.
      expect(
        pluginListPresent,
        isTrue,
        reason:
            '.flutter-plugins-dependencies is missing. Run `flutter pub get` '
            'first; CI already does.',
      );
      expect(
        pluginManifestsRead,
        greaterThan(0),
        reason:
            'The plugin list resolved to no readable manifests, so the plugin '
            'half of this guard passed without checking anything.',
      );
    });

    test('no plugin merges a health permission into the manifest', () {
      expect(
        pluginPermissions,
        isEmpty,
        reason:
            'Gradle merges plugin manifests into the application manifest, so '
            'a permission declared there reaches the APK and Play without '
            'appearing in android/app/src/main/AndroidManifest.xml. If a '
            'plugin genuinely needs one, the Play Console declaration has to '
            'cover it first — the health plugin wanting READ_DISTANCE and '
            'READ_STEPS for its own workout path is precisely why this app '
            'reads ExerciseSessionRecord itself.',
      );
    });
  });
}
