import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';

/// Which model forums get merged into a brand forum's post list — the pure
/// filtering `ForumRepository.getPosts` runs on candidate forums fetched by
/// `brand`. See that method's doc comment: a post made in "Honda CB Shine
/// 125" should also surface when viewing "Honda", but nothing else should.
ForumEntity forum(String id,
        {required ForumType type, required String brand, int postCount = 0}) =>
    ForumEntity(id: id, type: type, brand: brand, postCount: postCount, displayName: id,
        createdAt: DateTime(2026, 1, 1));

void main() {
  group('modelForumsToMergeInto', () {
    test('a bike-model forum with posts, under the right brand, qualifies', () {
      final candidates = [
        forum('honda__cb_shine_125', type: ForumType.bikeModel, brand: 'Honda', postCount: 3),
      ];

      final merged = modelForumsToMergeInto('Honda', candidates);

      expect(merged.map((f) => f.id), ['honda__cb_shine_125']);
    });

    test('the brand forum itself never merges into its own list', () {
      final candidates = [
        forum('honda', type: ForumType.brand, brand: 'Honda', postCount: 5),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('a model forum under a different brand is excluded', () {
      final candidates = [
        forum('yamaha__mt_15', type: ForumType.bikeModel, brand: 'Yamaha', postCount: 3),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('a general or custom forum that happens to carry the brand string is excluded', () {
      final candidates = [
        forum('maintenance', type: ForumType.general, brand: 'Honda', postCount: 10),
        forum('c-honda-owners-club', type: ForumType.custom, brand: 'Honda', postCount: 10),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('an empty model forum is skipped — not worth a read for zero posts', () {
      final candidates = [
        forum('honda__x_blade_160', type: ForumType.bikeModel, brand: 'Honda', postCount: 0),
      ];

      expect(modelForumsToMergeInto('Honda', candidates), isEmpty);
    });

    test('several model forums under the same brand all qualify', () {
      final candidates = [
        forum('honda__cb_shine_125', type: ForumType.bikeModel, brand: 'Honda', postCount: 1),
        forum('honda__x_blade_160', type: ForumType.bikeModel, brand: 'Honda', postCount: 2),
        forum('honda__cbr250rr', type: ForumType.bikeModel, brand: 'Honda', postCount: 0),
        forum('yamaha__mt_15', type: ForumType.bikeModel, brand: 'Yamaha', postCount: 4),
      ];

      final merged = modelForumsToMergeInto('Honda', candidates);

      expect(merged.map((f) => f.id), ['honda__cb_shine_125', 'honda__x_blade_160']);
    });
  });
}
