import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/models/forum_post_model.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/profile/data/models/user_profile_model.dart';
import 'package:throttleiq/features/profile/data/repositories/profile_repository.dart';
import 'package:throttleiq/features/social/data/models/ride_share_model.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';

/// Shared lists (the social feed, a ride's comments, All People, the forum
/// feeds) are read by every rider, and any account can write a doc into
/// them. One doc with a field of the wrong type must not fail the whole list:
/// the parsers tolerate it, and a doc that still can't be parsed is dropped.
void main() {
  final older = Timestamp.fromDate(DateTime(2026, 10, 1));
  final newer = Timestamp.fromDate(DateTime(2026, 10, 2));

  Map<String, dynamic> goodRide(String uid) => {
        'userId': uid,
        'userName': 'Rider',
        'userPhotoUrl': '',
        'bikeId': 'b1',
        'bikeName': 'FZS',
        'bikeType': '150cc',
        'rideDate': older,
        'polyline': [
          {'lat': 23.8, 'lng': 90.4},
        ],
        'audience': 'public',
        'allowedUserIds': <String>[],
        'createdAt': older,
      };

  group('the social feed', () {
    test('a share with missing or mistyped fields still parses', () {
      final model = RideShareModel.fromFirestore({
        'userId': 'm',
        'userName': 7,
        'bikeName': null,
        'polyline': [
          'x',
          {'lat': 'a', 'lng': 1},
          {'lat': 23.8, 'lng': 90}
        ],
        'allowedUserIds': [1, 'u2'],
        'audience': 3,
        'caption': 5,
      }, 'evil');
      expect(model.userName, '');
      expect(model.userPhotoUrl, '');
      expect(model.bikeId, '');
      expect(model.bikeName, '');
      expect(model.bikeType, '');
      expect(model.polyline, hasLength(1));
      expect(model.polyline.single.longitude, 90.0);
      expect(model.allowedUserIds, ['u2']);
      expect(model.audience, 'public');
      expect(model.caption, isNull);
    });

    test('getPublicRides drops a doc it cannot parse and keeps the rest',
        () async {
      final fs = FakeFirebaseFirestore();
      await fs.doc('rides/good').set(goodRide('alice'));
      // No userId at all: nothing to attribute it to, so it is dropped.
      await fs.doc('rides/evil').set({
        'audience': 'public',
        'createdAt': newer,
        'polyline': 'x',
      });

      final rides = await RideShareRepository.withFirestore(fs)
          .getPublicRides(hydrateVotes: false);

      expect(rides.map((r) => r.id), ['good']);
    });
  });

  test('getComments keeps the good comments around a malformed one', () async {
    final fs = FakeFirebaseFirestore();
    final comments = fs.collection('rides/r1/comments');
    await comments.doc('good').set({
      'userId': 'u1',
      'userName': 'Rider',
      'userPhotoUrl': '',
      'text': 'nice',
      'createdAt': older,
    });
    await comments.doc('no-name').set({
      'userId': 'm',
      'text': 'hi',
      'createdAt': newer,
    });
    await comments.doc('broken').set({
      'userId': 7,
      'text': ['x'],
      'createdAt': newer,
    });

    final list = await RideShareRepository.withFirestore(fs).getComments('r1');

    expect(list.map((c) => c.id), unorderedEquals(['good', 'no-name']));
    expect(list.firstWhere((c) => c.id == 'no-name').userName, '');
  });

  group('All People', () {
    test('a profile with a mistyped createdAt or bikesVisibility parses', () {
      final p = UserProfileModel.fromFirestore(
          {'displayName': 5, 'createdAt': 'zzzz', 'bikesVisibility': 7}, 'm');
      expect(p.displayName, '');
      expect(p.createdAt, isNull);
      expect(p.bikesVisibility, 'public');
    });

    test('getRecentUsers keeps the good profiles', () async {
      final fs = FakeFirebaseFirestore();
      await fs.doc('users/good').set({
        'displayName': 'Alice',
        'visibility': 'public',
        'createdAt': older,
      });
      await fs.doc('users/evil').set({
        'displayName': 'Mallory',
        'visibility': 'public',
        'createdAt': newer,
        'bikesVisibility': 7,
        'followerCount': 'lots',
      });

      final users =
          await ProfileRepository.withFirestore(fs).getRecentUsers(limit: 10);

      expect(users.map((u) => u.uid), contains('good'));
    });
  });

  group('forum feeds', () {
    test('a post with a mistyped forumId or title parses', () {
      final post =
          forumPostFromMap('p', {'forumId': 7, 'title': 3, 'userName': null});
      expect(post.forumId, '');
      expect(post.title, '');
      expect(post.userName, '');
    });

    test('postsFrom keeps the good posts around a malformed one', () async {
      final fs = FakeFirebaseFirestore();
      final posts = fs.collection('forums/general/posts');
      await posts.doc('good').set({
        'forumId': 'general',
        'userId': 'u1',
        'title': 'Hello',
        'createdAt': older,
      });
      await posts.doc('evil').set({
        'forumId': 7,
        'userId': 'm',
        'replyCount': 'many',
        'createdAt': newer,
      });

      final list = await ForumRepository.withFirestore(fs)
          .postsFrom(fs.collectionGroup('posts'), limit: 10);

      expect(list.map((p) => p.id), contains('good'));
    });
  });
}
