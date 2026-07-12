import 'package:equatable/equatable.dart';

class ReviewEntity extends Equatable {
  final String id;
  final String placeId;
  final String userId;
  final int stars;
  final String text;
  final List<String> imageUrls;
  final DateTime createdAt;
  final bool flagged;

  const ReviewEntity({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.stars,
    required this.text,
    this.imageUrls = const [],
    required this.createdAt,
    this.flagged = false,
  });

  @override
  List<Object?> get props => [
    id,
    placeId,
    userId,
    stars,
    text,
    imageUrls,
    createdAt,
    flagged,
  ];
}
