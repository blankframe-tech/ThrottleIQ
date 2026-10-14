import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_window_recorder.dart';

void main() {
  final spike = DateTime.utc(2026, 10, 14, 15, 28, 58, 900);

  /// 30 s of 50 Hz samples on all three streams around [spike].
  ImpactWindowRecorder filled() {
    final r = ImpactWindowRecorder();
    var t = spike.subtract(const Duration(seconds: 20));
    while (t.isBefore(spike.add(const Duration(seconds: 10)))) {
      final s = t.difference(spike).inMilliseconds / 1000;
      r.addRaw(t, 0, 0, 9.81 + s);
      r.addUser(t, s, -s, 0.5);
      r.addGyro(t, 0.001 * s, 0, -1.234);
      t = t.add(const Duration(milliseconds: 20));
    }
    return r;
  }

  test('round-trips the 12 s around an impact', () {
    final w = ImpactWindowRecorder.decode(filled().encodeWindow(spike)!);
    expect(w.spikeAt, spike);
    for (final stream in [w.raw, w.user, w.gyro]) {
      expect(stream.first.offsetMs, greaterThanOrEqualTo(-4000));
      expect(stream.last.offsetMs, lessThanOrEqualTo(8000));
      expect(stream.length, inInclusiveRange(599, 601),
          reason: '12 s at 50 Hz');
    }
    final at0 = w.user.firstWhere((s) => s.offsetMs == 0);
    expect(at0.x, 0);
    expect(at0.z, 0.5);
    final later = w.user.firstWhere((s) => s.offsetMs == 2000);
    expect(later.x, closeTo(2, 0.01));
    expect(w.gyro.first.z, closeTo(-1.234, 0.001));
  });

  test('a 12 s window is small enough for the Spark budget', () {
    final bytes = filled().encodeWindow(spike)!;
    expect(bytes.length, lessThan(16 * 1024));
  });

  test('null when nothing was recorded near the impact', () {
    expect(ImpactWindowRecorder().encodeWindow(spike), isNull);
    final r = ImpactWindowRecorder()
      ..addUser(spike.subtract(const Duration(seconds: 5)), 1, 1, 1);
    expect(r.encodeWindow(spike), isNull);
  });

  test('keeps only the last 30 s', () {
    final r = ImpactWindowRecorder();
    r.addUser(spike.subtract(const Duration(seconds: 40)), 1, 0, 0);
    r.addUser(spike, 2, 0, 0);
    final w = ImpactWindowRecorder.decode(
        r.encodeWindow(spike, before: const Duration(seconds: 60))!);
    expect(w.user.single.x, 2);
  });

  test('values beyond int16 are clamped, non-finite samples dropped', () {
    final r = ImpactWindowRecorder()
      ..addUser(spike, 9999, -9999, 0)
      ..addUser(spike.add(const Duration(milliseconds: 20)), double.nan, 0, 0);
    final w = ImpactWindowRecorder.decode(r.encodeWindow(spike)!);
    expect(w.user, hasLength(1));
    expect(w.user.single.x, closeTo(327.67, 0.001));
    expect(w.user.single.y, closeTo(-327.68, 0.001));
  });

  test('rejects anything that is not a window', () {
    expect(
        () => ImpactWindowRecorder.decode(
            Uint8List.fromList(gzip.encode([1, 2, 3]))),
        throwsFormatException);
    final wrongMagic = Uint8List(16);
    expect(
        () => ImpactWindowRecorder.decode(
            Uint8List.fromList(gzip.encode(wrongMagic))),
        throwsFormatException);
  });

  test('reset forgets everything', () {
    final r = filled()..reset();
    expect(r.encodeWindow(spike), isNull);
  });
}
