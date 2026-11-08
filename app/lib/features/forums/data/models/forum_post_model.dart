import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/num_cast.dart';
import '../../../../core/utils/photo_url_policy.dart';
import '../../domain/entities/forum_post_entity.dart';

/// Decodes a post doc's fields into an entity. Split from [ForumPostModel]
/// (which needs a DocumentSnapshot) so the defaults for docs written before
/// post types, solutions and attachments existed are unit-testable.
ForumPostEntity forumPostFromMap(String id, Map<String, dynamic> data,
    {bool hasPendingWrites = false}) {
  final solutionReplyId = data['solutionReplyId'];
  final authorBike = data['authorBike'];
  // The All Riders feed parses every post in every group, and any rider can
  // write one, so a wrong-typed field falls back instead of throwing.
  String str(String key) => asOrNull<String>(data[key]) ?? '';
  int count(String key) => asOrNull<num>(data[key])?.toInt() ?? 0;
  return ForumPostEntity(
    id: id,
    forumId: str('forumId'),
    userId: str('userId'),
    userName: str('userName'),
    userPhotoUrl: str('userPhotoUrl'),
    title: str('title'),
    body: str('body'),
    createdAt:
        asOrNull<Timestamp>(data['createdAt'])?.toDate() ?? DateTime.now(),
    replyCount: count('replyCount'),
    upvotes: count('upvotes'),
    downvotes: count('downvotes'),
    postType: ForumPostType.fromString(asOrNull<String>(data['postType'])),
    isSolved: data['isSolved'] == true,
    solutionReplyId: solutionReplyId is String && solutionReplyId.isNotEmpty
        ? solutionReplyId
        : null,
    authorBike: authorBike is String && authorBike.trim().isNotEmpty
        ? authorBike
        : null,
    attachment: ForumAttachment.fromMap(data['attachment']),
    imageUrls: forumImageUrlsFromRaw(data['imageUrls']),
    writtenAt: asOrNull<Timestamp>(data['writtenAt'])?.toDate(),
    hasPendingWrites: hasPendingWrites,
  );
}

/// A post's `imageUrls`, keeping only non-empty allow-listed URLs and at most
/// [kForumPostMaxImages] — a malformed field drops photos, never the post.
List<String> forumImageUrlsFromRaw(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final url in raw)
      if (url is String && url.isNotEmpty && isAllowedPhotoUrl(url)) url,
  ].take(kForumPostMaxImages).toList();
}

/// The fields a new post is created with — what `ForumRepository.createPost`
/// writes, minus `createdAt` (a server timestamp). Kept in step with the
/// post create rule's key allow-list in firestore.rules.
Map<String, dynamic> newForumPostFields({
  required String forumId,
  required String userId,
  required String userName,
  required String userPhotoUrl,
  required String title,
  required String body,
  ForumPostType postType = ForumPostType.general,
  String? authorBike,
  ForumAttachment? attachment,
  List<String> imageUrls = const [],
  List<String> alsoIn = const [],
}) {
  final bike = authorBike?.trim();
  return {
    'forumId': forumId,
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'title': title,
    'body': body,
    'replyCount': 0,
    'upvotes': 0,
    'downvotes': 0,
    'postType': postType.name,
    'isSolved': false,
    if (bike != null && bike.isNotEmpty)
      'authorBike': bike.length <= kAuthorBikeMaxLength
          ? bike
          : bike.substring(0, kAuthorBikeMaxLength),
    if (attachment != null) 'attachment': attachment.toMap(),
    if (imageUrls.isNotEmpty)
      'imageUrls': imageUrls.take(kForumPostMaxImages).toList(),
    if (alsoIn.isNotEmpty) 'alsoIn': alsoIn,
  };
}

class ForumPostModel {
  final ForumPostEntity _entity;

  const ForumPostModel._(this._entity);

  ForumPostEntity toEntity() => _entity;

  factory ForumPostModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return ForumPostModel._(forumPostFromMap(doc.id, doc.data()!,
        hasPendingWrites: doc.metadata.hasPendingWrites));
  }
}
