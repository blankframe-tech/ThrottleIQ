import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_join_code.dart';

void main() {
  group('generateGroupRideJoinCode', () {
    test('is 6 characters from the unambiguous alphabet', () {
      final code = generateGroupRideJoinCode(Random(1));
      expect(code.length, kJoinCodeLength);
      expect(looksLikeGroupRideJoinCode(code), isTrue);
    });

    test('never contains visually ambiguous characters', () {
      for (var seed = 0; seed < 50; seed++) {
        final code = generateGroupRideJoinCode(Random(seed));
        expect(code.contains(RegExp('[01OIL]')), isFalse);
      }
    });

    test('is deterministic for an injected Random', () {
      expect(
        generateGroupRideJoinCode(Random(42)),
        generateGroupRideJoinCode(Random(42)),
      );
    });
  });

  group('normalizeGroupRideJoinCode', () {
    test('upper-cases and strips whitespace', () {
      expect(normalizeGroupRideJoinCode(' ab 12cd '), 'AB12CD');
    });

    test('is idempotent', () {
      final once = normalizeGroupRideJoinCode('a1 b2 c3');
      expect(normalizeGroupRideJoinCode(once), once);
    });
  });

  group('looksLikeGroupRideJoinCode', () {
    test('accepts a well-formed code regardless of case/whitespace', () {
      expect(looksLikeGroupRideJoinCode('ab34cd'), isTrue);
      expect(looksLikeGroupRideJoinCode(' AB34CD '), isTrue);
    });

    test('rejects the wrong length', () {
      expect(looksLikeGroupRideJoinCode('AB34C'), isFalse);
      expect(looksLikeGroupRideJoinCode('AB34CDE'), isFalse);
      expect(looksLikeGroupRideJoinCode(''), isFalse);
    });

    test('rejects ambiguous or out-of-alphabet characters', () {
      expect(looksLikeGroupRideJoinCode('AB34O1'), isFalse); // O, 1
      expect(looksLikeGroupRideJoinCode('AB34-D'), isFalse); // punctuation
    });
  });
}
