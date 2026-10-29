import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/repositories/group_ride_repository.dart';

/// Group-ride live positions through the shared `positions/all` doc
/// (issues §104.2), with `memberLocations` kept for build 29.
void main() {
  test('a shared publish writes both the shared doc and memberLocations',
      () async {
    final fs = FakeFirebaseFirestore();
    final repo = GroupRideRepository.withFirestore(fs);
    await repo.updateMemberLocation(
        groupRideId: 'g', userId: 'a', lat: 23.8, lng: 90.4, shared: true);
    await repo.updateMemberLocation(
        groupRideId: 'g', userId: 'b', lat: 23.9, lng: 90.5, shared: true);

    final all = (await fs.doc('groupRides/g/positions/all').get()).data()!;
    expect(all.keys, unorderedEquals(['a', 'b']));
    expect(all['a']['lat'], 23.8);
    expect(all['b']['lng'], 90.5);
    final legacy = await fs.doc('groupRides/g/memberLocations/a').get();
    expect(legacy.data()!['userId'], 'a');
  });

  test('a legacy publish writes memberLocations only', () async {
    final fs = FakeFirebaseFirestore();
    final repo = GroupRideRepository.withFirestore(fs);
    await repo.updateMemberLocation(
        groupRideId: 'g', userId: 'a', lat: 23.8, lng: 90.4);
    expect((await fs.doc('groupRides/g/positions/all').get()).exists, false);
    expect((await fs.doc('groupRides/g/memberLocations/a').get()).exists, true);
  });

  test('a poll fills members missing from the shared doc from memberLocations',
      () async {
    final fs = FakeFirebaseFirestore();
    final repo = GroupRideRepository.withFirestore(fs);
    await repo.updateMemberLocation(
        groupRideId: 'g', userId: 'new', lat: 1, lng: 1, shared: true);
    // A build 29 rider, and a member who left (not asked about).
    await repo.updateMemberLocation(
        groupRideId: 'g', userId: 'old', lat: 2, lng: 2);
    await repo.updateMemberLocation(
        groupRideId: 'g', userId: 'gone', lat: 3, lng: 3);

    final got = await repo.fetchLivePositions('g', ['new', 'old', 'quiet']);

    expect(got.keys, unorderedEquals(['new', 'old']));
    expect(got['old']!['lat'], 2);
    expect(got['new']!['lat'], 1);
  });

  test('a poll of a ride nobody published on is empty', () async {
    final repo = GroupRideRepository.withFirestore(FakeFirebaseFirestore());
    expect(await repo.fetchLivePositions('g', ['a']), isEmpty);
  });
}
