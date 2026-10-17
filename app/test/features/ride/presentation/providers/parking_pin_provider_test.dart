import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/ride/presentation/providers/parking_pin_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

class _FakeRideRecordingNotifier extends StateNotifier<RideRecordingState>
    implements RideRecordingNotifier {
  _FakeRideRecordingNotifier(
      {RecordingStatus initialStatus = RecordingStatus.paused})
      : super(RideRecordingState(status: initialStatus));

  void setStatus(RecordingStatus status) {
    state = state.copyWith(status: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParkingPinNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('drop persists to SharedPreferences and updates state', () async {
      final notifier = ParkingPinNotifier();
      expect(notifier.state, isNull);

      const pinLocation = LatLng(23.8103, 90.4125);
      await notifier.drop(pinLocation);

      expect(notifier.state, isNotNull);
      expect(notifier.state!.point.latitude, 23.8103);
      expect(notifier.state!.point.longitude, 90.4125);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(ParkingPinNotifier.prefsKey);
      expect(stored, isNotNull);
      expect(stored!.startsWith('23.8103,90.4125,'), isTrue);
    });

    test('loads saved pin from SharedPreferences on initialization', () async {
      final epochMs = DateTime.utc(2026, 10, 17, 10).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        ParkingPinNotifier.prefsKey: '23.8103,90.4125,$epochMs',
      });

      final prefs = await SharedPreferences.getInstance();
      final notifier = ParkingPinNotifier(prefs: prefs);

      expect(notifier.state, isNotNull);
      expect(notifier.state!.point.latitude, 23.8103);
      expect(notifier.state!.point.longitude, 90.4125);
      expect(notifier.state!.at.millisecondsSinceEpoch, epochMs);
    });

    test('clear removes pin from state and SharedPreferences', () async {
      final notifier = ParkingPinNotifier();
      await notifier.drop(const LatLng(23.8, 90.4));
      expect(notifier.state, isNotNull);

      await notifier.clear();
      expect(notifier.state, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ParkingPinNotifier.prefsKey), isNull);
    });

    test('a stored pin older than the current ride is dropped on load',
        () async {
      final pinAt = DateTime(2026, 10, 17, 9);
      SharedPreferences.setMockInitialValues({
        ParkingPinNotifier.prefsKey:
            '23.8,90.4,${pinAt.millisecondsSinceEpoch}',
      });
      final prefs = await SharedPreferences.getInstance();

      final stale = ParkingPinNotifier(
          prefs: prefs, rideStart: () => DateTime(2026, 10, 17, 10));
      expect(stale.state, isNull);
      expect(prefs.getString(ParkingPinNotifier.prefsKey), isNull);
    });

    test('a pin dropped during the current ride survives a reload', () async {
      final pinAt = DateTime(2026, 10, 17, 11);
      SharedPreferences.setMockInitialValues({
        ParkingPinNotifier.prefsKey:
            '23.8,90.4,${pinAt.millisecondsSinceEpoch}',
      });
      final prefs = await SharedPreferences.getInstance();

      final kept = ParkingPinNotifier(
          prefs: prefs, rideStart: () => DateTime(2026, 10, 17, 10));
      expect(kept.state, isNotNull);
    });

    test('a clear() issued before the initial load finishes wins', () async {
      SharedPreferences.setMockInitialValues({
        ParkingPinNotifier.prefsKey:
            '23.8,90.4,${DateTime.now().millisecondsSinceEpoch}',
      });
      final notifier = ParkingPinNotifier(); // async load in flight
      await notifier.clear();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isNull);
    });

    test('parse handles valid, malformed, and corrupt strings', () {
      expect(ParkingPinNotifier.parse(''), isNull);
      expect(ParkingPinNotifier.parse('23.8,90.4'), isNull);
      expect(ParkingPinNotifier.parse('not,a,number'), isNull);
      expect(ParkingPinNotifier.parse('23.8,90.4,invalid'), isNull);

      final valid = ParkingPinNotifier.parse('23.8,90.4,1729160000000');
      expect(valid, isNotNull);
      expect(valid!.point.latitude, 23.8);
      expect(valid.point.longitude, 90.4);
      expect(valid.at.millisecondsSinceEpoch, 1729160000000);
    });
  });

  group('parkingPinProvider lifecycle listener', () {
    test('a leftover pin is cleared when built while no ride is paused',
        () async {
      SharedPreferences.setMockInitialValues({
        ParkingPinNotifier.prefsKey:
            '23.8,90.4,${DateTime.now().millisecondsSinceEpoch}',
      });
      final container = ProviderContainer(
        overrides: [
          rideRecordingProvider.overrideWith((ref) =>
              _FakeRideRecordingNotifier(initialStatus: RecordingStatus.idle)),
        ],
      );
      addTearDown(container.dispose);

      container.read(parkingPinProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(parkingPinProvider), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ParkingPinNotifier.prefsKey), isNull);
    });

    test('clears when status transitions to active (resume)', () async {
      SharedPreferences.setMockInitialValues({});
      late _FakeRideRecordingNotifier fakeRecorder;

      final container = ProviderContainer(
        overrides: [
          rideRecordingProvider.overrideWith((ref) {
            return _FakeRideRecordingNotifier(
                initialStatus: RecordingStatus.paused);
          }),
        ],
      );
      addTearDown(container.dispose);

      fakeRecorder = container.read(rideRecordingProvider.notifier)
          as _FakeRideRecordingNotifier;

      // Initialize provider and drop pin
      final pinNotifier = container.read(parkingPinProvider.notifier);
      await pinNotifier.drop(const LatLng(23.81, 90.41));
      expect(container.read(parkingPinProvider), isNotNull);

      // Transition to active (resumed)
      fakeRecorder.setStatus(RecordingStatus.active);
      expect(container.read(parkingPinProvider), isNull);
    });

    test('clears when status transitions to idle', () async {
      SharedPreferences.setMockInitialValues({});
      late _FakeRideRecordingNotifier fakeRecorder;

      final container = ProviderContainer(
        overrides: [
          rideRecordingProvider.overrideWith((ref) {
            return _FakeRideRecordingNotifier(
                initialStatus: RecordingStatus.paused);
          }),
        ],
      );
      addTearDown(container.dispose);

      fakeRecorder = container.read(rideRecordingProvider.notifier)
          as _FakeRideRecordingNotifier;

      final pinNotifier = container.read(parkingPinProvider.notifier);
      await pinNotifier.drop(const LatLng(23.81, 90.41));
      expect(container.read(parkingPinProvider), isNotNull);

      // Transition to idle
      fakeRecorder.setStatus(RecordingStatus.idle);
      expect(container.read(parkingPinProvider), isNull);
    });

    test('clears when status transitions to completed', () async {
      SharedPreferences.setMockInitialValues({});
      late _FakeRideRecordingNotifier fakeRecorder;

      final container = ProviderContainer(
        overrides: [
          rideRecordingProvider.overrideWith((ref) {
            return _FakeRideRecordingNotifier(
                initialStatus: RecordingStatus.paused);
          }),
        ],
      );
      addTearDown(container.dispose);

      fakeRecorder = container.read(rideRecordingProvider.notifier)
          as _FakeRideRecordingNotifier;

      final pinNotifier = container.read(parkingPinProvider.notifier);
      await pinNotifier.drop(const LatLng(23.81, 90.41));
      expect(container.read(parkingPinProvider), isNotNull);

      // Transition to completed
      fakeRecorder.setStatus(RecordingStatus.completed);
      expect(container.read(parkingPinProvider), isNull);
    });
  });
}
