import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/presentation/providers/helpers/ride_persistence_coordinator.dart';

/// critique oct27 #12: a ride restored after the OS killed the app kept its
/// distance and clock but restarted the hard-brake / rapid-accel / jerk /
/// overspeed counts at zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(Firebase.initializeApp);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  EventDetector counted() => EventDetector()
    ..hardBrakeCount = 3
    ..rapidAccelCount = 2
    ..highJerkCount = 5
    ..overspeedCount = 1;

  List<int> counts(EventDetector d) => [
        d.hardBrakeCount,
        d.rapidAccelCount,
        d.highJerkCount,
        d.overspeedCount,
      ];

  test('counts saved with the clock seed a fresh detector on restore',
      () async {
    await RidePersistenceCoordinator()
        .persistElapsed(const Duration(minutes: 40), detector: counted());

    // A new process: new coordinator, new (reset) detector.
    final restored = EventDetector();
    await RidePersistenceCoordinator().restoreEventCounts(restored);
    expect(counts(restored), [3, 2, 5, 1]);
  });

  test('nothing saved, or a finished ride: the detector stays at zero',
      () async {
    final coordinator = RidePersistenceCoordinator();
    final fresh = EventDetector();
    await coordinator.restoreEventCounts(fresh);
    expect(counts(fresh), [0, 0, 0, 0]);

    await coordinator.persistElapsed(Duration.zero,
        detector: counted(), force: true);
    await coordinator.clearRecordingState();
    await coordinator.restoreEventCounts(fresh);
    expect(counts(fresh), [0, 0, 0, 0]);
  });
}
