import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/review_entity.dart';

void main() {
  group('ReviewEntity', () {
    final testReview = ReviewEntity(
      id: 'review1',
      placeId: 'place1',
      userId: 'user1',
      stars: 4,
      text: 'Great place!',
      imageUrls: [],
      createdAt: DateTime.now(),
      flagged: false,
    );

    test('ReviewEntity should be created correctly', () {
      expect(testReview.id, equals('review1'));
      expect(testReview.placeId, equals('place1'));
      expect(testReview.userId, equals('user1'));
      expect(testReview.stars, equals(4));
      expect(testReview.text, equals('Great place!'));
      expect(testReview.flagged, isFalse);
    });

    test('ReviewEntity equality works', () {
      final review2 = ReviewEntity(
        id: 'review1',
        placeId: 'place1',
        userId: 'user1',
        stars: 4,
        text: 'Great place!',
        imageUrls: [],
        createdAt: testReview.createdAt,
        flagged: false,
      );

      expect(testReview, equals(review2));
    });
  });

  group('Rating Aggregation', () {
    test('calculate average rating from reviews', () {
      final reviews = [
        ReviewEntity(
          id: 'r1',
          placeId: 'place1',
          userId: 'user1',
          stars: 5,
          text: 'Excellent',
          createdAt: DateTime.now(),
        ),
        ReviewEntity(
          id: 'r2',
          placeId: 'place1',
          userId: 'user2',
          stars: 4,
          text: 'Good',
          createdAt: DateTime.now(),
        ),
        ReviewEntity(
          id: 'r3',
          placeId: 'place1',
          userId: 'user3',
          stars: 3,
          text: 'Average',
          createdAt: DateTime.now(),
        ),
      ];

      double totalStars = 0;
      for (final review in reviews) {
        totalStars += review.stars;
      }
      final averageRating = totalStars / reviews.length;

      expect(averageRating, equals(4.0));
    });

    test('rating distribution calculation', () {
      final reviews = [
        ReviewEntity(
          id: 'r1',
          placeId: 'place1',
          userId: 'user1',
          stars: 5,
          text: 'Excellent',
          createdAt: DateTime.now(),
        ),
        ReviewEntity(
          id: 'r2',
          placeId: 'place1',
          userId: 'user2',
          stars: 5,
          text: 'Excellent',
          createdAt: DateTime.now(),
        ),
        ReviewEntity(
          id: 'r3',
          placeId: 'place1',
          userId: 'user3',
          stars: 4,
          text: 'Good',
          createdAt: DateTime.now(),
        ),
        ReviewEntity(
          id: 'r4',
          placeId: 'place1',
          userId: 'user4',
          stars: 3,
          text: 'Average',
          createdAt: DateTime.now(),
        ),
        ReviewEntity(
          id: 'r5',
          placeId: 'place1',
          userId: 'user5',
          stars: 1,
          text: 'Poor',
          createdAt: DateTime.now(),
        ),
      ];

      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final review in reviews) {
        distribution[review.stars] = (distribution[review.stars] ?? 0) + 1;
      }

      expect(distribution[5], equals(2));
      expect(distribution[4], equals(1));
      expect(distribution[3], equals(1));
      expect(distribution[1], equals(1));
      expect(distribution[2], equals(0));
    });

    test('calculate rating from sum and count', () {
      const ratingSum = 18.0; // 5 + 4 + 3 + 3 + 3
      const ratingCount = 5;

      final averageRating = ratingSum / ratingCount;

      expect(averageRating, equals(3.6));
    });

    test('zero reviews should have zero rating', () {
      const ratingSum = 0.0;
      const ratingCount = 0;

      final averageRating = ratingCount == 0 ? 0.0 : ratingSum / ratingCount;

      expect(averageRating, equals(0.0));
    });
  });

  group('Review Validation', () {
    test('valid star ratings are 1-5', () {
      for (int stars = 1; stars <= 5; stars++) {
        final review = ReviewEntity(
          id: 'r1',
          placeId: 'place1',
          userId: 'user1',
          stars: stars,
          text: 'Test',
          createdAt: DateTime.now(),
        );

        expect(review.stars, greaterThanOrEqualTo(1));
        expect(review.stars, lessThanOrEqualTo(5));
      }
    });

    test('review with images stores urls', () {
      final imageUrls = [
        'https://example.com/image1.jpg',
        'https://example.com/image2.jpg',
      ];

      final review = ReviewEntity(
        id: 'r1',
        placeId: 'place1',
        userId: 'user1',
        stars: 5,
        text: 'Great!',
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
      );

      expect(review.imageUrls, equals(imageUrls));
      expect(review.imageUrls.length, equals(2));
    });

    test('flagged review state', () {
      final review = ReviewEntity(
        id: 'r1',
        placeId: 'place1',
        userId: 'user1',
        stars: 3,
        text: 'Inappropriate content',
        createdAt: DateTime.now(),
        flagged: true,
      );

      expect(review.flagged, isTrue);
    });
  });
}
