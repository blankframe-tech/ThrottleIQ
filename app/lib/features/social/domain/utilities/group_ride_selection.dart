/// Bounds and validation for "Ride with friends" group-ride invites.
///
/// Kept as plain top-level Dart (no Flutter, no Firestore) so the bound
/// lives in exactly one place and can be unit-tested without a widget tree.
/// Both the picker's confirm button and its "you've hit the cap" refusal read
/// from here; nothing hard-codes 1 or 10 anywhere else.
library;

/// Minimum riders (besides the inviter) needed before a group ride can start.
///
/// One, not two: riding with a single friend is the commonest case by far —
/// two mates heading out together — and refusing it forced riders to invent a
/// third invitee or skip the feature entirely. The inviter still counts, so
/// the smallest real group is two people.
const int kMinGroupRideFriends = 1;

/// Maximum riders (besides the inviter) that may be invited to one group ride.
/// The group ride document is therefore sized for 11 participants — the ten
/// invitees plus the rider who created it.
const int kMaxGroupRideFriends = 10;

/// Validates a friend-picker selection of [count] riders.
///
/// Returns `null` when the selection is startable, otherwise a message fit to
/// show the rider verbatim. Deliberately total: it answers for every integer
/// including negatives (treated the same as zero — nothing picked yet).
String? validateGroupSelection(int count) {
  if (count > kMaxGroupRideFriends) {
    return 'You can only ride with $kMaxGroupRideFriends friends at once.';
  }
  if (count < kMinGroupRideFriends) {
    final short = kMinGroupRideFriends - (count < 0 ? 0 : count);
    // Pluralized off the bound rather than hard-coded, so the message stays
    // grammatical if the minimum ever moves again ("at least 1 rider" vs
    // "at least 2 riders").
    const noun = kMinGroupRideFriends == 1 ? 'rider' : 'riders';
    return 'Pick at least $kMinGroupRideFriends $noun — '
        '$short more to go.';
  }
  return null;
}

/// Whether one more rider may be added to a selection that currently holds
/// [count]. Used to refuse the 11th tap *before* it mutates the set, so the
/// counter never briefly reads "11/10".
bool canAddAnotherFriend(int count) => count < kMaxGroupRideFriends;
