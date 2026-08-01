import 'package:equatable/equatable.dart';

enum ForumType {
  brand,
  bikeModel,
  general,

  /// A forum a rider created themselves (not auto-derived from a garage bike
  /// or a built-in topic). These are the only forums that have a
  /// [ForumEntity.createdBy] and a maintainer list.
  custom;

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

  /// The uid of the rider who created this forum. Null for auto-created
  /// bike (brand/model) and built-in topic forums, which nobody owns.
  final String? createdBy;

  /// Uids allowed to moderate this forum alongside its creator (see
  /// `forum_permissions.dart`). Always empty for auto-created forums.
  final List<String> maintainerIds;

  /// Optional blurb shown on rider-created forums.
  final String? description;

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
    this.createdBy,
    this.maintainerIds = const [],
    this.description,
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
        createdBy,
        maintainerIds,
        description,
      ];
}
