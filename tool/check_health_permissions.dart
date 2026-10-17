import 'dart:io';

import 'package:xml/xml.dart';

const expectedHealthPermissions = {
  'READ_EXERCISE',
  'READ_TOTAL_CALORIES_BURNED',
};

({Set<String> kept, Set<String> removed}) healthPermissionsIn(String source) {
  final kept = <String>{};
  final removed = <String>{};
  for (final element in XmlDocument.parse(source).rootElement.childElements) {
    if (element.name.local != 'uses-permission' &&
        element.name.local != 'uses-permission-sdk-23') {
      continue;
    }
    final name = element.getAttribute(
      'name',
      namespace: 'http://schemas.android.com/apk/res/android',
    );
    const prefix = 'android.permission.health.';
    if (name == null || !name.startsWith(prefix)) continue;
    final remove =
        element.getAttribute(
          'node',
          namespace: 'http://schemas.android.com/tools',
        ) ==
        'remove';
    (remove ? removed : kept).add(name.substring(prefix.length));
  }
  return (kept: kept, removed: removed);
}

({bool ok, String report}) checkHealthPermissions(String source) {
  try {
    final actual = healthPermissionsIn(source).kept;
    final missing = expectedHealthPermissions.difference(actual).toList()
      ..sort();
    final unexpected = actual.difference(expectedHealthPermissions).toList()
      ..sort();
    final problems = [
      if (missing.isNotEmpty)
        'Missing Health Connect permissions: ${missing.join(', ')}.',
      if (unexpected.isNotEmpty)
        'Unexpected Health Connect permissions: ${unexpected.join(', ')}.',
    ];
    return (
      ok: problems.isEmpty,
      report: problems.isEmpty
          ? 'OK: packaged manifest declares exactly ${expectedHealthPermissions.join(', ')}.'
          : problems.join('\n'),
    );
  } on XmlException catch (error) {
    return (ok: false, report: 'Invalid Android manifest XML: $error');
  }
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart tool/check_health_permissions.dart <AndroidManifest.xml>',
    );
    exitCode = 64;
    return;
  }
  try {
    final result = checkHealthPermissions(File(args.single).readAsStringSync());
    (result.ok ? stdout : stderr).writeln('${args.single}: ${result.report}');
    exitCode = result.ok ? 0 : 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Cannot read Android manifest: $error');
    exitCode = 1;
  }
}
