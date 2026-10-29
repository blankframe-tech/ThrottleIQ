import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';

SharedRideEntity ride(String id, {int upvotes = 0, int downvotes = 0}) =>
    SharedRideEntity(
      id: id,
      userId: 'rider-$id',
      userName: 'Rider $id',
      userPhotoUrl: '',
      bikeId: 'bike',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: DateTime(2026, 9, 1),
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 60,
      polyline: const [],
      createdAt: DateTime(2026, 9, 1),
      upvotes: upvotes,
      downvotes: downvotes,
    );

/// Feed vote hydration (issues §104.3): one batched ask per page, skipping
/// rides nobody has voted on.
void main() {
  test('only rides with votes are asked about, in one call', () async {
    final asked = <List<String>>[];
    final result = await RideShareRepository.hydrateWith(
      [ride('none'), ride('up', upvotes: 2), ride('down', downvotes: 1)],
      (ids) async {
        asked.add(ids);
        return {'up': 1};
      },
    );
    expect(asked, [
      ['up', 'down']
    ]);
    expect(result.map((r) => r.myVote), [null, 1, null]);
    expect(result.map((r) => r.id), ['none', 'up', 'down']);
  });

  test('a page nobody voted on reads nothing', () async {
    var calls = 0;
    final result = await RideShareRepository.hydrateWith(
      [ride('a'), ride('b')],
      (_) async {
        calls++;
        return {};
      },
    );
    expect(result.map((r) => r.myVote), [null, null]);
    expect(calls, 0);
  });
}
