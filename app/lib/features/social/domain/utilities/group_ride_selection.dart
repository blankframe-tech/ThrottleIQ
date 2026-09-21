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

/// What is wrong with a friend-picker selection.
enum GroupSelectionProblem { tooFew, tooMany }

/// Validates a friend-picker selection of [count] riders.
///
/// Returns `null` when the selection is startable, otherwise the problem and —
/// for [GroupSelectionProblem.tooFew] — how many more riders are needed. The
/// wording lives in the picker, not here: this file has no `BuildContext` and
/// so cannot produce Bangla, and it used to hand the UI an English sentence to
/// show verbatim. Same split as `recordingErrorText`.
///
/// Deliberately total: it answers for every integer including negatives
/// (treated the same as zero — nothing picked yet).
({GroupSelectionProblem problem, int shortBy})? validateGroupSelection(int count) {
  if (count > kMaxGroupRideFriends) {
    return (problem: GroupSelectionProblem.tooMany, shortBy: 0);
  }
  if (count < kMinGroupRideFriends) {
    return (
      problem: GroupSelectionProblem.tooFew,
      shortBy: kMinGroupRideFriends - (count < 0 ? 0 : count),
    );
  }
  return null;
}

/// Whether one more rider may be added to a selection that currently holds
/// [count]. Used to refuse the 11th tap *before* it mutates the set, so the
/// counter never briefly reads "11/10".
bool canAddAnotherFriend(int count) => count < kMaxGroupRideFriends;
