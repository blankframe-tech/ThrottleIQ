import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/auto_detection_policy.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 6, 8);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  group('shouldCloseRecordingDetection (§90.C2)', () {
    const staleAfter = Duration(minutes: 10);

    test('a live detection is left alone while the service runs', () {
      expect(
        shouldCloseRecordingDetection(
          serviceRunning: true,
          lastActivity: at(0),
          now: at(1),
          staleAfter: staleAfter,
        ),
        isFalse,
      );
    });

    test('a quiet detection is closed even with the service running', () {
      expect(
        shouldCloseRecordingDetection(
          serviceRunning: true,
          lastActivity: at(0),
          now: at(11),
          staleAfter: staleAfter,
        ),
        isTrue,
      );
    });

    test('with no service, nothing can append, so it is always closed', () {
      expect(
        shouldCloseRecordingDetection(
          serviceRunning: false,
          lastActivity: at(0),
          now: at(0),
          staleAfter: staleAfter,
        ),
        isTrue,
      );
    });
  });

  group('longestRunClearOfRides (§90.C3)', () {
    List<DateTime> fixes(int from, int to) =>
        [for (var m = from; m <= to; m++) at(m)];
    List<DateTime> clear(List<DateTime> f, List<RideWindow> w) =>
        longestRunClearOfRides<DateTime>(f, (t) => t, w);

    test('no rides: every fix is kept', () {
      final f = fixes(0, 10);
      expect(clear(f, []), f);
    });

    test('a detection entirely inside a manual ride is emptied', () {
      expect(clear(fixes(5, 15), [(start: at(0), end: at(20))]), isEmpty);
    });

    test('a detection overlapping an open (still recording) ride is trimmed',
        () {
      // Rider rode 0–9 undetected by hand, then tapped Start at 10.
      final kept = clear(fixes(0, 30), [(start: at(10), end: null)]);
      expect(kept, fixes(0, 9));
    });

    test('keeps the longer side when a ride splits the detection', () {
      // Detection 0–60, manual ride 10–20: 21–60 is the longer stretch.
      final kept = clear(fixes(0, 60), [(start: at(10), end: at(20))]);
      expect(kept, fixes(21, 60));
    });

    test('a ride that falls between two sparse fixes still breaks the run',
        () {
      final sparse = [at(0), at(1), at(30), at(31), at(32)];
      final kept = clear(sparse, [(start: at(5), end: at(25))]);
      expect(kept, [at(30), at(31), at(32)]);
    });

    test('an already-promoted copy of the same detection removes it entirely',
        () {
      // The double-incrementStats case: the run that inserted this ride died
      // before marking the detection reconciled.
      expect(clear(fixes(0, 10), [(start: at(0), end: at(10))]), isEmpty);
    });
  });

  group('runsClearOfRides (daily summary)', () {
    List<DateTime> fixes(int from, int to) =>
        [for (var m = from; m <= to; m++) at(m)];
    List<List<DateTime>> runs(List<DateTime> f, List<RideWindow> w) =>
        runsClearOfRides<DateTime>(f, (t) => t, w);

    test('no rides: one run of everything', () {
      expect(runs(fixes(0, 5), []), [fixes(0, 5)]);
    });

    test('no fixes: no runs', () {
      expect(runs([], [(start: at(0), end: at(1))]), isEmpty);
    });

    test('keeps the stretch before Start AND after Stop, drops the ride', () {
      // Auto noticed the bike at 0, the rider tapped Start at 3 and Stop at
      // 30, and auto kept going till 35.
      final r = runs(fixes(0, 35), [(start: at(3), end: at(30))]);
      expect(r, [fixes(0, 2), fixes(31, 35)]);
    });

    test('a still-recording ride (open window) swallows everything after it',
        () {
      expect(runs(fixes(0, 10), [(start: at(4), end: null)]), [fixes(0, 3)]);
    });

    test('longestRunClearOfRides is still the longest of these runs', () {
      final w = [(start: at(3), end: at(30))];
      expect(longestRunClearOfRides<DateTime>(fixes(0, 35), (t) => t, w),
          fixes(31, 35));
    });
  });
}
