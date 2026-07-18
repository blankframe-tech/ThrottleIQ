import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';

void main() {
  group('ForumEntity', () {
    final testForum = ForumEntity(
      id: 'yamaha_mt-15',
      type: ForumType.bikeModel,
      brand: 'Yamaha',
      model: 'MT-15',
      displayName: 'Yamaha MT-15',
      followerCount: 12,
      postCount: 4,
      createdAt: DateTime(2024, 1, 15),
    );

    test('exposes brand+model forum fields', () {
      expect(testForum.id, 'yamaha_mt-15');
      expect(testForum.type, ForumType.bikeModel);
      expect(testForum.brand, 'Yamaha');
      expect(testForum.model, 'MT-15');
      expect(testForum.displayName, 'Yamaha MT-15');
    });

    test('brand-only forum has a null model', () {
      final brandForum = ForumEntity(
        id: 'yamaha',
        type: ForumType.brand,
        brand: 'Yamaha',
        displayName: 'Yamaha',
        createdAt: DateTime.now(),
      );

      expect(brandForum.model, isNull);
      expect(brandForum.type, ForumType.brand);
      expect(brandForum.followerCount, 0);
      expect(brandForum.postCount, 0);
    });

    test('props include identity and counters', () {
      expect(testForum.props, contains(testForum.id));
      expect(testForum.props, contains(testForum.followerCount));
      expect(testForum.props, contains(testForum.postCount));
    });

    test('equatable equality is value-based', () {
      final copy = ForumEntity(
        id: testForum.id,
        type: testForum.type,
        brand: testForum.brand,
        model: testForum.model,
        displayName: testForum.displayName,
        followerCount: testForum.followerCount,
        postCount: testForum.postCount,
        createdAt: testForum.createdAt,
      );

      expect(copy, testForum);
    });

    test('ForumType.fromString round-trips known values', () {
      expect(ForumType.fromString('brand'), ForumType.brand);
      expect(ForumType.fromString('bikeModel'), ForumType.bikeModel);
    });

    test('ForumType.fromString falls back to brand for unknown values', () {
      expect(ForumType.fromString('nonsense'), ForumType.brand);
    });
  });
}
