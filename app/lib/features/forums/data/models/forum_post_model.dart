import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';

class ForumPostModel {
  final String id;
  final String forumId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String title;
  final String body;
  final DateTime createdAt;
  final int replyCount;
  final int likes;

  const ForumPostModel({
    required this.id,
    required this.forumId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl = '',
    required this.title,
    required this.body,
    required this.createdAt,
    this.replyCount = 0,
    this.likes = 0,
  });

  ForumPostEntity toEntity() {
    return ForumPostEntity(
      id: id,
      forumId: forumId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      title: title,
      body: body,
      createdAt: createdAt,
      replyCount: replyCount,
      likes: likes,
    );
  }

  factory ForumPostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ForumPostModel(
      id: doc.id,
      forumId: data['forumId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyCount: data['replyCount'] ?? 0,
      likes: data['likes'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'forumId': forumId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'replyCount': replyCount,
      'likes': likes,
    };
  }
}
