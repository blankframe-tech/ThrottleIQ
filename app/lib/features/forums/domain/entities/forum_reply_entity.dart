import 'package:equatable/equatable.dart';

class ForumReplyEntity extends Equatable {
  final String id;
  final String postId;
  final String forumId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String body;
  final DateTime createdAt;

  const ForumReplyEntity({
    required this.id,
    required this.postId,
    required this.forumId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl = '',
    required this.body,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        postId,
        forumId,
        userId,
        userName,
        userPhotoUrl,
        body,
        createdAt,
      ];
}
