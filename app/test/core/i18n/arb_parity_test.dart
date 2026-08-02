import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the localization pipeline against the failure mode that kills
/// half-finished i18n efforts: someone adds a string to the English template,
/// ships it, and Bangla riders silently get English for the next six months.
///
/// `flutter gen-l10n` only *warns* about untranslated keys — it still emits a
/// class that falls back to English, so nothing breaks loudly. This test is the
/// thing that breaks loudly.
void main() {
  // `flutter test` runs with the package root as the working directory.
  final arbDir = Directory('lib/l10n');

  Map<String, dynamic> readArb(String fileName) {
    final file = File('${arbDir.path}/$fileName');
    expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Message keys only — `@@locale` and the `@key` metadata blocks are not
  /// translatable content and are expected to differ between files.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  late Map<String, dynamic> en;
  late Map<String, dynamic> bn;

  setUpAll(() {
    en = readArb('app_en.arb');
    bn = readArb('app_bn.arb');
  });

  group('ARB parity', () {
    test('each ARB declares its own @@locale', () {
      expect(en['@@locale'], 'en');
      expect(bn['@@locale'], 'bn');
    });

    test('app_bn.arb has a translation for every key in app_en.arb', () {
      final missing = messageKeys(en).difference(messageKeys(bn)).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'Untranslated in app_bn.arb: ${missing.join(', ')}.\n'
            'Add a Bangla string for each, then re-run `flutter gen-l10n`.',
      );
    });

    test('app_bn.arb has no keys that app_en.arb dropped', () {
      // The other direction: a stale translation left behind after the English
      // string was deleted or renamed. Harmless at runtime, but it hides the
      // rename — the renamed key would show up as "missing" above while the
      // old translation sits there looking done.
      final orphaned = messageKeys(bn).difference(messageKeys(en)).toList()
        ..sort();
      expect(orphaned, isEmpty,
          reason: 'Orphaned keys in app_bn.arb: ${orphaned.join(', ')}');
    });

    test('no Bangla value is empty or whitespace', () {
      for (final key in messageKeys(bn)) {
        final value = bn[key];
        expect(value, isA<String>(), reason: '$key is not a string in bn');
        expect((value as String).trim(), isNotEmpty,
            reason: '$key is blank in app_bn.arb');
      }
    });

    test('placeholders survive translation', () {
      // A translated string that drops (or misspells) a {placeholder} makes
      // gen-l10n emit a method whose argument is silently unused, so the value
      // just vanishes from the UI in that language only.
      final placeholder = RegExp(r'\{(\w+)\}');
      Set<String> placeholdersIn(String s) =>
          placeholder.allMatches(s).map((m) => m.group(1)!).toSet();

      for (final key in messageKeys(en)) {
        final expected = placeholdersIn(en[key] as String);
        if (expected.isEmpty) continue;
        expect(placeholdersIn(bn[key] as String), expected,
            reason: 'Placeholder mismatch for "$key" in app_bn.arb');
      }
    });

    test('translations are actually Bangla, not English echoed back', () {
      // Catches the "copy the English file and call it done" placeholder pass.
      // Two keys are legitimately identical across both files: language names
      // are always written in their own language, so English stays "English"
      // and Bangla stays "বাংলা" in both ARBs.
      const intentionallyIdentical = {
        'languageEnglishLabel',
        'languageBanglaLabel',
      };
      final bengali = RegExp(r'[ঀ-৿]');

      final echoed = <String>[];
      for (final key in messageKeys(en)) {
        if (intentionallyIdentical.contains(key)) continue;
        final bnValue = bn[key] as String;
        if (bnValue == en[key] || !bengali.hasMatch(bnValue)) echoed.add(key);
      }
      echoed.sort();
      expect(echoed, isEmpty,
          reason: 'Not translated into Bangla: ${echoed.join(', ')}');
    });

    test('Bangla strings use Western digits, per core/i18n/numeric_locale.dart',
        () {
      // Project decision: digits stay 0-9 in every language so instrument
      // readouts and prose agree. Bengali numerals in an ARB would break that
      // silently, one string at a time.
      final bengaliDigits = RegExp(r'[০-৯]');
      final offenders = messageKeys(bn)
          .where((k) => bengaliDigits.hasMatch(bn[k] as String))
          .toList()
        ..sort();
      expect(offenders, isEmpty,
          reason: 'Bengali numerals found in: ${offenders.join(', ')}');
    });
  });

  group('ARB template hygiene', () {
    test('every English message carries an @-description', () {
      // The description is the only context a translator gets. Missing ones are
      // how "Add" ends up translated as the arithmetic kind.
      final undocumented = messageKeys(en)
          .where((k) => !en.containsKey('@$k'))
          .toList()
        ..sort();
      expect(undocumented, isEmpty,
          reason: 'Missing @description in app_en.arb for: '
              '${undocumented.join(', ')}');
    });

    test('the generated Dart is in sync with the ARBs', () {
      // lib/l10n/app_localizations*.dart is committed, so a dev who edits an
      // ARB and forgets `flutter gen-l10n` would otherwise ship a build where
      // the new string exists but is unreachable.
      final generated =
          File('${arbDir.path}/app_localizations.dart').readAsStringSync();
      final missing = messageKeys(en)
          .where((k) => !generated.contains(RegExp('\\b$k\\b')))
          .toList()
        ..sort();
      expect(missing, isEmpty,
          reason: 'Not present in the generated AppLocalizations: '
              '${missing.join(', ')}. Run `flutter gen-l10n`.');
    });
  });
}
