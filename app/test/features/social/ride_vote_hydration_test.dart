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

/// Feed vote hydration (issues §104.3): one `votes/{uid}` read per ride,
/// skipped for rides nobody has voted on.
void main() {
  test('only rides with votes are asked about', () async {
    final asked = <String>[];
    final result = await RideShareRepository.hydrateWith(
      [ride('none'), ride('up', upvotes: 2), ride('down', downvotes: 1)],
      (id) async {
        asked.add(id);
        return id == 'up' ? 1 : null;
      },
    );
    expect(asked, ['up', 'down']);
    expect(result.map((r) => r.myVote), [null, 1, null]);
    expect(result.map((r) => r.id), ['none', 'up', 'down']);
  });

  test('an empty page reads nothing', () async {
    var calls = 0;
    final result = await RideShareRepository.hydrateWith([], (_) async {
      calls++;
      return null;
    });
    expect(result, isEmpty);
    expect(calls, 0);
  });
}
