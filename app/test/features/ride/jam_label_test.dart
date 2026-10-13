import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/constants/beta_testers.dart';
import 'package:throttleiq/features/ride/domain/entities/jam_label_entity.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/jam_label_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

void main() {
  group('BetaTesters.canLabelJams', () {
    test('matches the hard-coded handle, ignoring case and @', () {
      expect(BetaTesters.canLabelJams('abraaraidev'), isTrue);
      expect(BetaTesters.canLabelJams('@AbraarAIDev'), isTrue);
      expect(BetaTesters.canLabelJams('someone_else'), isFalse);
      expect(BetaTesters.canLabelJams(null), isFalse);
    });
  });

  group('JamLabelNotifier', () {
    late List<JamLabel> saved;
    late DateTime clock;
    late JamLabelNotifier notifier;

    final ride = RideEntity(
      id: 'ride-1',
      userId: 'u1',
      bikeId: 'b1',
      startTime: DateTime(2026, 10, 6, 9),
    );

    RideRecordingState rec({
      RecordingStatus status = RecordingStatus.active,
      int elapsed = 0,
      int moving = 0,
      double distance = 0,
      RideEntity? r,
    }) =>
        RideRecordingState(
          status: status,
          ride: r ?? ride,
          elapsed: Duration(seconds: elapsed),
          movingSeconds: moving,
          distanceM: distance,
          currentSpeedMs: 0.4,
          currentPosition: const LatLng(23.78, 90.41),
        );

    setUp(() {
      saved = [];
      clock = DateTime(2026, 10, 6, 9, 10);
      notifier = JamLabelNotifier(
        save: saved.add,
        now: () => clock,
        newId: () => 'label-1',
      );
    });

    test('start then release records the window and the detector view', () {
      notifier.startJam(rec(elapsed: 600, moving: 500, distance: 3000));
      expect(notifier.state?.isOpen, isTrue);
      expect(saved.single.end, isNull, reason: 'open label saved on start');

      clock = clock.add(const Duration(minutes: 10));
      // 600 s labelled, but the detector only counted 420 s as stopped
      // (crawling at walking pace counts as moving).
      notifier.releaseJam(rec(elapsed: 1200, moving: 680, distance: 3150));

      expect(notifier.state, isNull);
      final closed = saved.last;
      expect(closed.endReason, JamLabelEndReason.released);
      expect(closed.labelledSeconds, 600);
      expect(closed.rideClockSeconds, 600);
      expect(closed.detectedStoppedSeconds, 420);
      expect(closed.distanceDuringM, 150);
      expect(closed.toMap()['start']['lat'], 23.78);
    });

    test('ignored when not actively recording or already open', () {
      notifier.startJam(rec(status: RecordingStatus.paused));
      expect(notifier.state, isNull);
      notifier.startJam(rec());
      notifier.startJam(rec());
      expect(saved, hasLength(1));
    });

    test('pause closes the label from the last active snapshot', () {
      notifier.startJam(rec(elapsed: 100, moving: 90));
      clock = clock.add(const Duration(minutes: 2));
      notifier.onRecordingChanged(
        rec(elapsed: 220, moving: 95),
        rec(status: RecordingStatus.paused, elapsed: 220, moving: 95),
      );
      expect(notifier.state, isNull);
      expect(saved.last.endReason, JamLabelEndReason.paused);
      expect(saved.last.detectedStoppedSeconds, 115);
    });

    test('ride ending closes the label as rideEnded', () {
      notifier.startJam(rec(elapsed: 100, moving: 90));
      notifier.onRecordingChanged(
        rec(elapsed: 150, moving: 90),
        const RideRecordingState(),
      );
      expect(saved.last.endReason, JamLabelEndReason.rideEnded);
      expect(saved.last.end!.elapsedSeconds, 150);
    });

    test('ordinary active updates leave the label open', () {
      notifier.startJam(rec(elapsed: 100));
      notifier.onRecordingChanged(rec(elapsed: 100), rec(elapsed: 101));
      expect(notifier.state?.isOpen, isTrue);
      expect(saved, hasLength(1));
    });
  });
}
