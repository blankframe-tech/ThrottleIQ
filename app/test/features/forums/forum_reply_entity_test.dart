import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_reply_entity.dart';

void main() {
  group('ForumReplyEntity', () {
    final testReply = ForumReplyEntity(
      id: 'reply1',
      postId: 'post1',
      forumId: 'yamaha_mt-15',
      userId: 'user2',
      userName: 'Jane Doe',
      body: 'About 20-30mm of slack is normal.',
      createdAt: DateTime(2024, 1, 16),
    );

    test('exposes reply fields', () {
      expect(testReply.postId, 'post1');
      expect(testReply.forumId, 'yamaha_mt-15');
      expect(testReply.userName, 'Jane Doe');
      expect(testReply.body, 'About 20-30mm of slack is normal.');
    });

    test('props include critical identifiers', () {
      expect(testReply.props, contains(testReply.id));
      expect(testReply.props, contains(testReply.postId));
      expect(testReply.props, contains(testReply.forumId));
      expect(testReply.props, contains(testReply.userId));
    });

    test('equatable equality is value-based', () {
      final copy = ForumReplyEntity(
        id: testReply.id,
        postId: testReply.postId,
        forumId: testReply.forumId,
        userId: testReply.userId,
        userName: testReply.userName,
        body: testReply.body,
        createdAt: testReply.createdAt,
      );

      expect(copy, testReply);
    });
  });
}
