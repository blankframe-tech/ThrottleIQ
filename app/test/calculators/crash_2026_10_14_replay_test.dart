import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';

/// The 14 Oct 2026 crash (a real field crash; its full analysis is kept
/// local, not in git): a walking-pace fall at a rail crossing that nothing
/// in the app saw.
///
/// The GPS fixes below are the ride's real saved points, 21:27–21:31 local
/// (UTC+6), from the phone's database. No accelerometer data exists for it,
/// so the impact and what the phone did afterwards are simulated, for the
/// five situations in the crash-detection plan §2. Two readings of the
/// timing are replayed: a fall right at the stop (21:28:48–52), and a
/// tip-over from a standstill when the iPhone logged "Lift detected"
/// (21:28:58.9).
const _fixes = <(String, double)>[
  ('2026-10-14T15:27:00.000Z', 9.8130),
  ('2026-10-14T15:27:05.000Z', 8.7362),
  ('2026-10-14T15:27:10.000Z', 9.4880),
  ('2026-10-14T15:27:15.000Z', 9.6014),
  ('2026-10-14T15:27:20.000Z', 9.4329),
  ('2026-10-14T15:27:25.000Z', 11.7216),
  ('2026-10-14T15:27:28.000Z', 10.3328),
  ('2026-10-14T15:27:29.000Z', 9.9916),
  ('2026-10-14T15:27:30.000Z', 9.7370),
  ('2026-10-14T15:27:31.000Z', 9.0932),
  ('2026-10-14T15:27:36.000Z', 6.9720),
  ('2026-10-14T15:27:41.000Z', 6.0126),
  ('2026-10-14T15:27:42.000Z', 6.6537),
  ('2026-10-14T15:27:43.000Z', 6.8699),
  ('2026-10-14T15:27:48.000Z', 8.9591),
  ('2026-10-14T15:27:53.000Z', 8.2639),
  ('2026-10-14T15:27:58.000Z', 8.0658),
  ('2026-10-14T15:28:03.000Z', 6.5730),
  ('2026-10-14T15:28:04.000Z', 6.5164),
  ('2026-10-14T15:28:08.000Z', 6.3990),
  ('2026-10-14T15:28:09.000Z', 6.6349),
  ('2026-10-14T15:28:11.000Z', 6.9157),
  ('2026-10-14T15:28:13.000Z', 7.4674),
  ('2026-10-14T15:28:14.000Z', 6.8234),
  ('2026-10-14T15:28:15.000Z', 6.3758),
  ('2026-10-14T15:28:16.000Z', 5.4478),
  ('2026-10-14T15:28:17.000Z', 5.9946),
  ('2026-10-14T15:28:18.000Z', 5.6225),
  ('2026-10-14T15:28:24.999Z', 2.9703),
  ('2026-10-14T15:28:28.999Z', 1.8674),
  ('2026-10-14T15:28:31.999Z', 2.0484),
  ('2026-10-14T15:28:40.999Z', 1.1570),
  ('2026-10-14T15:28:42.999Z', 1.4369),
  ('2026-10-14T15:28:46.999Z', 3.5415),
  ('2026-10-14T15:29:01.999Z', 0.0000),
  ('2026-10-14T15:29:06.999Z', 0.0000),
  ('2026-10-14T15:29:21.999Z', 0.0000),
  ('2026-10-14T15:29:24.999Z', 1.6386),
  ('2026-10-14T15:29:26.999Z', 1.5881),
  ('2026-10-14T15:29:30.999Z', 1.5006),
  ('2026-10-14T15:29:32.999Z', 0.0000),
  ('2026-10-14T15:29:33.999Z', 0.0000),
  ('2026-10-14T15:29:39.999Z', 0.0000),
  ('2026-10-14T15:29:46.999Z', 0.0000),
  ('2026-10-14T15:30:00.999Z', 0.0000),
  ('2026-10-14T15:30:24.000Z', 1.4316),
  ('2026-10-14T15:30:52.999Z', 0.0000),
  ('2026-10-14T15:30:59.999Z', 0.0000),
];

class _Situation {
  const _Situation(this.name,
      {required this.mount,
      required this.postSigma,
      required this.rotationDeg,
      this.thrown = false});
  final String name;
  final bool mount;
  final double postSigma; // m/s², per axis, after the impact
  final double rotationDeg; // where the gravity vector ends up
  final bool thrown; // free fall before the impact (out of a pocket)
}

const _situations = [
  _Situation('A pocket, phone thrown out, lies still',
      mount: false, postSigma: 0.03, rotationDeg: 75, thrown: true),
  _Situation('B pocket, rider on side under the bike, moving',
      mount: false, postSigma: 1.0, rotationDeg: 90),
  _Situation('C pocket, rider on back, moving',
      mount: false, postSigma: 1.0, rotationDeg: 15),
  _Situation('D mount, bike on its side, engine idling',
      mount: true, postSigma: 1.0, rotationDeg: 85),
  _Situation('E mount, bike on its side, engine off',
      mount: true, postSigma: 0.03, rotationDeg: 85),
];

