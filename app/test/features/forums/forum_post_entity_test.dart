import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';

void main() {
  group('ForumPostEntity', () {
    final testPost = ForumPostEntity(
      id: 'post1',
      forumId: 'yamaha_mt-15',
      userId: 'user1',
      userName: 'John Doe',
      userPhotoUrl: 'http://example.com/photo.jpg',
      title: 'Chain slack question',
      body: 'How much slack should the chain have on a MT-15?',
      createdAt: DateTime(2024, 1, 15),
    );

    test('exposes post fields', () {
      expect(testPost.forumId, 'yamaha_mt-15');
      expect(testPost.title, 'Chain slack question');
      expect(testPost.replyCount, 0);
      expect(testPost.likes, 0);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = testPost.copyWith(replyCount: 3, likes: 5);

      expect(updated.id, testPost.id);
      expect(updated.title, testPost.title);
      expect(updated.body, testPost.body);
      expect(updated.replyCount, 3);
      expect(updated.likes, 5);
    });

    test('copyWith with no args returns an equal copy', () {
      expect(testPost.copyWith(), testPost);
    });

    test('props include critical identifiers', () {
      expect(testPost.props, contains(testPost.id));
      expect(testPost.props, contains(testPost.forumId));
      expect(testPost.props, contains(testPost.userId));
    });
  });
}
