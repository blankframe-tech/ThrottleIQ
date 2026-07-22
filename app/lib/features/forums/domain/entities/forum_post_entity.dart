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
  final int upvotes;
  final int downvotes;

  /// The signed-in rider's own vote on this post: 1, -1, or null (none).
  /// Entity-only — hydrated from the `votes/{uid}` subcollection at read
  /// time, never stored on the post doc itself (mirrors
  /// SharedRideEntity.myVote).
  final int? myVote;

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
    this.upvotes = 0,
    this.downvotes = 0,
    this.myVote,
  });

  int get netScore => upvotes - downvotes;

  /// Sentinel so [copyWith] can distinguish "leave myVote alone" from "set
  /// myVote to null" (clearing a vote) — see SharedRideEntity.copyWith for
  /// the same problem/fix.
  static const _unset = Object();

  ForumPostEntity copyWith({
    int? replyCount,
    int? upvotes,
    int? downvotes,
    Object? myVote = _unset,
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
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      myVote: identical(myVote, _unset) ? this.myVote : myVote as int?,
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
        upvotes,
        downvotes,
        myVote,
      ];
}
