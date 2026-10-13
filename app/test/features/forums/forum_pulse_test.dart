import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';
import 'package:throttleiq/features/forums/domain/forum_directory.dart';
import 'package:throttleiq/features/forums/domain/forum_pulse.dart';

ForumPostEntity p(
  String id, {
  String forum = 'f1',
  ForumPostType type = ForumPostType.general,
  int up = 0,
  int down = 0,
  int minute = 0,
}) =>
    ForumPostEntity(
      id: id,
      forumId: forum,
      userId: 'u',
      userName: 'n',
      title: id,
      body: '',
      createdAt: DateTime(2026, 10, 1, 12, minute),
      postType: type,
      upvotes: up,
      downvotes: down,
    );

void main() {
  group('pulseSourceForumIds', () {
    test('garage forums first, then followed, de-duplicated', () {
      expect(
        pulseSourceForumIds(
          garageForumIds: ['yamaha__mt_15', 'honda__cb_shine'],
          followedForumIds: ['maintenance', 'yamaha__mt_15', 'ktm'],
        ),
        ['yamaha__mt_15', 'honda__cb_shine', 'maintenance', 'ktm'],
      );
    });

    test('capped so one page can never fan out unboundedly', () {
      final ids = pulseSourceForumIds(
        garageForumIds: [for (var i = 0; i < 5; i++) 'g$i'],
        followedForumIds: [for (var i = 0; i < 50; i++) 'f$i'],
      );
      expect(ids.length, kPulseMaxSources);
      expect(ids.take(5), ['g0', 'g1', 'g2', 'g3', 'g4']);
    });

    test('empty ids are skipped', () {
      expect(pulseSourceForumIds(garageForumIds: [''], followedForumIds: ['a', '']), ['a']);
    });

    test('a Pulse page reads no more than a thread page per source', () {
      expect(kPulsePerSourceLimit, lessThanOrEqualTo(kForumPostsPageSize));
    });
  });

  group('filterPulsePosts', () {
    final posts = [
      p('help', forum: 'garage', type: ForumPostType.troubleshoot, up: 1, minute: 5),
      p('diy', forum: 'followed', type: ForumPostType.diyGuide, up: 5, minute: 4),
      p('chat', forum: 'followed', up: 3, down: 3, minute: 3),
      p('hot', forum: 'garage', type: ForumPostType.gearReview, up: 5, minute: 6),
    ];

    test('All passes everything through in order', () {
      expect(filterPulsePosts(posts, PulseFilter.all), posts);
    });

    test('My bikes keeps only garage forum posts', () {
      expect(
        filterPulsePosts(posts, PulseFilter.myBikes, garageForumIds: {'garage'}).map((x) => x.id),
        ['help', 'hot'],
      );
    });

    test('Help & fixes and DIY guides filter by post type', () {
      expect(filterPulsePosts(posts, PulseFilter.help).map((x) => x.id), ['help']);
      expect(filterPulsePosts(posts, PulseFilter.diy).map((x) => x.id), ['diy']);
    });

    test('Most voted drops unscored posts and sorts by score, then newest', () {
      expect(
        filterPulsePosts(posts, PulseFilter.mostVoted).map((x) => x.id),
        ['hot', 'diy', 'help'],
      );
    });

    test('Saved is not a post filter', () {
      expect(filterPulsePosts(posts, PulseFilter.saved), isEmpty);
    });
  });

  group('mergeForumPostPages at the Pulse page size', () {
    test('merges sources newest first without holes', () {
      // Source A returned a full page (could have older posts); B is short.
      final a = [for (var i = 9; i >= 0; i--) p('a$i', forum: 'A', minute: 20 + i)];
      final b = [p('b0', forum: 'B', minute: 25), p('b1', forum: 'B', minute: 5)];

      final page = mergeForumPostPages([a, b], limit: kPulsePerSourceLimit);

      expect(page.hasMore, isTrue);
      // b1 is older than A's horizon (minute 20), so it waits for the next page.
      expect(page.posts.map((x) => x.id), isNot(contains('b1')));
      expect(page.posts.map((x) => x.id), contains('b0'));
      final times = page.posts.map((x) => x.createdAt).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i - 1].isBefore(times[i]), isFalse);
      }
    });
  });

  group('forum directory', () {
    test('every directory id is distinct and fits one documentId-in query', () {
      final ids = directoryForumIds();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, lessThanOrEqualTo(30));
    });

    test('topic boards keep their existing forum identities', () {
      // Renaming a board's topic would orphan its forum doc — see
      // forum_directory.dart.
      expect(TopicBoard.wrenchBench.slug, 'maintenance');
      expect(TopicBoard.twoStrokeSmoke.slug, 'two_strokes');
      expect(TopicBoard.apexLab.slug, 'riding_skills');
      expect(TopicBoard.sparkPlugCorner.slug, 'spark_plug_corner');
    });
  });
}
