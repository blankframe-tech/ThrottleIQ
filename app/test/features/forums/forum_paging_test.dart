import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';

final t0 = DateTime(2026, 10, 1, 12);
DateTime minutesAgo(int m) => t0.subtract(Duration(minutes: m));

ForumPostEntity post(String id, int minsAgo, {String forumId = 'f'}) =>
    ForumPostEntity(
      id: id,
      forumId: forumId,
      userId: 'u',
      userName: 'U',
      title: id,
      body: '',
      createdAt: minutesAgo(minsAgo),
    );

ForumEntity forum(String name, {int followers = 0}) => ForumEntity(
      id: name.toLowerCase(),
      type: ForumType.general,
      brand: '',
      displayName: name,
      followerCount: followers,
      createdAt: DateTime(2026),
    );

/// Paged forum post reads and the cached forum-name search
/// (issues §90.A7 / §90.A8).
void main() {
  group('mergeForumPostPages', () {
    test('every source short: all posts, newest first, no more pages', () {
      final page = mergeForumPostPages([
        [post('a', 1), post('b', 10)],
        [post('c', 5, forumId: 'model')],
      ], limit: 3);
      expect(page.posts.map((p) => p.id), ['a', 'c', 'b']);
      expect(page.hasMore, isFalse);
      expect(page.cursor, minutesAgo(10));
    });

    test('a full source bounds the page so a sparse one leaves no hole', () {
      final dense = [post('d1', 1), post('d2', 2), post('d3', 3)];
      final sparse = [
        post('s1', 2, forumId: 'm'),
        post('s2', 600, forumId: 'm')
      ];
      final page = mergeForumPostPages([dense, sparse], limit: 3);
      // s2 is older than the dense source's horizon: it waits for page two.
      expect(page.posts.map((p) => p.id), ['d1', 'd2', 's1', 'd3']);
      expect(page.cursor, minutesAgo(3));
      expect(page.hasMore, isTrue);
    });

    test('a post returned by two pages is shown once', () {
      final page = mergeForumPostPages([
        [post('x', 1)],
        [post('x', 1)],
      ], limit: 5);
      expect(page.posts, hasLength(1));
    });

    test('no posts at all: empty, no cursor', () {
      final page = mergeForumPostPages([[], []], limit: 5);
      expect(page.posts, isEmpty);
      expect(page.cursor, isNull);
      expect(page.hasMore, isFalse);
    });
  });

  group('filterForumsByName', () {
    final forums = [
      forum('Vintage Royals', followers: 50),
      forum('Royal Enfield', followers: 10),
      forum('Yamaha', followers: 99),
    ];

    test('prefix matches rank above mid-string ones, case-insensitively', () {
      expect(filterForumsByName(forums, 'ROY').map((f) => f.displayName),
          ['Royal Enfield', 'Vintage Royals']);
    });

    test('blank query matches nothing', () {
      expect(filterForumsByName(forums, '   '), isEmpty);
    });

    test('respects the limit', () {
      expect(filterForumsByName(forums, 'a', limit: 1), hasLength(1));
    });
  });
}
