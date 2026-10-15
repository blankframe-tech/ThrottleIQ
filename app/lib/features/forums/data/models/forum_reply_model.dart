import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_reply_entity.dart';

class ForumReplyModel {
  final String id;
  final String postId;
  final String forumId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String body;
  final DateTime createdAt;

  const ForumReplyModel({
    required this.id,
    required this.postId,
    required this.forumId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl = '',
    required this.body,
    required this.createdAt,
  });

  ForumReplyEntity toEntity() {
    return ForumReplyEntity(
      id: id,
      postId: postId,
      forumId: forumId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      body: body,
      createdAt: createdAt,
    );
  }

  factory ForumReplyModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ForumReplyModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      forumId: data['forumId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      body: data['body'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'forumId': forumId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
