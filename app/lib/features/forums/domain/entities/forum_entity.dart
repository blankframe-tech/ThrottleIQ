import 'package:equatable/equatable.dart';

enum ForumType {
  brand,
  bikeModel,
  general;

  static ForumType fromString(String value) {
    return ForumType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ForumType.brand,
    );
  }
}

class ForumEntity extends Equatable {
  final String id;
  final ForumType type;
  final String brand;
  final String? model;

  /// Set only for [ForumType.general] forums (e.g. "Maintenance",
  /// "Two-Strokes") — non-bike discussion boards that have no brand/model.
  final String? topic;

  final String displayName;
  final int followerCount;
  final int postCount;
  final DateTime createdAt;

  const ForumEntity({
    required this.id,
    required this.type,
    required this.brand,
    this.model,
    this.topic,
    required this.displayName,
    this.followerCount = 0,
    this.postCount = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        type,
        brand,
        model,
        topic,
        displayName,
        followerCount,
        postCount,
        createdAt,
      ];
}
