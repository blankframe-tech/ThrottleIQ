import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_reply_entity.dart';
import 'package:throttleiq/features/forums/domain/forum_solution.dart';

ForumPostEntity post({
  ForumPostType type = ForumPostType.troubleshoot,
  bool solved = false,
  String? solution,
}) =>
    ForumPostEntity(
      id: 'p',
      forumId: 'f',
      userId: 'author',
      userName: 'A',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026),
      postType: type,
      isSolved: solved,
      solutionReplyId: solution,
    );

ForumReplyEntity reply(String id) => ForumReplyEntity(
      id: id,
      postId: 'p',
      forumId: 'f',
      userId: 'u-$id',
      userName: id,
      body: 'b',
      createdAt: DateTime(2026),
    );

void main() {
  group('canMarkSolution', () {
    test('only the author of a troubleshoot post', () {
      expect(canMarkSolution(post(), 'author'), isTrue);
      expect(canMarkSolution(post(), 'someone-else'), isFalse);
      expect(canMarkSolution(post(), null), isFalse);
      expect(canMarkSolution(post(type: ForumPostType.diyGuide), 'author'), isFalse);
      expect(canMarkSolution(post(type: ForumPostType.general), 'author'), isFalse);
    });
  });

  group('toggleAcceptedReply', () {
    test('accepting a reply solves the post', () {
      final next = toggleAcceptedReply(post(), 'r1');
      expect(next.isSolved, isTrue);
      expect(next.solutionReplyId, 'r1');
    });

    test('accepting a different reply moves the solution', () {
      final next = toggleAcceptedReply(post(solved: true, solution: 'r1'), 'r2');
      expect(next.isSolved, isTrue);
      expect(next.solutionReplyId, 'r2');
    });

    test('accepting the accepted reply again un-accepts and reopens', () {
      final next = toggleAcceptedReply(post(solved: true, solution: 'r1'), 'r1');
      expect(next.isSolved, isFalse);
      expect(next.solutionReplyId, isNull);
    });
  });

  group('toggleSolvedFlag', () {
    test('marks an open post solved without inventing a solution', () {
      final next = toggleSolvedFlag(post());
      expect(next.isSolved, isTrue);
      expect(next.solutionReplyId, isNull);
    });

    test('reopening drops the accepted reply too', () {
      final next = toggleSolvedFlag(post(solved: true, solution: 'r1'));
      expect(next.isSolved, isFalse);
      expect(next.solutionReplyId, isNull);
    });
  });

  group('orderRepliesWithSolutionFirst', () {
    final replies = [reply('a'), reply('b'), reply('c')];

    test('pins the accepted reply first, rest in order', () {
      expect(orderRepliesWithSolutionFirst(replies, 'b').map((r) => r.id), ['b', 'a', 'c']);
    });

    test('no solution, or a deleted one, leaves the order alone', () {
      expect(orderRepliesWithSolutionFirst(replies, null).map((r) => r.id), ['a', 'b', 'c']);
      expect(orderRepliesWithSolutionFirst(replies, 'gone').map((r) => r.id), ['a', 'b', 'c']);
    });
  });
}
