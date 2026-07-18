import 'package:equatable/equatable.dart';

enum ForumType {
  brand,
  bikeModel;

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
  final String displayName;
  final int followerCount;
  final int postCount;
  final DateTime createdAt;

  const ForumEntity({
    required this.id,
    required this.type,
    required this.brand,
    this.model,
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
        displayName,
        followerCount,
        postCount,
        createdAt,
      ];
}
