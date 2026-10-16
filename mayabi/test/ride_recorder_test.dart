import 'dart:convert';

import 'package:test/test.dart';
import 'package:throttleiq_mayabi/throttleiq_mayabi.dart';

/// A rider heading east along a Dhaka street (Banani, lat 23.79) at
/// [speedMs], one fix per second. Returns the time after the last fix.
DateTime ride(RideRecorder r, DateTime from, Duration d, double speedMs,
    {double lat = 23.79, required List<double> lng}) {
  var t = from;
  final degPerM = 1 / (111320 * 0.9150); // cos(23.79°)
  for (var s = 0; s < d.inSeconds; s++) {
    lng[0] += speedMs * degPerM;
    r.addLocation(lat: lat, lng: lng[0], speedMs: speedMs, accuracyM: 5, at: t);
    t = t.add(const Duration(seconds: 1));
  }
  return t;
}

void main() {
  final t0 = DateTime.utc(2026, 10, 17, 3); // 09:00 Dhaka

  test('legs, segments, report JSON for a pickup → trip → home ride', () {
    final r = RideRecorder(rideId: 'trip_1', riderRef: 'mayabi-42');
    final lng = [90.40];
    var t = ride(r, t0, const Duration(seconds: 60), 8, lng: lng);
    r.phase = RidePhase.onTrip;
    t = ride(r, t, const Duration(seconds: 120), 8, lng: lng);
    r.phase = RidePhase.toHome;
    ride(r, t, const Duration(seconds: 60), 8, lng: lng);

    final rep = r.finish(weatherCode: 61);
    expect(rep.pickupKm, closeTo(0.48, 0.03));
    expect(rep.tripKm, closeTo(0.96, 0.05));
    expect(rep.homeKm, closeTo(0.48, 0.03));
    expect(
        rep.distanceKm, closeTo(rep.pickupKm + rep.tripKm + rep.homeKm, 1e-9));
    expect(rep.avgSpeedKmh, closeTo(28.8, 0.5));
    expect(rep.movingSeconds, greaterThan(200));
    expect(rep.segments.length, greaterThan(8));
    expect(
        rep.segments.every(
            (s) => s.segmentId.length == 7 && s.segmentId.startsWith('wh0')),
        isTrue);
    expect(rep.segments.every((s) => (s.avgSpeedKmh - 28.8).abs() < 1), isTrue);
    expect(rep.eventScore, 100);

    final j = rep.toJson();
    expect(j['returnKm'], rep.homeKm);
    expect(j['weatherCode'], 61);
    expect(j['startedAt'], '2026-10-17T03:00:00.000Z');
    expect(j.containsKey('points'), isFalse,
        reason: 'no raw track leaves the phone');
    final back =
        RideReport.fromJson(jsonDecode(jsonEncode(j)) as Map<String, Object?>);
    expect(back.toJson(), j);
  });

  test('a hard stop is counted on the GPS path before the IMU is calibrated',
      () {
    final r = RideRecorder(rideId: 'b', riderRef: 'm');
    final lng = [90.40];
    var t = ride(r, t0, const Duration(seconds: 10), 10, lng: lng);
    r.addLocation(
        lat: 23.79, lng: lng[0] + 0.00002, speedMs: 2, accuracyM: 5, at: t);
    expect(r.finish().hardBrakes, greaterThanOrEqualTo(1));
  });

  test('poor, out-of-order and non-finite fixes are ignored', () {
    final r = RideRecorder(rideId: 'x', riderRef: 'm');
    r.addLocation(lat: 23.79, lng: 90.40, speedMs: 5, accuracyM: 5, at: t0);
    r.addLocation(
        lat: 23.80,
        lng: 90.50,
        speedMs: 5,
        accuracyM: 80,
        at: t0.add(const Duration(seconds: 1)));
    r.addLocation(lat: 23.80, lng: 90.50, speedMs: 5, accuracyM: 5, at: t0);
    r.addLocation(
        lat: double.nan,
        lng: 90.50,
        speedMs: 5,
        accuracyM: 5,
        at: t0.add(const Duration(seconds: 2)));
    expect(r.distanceKm, 0);
  });

  test('an unusual stop is raised once, mid-trip only', () {
    final events = <SafetyEvent>[];
    final r =
        RideRecorder(rideId: 's', riderRef: 'm', onSafetyEvent: events.add);
    void sit(DateTime from, int minutes) {
      for (var s = 0; s <= minutes * 60; s += 10) {
        r.addLocation(
            lat: 23.79,
            lng: 90.40,
            speedMs: 0,
            accuracyM: 5,
            at: from.add(Duration(seconds: s)));
      }
    }

    sit(t0, 12); // waiting for the passenger: fine
    expect(events, isEmpty);
    r.phase = RidePhase.onTrip;
    sit(t0.add(const Duration(minutes: 13)), 15);
    expect(events.map((e) => e.kind), [SafetyEventKind.unusualStop]);
    expect(events.single.lat, 23.79);
  });

  test(
      'impact, stop, stillness raises one crash event (the app\'s tier-2 scenario)',
      () {
    var now = t0;
    final events = <SafetyEvent>[];
    final r = RideRecorder(
        rideId: 'c',
        riderRef: 'm',
        onSafetyEvent: events.add,
        clock: () => now);
    const period = Duration(milliseconds: 50);
    DateTime feed(DateTime from, Duration d, double Function(int i) mag) {
      var t = from;
      var i = 0;
      while (t.isBefore(from.add(d))) {
        now = t;
        r.addUserAccel(mag(i), 0, 0, at: t);
        t = t.add(period);
        i++;
      }
      return t;
    }

    final crashAt = t0.add(const Duration(seconds: 10));
    final lng = [90.40];
    for (var s = 3; s >= 0; s--) {
      final at = crashAt.subtract(Duration(seconds: s));
      now = at;
      lng[0] += 15 / (111320 * 0.915);
      r.addLocation(lat: 23.79, lng: lng[0], speedMs: 15, accuracyM: 5, at: at);
    }
    feed(crashAt.subtract(const Duration(seconds: 3)),
        const Duration(seconds: 3), (i) => i.isEven ? 0.8 : 1.2);
    var t = feed(crashAt, const Duration(milliseconds: 100), (_) => 60);
    t = feed(t, const Duration(seconds: 1), (i) => i.isEven ? 12 : 3);
    now = crashAt.add(const Duration(seconds: 2));
    r.addLocation(
        lat: 23.79,
        lng: lng[0] + 0.000005,
        speedMs: 0.4,
        accuracyM: 5,
        at: now);
    feed(t, const Duration(seconds: 11), (i) => i.isEven ? 0.05 : 0.1);

    expect(events.map((e) => e.kind), [SafetyEventKind.crash]);
    final rep = r.finish();
    expect(rep.impacts, hasLength(1));
    expect(rep.impacts.single.tier, 2);
    expect(rep.impacts.single.speedBeforeKmh, closeTo(54, 0.1));

    final answered = rep.withFellAnswers([true]);
    expect(answered.impacts.single.riderSaysFell, isTrue);
    expect(() => rep.withFellAnswers([]), throwsArgumentError);
  });

  test('crashDetection off still records the impact but raises nothing', () {
    var now = t0;
    final events = <SafetyEvent>[];
    final r = RideRecorder(
        rideId: 'c',
        riderRef: 'm',
        onSafetyEvent: events.add,
        crashDetection: false,
        clock: () => now);
    r.addLocation(lat: 23.79, lng: 90.40, speedMs: 15, accuracyM: 5, at: now);
    for (var i = 0; i < 2; i++) {
      now = now.add(const Duration(milliseconds: 50));
      r.addUserAccel(60, 0, 0, at: now);
    }
    expect(events, isEmpty);
  });

  test('segments outside Bangladesh are dropped before upload', () {
    expect(inBangladesh('wh0r3qs'), isTrue); // Dhaka
    expect(inBangladesh('u4pruyd'), isFalse); // Denmark
  });
}
