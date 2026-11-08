import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/auto_tracking_service.dart';

/// issues §109.1 / §109.2: the swiped-away takeover ends when idle and does
/// not double-write points the UI recorder already stored.
void main() {
  final t0 = DateTime(2026, 11, 6, 9);

  test('takeoverIdle flips at the limit', () {
    expect(
        AutoTrackingService.takeoverIdle(
            now: t0.add(const Duration(minutes: 11)), lastMoveAt: t0),
        isFalse);
    expect(
        AutoTrackingService.takeoverIdle(
            now: t0.add(AutoTrackingService.takeoverIdleLimit), lastMoveAt: t0),
        isTrue);
  });

  test('takeoverPointWanted drops fixes within 1 s of a stored point', () {
    expect(AutoTrackingService.takeoverPointWanted(t0, null), isTrue);
    expect(
        AutoTrackingService.takeoverPointWanted(
            t0.add(const Duration(milliseconds: 600)), t0),
        isFalse);
    expect(
        AutoTrackingService.takeoverPointWanted(
            t0.subtract(const Duration(milliseconds: 400)), t0),
        isFalse);
    expect(
        AutoTrackingService.takeoverPointWanted(
            t0.add(const Duration(seconds: 1)), t0),
        isTrue);
  });
}
