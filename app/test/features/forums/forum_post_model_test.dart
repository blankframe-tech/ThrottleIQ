import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/models/forum_post_model.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';

/// Serialization of the Pit Wall post fields: post type, solved state,
/// author bike and attachment — and that docs written before any of them
/// existed still read back cleanly.
void main() {
  group('forumPostFromMap', () {
    test('a pre-redesign doc reads as an unsolved general post', () {
      final post = forumPostFromMap('p1', {
        'forumId': 'yamaha__mt_15',
        'userId': 'u1',
        'userName': 'Alex',
        'title': 'Chain slack',
        'body': 'How much?',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'replyCount': 2,
        'upvotes': 3,
        'downvotes': 1,
      });

      expect(post.postType, ForumPostType.general);
      expect(post.isSolved, isFalse);
      expect(post.solutionReplyId, isNull);
      expect(post.authorBike, isNull);
      expect(post.attachment, isNull);
      expect(post.netScore, 2);
    });

    test('reads every Pit Wall field', () {
      final post = forumPostFromMap('p2', {
        'forumId': 'f',
        'userId': 'u1',
        'title': 't',
        'body': 'b',
        'postType': 'troubleshoot',
        'isSolved': true,
        'solutionReplyId': 'r9',
        'authorBike': 'KTM Duke 390 · 12,400 km',
        'attachment': {
          'kind': 'maintenance',
          'refId': 'visit-1',
          'title': 'Oil change',
          'subtitle': '3 Oct · 12,400 km',
          'bikeId': 'bike-1',
        },
      });

      expect(post.postType, ForumPostType.troubleshoot);
      expect(post.isSolved, isTrue);
      expect(post.solutionReplyId, 'r9');
      expect(post.authorBike, 'KTM Duke 390 · 12,400 km');
      expect(post.attachment!.kind, ForumAttachmentKind.maintenance);
      expect(post.attachment!.bikeId, 'bike-1');
    });

    test('an unknown post type or a malformed attachment degrades, not throws', () {
      final post = forumPostFromMap('p3', {
        'postType': 'from-the-future',
        'attachment': {'kind': 'video', 'refId': 'x'},
        'authorBike': '   ',
        'solutionReplyId': '',
        'upvotes': 2.0,
      });

      expect(post.postType, ForumPostType.general);
      expect(post.attachment, isNull);
      expect(post.authorBike, isNull);
      expect(post.solutionReplyId, isNull);
      expect(post.upvotes, 2);
    });
  });

  group('newForumPostFields', () {
    test('a new post starts unsolved, unscored, and with its type', () {
      final fields = newForumPostFields(
        forumId: 'f',
        userId: 'u',
        userName: 'n',
        userPhotoUrl: '',
        title: 't',
        body: 'b',
        postType: ForumPostType.diyGuide,
      );

      expect(fields['postType'], 'diyGuide');
      expect(fields['isSolved'], false);
      expect(fields['replyCount'], 0);
      expect(fields['upvotes'], 0);
      expect(fields['downvotes'], 0);
      expect(fields.containsKey('solutionReplyId'), isFalse);
      expect(fields.containsKey('authorBike'), isFalse);
      expect(fields.containsKey('attachment'), isFalse);
    });

    test('only writes keys the post create rule allows', () {
      const allowed = {
        'forumId', 'userId', 'userName', 'userPhotoUrl', 'title', 'body',
        'createdAt', 'replyCount', 'upvotes', 'downvotes',
        'postType', 'isSolved', 'authorBike', 'attachment',
      };
      final fields = newForumPostFields(
        forumId: 'f',
        userId: 'u',
        userName: 'n',
        userPhotoUrl: '',
        title: 't',
        body: 'b',
        authorBike: 'Honda',
        attachment: const ForumAttachment(
            kind: ForumAttachmentKind.ride, refId: 'r', title: 't', subtitle: 's'),
      );
      expect(allowed.containsAll(fields.keys), isTrue);
    });

    test('caps the bike byline at the rules limit', () {
      final fields = newForumPostFields(
        forumId: 'f',
        userId: 'u',
        userName: 'n',
        userPhotoUrl: '',
        title: 't',
        body: 'b',
        authorBike: 'x' * 200,
      );
      expect((fields['authorBike'] as String).length, kAuthorBikeMaxLength);
    });

    test('an attachment round-trips and is capped', () {
      final attachment = ForumAttachment(
        kind: ForumAttachmentKind.ride,
        refId: 'ride-1',
        title: 'T' * 200,
        subtitle: 'S' * 400,
      );
      final map = attachment.toMap();
      expect((map['title'] as String).length, ForumAttachment.maxTitleLength);
      expect((map['subtitle'] as String).length, ForumAttachment.maxSubtitleLength);
      expect(map.containsKey('bikeId'), isFalse);

      final back = ForumAttachment.fromMap(map)!;
      expect(back.kind, ForumAttachmentKind.ride);
      expect(back.refId, 'ride-1');
    });
  });

  group('ForumPostEntity.copyWith', () {
    final post = ForumPostEntity(
      id: 'p',
      forumId: 'f',
      userId: 'u',
      userName: 'n',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026),
      postType: ForumPostType.troubleshoot,
      isSolved: true,
      solutionReplyId: 'r1',
      authorBike: 'bike',
    );

    test('can clear the accepted solution', () {
      final reopened = post.copyWith(isSolved: false, solutionReplyId: null);
      expect(reopened.isSolved, isFalse);
      expect(reopened.solutionReplyId, isNull);
      expect(reopened.authorBike, 'bike');
      expect(reopened.postType, ForumPostType.troubleshoot);
    });

    test('leaves the solution alone when not passed', () {
      expect(post.copyWith(upvotes: 4).solutionReplyId, 'r1');
    });
  });

  group('post photos', () {
    const ok = 'https://res.cloudinary.com/vjvcigkt/image/upload/v1/forumPhotos/u/a.jpg';

    test('a post without imageUrls reads as no photos', () {
      final post = forumPostFromMap('p', {'title': 't', 'body': 'b'});
      expect(post.imageUrls, isEmpty);
    });

    test('keeps allow-listed URLs, drops junk, caps at the max', () {
      expect(
        forumImageUrlsFromRaw([ok, 'https://evil.example.com/x.jpg', 7, '', ok, ok, ok, ok]),
        List.filled(kForumPostMaxImages, ok),
      );
      expect(forumImageUrlsFromRaw('nope'), isEmpty);
    });

    test('newForumPostFields writes imageUrls only when there are photos', () {
      Map<String, dynamic> fields(List<String> urls) => newForumPostFields(
            forumId: 'f',
            userId: 'u',
            userName: 'n',
            userPhotoUrl: '',
            title: 't',
            body: 'b',
            imageUrls: urls,
          );
      expect(fields(const []).containsKey('imageUrls'), isFalse);
      expect(fields([ok])['imageUrls'], [ok]);
      expect(fields(List.filled(6, ok))['imageUrls'], hasLength(kForumPostMaxImages));
    });
  });
}