/// Replays 21:27:30–21:29:40 local through a fresh detector; returns what it
/// resolved. [impactAt] null = no impact at all (the control).
List<ImpactCandidate> _replay(_Situation s, DateTime? impactAt,
    {double peakG = 5}) {
  final detector = ImpactDetector();
  final rng = math.Random(impactAt?.millisecondsSinceEpoch ?? 1);
  double n(double sigma) {
    final u1 = rng.nextDouble().clamp(1e-9, 1.0), u2 = rng.nextDouble();
    return sigma * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  const g = 9.81;
  final rot = s.rotationDeg * math.pi / 180;
  final events = <(DateTime, int, List<double>)>[];
  final start = DateTime.parse('2026-10-14T15:27:30Z');
  final end = DateTime.parse('2026-10-14T15:29:40Z');
  for (var t = start;
      t.isBefore(end);
      t = t.add(const Duration(milliseconds: 20))) {
    final dt =
        impactAt == null ? -1e9 : t.difference(impactAt).inMicroseconds / 1e6;
    final ridingSigma = s.mount ? 1.5 : 0.6;
    List<double> user;
    List<double> grav;
    if (dt < -0.25 || (!s.thrown && dt < 0)) {
      user = [n(ridingSigma), n(ridingSigma), n(ridingSigma)];
      grav = [n(0.3), n(0.3), g + n(0.3)];
    } else if (dt < 0) {
      user = [0, 0, -g]; // falling: no gravity felt
      grav = [0, 0, 0.2];
    } else if (dt < 0.04) {
      user = [peakG * g, 0, 0];
      grav = [peakG * g, 0, g];
    } else if (dt < 0.8) {
      final m = (1.5 - dt) * g; // tumbling, sliding
      user = [n(m / 2), n(m / 2), n(m / 2)];
      grav = [n(4), n(4), g * 0.5 + n(4)];
    } else {
      user = [n(s.postSigma), n(s.postSigma), n(s.postSigma)];
      grav = [0, g * math.sin(rot) + n(0.1), g * math.cos(rot) + n(0.1)];
    }
    events.add((t, 0, user));
    events.add((t, 1, grav));
  }
  for (final (iso, v) in _fixes) {
    final t = DateTime.parse(iso);
    if (t.isBefore(start) || t.isAfter(end)) continue;
    events.add((t, 2, [v]));
  }
  events.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (t, kind, v) in events) {
    switch (kind) {
      case 0:
        detector.addSample(t, v[0], v[1], v[2]);
      case 1:
        detector.addGravitySample(t, v[0], v[1], v[2]);
      default:
        detector.addSpeed(t, v[0]);
    }
  }
  return detector.candidates;
}

void main() {
  group('fall right at the stop (21:28:48–52)', () {
    for (final s in _situations) {
      for (final local in ['15:28:48.000', '15:28:50.000', '15:28:52.500']) {
        test('${s.name} @ $local UTC: asked about (tier 1), no alarm', () {
          final out = _replay(s, DateTime.parse('2026-10-14T${local}Z'));
          final c = out.firstWhere(
              (c) => c.spikeAt.isAfter(DateTime.parse('2026-10-14T15:28:47Z')));
          expect(c.tier, 1);
          expect(c.reason, ImpactReason.speedDrop);
          expect(c.speedBeforeMs, closeTo(3.54, 0.01),
              reason: 'the 12.7 km/h fix at 21:28:47, within 10 s');
        });
      }
    }
  });

  group('tip-over from a standstill at the "Lift detected" moment', () {
    final at = DateTime.parse('2026-10-14T15:28:58.900Z');
    for (final s in _situations) {
      final turned = s.rotationDeg >= 60;
      test('${s.name}: ${turned ? 'tier 1 (tip-over)' : 'tier 0 (blind spot)'}',
          () {
        final c =
            _replay(s, at, peakG: 3).firstWhere((c) => !c.spikeAt.isBefore(at));
        if (turned) {
          expect(c.tier, 1);
          expect(c.reason, ImpactReason.tipOver);
        } else {
          // Lying on the back barely turns a thigh pocket, and the bike had
          // already stopped: neither rule can see it. The after-ride
          // "Report a crash" button exists for exactly this.
          expect(c.tier, 0);
        }
      });
    }
  });

  test('control: the same ride with no impact logs nothing', () {
    for (final s in _situations) {
      expect(_replay(s, null), isEmpty, reason: s.name);
    }
  });
}
