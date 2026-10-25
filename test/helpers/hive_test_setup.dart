import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

/// Process-wide flag — Hive's TypeRegistry is shared across all tests in
/// the same `flutter test` run, so calling `Hive.registerAdapter(...)`
/// twice with the same typeId throws. This guard makes the call
/// idempotent so test files can use it freely from setUp.
bool _hiveAdaptersRegistered = false;

/// Registers every DBO adapter via the generated [HiveRegistrar] extension
/// in `hive_registrar.g.dart`. Safe to call from any test's setUp — the
/// first call registers, subsequent calls are no-ops.
///
/// Prefer this over hand-listing the adapters a specific test "needs":
/// the hand-list silently rots when new DBO types are added, and
/// you only learn about it when something throws at write time.
void registerHiveAdaptersOnce() {
  if (_hiveAdaptersRegistered) return;
  Hive.registerAdapters();
  _hiveAdaptersRegistered = true;
}

/// Installs isolated storage for each test in the current group.
///
/// Call before registering feature teardown so dependent blocs are closed
/// before Hive. Closing Hive alone does not remove already closed boxes;
/// deleting the whole directory also cleans up persistence/reopen tests.
void useTestHive() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ont-hive-test-');
    Hive.init(directory.path);
    registerHiveAdaptersOnce();
  });
  tearDown(() async {
    try {
      await Hive.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
