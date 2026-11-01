import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/vote_batch.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';

/// Issue #154: ride and forum votes go through a batch (queues offline), in
/// exactly the three shapes `voteTallied` in firestore.rules allows.
void main() {
  group('voteTallyDelta', () {
    test('a new vote bumps only its own tally', () {
      expect(voteTallyDelta(null, 1), {'upvotes': 1});
      expect(voteTallyDelta(null, -1), {'downvotes': 1});
    });

    test('the same vote again toggles off', () {
      expect(voteTallyDelta(1, 1), {'upvotes': -1});
      expect(voteTallyDelta(-1, -1), {'downvotes': -1});
    });

    test('the other vote flips both tallies', () {
      expect(voteTallyDelta(-1, 1), {'upvotes': 1, 'downvotes': -1});
      expect(voteTallyDelta(1, -1), {'upvotes': -1, 'downvotes': 1});
    });
  });

  final repos = {
    'ride': (
      path: 'rides/r1',
      vote: (FakeFirebaseFirestore fs, int v) =>
          RideShareRepository.withFirestore(fs).vote('r1', 'u1', v),
    ),
    'forum post': (
      path: 'forums/f1/posts/p1',
      vote: (FakeFirebaseFirestore fs, int v) =>
          ForumRepository.withFirestore(fs).votePost('f1', 'p1', 'u1', v),
    ),
  };

  for (final MapEntry(key: name, value: r) in repos.entries) {
    group('$name vote', () {
      late FakeFirebaseFirestore fs;
      Future<Map<String, dynamic>?> voteDoc() async =>
          (await fs.doc('${r.path}/votes/u1').get()).data();
      Future<List<int>> tallies() async {
        final d = (await fs.doc(r.path).get()).data()!;
        return [d['upvotes'] as int, d['downvotes'] as int];
      }

      setUp(() async {
        fs = FakeFirebaseFirestore();
        await fs.doc(r.path).set({'upvotes': 3, 'downvotes': 2});
      });

      test('new: writes {value, uid} and bumps one tally', () async {
        await r.vote(fs, 1);
        expect(await voteDoc(), {'value': 1, 'uid': 'u1'});
        expect(await tallies(), [4, 2]);
      });

      test('toggle off: deletes the vote doc and un-bumps its tally', () async {
        await fs.doc('${r.path}/votes/u1').set({'value': -1, 'uid': 'u1'});
        await r.vote(fs, -1);
        expect(await voteDoc(), isNull);
        expect(await tallies(), [3, 1]);
      });

      test('flip: rewrites the vote doc and moves both tallies', () async {
        await fs.doc('${r.path}/votes/u1').set({'value': -1, 'uid': 'u1'});
        await r.vote(fs, 1);
        expect(await voteDoc(), {'value': 1, 'uid': 'u1'});
        expect(await tallies(), [4, 1]);
      });
    });
  }
}
