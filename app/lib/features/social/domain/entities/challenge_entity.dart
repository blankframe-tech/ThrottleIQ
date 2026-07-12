import 'package:equatable/equatable.dart';

enum ChallengeType { distance, streak }

class ChallengeEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final double? targetValue; // e.g., 500 km
  final int? targetDays; // e.g., 7 days for streak
  final DateTime startDate;
  final DateTime endDate;
  final String badge; // Badge name/ID
  final bool isActive;

  const ChallengeEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.targetValue,
    this.targetDays,
    required this.startDate,
    required this.endDate,
    required this.badge,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, startDate, endDate];
}

class UserChallengeProgress extends Equatable {
  final String challengeId;
  final String userId;
  final double currentValue; // Current km or days
  final bool isCompleted;
  final DateTime? completedAt;
  final bool badgeEarned;

  const UserChallengeProgress({
    required this.challengeId,
    required this.userId,
    this.currentValue = 0,
    this.isCompleted = false,
    this.completedAt,
    this.badgeEarned = false,
  });

  UserChallengeProgress copyWith({
    double? currentValue,
    bool? isCompleted,
    DateTime? completedAt,
    bool? badgeEarned,
  }) {
    return UserChallengeProgress(
      challengeId: challengeId,
      userId: userId,
      currentValue: currentValue ?? this.currentValue,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      badgeEarned: badgeEarned ?? this.badgeEarned,
    );
  }

  @override
  List<Object?> get props => [challengeId, userId, isCompleted];
}
