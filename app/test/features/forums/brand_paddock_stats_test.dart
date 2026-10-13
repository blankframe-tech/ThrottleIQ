import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';
import 'package:throttleiq/features/forums/domain/forum_directory.dart';

ForumEntity _forum(
  String id,
  ForumType type,
  String brand, {
  int followers = 0,
  int posts = 0,
}) =>
    ForumEntity(
      id: id,
      type: type,
      brand: brand,
      displayName: id,
      followerCount: followers,
      postCount: posts,
      createdAt: DateTime(2026),
    );

void main() {
  test('a paddock sums its brand forum and every model forum under it', () {
    final stats = aggregateBrandPaddockStats([
      // The brand doc itself is often empty — riders post in model forums.
      _forum('yamaha', ForumType.brand, 'Yamaha'),
      _forum('yamaha__mt_15', ForumType.bikeModel, 'Yamaha', followers: 3, posts: 20),
      _forum('yamaha__fzs', ForumType.bikeModel, 'yamaha', followers: 2, posts: 11),
      _forum('honda__shine', ForumType.bikeModel, 'Honda', followers: 1, posts: 4),
    ]);

    expect(stats['yamaha']!.riders, 5);
    expect(stats['yamaha']!.posts, 31);
    expect(stats['honda']!.posts, 4);
    expect(stats.containsKey('ktm'), isFalse);
  });

  test('general and custom forums sharing a brand string are left out', () {
    final stats = aggregateBrandPaddockStats([
      _forum('club', ForumType.custom, 'Yamaha', followers: 99, posts: 99),
      _forum('topic', ForumType.general, 'Yamaha', followers: 99, posts: 99),
    ]);
    expect(stats, isEmpty);
  });

  test('forums of brands without a paddock are ignored', () {
    final stats = aggregateBrandPaddockStats([
      _forum('lifan__kpr', ForumType.bikeModel, 'Lifan', followers: 4, posts: 9),
    ]);
    expect(stats, isEmpty);
  });
}
