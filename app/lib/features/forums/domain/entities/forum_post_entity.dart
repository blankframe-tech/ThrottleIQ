import 'package:equatable/equatable.dart';

/// What kind of discussion a post is. Stored as `postType` on the post doc;
/// a doc written before post types existed has no field and reads back as
/// [general].
///
/// Only [troubleshoot] posts carry a solved state — see
/// `forum_solution.dart` and the matching firestore.rules clause.
enum ForumPostType {
  troubleshoot,
  diyGuide,
  gearReview,
  general;

  static ForumPostType fromString(String? value) {
    return ForumPostType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ForumPostType.general,
    );
  }
}

/// Mirrors firestore.rules' cap on a post's `authorBike`.
const int kAuthorBikeMaxLength = 80;

/// Mirrors firestore.rules' cap on a post's `imageUrls` (forumImagesValid).
const int kForumPostMaxImages = 4;

/// What a [ForumAttachment] points at.
enum ForumAttachmentKind {
  ride,
  maintenance;

  static ForumAttachmentKind? fromString(String? value) {
    for (final kind in ForumAttachmentKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// A ride summary or maintenance visit shared into a post.
///
/// A snapshot, not a live reference: rides and maintenance logs live in the
/// author's local database, which no other rider can read, so the card has
/// to carry everything it shows. [refId] (and [bikeId] for a maintenance
/// visit) only lets the author jump back to their own record.
class ForumAttachment extends Equatable {
  final ForumAttachmentKind kind;
  final String refId;
  final String title;
  final String subtitle;
  final String? bikeId;

  const ForumAttachment({
    required this.kind,
    required this.refId,
    required this.title,
    required this.subtitle,
    this.bikeId,
  });

  /// Caps mirror firestore.rules' `forumAttachmentValid`.
  static const int maxTitleLength = 80;
  static const int maxSubtitleLength = 160;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'refId': refId,
        'title': _cap(title, maxTitleLength),
        'subtitle': _cap(subtitle, maxSubtitleLength),
        if (bikeId != null) 'bikeId': bikeId,
      };

  /// Null on anything malformed, so a bad attachment drops the card rather
  /// than the whole post.
  static ForumAttachment? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = ForumAttachmentKind.fromString(raw['kind'] as String?);
    final refId = raw['refId'];
    if (kind == null || refId is! String || refId.isEmpty) return null;
    return ForumAttachment(
      kind: kind,
      refId: refId,
      title: raw['title'] is String ? raw['title'] as String : '',
      subtitle: raw['subtitle'] is String ? raw['subtitle'] as String : '',
      bikeId: raw['bikeId'] is String ? raw['bikeId'] as String : null,
    );
  }

  static String _cap(String s, int max) => s.length <= max ? s : s.substring(0, max);

  @override
  List<Object?> get props => [kind, refId, title, subtitle, bikeId];
}

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

  final ForumPostType postType;

  /// Only meaningful for [ForumPostType.troubleshoot] posts.
  final bool isSolved;

  /// The reply the author accepted as the fix, if any. A post can be solved
  /// with no accepted reply (the author fixed it themselves).
  final String? solutionReplyId;

  /// The author's bike at posting time, e.g. "Yamaha MT-15 (2023) · 12,400
  /// km" — a byline badge, so advice carries the bike it came from.
  final String? authorBike;

  final ForumAttachment? attachment;

  /// Photos attached to the post (Cloudinary URLs, at most
  /// [kForumPostMaxImages]). Empty on posts written before photos existed.
  final List<String> imageUrls;

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
    this.postType = ForumPostType.general,
    this.isSolved = false,
    this.solutionReplyId,
    this.authorBike,
    this.attachment,
    this.imageUrls = const [],
    this.myVote,
  });

  int get netScore => upvotes - downvotes;

  bool get isTroubleshoot => postType == ForumPostType.troubleshoot;

  /// Sentinel so [copyWith] can distinguish "leave a nullable field alone"
  /// from "set it to null" (clearing a vote, un-accepting a solution) — see
  /// SharedRideEntity.copyWith for the same problem/fix.
  static const _unset = Object();

  ForumPostEntity copyWith({
    int? replyCount,
    int? upvotes,
    int? downvotes,
    bool? isSolved,
    Object? solutionReplyId = _unset,
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
      postType: postType,
      isSolved: isSolved ?? this.isSolved,
      solutionReplyId: identical(solutionReplyId, _unset)
          ? this.solutionReplyId
          : solutionReplyId as String?,
      authorBike: authorBike,
      attachment: attachment,
      imageUrls: imageUrls,
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
        postType,
        isSolved,
        solutionReplyId,
        authorBike,
        attachment,
        imageUrls,
        myVote,
      ];
}
