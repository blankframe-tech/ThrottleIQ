import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/features/social/domain/utilities/privacy_zone_clipper.dart';
import 'package:throttleiq/features/social/domain/utilities/privacy_zone_salt.dart';

void main() {
  group('PrivacyZoneClipper', () {
    test('clips short polylines completely', () {
      final polyline = [
        const LatLng(40.7128, -74.0060), // NYC
        const LatLng(40.7130, -74.0058),
        const LatLng(40.7132, -74.0056),
      ];

      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('clips first 200m from polyline', () {
      // Create a polyline with points ~100m apart
      // ~800m ride: clipping 200m from each end must leave a middle.
      final polyline = <LatLng>[
        for (int i = 0; i <= 8; i++) LatLng(0.0009 * i, 0.0), // ~100m apart
      ];

      final clipped = PrivacyZoneClipper.clipPolyline(polyline);

      // Should have at least 2 points left
      expect(clipped.isNotEmpty, true);
      // First clipped point should be around index 2-3
      expect(clipped.length, lessThan(polyline.length));
    });

    test('clips last 200m from polyline', () {
      // Create a polyline
      // ~800m ride: clipping 200m from each end must leave a middle.
      final polyline = <LatLng>[
        for (int i = 0; i <= 8; i++) LatLng(0.0009 * i, 0.0), // ~100m apart
      ];

      final clipped = PrivacyZoneClipper.clipPolyline(polyline);

      // Last clipped point should not be the last point
      expect(clipped.isNotEmpty, true);
      expect(
        clipped.last.latitude != polyline.last.latitude ||
            clipped.last.longitude != polyline.last.longitude,
        true,
      );
    });

    test('(a) GPS drift near home cannot walk the clip off the doorstep', () {
      // 300+ m of accumulated jitter, all within 10 m of the start (the
      // bike idling in the driveway). The old path-distance clipper counted
      // this as "200 m ridden" and started the shared line right at home.
      const home = LatLng(23.8103, 90.4125);
      final drift = <LatLng>[
        for (var k = 0; k < 40; k++)
          LatLng(
            home.latitude + (k.isEven ? 0.00008 : -0.00008), // ~9 m
            home.longitude,
          ),
      ];
      final ride = <LatLng>[
        home,
        ...drift,
        // Then 6 km due north, a point every ~50 m.
        for (var k = 1; k <= 120; k++)
          LatLng(home.latitude + 0.00045 * k, home.longitude),
      ];
      var drifted = 0.0;
      for (var k = 1; k <= drift.length; k++) {
        drifted += haversineMetersLatLng(ride[k - 1], ride[k]);
      }
      expect(drifted, greaterThan(300));

      for (final seed in [
        0,
        7,
        149,
        PrivacyZoneClipper.seedForUid('rider-1')
      ]) {
        final r = PrivacyZoneClipper.radiusFor(seed);
        final clear = r - PrivacyZoneClipper.offsetMetersFor(seed);
        final clipped = PrivacyZoneClipper.clipPolyline(ride, seed: seed);
        expect(clipped, isNotEmpty);
        for (final p in clipped) {
          for (final end in [home, ride.last]) {
            final centre = PrivacyZoneClipper.hiddenCentre(end, seed);
            expect(haversineMetersLatLng(p, centre), greaterThan(r));
            expect(haversineMetersLatLng(p, end), greaterThan(clear - 1));
          }
        }
      }
    });

    test('(b) a straight 5 km ride loses 200-1600 m at each end', () {
      // ~5 km due north at ~11 m spacing.
      final ride = <LatLng>[
        for (var k = 0; k <= 450; k++) LatLng(0.0001 * k, 0.0),
      ];
      for (final uid in ['alice', 'bob', 'carol-uid-xyz']) {
        final seed = PrivacyZoneClipper.seedForUid(uid);
        final clipped = PrivacyZoneClipper.clipPolyline(ride, seed: seed);
        final r = PrivacyZoneClipper.radiusFor(seed);
        final offset = PrivacyZoneClipper.offsetMetersFor(seed);
        final trimmedStart = haversineMetersLatLng(ride.first, clipped.first);
        final trimmedEnd = haversineMetersLatLng(clipped.last, ride.last);
        for (final trimmed in [trimmedStart, trimmedEnd]) {
          // The circle's centre is offset from the end, so a straight line
          // loses between r - offset and r + offset.
          expect(trimmed, greaterThanOrEqualTo(r - offset - 1));
          expect(trimmed, greaterThanOrEqualTo(200));
          expect(trimmed, lessThanOrEqualTo(r + offset + 12)); // + one step
        }
      }
    });

    test('decoy and radius are stable per rider and bounded', () {
      expect(
        PrivacyZoneClipper.seedForUid('abc123'),
        PrivacyZoneClipper.seedForUid('abc123'),
      );
      final radii = {
        for (var i = 0; i < 200; i++)
          PrivacyZoneClipper.radiusFor(PrivacyZoneClipper.seedForUid('uid$i')),
      };
      expect(radii.length, greaterThan(50)); // actually varies across riders
      for (final r in radii) {
        expect(r, inInclusiveRange(330, 949));
      }
      final bearings = <double>{};
      for (var i = 0; i < 200; i++) {
        final seed = PrivacyZoneClipper.seedForUid('uid$i');
        final offset = PrivacyZoneClipper.offsetMetersFor(seed);
        expect(offset, inInclusiveRange(130, 600));
        // The true endpoint always sits at least 200 m inside the circle.
        expect(PrivacyZoneClipper.radiusFor(seed) - offset,
            greaterThanOrEqualTo(200));
        const end = LatLng(23.8, 90.4);
        expect(
            haversineMetersLatLng(
                end, PrivacyZoneClipper.hiddenCentre(end, seed)),
            closeTo(offset, 1));
        bearings.add(PrivacyZoneClipper.bearingFor(seed));
      }
      expect(bearings.length, greaterThan(100));
    });

    test('keeps a loop ride\'s middle even when it passes near home', () {
      // Out 1 km north, back to the start. Only leading/trailing runs are
      // trimmed, so the far half of the loop survives.
      final ride = <LatLng>[
        for (var k = 0; k <= 100; k++) LatLng(0.00009 * k, 0.0),
        for (var k = 99; k >= 0; k--) LatLng(0.00009 * k, 0.0001),
      ];
      final clipped = PrivacyZoneClipper.clipPolyline(ride);
      expect(clipped, isNotEmpty);
      expect(
        clipped.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        closeTo(0.009, 1e-9),
      );
    });

    test('empty polyline returns empty', () {
      final polyline = <LatLng>[];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('single point polyline returns empty', () {
      final polyline = [const LatLng(40.7128, -74.0060)];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('two point polyline returns empty', () {
      final polyline = [
        const LatLng(40.7128, -74.0060),
        const LatLng(40.7130, -74.0058),
      ];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });
  });

  group('triangulation resistance', () {
    // An attacker lists a rider's public shares, takes the first visible
    // point of each and fits a circle. With a hidden circle centred on the
    // start itself the fit lands on the start (median error ~3 m). The
    // circle must be centred on a secret decoy instead.
    test('a circle fit through 6 shares misses the start for >=95% of riders',
        () {
      final rng = math.Random.secure();
      const riders = 500;
      const sharesPerRider = 6;
      var far = 0;
      for (var rider = 0; rider < riders; rider++) {
        final salt = rng.nextInt(1 << 31); // as PrivacyZoneSalt creates it
        final home = LatLng(
          23.70 + rng.nextDouble() * 0.2,
          90.35 + rng.nextDouble() * 0.2,
        );
        final anchors = <LatLng>[];
        final firsts = <LatLng>[];
        for (var s = 0; s < sharesPerRider; s++) {
          firsts.add(
              _share(_rideFrom(_jitter(home, rng), rng), salt, anchors).first);
        }
        if (haversineMetersLatLng(_fitCircleCentre(firsts), home) > 100) {
          far++;
        }
      }
      expect(far / riders, greaterThanOrEqualTo(0.95),
          reason: 'only $far of $riders fits missed home by >100 m');
    });

    // The attacker also knows one place the rider goes (a workplace), so
    // can fit the decoy there and work out its offset. With one offset per
    // rider, that offset applied to the home decoy lands on home. Seeds are
    // per place, so it must not.
    test(
        'an offset learned at a known workplace does not find home '
        '(>=95% of riders)', () {
      final rng = math.Random.secure();
      const riders = 1000;
      var far = 0, farIfOneSeed = 0;
      for (var rider = 0; rider < riders; rider++) {
        final salt = rng.nextInt(1 << 31);
        final home = LatLng(
          23.70 + rng.nextDouble() * 0.2,
          90.35 + rng.nextDouble() * 0.2,
        );
        final work = const Distance(calculator: Haversine()).offset(
            home, 3000 + rng.nextDouble() * 7000, rng.nextDouble() * 360 - 180);
        final outOfHome = [
          for (var s = 0; s < 6; s++) _rideFrom(_jitter(home, rng), rng),
        ];
        final intoWork = [
          for (var s = 0; s < 6; s++)
            _rideFrom(_jitter(work, rng), rng).reversed.toList(),
        ];
        double attack(List<LatLng> Function(List<LatLng>) share) {
          final decoyAtWork =
              _fitCircleCentre([for (final t in intoWork) share(t).last]);
          final decoyAtHome =
              _fitCircleCentre([for (final t in outOfHome) share(t).first]);
          final guess = LatLng(
            decoyAtHome.latitude - (decoyAtWork.latitude - work.latitude),
            decoyAtHome.longitude - (decoyAtWork.longitude - work.longitude),
          );
          return haversineMetersLatLng(guess, home);
        }

        final anchors = <LatLng>[];
        if (attack((t) => _share(t, salt, anchors)) > 100) far++;
        // Control: the same attack against one seed per rider must work,
        // or this test proves nothing.
        if (attack((t) => PrivacyZoneClipper.clipForSharing(t, seed: salt)) >
            100) {
          farIfOneSeed++;
        }
      }
      expect(farIfOneSeed / riders, lessThan(0.2),
          reason: 'control: $farIfOneSeed of $riders missed with one seed');
      expect(far / riders, greaterThanOrEqualTo(0.95),
          reason: 'only $far of $riders guesses missed home by >100 m');
    });

    test('no shared point is within 200 m of the true start or end', () {
      final rng = math.Random(1);
      for (var k = 0; k < 200; k++) {
        final salt = rng.nextInt(1 << 31);
        final ride = _rideFrom(const LatLng(23.8, 90.4), rng);
        for (final p in _share(ride, salt, [])) {
          expect(haversineMetersLatLng(p, ride.first), greaterThan(200));
          expect(haversineMetersLatLng(p, ride.last), greaterThan(200));
        }
      }
    });
  });
}

const _mPerDegLat = 111320.0;

/// What the app writes for [track]: per-place seeds, as
/// `RideShareRepository` gets them from `PrivacyZoneSalt.seedsFor`.
List<LatLng> _share(List<LatLng> track, int salt, List<LatLng> anchors) {
  final (start, end) =
      PrivacyZoneSalt.seedsWith(salt, anchors, track.first, track.last);
  return PrivacyZoneClipper.clipForSharing(track, seed: start, endSeed: end);
}

/// [p] moved up to ~15 m, like a GPS fix at the same parking spot.
LatLng _jitter(LatLng p, math.Random rng) => LatLng(
    p.latitude + (rng.nextDouble() - 0.5) * 0.00027,
    p.longitude + (rng.nextDouble() - 0.5) * 0.00027);

/// A ~6 km ride out of [home] on a random heading, a point every ~15 m,
/// with a gentle random wander so it is not a ruler-straight line.
List<LatLng> _rideFrom(LatLng home, math.Random rng) {
  final mPerDegLng = _mPerDegLat * math.cos(home.latitude * math.pi / 180);
  var heading = rng.nextDouble() * 2 * math.pi;
  var x = 0.0, y = 0.0;
  final pts = <LatLng>[home];
  for (var k = 0; k < 400; k++) {
    heading += (rng.nextDouble() - 0.5) * 0.15;
    x += 15 * math.sin(heading);
    y += 15 * math.cos(heading);
    pts.add(LatLng(
        home.latitude + y / _mPerDegLat, home.longitude + x / mPerDegLng));
  }
  return pts;
}

/// Algebraic (Kasa) least-squares circle fit; returns the centre.
LatLng _fitCircleCentre(List<LatLng> pts) {
  final lat0 = pts.first.latitude, lng0 = pts.first.longitude;
  final mPerDegLng = _mPerDegLat * math.cos(lat0 * math.pi / 180);
  // Solve [x y 1]·[D E F]ᵀ = -(x²+y²) in least squares (3x3 normal eqs).
  final a = List.generate(3, (_) => List<double>.filled(4, 0));
  for (final p in pts) {
    final x = (p.longitude - lng0) * mPerDegLng;
    final y = (p.latitude - lat0) * _mPerDegLat;
    final row = [x, y, 1.0];
    final rhs = -(x * x + y * y);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        a[i][j] += row[i] * row[j];
      }
      a[i][3] += row[i] * rhs;
    }
  }
  for (var c = 0; c < 3; c++) {
    var piv = c;
    for (var r = c + 1; r < 3; r++) {
      if (a[r][c].abs() > a[piv][c].abs()) piv = r;
    }
    final t = a[c];
    a[c] = a[piv];
    a[piv] = t;
    for (var r = 0; r < 3; r++) {
      if (r == c || a[c][c] == 0) continue;
      final f = a[r][c] / a[c][c];
      for (var k = c; k < 4; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  final d = a[0][3] / a[0][0], e = a[1][3] / a[1][1];
  return LatLng(lat0 + (-e / 2) / _mPerDegLat, lng0 + (-d / 2) / mPerDegLng);
}
