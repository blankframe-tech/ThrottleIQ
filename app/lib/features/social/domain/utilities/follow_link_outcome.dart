/// What came of acting on a follow link (scanned in-app or opened from the
/// system camera / a browser).
enum FollowLinkOutcome {
  /// Not a ThrottleIQ follow link, or it points at no rider.
  invalid,

  /// The rider scanned their own code.
  self,

  /// Already following that rider — nothing written.
  alreadyFollowing,

  /// The follow edge was written (or queued offline).
  followed,

  /// Nobody is signed in; the follow is stashed and completed after sign-in.
  pendingSignIn,

  /// The follow write was rejected.
  failed,
}

/// The decision that needs no network: whether a follow link can be acted on
/// at all, given who is signed in and whom they already follow. Returns null
/// when the follow should go ahead.
///
/// Pure, so the self-scan / already-following / signed-out branches are unit
/// tested without Firestore.
FollowLinkOutcome? precheckFollowLink({
  required String? targetUid,
  required String? myUid,
  required Set<String> following,
}) {
  if (targetUid == null) return FollowLinkOutcome.invalid;
  if (myUid == null) return FollowLinkOutcome.pendingSignIn;
  if (targetUid == myUid) return FollowLinkOutcome.self;
  if (following.contains(targetUid)) return FollowLinkOutcome.alreadyFollowing;
  return null;
}
