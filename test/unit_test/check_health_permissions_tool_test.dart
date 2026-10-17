import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_health_permissions.dart';

String manifest(
  List<String> permissions, {
  String element = 'uses-permission',
}) =>
    '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  ${permissions.map((name) => '<$element android:name="$name"/>').join('\n')}
</manifest>''';

void main() {
  const requiredPermissions = [
    'android.permission.health.READ_EXERCISE',
    'android.permission.health.READ_TOTAL_CALORIES_BURNED',
  ];

  test(
    'the required health permissions allow unrelated Android permissions',
    () {
      final result = checkHealthPermissions(
        manifest([...requiredPermissions, 'android.permission.INTERNET']),
      );
      expect(result.ok, isTrue, reason: result.report);
    },
  );

  for (final permission in ['READ_STEPS', 'WRITE_EXERCISE']) {
    test('an extra $permission fails validation', () {
      final result = checkHealthPermissions(
        manifest([
          ...requiredPermissions,
          'android.permission.health.$permission',
        ]),
      );
      expect(result.ok, isFalse);
      expect(
        result.report,
        contains('Unexpected Health Connect permissions: $permission.'),
      );
    });
  }

  test('SDK-23 permission declarations also enforce the health policy', () {
    final result = checkHealthPermissions(
      manifest([
        ...requiredPermissions,
        'android.permission.health.READ_STEPS',
      ], element: 'uses-permission-sdk-23'),
    );
    expect(result.ok, isFalse);
    expect(
      result.report,
      contains('Unexpected Health Connect permissions: READ_STEPS.'),
    );
  });

  test('a missing required permission fails validation', () {
    final result = checkHealthPermissions(
      manifest([requiredPermissions.first]),
    );
    expect(result.ok, isFalse);
    expect(
      result.report,
      contains(
        'Missing Health Connect permissions: READ_TOTAL_CALORIES_BURNED.',
      ),
    );
  });

  for (final (name, source) in [
    ('no permissions', manifest([])),
    ('empty output', ''),
    ('malformed XML', '<manifest>'),
  ]) {
    test('$name fails validation', () {
      expect(checkHealthPermissions(source).ok, isFalse);
    });
  }
}
