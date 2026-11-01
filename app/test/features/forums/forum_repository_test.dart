import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';

/// Which model forums get merged into a brand forum's post list — the pure
/// filtering `ForumRepository.postSourceForumIds` runs on candidate forums fetched by
/// `brand`. See that method's doc comment: a post made in "Honda CB Shine
/// 125" should also surface when viewing "Honda", but nothing else should.
/// Fails like the real SDK does offline / past the quota, so a test proves
/// the code path never needs a transaction.
class _NoTransactionFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
          {Duration timeout = const Duration(seconds: 30),
          int maxAttempts = 5}) =>
      throw StateError('transactions fail offline');
}

ForumEntity forum(String id,
        {required ForumType type, required String brand, int postCount = 0}) =>
    ForumEntity(
        id: id,
        type: type,
        brand: brand,
        postCount: postCount,
        displayName: id,
        createdAt: DateTime(2026, 1, 1));

void main() {
  // Issue #46: replies go through a batch (queues offline) and a known forum
  // resolves from a plain read, so neither needs a transaction.
  group('offline-safe writes', () {
    test('addReply writes the reply and bumps replyCount with its id',
        () async {
      final fs = FakeFirebaseFirestore();
      final post = fs.doc('forums/f1/posts/p1');
      await post.set({'replyCount': 2});

      final id = await ForumRepository.withFirestore(fs).addReply(
          forumId: 'f1',
          postId: 'p1',
          userId: 'u1',
          userName: 'Rider',
          userPhotoUrl: '',
          body: 'hi');

      final reply = await post.collection('replies').doc(id).get();
      expect(reply.data()?['body'], 'hi');
      expect(reply.data()?['userId'], 'u1');
      expect(reply.data()?['writtenAt'], isA<Timestamp>()); // issue #157
      final bumped = (await post.get()).data()!;
      expect(bumped['replyCount'], 3);
      expect(bumped['lastReplyId'], id);
    });

    // Issue #157: the phone time rides along for display; createdAt stays
    // the server time.
    test('createPost writes writtenAt next to the server createdAt', () async {
      final fs = FakeFirebaseFirestore();
      await fs.doc('forums/f1').set({'postCount': 0});

      final created = await ForumRepository.withFirestore(fs).createPost(
          forumId: 'f1',
          userId: 'u1',
          userName: 'Rider',
          userPhotoUrl: '',
          title: 't',
          body: 'b');

      expect(created.queued, isFalse); // acked at once, nothing pending
      final post =
          (await fs.doc('forums/f1/posts/${created.id}').get()).data()!;
      expect(post['createdAt'], isA<Timestamp>());
      expect(post['writtenAt'], isA<Timestamp>());
      expect((await fs.doc('forums/f1').get()).data()?['postCount'], 1);
    });

    test('getOrCreateGeneralForum returns an existing forum untouched',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = ForumRepository.withFirestore(fs);
      final created = await repo.getOrCreateGeneralForum(topic: 'Maintenance');
      await fs.doc('forums/${created.id}').update({'postCount': 7});

      final again = await repo.getOrCreateGeneralForum(topic: 'Maintenance');

      expect(again.id, created.id);
      expect(again.postCount, 7);
      expect((await fs.collection('forums').get()).docs, hasLength(1));
    });

    test('getOrCreateForum creates a missing bike forum', () async {
      final fs = FakeFirebaseFirestore();
      final forum = await ForumRepository.withFirestore(fs)
          .getOrCreateForum(brand: 'Honda');
      final doc = await fs.doc('forums/${forum.id}').get();
      expect(doc.data()?['type'], ForumType.brand.name);
      expect(doc.data()?['postCount'], 0);
    });

    // Issue #155: follow/unfollow are a plain read + batch, so they still
    // work when transactions fail (offline, Spark quota spent).
    test('followForum writes the follow doc and bumps followerCount once',
        () async {
      final fs = _NoTransactionFirestore();
      await fs.doc('forums/f1').set({'followerCount': 4});
      final repo = ForumRepository.withFirestore(fs);

      await repo.followForum('f1', 'u1');
      await repo.followForum('f1', 'u1'); // repeat tap

      final follow = await fs.doc('forum_follows/u1_f1').get();
      expect(follow.data()?['userId'], 'u1');
      expect(follow.data()?['forumId'], 'f1');
      expect((await fs.doc('forums/f1').get()).data()?['followerCount'], 5);
    });

    test('unfollowForum deletes the follow doc and drops followerCount once',
        () async {
      final fs = _NoTransactionFirestore();
      await fs.doc('forums/f1').set({'followerCount': 5});
      await fs.doc('forum_follows/u1_f1').set({'userId': 'u1'});
      final repo = ForumRepository.withFirestore(fs);

      await repo.unfollowForum('f1', 'u1');
      await repo.unfollowForum('f1', 'u1'); // repeat tap

      expect((await fs.doc('forum_follows/u1_f1').get()).exists, isFalse);
      expect((await fs.doc('forums/f1').get()).data()?['followerCount'], 4);
    });

    test('unfollowForum on a forum never followed writes nothing', () async {
      final fs = _NoTransactionFirestore();
      await fs.doc('forums/f1').set({'followerCount': 5});

      await ForumRepository.withFirestore(fs).unfollowForum('f1', 'u1');

      expect((await fs.doc('forums/f1').get()).data()?['followerCount'], 5);
    });
  });

  group('modelForumsToMergeInto', () {
    test('a bike-model forum with posts, under the right brand, qualifies', () {
      final candidates = [
        forum('honda__cb_shine_125',
            type: ForumType.bikeModel, brand: 'Honda', postCount: 3),
      ];

      final merged = modelForumsToMergeInto('Honda', candidates);

      expect(merged.map((f) => f.id), ['honda__cb_shine_125']);
    });

    test('the brand forum itself never merges into its own list', () {
      final candidates = [
        forum('honda', type: ForumType.brand, brand: 'Honda', postCount: 5),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('a model forum under a different brand is excluded', () {
      final candidates = [
        forum('yamaha__mt_15',
            type: ForumType.bikeModel, brand: 'Yamaha', postCount: 3),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test(
        'a general or custom forum that happens to carry the brand string is excluded',
        () {
      final candidates = [
        forum('maintenance',
            type: ForumType.general, brand: 'Honda', postCount: 10),
        forum('c-honda-owners-club',
            type: ForumType.custom, brand: 'Honda', postCount: 10),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('an empty model forum is skipped — not worth a read for zero posts',
        () {
      final candidates = [
        forum('honda__x_blade_160',
            type: ForumType.bikeModel, brand: 'Honda', postCount: 0),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('several model forums under the same brand all qualify', () {
      final candidates = [
        forum('honda__cb_shine_125',
            type: ForumType.bikeModel, brand: 'Honda', postCount: 1),
        forum('honda__x_blade_160',
            type: ForumType.bikeModel, brand: 'Honda', postCount: 2),
        forum('honda__cbr250rr',
            type: ForumType.bikeModel, brand: 'Honda', postCount: 0),
        forum('yamaha__mt_15',
            type: ForumType.bikeModel, brand: 'Yamaha', postCount: 4),
      ];

      final merged = modelForumsToMergeInto('Honda', candidates);

      expect(merged.map((f) => f.id),
          ['honda__cb_shine_125', 'honda__x_blade_160']);
    });
  });
}
