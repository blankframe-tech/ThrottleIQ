import 'package:equatable/equatable.dart';

class ForumPostEntity extends Equatable {
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

  const ForumPostEntity({
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

  ForumPostEntity copyWith({
    int? replyCount,
    int? likes,
  }) {
    return ForumPostEntity(
      id: id,
      forumId: forumId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      title: title,
      body: body,
      createdAt: createdAt,
      replyCount: replyCount ?? this.replyCount,
      likes: likes ?? this.likes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        forumId,
        userId,
        userName,
        userPhotoUrl,
        title,
        body,
        createdAt,
        replyCount,
        likes,
      ];
}
