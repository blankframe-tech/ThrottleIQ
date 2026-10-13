import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';

/// Schema v17 added `route_id`/`route_name` to `rides` (issues §78.21).
/// `downloadRides` inserts cloud documents verbatim, so a field a device's
/// schema doesn't have is an insert that throws and silently drops the ride —
/// the hazard `track_synced` and `archived` each needed a bespoke guard for.
void main() {
  group('ridePayload', () {
    test('an ordinary ride looks exactly as it did before v17', () {
      final payload = CloudRepository.ridePayload({
        'id': 'r1',
        'route_id': null,
        'route_name': null,
        'track_synced': 0,
      });
      expect(payload.containsKey('route_id'), isFalse);
      expect(payload.containsKey('route_name'), isFalse);
      expect(payload.containsKey('track_synced'), isFalse);
      expect(payload['id'], 'r1');
    });

    test('a ride that followed a route carries both fields', () {
      final payload = CloudRepository.ridePayload({
        'id': 'r2',
        'route_id': 'route-9',
        'route_name': 'Mirpur loop',
      });
      expect(payload['route_id'], 'route-9');
      expect(payload['route_name'], 'Mirpur loop');
    });
  });

  group('knownRideColumnsOnly', () {
    const columns = {'id', 'user_id', 'route_id'};

    test('drops a field this build has no column for', () {
      final row = CloudRepository.knownRideColumnsOnly({
        'id': 'r1',
        'user_id': 'u1',
        'route_id': 'route-9',
        'something_from_the_future': 42,
      }, columns);
      expect(row.keys, containsAll(['id', 'user_id', 'route_id']));
      expect(row.containsKey('something_from_the_future'), isFalse);
    });

    test('keeps a null that does have a column', () {
      final row = CloudRepository.knownRideColumnsOnly(
          {'id': 'r1', 'route_id': null}, columns);
      expect(row.containsKey('route_id'), isTrue);
      expect(row['route_id'], isNull);
    });

    test('an empty column set yields an empty row rather than throwing', () {
      expect(CloudRepository.knownRideColumnsOnly({'id': 'r1'}, const {}),
          isEmpty);
    });
  });
}
