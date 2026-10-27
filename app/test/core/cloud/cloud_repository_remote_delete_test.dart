import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';

/// Remote deletes take the ride's `track` children with it (§90.C10), and a
/// bike's delete takes its rides (and their tracks). Other bikes' rides stay.
void main() {
  late FakeFirebaseFirestore fs;
  late CloudRepository repo;

  Future<void> seedRide(String id, String bikeId, {int chunks = 2}) async {
    final ride = fs.doc('users/u1/rides/$id');
    await ride.set({'bike_id': bikeId});
    for (var i = 0; i < chunks; i++) {
      await ride.collection('track').doc('$i').set({'points': []});
    }
  }

  Future<int> count(String path) async =>
      (await fs.collection(path).get()).docs.length;

  setUp(() {
    fs = FakeFirebaseFirestore();
    repo = CloudRepository.withFirestore(fs);
  });

  test('deleteRideRemote removes the ride and every track chunk', () async {
    await seedRide('r1', 'b1', chunks: 3);
    await seedRide('r2', 'b1');

    await repo.deleteRideRemote('u1', 'r1');

    expect((await fs.doc('users/u1/rides/r1').get()).exists, isFalse);
    expect(await count('users/u1/rides/r1/track'), 0);
    // The other ride is untouched.
    expect(await count('users/u1/rides/r2/track'), 2);
  });

  test('deleteRideRemote on a ride with no track still deletes it', () async {
    await seedRide('r1', 'b1', chunks: 0);
    await repo.deleteRideRemote('u1', 'r1');
    expect(await count('users/u1/rides'), 0);
  });

  test('deleteBikeRemote removes the bike, its rides and their tracks',
      () async {
    await fs.doc('users/u1/bikes/b1').set({'brand': 'Bajaj'});
    await fs.doc('users/u1/bikes/b2').set({'brand': 'Honda'});
    await seedRide('r1', 'b1');
    await seedRide('r2', 'b1');
    await seedRide('r3', 'b2');

    await repo.deleteBikeRemote('u1', 'b1');

    expect((await fs.doc('users/u1/bikes/b1').get()).exists, isFalse);
    final rides = (await fs.collection('users/u1/rides').get()).docs;
    expect(rides.map((d) => d.id), ['r3']);
    expect(await count('users/u1/rides/r1/track'), 0);
    expect(await count('users/u1/rides/r2/track'), 0);
    expect(await count('users/u1/rides/r3/track'), 2);
    expect((await fs.doc('users/u1/bikes/b2').get()).exists, isTrue);
  });
}
