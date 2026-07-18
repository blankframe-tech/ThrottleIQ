import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';

class ForumModel {
  final String id;
  final String type;
  final String brand;
  final String? model;
  final String displayName;
  final int followerCount;
  final int postCount;
  final DateTime createdAt;

  const ForumModel({
    required this.id,
    required this.type,
    required this.brand,
    this.model,
    required this.displayName,
    this.followerCount = 0,
    this.postCount = 0,
    required this.createdAt,
  });

  ForumEntity toEntity() {
    return ForumEntity(
      id: id,
      type: ForumType.fromString(type),
      brand: brand,
      model: model,
      displayName: displayName,
      followerCount: followerCount,
      postCount: postCount,
      createdAt: createdAt,
    );
  }

  factory ForumModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ForumModel(
      id: doc.id,
      type: data['type'] ?? 'brand',
      brand: data['brand'] ?? '',
      model: data['model'],
      displayName: data['displayName'] ?? '',
      followerCount: data['followerCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'brand': brand,
      'model': model,
      'displayName': displayName,
      'followerCount': followerCount,
      'postCount': postCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
