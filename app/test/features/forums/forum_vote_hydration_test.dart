import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';

ForumPostEntity post(String id, {int upvotes = 0, int downvotes = 0}) =>
    ForumPostEntity(
      id: id,
      forumId: 'f',
      userId: 'u',
      userName: 'U',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 10, 27),
      upvotes: upvotes,
      downvotes: downvotes,
    );

/// Critique 2026-10-27 #13: no `votes/{uid}` read for a post nobody voted on.
void main() {
  test('only posts with votes are asked about', () async {
    final asked = <String>[];
    final result = await ForumRepository.hydrateWith(
      [post('none'), post('up', upvotes: 2), post('down', downvotes: 1)],
      (p) async {
        asked.add(p.id);
        return p.id == 'up' ? 1 : null;
      },
    );
    expect(asked, ['up', 'down']);
    expect(result.map((p) => p.myVote), [null, 1, null]);
    expect(result.map((p) => p.id), ['none', 'up', 'down']);
  });

  test('a 0/0 post reads nothing', () async {
    var calls = 0;
    final result = await ForumRepository.hydrateWith([post('none')], (_) async {
      calls++;
      return 1;
    });
    expect(calls, 0);
    expect(result.single.myVote, isNull);
  });
}
