import 'entities/forum_entity.dart';

/// Who may delete other riders' posts/replies in a forum: the global admin,
/// anyone on the forum's maintainer list, or the rider who created it.
///
/// Note this is *deliberately* only about moderating **other people's**
/// content — a rider deleting their own post doesn't need any of these, and
/// the UI checks `post.userId == uid` separately.
bool canModerate({
  required ForumEntity forum,
  required String? uid,
  required bool isAdmin,
}) {
  if (isAdmin) return true;
  if (uid == null) return false;
  return uid == forum.createdBy || forum.maintainerIds.contains(uid);
}

/// Who may add/remove maintainers: the global admin or the forum's creator.
/// Deliberately narrower than [canModerate] — a maintainer can moderate
/// content but can't appoint more maintainers (or remove the ones who
/// appointed them).
bool canManageMaintainers({
  required ForumEntity forum,
  required String? uid,
  required bool isAdmin,
}) {
  if (isAdmin) return true;
  if (uid == null) return false;
  return uid == forum.createdBy;
}
