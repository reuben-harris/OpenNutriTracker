import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

void main() {
  final arb =
      jsonDecode(File('lib/l10n/intl_en.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('own-server disclosure names the host without inventing a company', () {
    final disclosure = arb['bulkAddPhotoDisclosureOwnServer'] as String;
    expect(disclosure, contains('{host}'));
    for (final company in ['Anthropic', 'OpenAI', 'OpenRouter', 'Google']) {
      expect(disclosure, isNot(contains(company)));
    }
    expect(
      l10nEn.aiAssistProviderOwnServerLabel.toLowerCase(),
      isNot(contains('local')),
    );
  });

  test('AI disclosures never claim on-device processing', () {
    const forbidden = [
      'never leaves your device',
      'never leaves this device',
      'stays on your device',
      'stays on this device',
      'processed on your device',
      'processed on-device',
    ];
    for (final entry in arb.entries.where(
      (e) => e.key.startsWith('aiAssist') || e.key.startsWith('bulkAddPhoto'),
    )) {
      if (entry.value is! String) continue;
      for (final phrase in forbidden) {
        expect(
          (entry.value as String).toLowerCase(),
          isNot(contains(phrase)),
          reason: entry.key,
        );
      }
    }
  });

  test('plaintext disclosure makes no claim to enforce a network boundary', () {
    for (final phrase in [
      'your own network',
      'stays on your network',
      'only permitted because',
    ]) {
      expect(
        (arb['aiAssistDisclosureOwnServerPlaintext'] as String).toLowerCase(),
        isNot(contains(phrase)),
      );
    }
  });

  final states = {
    'never checked': l10nEn.aiAssistProbeUnknownLabel,
    'no answer': l10nEn.aiAssistProbeNoAnswerLabel,
    'passed': l10nEn.aiAssistProbePassedLabel,
    'text failed': l10nEn.aiAssistProbeTextFailedLabel,
    'photo failed': l10nEn.aiAssistProbePhotoFailedLabel,
  };
  for (final state in states.entries) {
    test('${state.key} has a distinct capability message', () {
      expect(
        states.entries.where((e) => e.value == state.value).map((e) => e.key),
        [state.key],
      );
    });
  }

  test('the running notice carries the calculated wait', () {
    expect(arb['aiAssistProbeRunningLabel'], contains('{minutes'));
  });

  test('text and photo capabilities have distinct labels', () {
    expect(
      l10nEn.aiAssistProbeTextLabel,
      isNot(l10nEn.aiAssistProbePhotoLabel),
    );
  });
}
