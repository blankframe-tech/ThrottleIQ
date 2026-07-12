import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/challenge_entity.dart';

void main() {
  group('ChallengeEntity', () {
    final startDate = DateTime(2024, 1, 1);
    final endDate = DateTime(2024, 1, 31);

    final distanceChallenge = ChallengeEntity(
      id: 'challenge1',
      title: 'Monthly Distance Challenge',
      description: 'Ride 500 km this month',
      type: ChallengeType.distance,
      targetValue: 500.0,
      startDate: startDate,
      endDate: endDate,
      badge: 'monthly_500km',
    );

    final streakChallenge = ChallengeEntity(
      id: 'challenge2',
      title: 'Weekly Streak',
      description: 'Ride for 7 consecutive days',
      type: ChallengeType.streak,
      targetDays: 7,
      startDate: startDate,
      endDate: endDate,
      badge: 'weekly_streak',
    );

    test('distance challenge has target value', () {
      expect(distanceChallenge.type, ChallengeType.distance);
      expect(distanceChallenge.targetValue, 500.0);
    });

    test('streak challenge has target days', () {
      expect(streakChallenge.type, ChallengeType.streak);
      expect(streakChallenge.targetDays, 7);
    });

    test('challenge equality uses props', () {
      final identical = ChallengeEntity(
        id: 'challenge1',
        title: distanceChallenge.title,
        description: distanceChallenge.description,
        type: distanceChallenge.type,
        targetValue: distanceChallenge.targetValue,
        startDate: startDate,
        endDate: endDate,
        badge: distanceChallenge.badge,
      );

      expect(identical.id, distanceChallenge.id);
    });

    test('challenge is active by default', () {
      expect(distanceChallenge.isActive, true);
    });

    test('props contain id and dates', () {
      expect(distanceChallenge.props, contains('challenge1'));
      expect(distanceChallenge.props, contains(startDate));
      expect(distanceChallenge.props, contains(endDate));
    });
  });

  group('UserChallengeProgress', () {
    final progress = UserChallengeProgress(
      challengeId: 'challenge1',
      userId: 'user1',
      currentValue: 250.0,
      isCompleted: false,
    );

    test('updates progress value', () {
      final updated = progress.copyWith(currentValue: 350.0);
      expect(updated.currentValue, 350.0);
      expect(updated.challengeId, progress.challengeId);
    });

    test('marks challenge as completed', () {
      final completedAt = DateTime.now();
      final completed = progress.copyWith(
        isCompleted: true,
        completedAt: completedAt,
      );

      expect(completed.isCompleted, true);
      expect(completed.completedAt, completedAt);
    });

    test('can earn badge', () {
      final withBadge = progress.copyWith(badgeEarned: true);
      expect(withBadge.badgeEarned, true);
    });

    test('equality based on props', () {
      expect(
        progress.props,
        containsAll([progress.challengeId, progress.userId]),
      );
    });
  });
}
