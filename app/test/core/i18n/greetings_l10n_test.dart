import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/i18n/greetings_l10n.dart';
import 'package:throttleiq/core/utils/greetings.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

void main() {
  final locales = {'en': AppLocalizationsEn(), 'bn': AppLocalizationsBn()};

  group('resolveGreeting', () {
    test('every bucket and variant resolves in both languages, with no leaked slot', () {
      for (final entry in locales.entries) {
        for (final bucket in GreetingBucket.values) {
          for (var i = 0; i < 5; i++) {
            final g = resolveGreeting((bucket: bucket, index: i), entry.value, name: 'Sam');
            expect(g.line, isNotEmpty, reason: '${entry.key} $bucket $i');
            expect(g.line, isNot(contains('{')), reason: '${entry.key} $bucket $i');
            expect(g.usesName, g.line.contains('Sam'), reason: '${entry.key} $bucket $i');
          }
        }
      }
    });

    test('the same choices have a name slot in English and Bangla', () {
      // A translation that drops or adds {name} would change how the record
      // screen lays the line out (name inline vs on its own line).
      for (final bucket in GreetingBucket.values) {
        for (var i = 0; i < 5; i++) {
          final en = resolveGreeting((bucket: bucket, index: i), locales['en']!, name: 'Sam');
          final bn = resolveGreeting((bucket: bucket, index: i), locales['bn']!, name: 'Sam');
          expect(bn.usesName, en.usesName, reason: '$bucket $i');
        }
      }
    });

    test('a blank or literal "null" name falls back to a generic word, never "null"', () {
      for (final name in <String?>[null, '', '   ', 'null']) {
        final g = resolveGreeting(
            (bucket: GreetingBucket.morning, index: 0), locales['en']!, name: name);
        expect(g.line, 'Morning, rider.');
      }
    });

    test('English variants match the pure greetings module', () {
      for (final bucket in GreetingBucket.values) {
        final raw = greetingVariants(bucket);
        for (var i = 0; i < raw.length; i++) {
          final g = resolveGreeting((bucket: bucket, index: i), locales['en']!, name: 'Sam');
          expect(g.line, applyGreetingName(raw[i], 'Sam'), reason: '$bucket $i');
        }
      }
    });
  });

  group('resolveQuote', () {
    test('all $kQuoteCount taglines resolve in both languages', () {
      for (final l in locales.values) {
        for (var i = 0; i < kQuoteCount; i++) {
          final (a, b) = resolveQuote(i, l);
          expect(a, isNotEmpty);
          expect(b, isNotEmpty);
        }
      }
    });
  });
}
