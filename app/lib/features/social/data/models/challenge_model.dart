import '../../domain/entities/challenge_entity.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type; // 'distance' or 'streak'
  final double? targetValue;
  final int? targetDays;
  final DateTime startDate;
  final DateTime endDate;
  final String badge;
  final bool isActive;

  ChallengeModel({
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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'targetValue': targetValue,
      'targetDays': targetDays,
      'startDate': startDate,
      'endDate': endDate,
      'badge': badge,
      'isActive': isActive,
    };
  }

  factory ChallengeModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return ChallengeModel(
      id: docId,
      title: data['title'] as String,
      description: data['description'] as String,
      type: data['type'] as String,
      targetValue: (data['targetValue'] as num?)?.toDouble(),
      targetDays: (data['targetDays'] as num?)?.toInt(),
      startDate: (data['startDate'] as dynamic).toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as dynamic).toDate() ?? DateTime.now(),
      badge: data['badge'] as String,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  ChallengeEntity toEntity() {
    return ChallengeEntity(
      id: id,
      title: title,
      description: description,
      type: type == 'streak' ? ChallengeType.streak : ChallengeType.distance,
      targetValue: targetValue,
      targetDays: targetDays,
      startDate: startDate,
      endDate: endDate,
      badge: badge,
      isActive: isActive,
    );
  }
}

class UserChallengeProgressModel {
  final String challengeId;
  final String userId;
  final double currentValue;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool badgeEarned;

  UserChallengeProgressModel({
    required this.challengeId,
    required this.userId,
    this.currentValue = 0,
    this.isCompleted = false,
    this.completedAt,
    this.badgeEarned = false,
  });

  factory UserChallengeProgressModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return UserChallengeProgressModel(
      challengeId: docId,
      userId: data['userId'] as String,
      currentValue: (data['currentValue'] as num?)?.toDouble() ?? 0,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as dynamic).toDate()
          : null,
      badgeEarned: data['badgeEarned'] as bool? ?? false,
    );
  }
}
