import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';

/// Issue #152: a ride comment is a batch (queues offline and when the daily
/// quota is spent), not a transaction, and a still-pending comment (no
/// server `createdAt` yet) must not crash the comment list.
void main() {
  test('addComment writes the comment and bumps comments with its id',
      () async {
    final fs = FakeFirebaseFirestore();
    final ride = fs.doc('rides/r1');
    await ride.set({'comments': 4});

    final id = await RideShareRepository.withFirestore(fs).addComment(
        rideId: 'r1',
        userId: 'u1',
        userName: 'Rider',
        userPhotoUrl: '',
        text: 'nice ride');

    final comment = (await ride.collection('comments').doc(id).get()).data()!;
    expect(comment['id'], id);
    expect(comment['rideId'], 'r1');
    expect(comment['userId'], 'u1');
    expect(comment['text'], 'nice ride');
    expect(comment['createdAt'], isA<Timestamp>());
    expect(comment['writtenAt'], isA<Timestamp>()); // issue #157
    final bumped = (await ride.get()).data()!;
    expect(bumped['comments'], 5);
    expect(bumped['lastCommentId'], id);
  });

  test('getComments reads a pending comment with a null createdAt', () async {
    final fs = FakeFirebaseFirestore();
    final comments = fs.collection('rides/r1/comments');
    await comments.doc('old').set({
      'userId': 'u2',
      'userName': 'Other',
      'userPhotoUrl': '',
      'text': 'first',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      'updatedAt': null,
    });
    await comments.doc('pending').set({
      'userId': 'u1',
      'userName': 'Rider',
      'userPhotoUrl': '',
      'text': 'queued',
      'createdAt': null,
      'writtenAt': Timestamp.fromDate(DateTime(2026, 10, 3, 20)),
      'updatedAt': null,
    });
    final before = DateTime.now();

    final list = await RideShareRepository.withFirestore(fs).getComments('r1');

    expect(list.map((c) => c.id), containsAll(['old', 'pending']));
    final pending = list.firstWhere((c) => c.id == 'pending');
    expect(pending.text, 'queued');
    expect(pending.createdAt.isBefore(before), isFalse);
    expect(pending.updatedAt, isNull);
    expect(pending.writtenAt, DateTime(2026, 10, 3, 20));
    final old = list.firstWhere((c) => c.id == 'old');
    expect(old.createdAt, DateTime(2026, 10, 1));
    expect(old.writtenAt, isNull); // written by a build before #157
  });
}
