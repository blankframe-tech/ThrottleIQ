import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/presentation/utils/group_ride_colors.dart';

void main() {
  group('colorForMember stability', () {
    test('the same (userId, index) always yields the same colour', () {
      for (var i = 0; i < 40; i++) {
        final first = colorForMember('rider-$i', i);
        final second = colorForMember('rider-$i', i);
        final third = colorForMember('rider-$i', i);
        expect(first, second);
        expect(second, third);
      }
    });

    test('colour depends on the index, not on call order', () {
      final ascending = [for (var i = 0; i < 8; i++) colorForMember('u$i', i)];
      final descending = [
        for (var i = 7; i >= 0; i--) colorForMember('u$i', i),
      ].reversed.toList();
      expect(ascending, descending);
    });

    test('distinct riders inside the palette get distinct colours', () {
      final colors = {
        for (var i = 0; i < kGroupRideMemberPalette.length; i++)
          colorForMember('u$i', i),
      };
      expect(colors.length, kGroupRideMemberPalette.length);
    });
  });

  group('colorForMember wrapping', () {
    test('an index past the palette length does not throw', () {
      expect(() => colorForMember('u', kGroupRideMemberPalette.length), returnsNormally);
      expect(() => colorForMember('u', 1000), returnsNormally);
    });

    test('wrapped indices stay inside the palette hue but differ in shade', () {
      final base = colorForMember('u', 0);
      final wrapped = colorForMember('u', kGroupRideMemberPalette.length);
      final twiceWrapped =
          colorForMember('u', kGroupRideMemberPalette.length * 2);
      expect(wrapped, isNot(base));
      expect(twiceWrapped, isNot(wrapped));
    });

    test('wrapping is still deterministic', () {
      final a = colorForMember('u', 137);
      final b = colorForMember('u', 137);
      expect(a, b);
    });

    test('a very large index still produces an opaque colour', () {
      final c = colorForMember('u', 100000);
      expect(c.a, 1.0);
    });
  });

  group('colorForMember with an unknown position', () {
    test('falls back to a stable hash of the userId', () {
      expect(colorForMember('sam', -1), colorForMember('sam', -1));
      expect(colorForMember('sam', -1), colorForMember('sam', -99));
    });

    test('different riders usually land on different fallback colours', () {
      final colors = {
        for (final id in ['sam', 'alex', 'jo', 'kim', 'rae'])
          colorForMember(id, -1),
      };
      expect(colors.length, greaterThan(1));
    });
  });

  group('stableUserIdHash', () {
    test('is deterministic and non-negative', () {
      expect(stableUserIdHash('abc'), stableUserIdHash('abc'));
      expect(stableUserIdHash(''), greaterThanOrEqualTo(0));
      expect(stableUserIdHash('a-very-long-firebase-uid-0123456789'),
          greaterThanOrEqualTo(0));
    });

    test('different ids hash differently', () {
      expect(stableUserIdHash('abc'), isNot(stableUserIdHash('abd')));
    });
  });

  group('onMemberColor', () {
    test('picks a legible foreground for every palette entry', () {
      for (final c in kGroupRideMemberPalette) {
        final fg = onMemberColor(c);
        final contrast =
            (fg.computeLuminance() - c.computeLuminance()).abs();
        expect(contrast, greaterThan(0.2), reason: '$c');
      }
    });
  });
}
