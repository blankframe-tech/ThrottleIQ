import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/challenge_entity.dart';
import '../models/challenge_model.dart';

class ChallengeRepository {
  static final ChallengeRepository _instance =
      ChallengeRepository._internal();

  factory ChallengeRepository() => _instance;

  ChallengeRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets all active challenges for the current month.
  Future<List<ChallengeEntity>> getActiveChallenges() async {
    final now = DateTime.now();
    final querySnapshot = await _firestore
        .collection('challenges')
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThan: now)
        .orderBy('endDate', descending: false)
        .get();

    return querySnapshot.docs
        .map((doc) =>
            ChallengeModel.fromFirestore(doc.data(), doc.id).toEntity())
        .toList();
  }

  /// Gets a specific challenge by ID.
  Future<ChallengeEntity?> getChallenge(String challengeId) async {
    final doc = await _firestore
        .collection('challenges')
        .doc(challengeId)
        .get();

    if (!doc.exists) return null;

    return ChallengeModel.fromFirestore(doc.data()!, doc.id).toEntity();
  }

  /// Gets user's progress on all challenges.
  Future<List<UserChallengeProgressModel>> getUserProgress(
    String userId,
  ) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('challengeProgress')
        .get();

    return querySnapshot.docs
        .map((doc) =>
            UserChallengeProgressModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Gets user's progress on a specific challenge.
  Future<UserChallengeProgressModel?> getUserChallengeProgress({
    required String userId,
    required String challengeId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('challengeProgress')
        .doc(challengeId)
        .get();

    if (!doc.exists) {
      return UserChallengeProgressModel(
        challengeId: challengeId,
        userId: userId,
        currentValue: 0,
        isCompleted: false,
        badgeEarned: false,
      );
    }

    return UserChallengeProgressModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Updates user's progress on a challenge.
  Future<void> updateChallengeProgress({
    required String userId,
    required String challengeId,
    required double currentValue,
    required bool isCompleted,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('challengeProgress')
        .doc(challengeId);

    await docRef.set({
      'challengeId': challengeId,
      'userId': userId,
      'currentValue': currentValue,
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
      'badgeEarned': false,
    }, SetOptions(merge: true));
  }

  /// Marks a badge as earned locally.
  Future<void> earnBadge({
    required String userId,
    required String challengeId,
    required String badgeId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('earnedBadges')
        .doc(badgeId)
        .set({
      'badgeId': badgeId,
      'challengeId': challengeId,
      'earnedAt': FieldValue.serverTimestamp(),
    });

    // Also update challenge progress
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('challengeProgress')
        .doc(challengeId)
        .update({
      'badgeEarned': true,
    });
  }

  /// Records a standalone milestone badge (e.g. "500 km", "Ton-up") — not
  /// tied to a time-boxed challenge doc, so unlike [earnBadge] this doesn't
  /// touch challengeProgress (there is no challenge backing these; the
  /// Rider Stats screen recomputes earned/not-earned locally and calls this
  /// as a fire-and-forget sync). Lays the groundwork for a future
  /// partner-discount lookup keyed off this same earnedBadges collection.
  Future<void> earnMilestoneBadge({
    required String userId,
    required String badgeId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('earnedBadges')
        .doc(badgeId)
        .set({
      'badgeId': badgeId,
      'earnedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gets all earned badges for a user.
  Future<List<Map<String, dynamic>>> getEarnedBadges(String userId) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('earnedBadges')
        .orderBy('earnedAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Creates a new challenge (admin only).
  Future<String> createChallenge({
    required String title,
    required String description,
    required String type, // 'distance' or 'streak'
    double? targetValue,
    int? targetDays,
    required DateTime startDate,
    required DateTime endDate,
    required String badge,
  }) async {
    final challengeRef = _firestore.collection('challenges').doc();

    final challenge = ChallengeModel(
      id: challengeRef.id,
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      targetDays: targetDays,
      startDate: startDate,
      endDate: endDate,
      badge: badge,
      isActive: true,
    );

    await challengeRef.set(challenge.toFirestore());
    return challengeRef.id;
  }

  /// Seeds monthly challenges.
  Future<void> seedMonthlyChallenges() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1)
        .subtract(Duration(days: 1));

    // Check if challenges for this month already exist
    final existing = await _firestore
        .collection('challenges')
        .where('startDate', isGreaterThanOrEqualTo: startOfMonth)
        .where('startDate', isLessThan: endOfMonth.add(Duration(days: 1)))
        .get();

    if (existing.docs.isNotEmpty) {
      return; // Already seeded
    }

    // Create monthly distance challenge
    await createChallenge(
      title: 'Monthly Distance Challenge',
      description: 'Ride 500 km this month',
      type: 'distance',
      targetValue: 500,
      startDate: startOfMonth,
      endDate: endOfMonth,
      badge: 'monthly_500km',
    );

    // Create weekly streak challenge
    final nextWeekEnd = now.add(Duration(days: 7 - now.weekday));
    await createChallenge(
      title: 'Weekly Streak Challenge',
      description: 'Ride for 7 consecutive days',
      type: 'streak',
      targetDays: 7,
      startDate: startOfMonth,
      endDate: nextWeekEnd,
      badge: 'weekly_streak',
    );
  }
}
