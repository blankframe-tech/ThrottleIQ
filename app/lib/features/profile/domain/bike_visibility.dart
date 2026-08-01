/// Who may see a rider's garage (their bikes), and the one pure predicate that
/// answers it.
///
/// Deliberately mirrors the profile-visibility vocabulary already in the
/// codebase (see [UserProfileEntity.visibility]) so the two read the same way
/// on the settings UI — the one difference is the middle tier: a profile's is
/// 'mutual' (both follow edges), a garage's is 'followers' (only the viewer →
/// owner edge), because "hide my bikes from my followers or the public or only
/// me" is about who follows *me*, not who I follow back.
library;

/// Any signed-in rider may see the garage. The default, and what a document
/// written before `bikesVisibility` existed decodes to — so adding this field
/// never changes an existing account's behavior.
const String kBikesVisibilityPublic = 'public';

/// Only riders who follow the owner.
const String kBikesVisibilityFollowers = 'followers';

/// Owner only.
const String kBikesVisibilityPrivate = 'private';

/// The three valid values, in UI order (most open → most closed).
const List<String> kBikesVisibilityLevels = [
  kBikesVisibilityPublic,
  kBikesVisibilityFollowers,
  kBikesVisibilityPrivate,
];

/// Human label for a `bikesVisibility` value, for read-only display. Unknown
/// values render as the default tier, matching [canSeeBikes]'s behavior.
String bikesVisibilityLabel(String visibility) {
  switch (visibility) {
    case kBikesVisibilityFollowers:
      return 'My followers';
    case kBikesVisibilityPrivate:
      return 'Only me';
    default:
      return 'Everyone';
  }
}

/// Whether [viewerUid] is allowed to see [ownerUid]'s bikes.
///
/// Pure and total — no Firestore, no providers — so the rule can be unit
/// tested exhaustively and reused anywhere a bikes list is about to be shown.
///
/// * The owner always sees their own garage, whatever the setting says.
/// * `public` (and any unrecognized/absent value, which decodes to `public`)
///   → any signed-in rider.
/// * `followers` → only if [viewerFollowsOwner], i.e. the viewer → owner
///   follow edge exists. Following back is not required.
/// * `private` → nobody but the owner.
///
/// [viewerUid] is empty for a signed-out viewer; an empty uid never counts as
/// owning anything, so a signed-out viewer falls through to the tier check.
bool canSeeBikes({
  required String viewerUid,
  required String ownerUid,
  required String visibility,
  required bool viewerFollowsOwner,
}) {
  if (viewerUid.isNotEmpty && viewerUid == ownerUid) return true;
  switch (visibility) {
    case kBikesVisibilityPrivate:
      return false;
    case kBikesVisibilityFollowers:
      return viewerFollowsOwner;
    default:
      // 'public' plus anything unrecognized (including the empty string a
      // legacy document with no `bikesVisibility` field decodes to).
      return true;
  }
}
