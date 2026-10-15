import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/review_entity.dart';

class ReviewModel {
  final String id;
  final String placeId;
  final String userId;
  final int stars;
  final String text;
  final List<String> imageUrls;
  final DateTime createdAt;
  final bool flagged;

  const ReviewModel({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.stars,
    required this.text,
    this.imageUrls = const [],
    required this.createdAt,
    this.flagged = false,
  });

  ReviewEntity toEntity() {
    return ReviewEntity(
      id: id,
      placeId: placeId,
      userId: userId,
      stars: stars,
      text: text,
      imageUrls: imageUrls,
      createdAt: createdAt,
      flagged: flagged,
    );
  }

  factory ReviewModel.fromEntity(ReviewEntity entity) {
    return ReviewModel(
      id: entity.id,
      placeId: entity.placeId,
      userId: entity.userId,
      stars: entity.stars,
      text: entity.text,
      imageUrls: entity.imageUrls,
      createdAt: entity.createdAt,
      flagged: entity.flagged,
    );
  }

  factory ReviewModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ReviewModel(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      userId: data['userId'] ?? '',
      stars: data['stars'] ?? 5,
      text: data['text'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      flagged: data['flagged'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'userId': userId,
      'stars': stars,
      'text': text,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'flagged': flagged,
    };
  }

  ReviewModel copyWith({
    String? id,
    String? placeId,
    String? userId,
    int? stars,
    String? text,
    List<String>? imageUrls,
    DateTime? createdAt,
    bool? flagged,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      userId: userId ?? this.userId,
      stars: stars ?? this.stars,
      text: text ?? this.text,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      flagged: flagged ?? this.flagged,
    );
  }
}
