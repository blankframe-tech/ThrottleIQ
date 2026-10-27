import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/providers/helpers/crash_coordinator.dart';

/// Crash alerts are keyed `{rideId}_{epochMs}` (critique oct27 #18): a second
/// crash on the same ride is its own alert, not a denied overwrite.
void main() {
  test('two crashes on one ride create two crashNotifications docs', () async {
    final fs = FakeFirebaseFirestore();
    final crash = CrashCoordinator(firestore: fs);

    Future<void> dispatch() => crash.dispatchEmergencyNotification(
        uid: 'u1', rideId: 'r1', lastLat: 23.8, lastLng: 90.4);
    await dispatch();
    // The id has ms resolution; make sure the clock moves.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await dispatch();

    final docs = (await fs.collection('crashNotifications').get()).docs;
    expect(docs, hasLength(2));
    for (final d in docs) {
      expect(d.id, matches(RegExp(r'^r1_\d+$')));
      expect(d['uid'], 'u1');
      expect(d['rideId'], 'r1');
      expect(d['status'], 'pending');
    }
  });

  test('no uid: nothing is written', () async {
    final fs = FakeFirebaseFirestore();
    await CrashCoordinator(firestore: fs).dispatchEmergencyNotification(
        uid: null, rideId: 'r1', lastLat: null, lastLng: null);
    expect((await fs.collection('crashNotifications').get()).docs, isEmpty);
  });
}
