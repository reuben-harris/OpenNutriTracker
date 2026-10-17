import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory stand-in for the platform keystore.
///
/// [reads] records access for credential-cache assertions; [readGates] can
/// hold selected reads pending for ordering tests.
class MemorySecureStorage implements FlutterSecureStorage {
  MemorySecureStorage([Map<String, String> initial = const {}])
    : store = Map.of(initial);

  final Map<String, String> store;
  final reads = <String>[];
  final readGates = <String, Completer<void>>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads.add(key);
    final gate = readGates[key];
    if (gate != null) await gate.future;
    return store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
