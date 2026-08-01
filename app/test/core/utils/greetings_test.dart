import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/greetings.dart';

/// A date with a known day so only the hour/minute under test varies.
DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 8, 1, hour, minute);

void main() {
  group('greetingFor', () {
    test('every hour of the day returns a non-empty line', () {
      for (var h = 0; h < 24; h++) {
        // Walk every variant index too, so no single variant can be empty.
        for (var i = 0; i < 20; i++) {
          final line = greetingFor(_at(h), name: 'Sam', random: math.Random(i));
          expect(line.trim(), isNotEmpty, reason: 'hour $h, seed $i');
        }
      }
    });

    test('a seeded Random gives a deterministic, reproducible result', () {
      final first = greetingFor(_at(19), name: 'Sam', random: math.Random(42));
      final second = greetingFor(_at(19), name: 'Sam', random: math.Random(42));
      expect(second, first);

      // ...and the same seed replayed over a whole day reproduces exactly.
      final runA = [
        for (var h = 0; h < 24; h++)
          greetingFor(_at(h), name: 'Sam', random: math.Random(7)),
      ];
      final runB = [
        for (var h = 0; h < 24; h++)
          greetingFor(_at(h), name: 'Sam', random: math.Random(7)),
      ];
      expect(runB, runA);
    });

    test('the {name} placeholder is never left in the output', () {
      for (var h = 0; h < 24; h++) {
        for (final name in <String?>[null, '', '   ', 'Sam', 'null']) {
          for (var i = 0; i < 20; i++) {
            final line = greetingFor(_at(h), name: name, random: math.Random(i));
            expect(line, isNot(contains(greetingNamePlaceholder)),
                reason: 'hour $h, name $name, seed $i');
          }
        }
      }
    });

    test('null / empty / whitespace names never leave a dangling comma, '
        'double space, or the literal "null"', () {
      for (final name in <String?>[null, '', '   ', '\t\n', 'null', 'NULL']) {
        for (var h = 0; h < 24; h++) {
          for (var i = 0; i < 20; i++) {
            final line = greetingFor(_at(h), name: name, random: math.Random(i));
            final ctx = 'name=$name hour=$h seed=$i -> "$line"';
            expect(line.contains('  '), isFalse, reason: 'double space: $ctx');
            expect(RegExp(r',\s*[.?!]|,\s*$').hasMatch(line), isFalse,
                reason: 'dangling comma: $ctx');
            expect(line.toLowerCase().contains('null'), isFalse,
                reason: 'literal null: $ctx');
            expect(line, equals(line.trim()), reason: 'stray padding: $ctx');
          }
        }
      }
    });

    test('a real name is trimmed and woven into the name-slot variants', () {
      // 'Morning, {name}.' is index 0 of the morning bucket.
      final morning = greetingVariants(GreetingBucket.morning);
      final slotIndex = morning.indexWhere((v) => v.contains(greetingNamePlaceholder));
      expect(slotIndex, isNonNegative);

      final rendered = applyGreetingName(morning[slotIndex], '  Sam  ');
      expect(rendered, contains('Sam'));
      expect(rendered, isNot(contains('  ')));
    });
  });

  group('greetingBucketFor boundaries', () {
    final cases = <(DateTime, GreetingBucket)>[
      (_at(0, 0), GreetingBucket.lateNight),
      (_at(4, 59), GreetingBucket.lateNight),
      (_at(5, 0), GreetingBucket.earlyMorning),
      (_at(7, 59), GreetingBucket.earlyMorning),
      (_at(8, 0), GreetingBucket.morning),
      (_at(11, 59), GreetingBucket.morning),
      (_at(12, 0), GreetingBucket.afternoon),
      (_at(16, 59), GreetingBucket.afternoon),
      (_at(17, 0), GreetingBucket.evening),
      (_at(20, 59), GreetingBucket.evening),
      (_at(21, 0), GreetingBucket.night),
      (_at(23, 59), GreetingBucket.night),
    ];

    for (final (moment, expected) in cases) {
      final label = '${moment.hour.toString().padLeft(2, '0')}:'
          '${moment.minute.toString().padLeft(2, '0')}';
      test('$label is ${expected.name}', () {
        expect(greetingBucketFor(moment), expected);

        // The rendered line must come from that bucket's variant list.
        final rendered = greetingFor(moment, name: 'Sam', random: math.Random(3));
        final expectedLines = greetingVariants(expected)
            .map((v) => applyGreetingName(v, 'Sam'))
            .toList();
        expect(expectedLines, contains(rendered));
      });
    }

    test('every bucket has at least four variants and none are blank', () {
      for (final bucket in GreetingBucket.values) {
        final variants = greetingVariants(bucket);
        expect(variants.length, greaterThanOrEqualTo(4), reason: bucket.name);
        for (final v in variants) {
          expect(v.trim(), isNotEmpty, reason: bucket.name);
        }
      }
    });
  });

  group('greetingDetailFor', () {
    test('usesName reflects whether the picked variant had a name slot', () {
      for (var h = 0; h < 24; h++) {
        for (var i = 0; i < 20; i++) {
          final detail =
              greetingDetailFor(_at(h), name: 'Sam', random: math.Random(i));
          expect(detail.usesName, detail.line.contains('Sam'),
              reason: 'hour $h seed $i -> "${detail.line}"');
        }
      }
    });

    test('line matches greetingFor for the same seed', () {
      final detail = greetingDetailFor(_at(2), name: 'Sam', random: math.Random(11));
      expect(detail.line, greetingFor(_at(2), name: 'Sam', random: math.Random(11)));
    });
  });

  group('applyGreetingName', () {
    test('substitutes a normal name', () {
      expect(applyGreetingName('Morning, {name}.', 'Sam'), 'Morning, Sam.');
    });

    test('falls back for null, blank, and the literal "null"', () {
      for (final name in <String?>[null, '', '   ', 'null', 'NULL']) {
        expect(applyGreetingName('Morning, {name}.', name),
            'Morning, $greetingNameFallback.');
      }
    });

    test('is a no-op on a template with no placeholder', () {
      expect(applyGreetingName('Night rider.', 'Sam'), 'Night rider.');
      expect(applyGreetingName('Night rider.', null), 'Night rider.');
    });

    test('substitutes every occurrence', () {
      expect(applyGreetingName('{name}, {name}!', 'Sam'), 'Sam, Sam!');
    });
  });
}
