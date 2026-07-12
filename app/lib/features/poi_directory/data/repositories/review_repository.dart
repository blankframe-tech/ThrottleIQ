import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/poi_directory/data/models/review_model.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/review_entity.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'reviews';

  /// Add or update a review (one per user per place)
  Future<String> addReview(ReviewEntity review) async {
    final model = ReviewModel.fromEntity(review);
    final docRef = await _firestore.collection(_collection).add(
      model.toFirestore(),
    );
    return docRef.id;
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
