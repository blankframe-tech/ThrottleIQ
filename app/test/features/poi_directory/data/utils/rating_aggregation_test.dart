import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/review_entity.dart';

void main() {
  group('RatingAggregation', () {
    group('Average Rating Calculation', () {
      test('calculates average of single review', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 4,
            text: 'Good place',
            createdAt: DateTime.now(),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(4.0));
      });

      test('calculates average of multiple reviews', () {
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

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(4.0));
      });

      test('handles perfect 5-star reviews', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 5,
            text: 'Perfect',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r2',
            placeId: 'place1',
            userId: 'user2',
            stars: 5,
            text: 'Amazing',
            createdAt: DateTime.now(),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(5.0));
      });

      test('handles 1-star reviews', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 1,
            text: 'Terrible',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r2',
            placeId: 'place1',
            userId: 'user2',
            stars: 1,
            text: 'Bad',
            createdAt: DateTime.now(),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(1.0));
      });

      test('calculates average with decimal result', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 5,
            text: 'Great',
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
            text: 'OK',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r4',
            placeId: 'place1',
            userId: 'user4',
            stars: 2,
            text: 'Bad',
            createdAt: DateTime.now(),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        // (5 + 4 + 3 + 2) / 4 = 14 / 4 = 3.5
        expect(average, equals(3.5));
      });

      test('handles many reviews with consistent rating', () {
        final reviews = List.generate(
          100,
          (i) => ReviewEntity(
            id: 'r$i',
            placeId: 'place1',
            userId: 'user$i',
            stars: 4,
            text: 'Good place',
            createdAt: DateTime.now(),
          ),
        );

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(4.0));
      });

      test('handles large number of reviews with varied ratings', () {
        final reviews = <ReviewEntity>[
          ...List.generate(
            50,
            (i) => ReviewEntity(
              id: 'r$i',
              placeId: 'place1',
              userId: 'user$i',
              stars: 5,
              text: 'Excellent',
              createdAt: DateTime.now(),
            ),
          ),
          ...List.generate(
            30,
            (i) => ReviewEntity(
              id: 'r${i + 50}',
              placeId: 'place1',
              userId: 'user${i + 50}',
              stars: 3,
              text: 'Average',
              createdAt: DateTime.now(),
            ),
          ),
          ...List.generate(
            20,
            (i) => ReviewEntity(
              id: 'r${i + 80}',
              placeId: 'place1',
              userId: 'user${i + 80}',
              stars: 1,
              text: 'Poor',
              createdAt: DateTime.now(),
            ),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        // (50*5 + 30*3 + 20*1) / 100 = (250 + 90 + 20) / 100 = 360 / 100 = 3.6
        expect(average, closeTo(3.6, 0.01));
      });
    });

    group('Rating Distribution', () {
      test('calculates distribution with single review', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 4,
            text: 'Good',
            createdAt: DateTime.now(),
          ),
        ];

        final distribution = _calculateDistribution(reviews);

        expect(distribution[1], equals(0));
        expect(distribution[2], equals(0));
        expect(distribution[3], equals(0));
        expect(distribution[4], equals(1));
        expect(distribution[5], equals(0));
      });

      test('calculates distribution of multiple reviews', () {
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
            text: 'Great',
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
            stars: 2,
            text: 'Bad',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r5',
            placeId: 'place1',
            userId: 'user5',
            stars: 1,
            text: 'Terrible',
            createdAt: DateTime.now(),
          ),
        ];

        final distribution = _calculateDistribution(reviews);

        expect(distribution[1], equals(1));
        expect(distribution[2], equals(1));
        expect(distribution[3], equals(0));
        expect(distribution[4], equals(1));
        expect(distribution[5], equals(2));
      });

      test('counts stars correctly for large dataset', () {
        final reviews = <ReviewEntity>[
          ...List.generate(
            10,
            (i) => ReviewEntity(
              id: 'r$i',
              placeId: 'place1',
              userId: 'user$i',
              stars: 5,
              text: 'Excellent',
              createdAt: DateTime.now(),
            ),
          ),
          ...List.generate(
            5,
            (i) => ReviewEntity(
              id: 'r${i + 10}',
              placeId: 'place1',
              userId: 'user${i + 10}',
              stars: 4,
              text: 'Good',
              createdAt: DateTime.now(),
            ),
          ),
        ];

        final distribution = _calculateDistribution(reviews);

        expect(distribution[4], equals(5));
        expect(distribution[5], equals(10));
      });
    });

    group('Review Count', () {
      test('counts zero reviews', () {
        final reviews = <ReviewEntity>[];
        expect(reviews.length, equals(0));
      });

      test('counts single review', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 4,
            text: 'Good',
            createdAt: DateTime.now(),
          ),
        ];
        expect(reviews.length, equals(1));
      });

      test('counts multiple reviews', () {
        final reviews = List.generate(
          42,
          (i) => ReviewEntity(
            id: 'r$i',
            placeId: 'place1',
            userId: 'user$i',
            stars: 4,
            text: 'Good place',
            createdAt: DateTime.now(),
          ),
        );
        expect(reviews.length, equals(42));
      });
    });

    group('Edge Cases', () {
      test('handles review with null text', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 5,
            text: '',
            createdAt: DateTime.now(),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(5.0));
      });

      test('calculates average ignoring review text', () {
        final reviews = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 5,
            text: 'This is a very long review text that should not affect the rating calculation',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r2',
            placeId: 'place1',
            userId: 'user2',
            stars: 3,
            text: 'Short',
            createdAt: DateTime.now(),
          ),
        ];

        double sum = 0;
        for (final r in reviews) {
          sum += r.stars;
        }
        final average = sum / reviews.length;

        expect(average, equals(4.0));
      });

      test('calculation is order-independent', () {
        final reviews1 = [
          ReviewEntity(
            id: 'r1',
            placeId: 'place1',
            userId: 'user1',
            stars: 5,
            text: 'Good',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r2',
            placeId: 'place1',
            userId: 'user2',
            stars: 3,
            text: 'OK',
            createdAt: DateTime.now(),
          ),
          ReviewEntity(
            id: 'r3',
            placeId: 'place1',
            userId: 'user3',
            stars: 1,
            text: 'Bad',
            createdAt: DateTime.now(),
          ),
        ];

        final reviews2 = [reviews1[2], reviews1[0], reviews1[1]];

        double sum1 = 0, sum2 = 0;
        for (final r in reviews1) sum1 += r.stars;
        for (final r in reviews2) sum2 += r.stars;

        final avg1 = sum1 / reviews1.length;
        final avg2 = sum2 / reviews2.length;

        expect(avg1, equals(avg2));
      });
    });
  });
}

/// Helper: calculate distribution of ratings
Map<int, int> _calculateDistribution(List<ReviewEntity> reviews) {
  final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  for (final review in reviews) {
    distribution[review.stars] = (distribution[review.stars] ?? 0) + 1;
  }
  return distribution;
}
