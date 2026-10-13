import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/error_reporter.dart';
import '../../domain/entities/forum_post_entity.dart';

/// SharedPreferences key for saved forum posts.
const String kForumBookmarksKey = 'forum_bookmarks';

/// Most bookmarks kept; saving past this drops the oldest.
const int kMaxForumBookmarks = 100;

/// A saved post — a local snapshot of what the "Saved" list shows, so
/// opening that list costs no Firestore reads. Tapping one opens the live
/// post.
class ForumBookmark extends Equatable {
  final String forumId;
  final String postId;
  final String title;
  final String forumName;
  final ForumPostType postType;
  final DateTime savedAt;

  const ForumBookmark({
    required this.forumId,
    required this.postId,
    required this.title,
    required this.forumName,
    required this.postType,
    required this.savedAt,
  });

  String get key => '$forumId/$postId';

  Map<String, dynamic> toJson() => {
        'forumId': forumId,
        'postId': postId,
        'title': title,
        'forumName': forumName,
        'postType': postType.name,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props => [forumId, postId, title, forumName, postType, savedAt];
}

String encodeForumBookmarks(List<ForumBookmark> bookmarks) =>
    jsonEncode([for (final b in bookmarks) b.toJson()]);

/// Inverse of [encodeForumBookmarks]. Malformed entries are skipped and a
/// malformed blob reads as empty — same degrade-don't-crash rule as the
/// garage forum cache (`decodeCachedGarageForums`).
List<ForumBookmark> decodeForumBookmarks(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic> && e['forumId'] is String && e['postId'] is String)
          ForumBookmark(
            forumId: e['forumId'] as String,
            postId: e['postId'] as String,
            title: e['title'] as String? ?? '',
            forumName: e['forumName'] as String? ?? '',
            postType: ForumPostType.fromString(e['postType'] as String?),
            savedAt: DateTime.fromMillisecondsSinceEpoch(
                (e['savedAt'] as num?)?.toInt() ?? 0),
          ),
    ];
  } on FormatException catch (e, st) {
    reportNonFatal(e, st, reason: 'decodeForumBookmarks');
    return const [];
  }
}

/// [bookmarks] with [bookmark] toggled: removed if already saved, else
/// added newest-first and trimmed to [kMaxForumBookmarks].
List<ForumBookmark> toggleForumBookmark(
  List<ForumBookmark> bookmarks,
  ForumBookmark bookmark,
) {
  if (bookmarks.any((b) => b.key == bookmark.key)) {
    return [for (final b in bookmarks) if (b.key != bookmark.key) b];
  }
  return [bookmark, ...bookmarks].take(kMaxForumBookmarks).toList();
}

final forumBookmarksProvider =
    StateNotifierProvider<ForumBookmarksNotifier, List<ForumBookmark>>(
        (ref) => ForumBookmarksNotifier()..load());

class ForumBookmarksNotifier extends StateNotifier<List<ForumBookmark>> {
  ForumBookmarksNotifier() : super(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = decodeForumBookmarks(prefs.getString(kForumBookmarksKey));
  }

  Future<void> toggle(ForumPostEntity post, {required String forumName}) async {
    state = toggleForumBookmark(
      state,
      ForumBookmark(
        forumId: post.forumId,
        postId: post.id,
        title: post.title,
        forumName: forumName,
        postType: post.postType,
        savedAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  /// Removes the bookmark with [ForumBookmark.key] == [key].
  Future<void> removeKey(String key) async {
    state = [for (final b in state) if (b.key != key) b];
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kForumBookmarksKey, encodeForumBookmarks(state));
  }
}
