import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/elapsed_at_pause.dart';

void main() {
  final start = DateTime(2026, 1, 1, 10);

  test('pausing 1.5 s after a tick keeps the whole 1.5 s', () {
    // Segment started at 10:00:00; the last tick showed 10 s; now is 11.5 s.
    final e = elapsedAtPause(
      accumulated: Duration.zero,
      activeStart: start,
      now: start.add(const Duration(milliseconds: 11500)),
      lastTick: const Duration(seconds: 10),
    );
    expect(e, const Duration(milliseconds: 11500));
  });

  test('earlier segments are included', () {
    final e = elapsedAtPause(
      accumulated: const Duration(minutes: 5),
      activeStart: start,
      now: start.add(const Duration(seconds: 30)),
      lastTick: const Duration(minutes: 5, seconds: 29),
    );
    expect(e, const Duration(minutes: 5, seconds: 30));
  });

  test('never less than what the rider saw (clock stepped back)', () {
    final e = elapsedAtPause(
      accumulated: Duration.zero,
      activeStart: start,
      now: start.subtract(const Duration(minutes: 1)),
      lastTick: const Duration(seconds: 42),
    );
    expect(e, const Duration(seconds: 42));
  });

  test('a restored ride with no active start keeps the last tick', () {
    final e = elapsedAtPause(
      accumulated: const Duration(minutes: 3),
      activeStart: null,
      now: start,
      lastTick: const Duration(minutes: 3),
    );
    expect(e, const Duration(minutes: 3));
  });
}
