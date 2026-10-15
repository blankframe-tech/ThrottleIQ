import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';

class ForumModel {
  final String id;
  final String type;
  final String brand;
  final String? model;
  final String? topic;
  final String displayName;
  final int followerCount;
  final int postCount;
  final DateTime createdAt;
  final String? createdBy;
  final List<String> maintainerIds;
  final String? description;

  const ForumModel({
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

  ForumEntity toEntity() {
    return ForumEntity(
      id: id,
      type: ForumType.fromString(type),
      brand: brand,
      model: model,
      topic: topic,
      displayName: displayName,
      followerCount: followerCount,
      postCount: postCount,
      createdAt: createdAt,
      createdBy: createdBy,
      maintainerIds: maintainerIds,
      description: description,
    );
  }

  /// Tolerant of docs written before rider-created forums existed: every
  /// forum doc already in Firestore lacks `createdBy`/`maintainerIds`/
  /// `description`, so those all fall back to null/empty rather than
  /// throwing.
  factory ForumModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ForumModel(
      id: doc.id,
      type: data['type'] ?? 'brand',
      brand: data['brand'] ?? '',
      model: data['model'],
      topic: data['topic'],
      displayName: data['displayName'] ?? '',
      followerCount: data['followerCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
      maintainerIds: (data['maintainerIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      description: data['description'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'brand': brand,
      'model': model,
      'topic': topic,
      'displayName': displayName,
      'followerCount': followerCount,
      'postCount': postCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'maintainerIds': maintainerIds,
      'description': description,
    };
  }
}
