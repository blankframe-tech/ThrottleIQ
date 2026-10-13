import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

/// `error`/`blockKind` are the only fields on [RideRecordingState] that clear
/// by default rather than persisting — the opposite of the other nineteen.
/// That was undocumented and contradicted by a neighbouring comment
/// (issues §83.10); these pin the intended contract.
void main() {
  group('RideRecordingState.copyWith', () {
    const blocked = RideRecordingState(
      error: 'Location services are off',
      blockKind: RecordingBlockKind.locationServicesOff,
      distanceM: 1200,
    );

    test('an unrelated update clears the error by default', () {
      final next = blocked.copyWith(distanceM: 1300);
      expect(next.error, isNull);
      expect(next.blockKind, RecordingBlockKind.none);
      expect(next.distanceM, 1300, reason: 'other fields still persist');
    });

    test('keepError carries the message and its kind through', () {
      final next = blocked.copyWith(distanceM: 1300, keepError: true);
      expect(next.error, 'Location services are off');
      expect(next.blockKind, RecordingBlockKind.locationServicesOff);
    });

    test('an explicit error still wins over keepError', () {
      final next = blocked.copyWith(error: 'Permission denied', keepError: true);
      expect(next.error, 'Permission denied');
    });

    test('every other field follows the usual null-means-keep rule', () {
      const s = RideRecordingState(
        status: RecordingStatus.active,
        distanceM: 500,
        maxSpeedMs: 30,
        movingSeconds: 60,
      );
      final next = s.copyWith(distanceM: 600);
      expect(next.status, RecordingStatus.active);
      expect(next.maxSpeedMs, 30);
      expect(next.movingSeconds, 60);
      expect(next.distanceM, 600);
    });
  });
}
