import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';
import 'package:throttleiq/features/forums/presentation/providers/forum_bookmarks_provider.dart';

ForumBookmark b(String postId, {int savedAt = 0}) => ForumBookmark(
      forumId: 'f',
      postId: postId,
      title: 'Title $postId',
      forumName: 'Yamaha MT-15',
      postType: ForumPostType.troubleshoot,
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt),
    );

void main() {
  test('bookmarks round-trip through the prefs encoding', () {
    final list = [b('1', savedAt: 1000), b('2', savedAt: 2000)];
    expect(decodeForumBookmarks(encodeForumBookmarks(list)), list);
  });

  test('a malformed blob or entry degrades instead of throwing', () {
    expect(decodeForumBookmarks(null), isEmpty);
    expect(decodeForumBookmarks('not json'), isEmpty);
    expect(decodeForumBookmarks('{"a":1}'), isEmpty);
    expect(
      decodeForumBookmarks('[{"forumId":"f"},{"forumId":"f","postId":"p"}]').map((x) => x.postId),
      ['p'],
    );
  });

  test('toggle adds newest first, and removes when already saved', () {
    var list = toggleForumBookmark(const [], b('1'));
    list = toggleForumBookmark(list, b('2'));
    expect(list.map((x) => x.postId), ['2', '1']);

    list = toggleForumBookmark(list, b('1'));
    expect(list.map((x) => x.postId), ['2']);
  });

  test('saving past the cap drops the oldest', () {
    var list = <ForumBookmark>[];
    for (var i = 0; i < kMaxForumBookmarks + 5; i++) {
      list = toggleForumBookmark(list, b('$i'));
    }
    expect(list.length, kMaxForumBookmarks);
    expect(list.first.postId, '${kMaxForumBookmarks + 4}');
  });
}
