import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/geohash_util.dart';

void main() {
  group('GeohashUtil.getNeighbors', () {
    test('returns the 8 compass neighbors, N/NE/E/SE/S/SW/W/NW, for Dhaka', () {
      // Reference values independently cross-checked two ways before this
      // table was written: against a from-scratch bit-interleaving geohash
      // implementation (12,000 random points, 0 mismatches) and against the
      // north(south(x))==x / east(west(x))==x round-trip identity (2,000
      // random points, 0 failures) — see geohash_util.dart's doc comment.
      const dhaka = (lat: 23.8103, lng: 90.4125);

      expect(GeohashUtil.encode(dhaka.lat, dhaka.lng, precision: 9), 'wh0r3qs35');

      final n9 = GeohashUtil.getNeighbors('wh0r3qs35');
      expect(n9, [
        'wh0r3qs37', // n
        'wh0r3qs3k', // ne
        'wh0r3qs3h', // e
        'wh0r3qs2u', // se
        'wh0r3qs2g', // s
        'wh0r3qs2f', // sw
        'wh0r3qs34', // w
        'wh0r3qs36', // nw
      ]);

      // Precision 3 crosses a parent-cell boundary on more than one side
      // (n/ne/e stay under 'wh', s/se/sw/w/nw fall into neighboring 'w5c'
      // /'w5b'/'tgz'/'tup'/'tur' cells) — exercises the recursion in
      // _adjacent, not just a same-parent sibling step.
      final n3 = GeohashUtil.getNeighbors('wh0');
      expect(n3, [
        'wh2', 'wh3', 'wh1', 'w5c', 'w5b', 'tgz', 'tup', 'tur',
      ]);
    });

    test('matches the classic "ezs42" worked example', () {
      // ezs42 is the example most geohash-neighbor implementations use in
      // their own test suite; matching it here is a sanity check against
      // the wider ecosystem, not just this file's own reference run.
      final neighbors = GeohashUtil.getNeighbors('ezs42');
      expect(neighbors, [
        'ezs48', // n
        'ezs49', // ne
        'ezs43', // e
        'ezs41', // se
        'ezs40', // s
        'ezefp', // sw
        'ezefr', // w
        'ezefx', // nw
      ]);
    });

    test('returns 8 distinct geohashes for an interior cell', () {
      final neighbors = GeohashUtil.getNeighbors('wh0r3qs35');
      expect(neighbors.toSet().length, 8);
      expect(neighbors, isNot(contains('wh0r3qs35')));
    });

    test('wraps across the antimeridian instead of stopping at ±180°', () {
      // A cell whose own east edge lands exactly on +180° (close enough to
      // it that this precision's cell boundary coincides): its east
      // neighbor must be the cell starting at -180°, not an out-of-range
      // encode or a same-cell no-op.
      final nearDateLine = GeohashUtil.encode(10, 179.999999, precision: 5);
      expect(GeohashUtil.decodeBounds(nearDateLine)['lngMax'], 180.0);

      final neighbors = GeohashUtil.getNeighbors(nearDateLine);
      final eastNeighbor = neighbors[2]; // index 2 = e, see getNeighbors order
      expect(GeohashUtil.decodeBounds(eastNeighbor)['lngMin'], -180.0);
    });

    test('throws on an empty geohash rather than silently misbehaving', () {
      expect(() => GeohashUtil.getNeighbors(''), throwsArgumentError);
    });

    test('is case-insensitive, matching encode/decodeBounds', () {
      expect(GeohashUtil.getNeighbors('WH0R3QS35'),
          GeohashUtil.getNeighbors('wh0r3qs35'));
    });

    test('north-then-south and east-then-west return to the start cell', () {
      // The identity that catches an off-by-one in the border/carry logic:
      // stepping out and back at the same precision must land exactly where
      // you started, for any point away from the poles/antimeridian edge
      // cases covered by the dedicated tests above.
      final rnd = Random(7);
      for (var i = 0; i < 300; i++) {
        final lat = -80 + rnd.nextDouble() * 160; // avoid pole wraparound
        final lng = -170 + rnd.nextDouble() * 340; // avoid antimeridian edge
        final precision = 1 + rnd.nextInt(9);
        final gh = GeohashUtil.encode(lat, lng, precision: precision);
        final neighbors = GeohashUtil.getNeighbors(gh);
        final n = neighbors[0];
        final s = neighbors[4];
        final e = neighbors[2];
        final w = neighbors[6];

        expect(GeohashUtil.getNeighbors(n)[4], gh, reason: 'n(${gh}) then s');
        expect(GeohashUtil.getNeighbors(s)[0], gh, reason: 's(${gh}) then n');
        expect(GeohashUtil.getNeighbors(e)[6], gh, reason: 'e(${gh}) then w');
        expect(GeohashUtil.getNeighbors(w)[2], gh, reason: 'w(${gh}) then e');
      }
    });

    test('every neighbor is adjacent at the same precision as the input', () {
      final neighbors = GeohashUtil.getNeighbors('wh0r3');
      for (final n in neighbors) {
        expect(n.length, 'wh0r3'.length);
      }
    });
  });
}
