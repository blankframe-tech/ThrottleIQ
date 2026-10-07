import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/poi_directory/data/models/review_model.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/review_entity.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'reviews';

  /// Add a review (one per user per place).
  ///
  /// The doc id is deterministic — `{userId}_{placeId}` — rather than a
  /// random auto-id, mirroring `forum_follows/{uid}_{forumId}`. This is
  /// what the `reviews/{reviewId}` security rule keys off to reject a
  /// second review from the same user for the same place: since that
  /// collection grants no `update` rule, a write targeting an
  /// already-existing `{userId}_{placeId}` doc (which Firestore evaluates
  /// as an `update`, not a `create`, because the doc already exists) falls
  /// through to the deny-all catch-all.
  Future<String> addReview(ReviewEntity review) async {
    final docId = '${review.userId}_${review.placeId}';
    final model = ReviewModel.fromEntity(review).copyWith(id: docId);
    await _firestore.collection(_collection).doc(docId).set(
      model.toFirestore(),
    );
    return docId;
  }

  /// Get or create user's review for a place
  Future<String?> getUserReviewId(String placeId, String userId) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('placeId', isEqualTo: placeId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return querySnapshot.docs.first.id;
  }

  /// Update a review
  Future<void> updateReview(String reviewId, ReviewEntity review) async {
    final model = ReviewModel.fromEntity(review);
    await _firestore.collection(_collection).doc(reviewId).update(
      model.toFirestore(),
    );
  }

  /// Get a review by ID
  Future<ReviewEntity?> getReview(String reviewId) async {
    final doc = await _firestore.collection(_collection).doc(reviewId).get();
    if (!doc.exists) return null;
    return ReviewModel.fromFirestore(doc).toEntity();
  }

  /// Get all reviews for a place
  Future<List<ReviewEntity>> getReviewsForPlace(String placeId) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .get();
    return querySnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get reviews by a user
  Future<List<ReviewEntity>> getUserReviews(String userId) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return querySnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get rating statistics for a place
  Future<Map<String, dynamic>> getPlaceRatingStats(String placeId) async {
    final reviews = await getReviewsForPlace(placeId);

    if (reviews.isEmpty) {
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }

    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalStars = 0;

    for (final review in reviews) {
      totalStars += review.stars;
      distribution[review.stars] = (distribution[review.stars] ?? 0) + 1;
    }

    return {
      'averageRating': totalStars / reviews.length,
      'totalReviews': reviews.length,
      'distribution': distribution,
    };
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection(_collection).doc(reviewId).delete();
  }

  /// Flag a review
  Future<void> flagReview(String reviewId) async {
    await _firestore.collection(_collection).doc(reviewId).update({
      'flagged': true,
    });
  }

  /// Get flagged reviews (for admin)
  Future<List<ReviewEntity>> getFlaggedReviews() async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('flagged', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return querySnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Adds a review and bumps the place's aggregate rating in ONE
  /// transaction.
  ///
  /// Both writes have to land in the same commit: the `places/{placeId}`
  /// security rule only allows the ratingSum/ratingCount bump when the
  /// caller's `reviews/{uid}_{placeId}` doc did not exist before this write
  /// and does exist after it (`exists()` / `existsAfter()` / `getAfter()`),
  /// with the delta equal to that review's stars (issues §101.S1). That is
  /// what stops a rider replaying their one review's +stars on the place
  /// over and over, which the old review-first-then-bump flow allowed.
  ///
  /// A second submission by the same rider targets the same deterministic
  /// review id, so Firestore evaluates it as an update — reviews have no
  /// update rule, so the whole transaction is denied and neither the review
  /// nor the rating moves.
  ///
  /// The new totals are computed from a fresh in-transaction read of the
  /// place doc, so two riders reviewing the same place concurrently can't
  /// race on a stale aggregate; Firestore retries the transaction on
  /// contention.
  Future<String> addReviewAndUpdatePlaceRating({
    required ReviewEntity review,
  }) async {
    final reviewId = '${review.userId}_${review.placeId}';
    final reviewRef = _firestore.collection(_collection).doc(reviewId);
    // 'places' mirrors PlaceRepository's private `_collection` constant —
    // duplicated as a literal here (rather than depending on
    // PlaceRepository) so this stays self-contained.
    final placeRef = _firestore.collection('places').doc(review.placeId);

    await _firestore.runTransaction((transaction) async {
      final placeSnapshot = await transaction.get(placeRef);
      if (!placeSnapshot.exists) {
        throw StateError('Place ${review.placeId} does not exist');
      }
      final data = placeSnapshot.data() as Map<String, dynamic>;
      final currentRatingSum = (data['ratingSum'] as num?)?.toDouble() ?? 0.0;
      final currentRatingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

      transaction.set(reviewRef, ReviewModel.fromEntity(review).toFirestore());
      transaction.update(placeRef, {
        'ratingSum': currentRatingSum + review.stars,
        'ratingCount': currentRatingCount + 1,
      });
    });

    return reviewId;
  }

  /// Stream reviews for a place (real-time)
  Stream<List<ReviewEntity>> streamReviewsForPlace(String placeId) {
    return _firestore
        .collection(_collection)
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromFirestore(doc).toEntity())
            .toList());
  }
}
