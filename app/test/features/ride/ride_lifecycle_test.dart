import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/providers/helpers/ride_lifecycle.dart';

/// The pieces of `RideRecordingNotifier`'s start/pause/resume/stop logic that
/// were pulled out to be testable (§90.B9): subscription ownership (§90.C1,
/// §90.C5), the transition latch (§90.C5) and the stop ordering (§90.C8).
void main() {
  group('RecordingSubscriptions (§90.C1)', () {
    test('events emitted while paused are never delivered after resume',
        () async {
      // Broadcast, like geolocator's and sensors_plus's streams.
      final gps = StreamController<int>.broadcast();
      final received = <int>[];
      final subs = RecordingSubscriptions();

      subs.open(() => [gps.stream.listen(received.add)]);
      gps.add(1);
      await pumpEventQueue();

      // Pause = cancel. The "van ride" happens now.
      await subs.cancel();
      for (var i = 100; i < 200; i++) {
        gps.add(i);
      }
      await pumpEventQueue();

      // Resume = a fresh subscription.
      subs.open(() => [gps.stream.listen(received.add)]);
      gps.add(2);
      await pumpEventQueue();

      expect(received, [1, 2]);
      await gps.close();
    });

    test('the old .pause() approach would have replayed the backlog', () async {
      // Documents the bug the class exists to prevent.
      final gps = StreamController<int>.broadcast();
      final received = <int>[];
      final sub = gps.stream.listen(received.add);
      sub.pause();
      gps.add(100);
      gps.add(101);
      sub.resume();
      await pumpEventQueue();
      expect(received, [100, 101]);
      await sub.cancel();
      await gps.close();
    });

    test('opening twice leaves exactly one live listener (§90.C5)', () async {
      final gps = StreamController<int>.broadcast();
      final received = <int>[];
      final subs = RecordingSubscriptions();

      subs.open(() => [gps.stream.listen(received.add)]);
      subs.open(() => [gps.stream.listen(received.add)]);
      gps.add(7);
      await pumpEventQueue();
      expect(received, [7]);

      await subs.cancel();
      expect(subs.isOpen, isFalse);
      expect(gps.hasListener, isFalse,
          reason: 'a leaked listener keeps GPS and the foreground '
              'notification alive after the ride ends');
      await gps.close();
    });

    test('cancel is safe with nothing open', () async {
      final subs = RecordingSubscriptions();
      await subs.cancel();
      expect(subs.isOpen, isFalse);
    });
  });

  group('TransitionLatch (§90.C5)', () {
    test('a second caller is refused synchronously while the first awaits',
        () async {
      final latch = TransitionLatch();
      final gate = Completer<void>();
      var opened = 0;

      Future<void> resume() => latch.run(() async {
            await gate.future;
            opened++;
          });

      // Two taps in the same frame.
      final first = resume();
      final second = resume();
      expect(latch.isBusy, isTrue);
      gate.complete();
      await Future.wait([first, second]);

      expect(opened, 1);
      expect(latch.isBusy, isFalse);
    });

    test('Stop waits for an in-flight pause instead of being refused',
        () async {
      final latch = TransitionLatch();
      expect(latch.tryEnter(), isTrue); // a pause is settling
      final stop = latch.enterWhenFree();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      latch.exit();
      expect(await stop, isTrue);
      expect(latch.isBusy, isTrue);
    });

    test('enterWhenFree gives up after its timeout', () async {
      final latch = TransitionLatch()..tryEnter();
      expect(
          await latch.enterWhenFree(
              timeout: const Duration(milliseconds: 30),
              poll: const Duration(milliseconds: 5)),
          isFalse);
    });

    test('the latch is released when the body throws', () async {
      final latch = TransitionLatch();
      await expectLater(
          latch.run<void>(() async => throw StateError('boom')),
          throwsStateError);
      expect(latch.tryEnter(), isTrue);
    });
  });

  group('runStopSequence (§90.C8)', () {
    test('finalizes first and clears the marker last', () async {
      final calls = <String>[];
      await runStopSequence(
        finalize: () async => calls.add('finalize'),
        afterFinalize: () async => calls.add('stats'),
        clearMarker: () async => calls.add('clearMarker'),
      );
      expect(calls, ['finalize', 'stats', 'clearMarker']);
    });

    test('a failed finalize keeps the marker so the ride can be restored',
        () async {
      var markerCleared = false;
      await expectLater(
        runStopSequence(
          finalize: () async => throw StateError('disk full'),
          clearMarker: () async => markerCleared = true,
        ),
        throwsStateError,
      );
      expect(markerCleared, isFalse);
    });

    test('a failed post-finalize step still clears the marker', () async {
      var markerCleared = false;
      await expectLater(
        runStopSequence(
          finalize: () async {},
          afterFinalize: () async => throw StateError('odometer'),
          clearMarker: () async => markerCleared = true,
        ),
        throwsStateError,
      );
      expect(markerCleared, isTrue);
    });
  });
}
