/// Combining the two places a group ride's roster can live.
///
/// Members used to be stored inline on `groupRides/{id}` as an array of maps.
/// Firestore rules can't project a field out of an array of maps, so the rule
/// that let an invited rider accept could only bound the array's *size* — an
/// accepting invitee was free to rewrite every other member's display name in
/// the same write. Members now live one document per rider at
/// `groupRides/{id}/members/{uid}`, where the rule is expressible: a rider may
/// write only the document whose id is their own uid.
///
/// Rides created before that change still carry the inline array and nothing
/// in the subcollection, so both are read and merged here.
///
/// Plain Dart — no Flutter, no Firestore — so the precedence rule is
/// unit-testable on its own.
library;

import '../entities/group_ride_entity.dart';

/// Merges a ride's [legacy] inline roster with the [fromSubcollection]
/// documents into one roster, keyed by uid.
///
/// [fromSubcollection] wins on collision: it is the only copy any current
/// write touches, so where the two disagree the inline array is stale by
/// definition. Riders present in only one source are kept — a legacy ride has
/// nothing in the subcollection until somebody accepts or is invited again,
/// and a current ride has nothing inline at all.
///
/// The result is ordered by uid, which is what keeps each member's marker
/// colour stable as people join and leave (see `colorForMember`).
List<GroupRideMember> mergeGroupRideMembers({
  required List<GroupRideMember> legacy,
  required List<GroupRideMember> fromSubcollection,
}) {
  final byUid = <String, GroupRideMember>{};
  for (final member in legacy) {
    if (member.userId.isEmpty) continue;
    byUid[member.userId] = member;
  }
  for (final member in fromSubcollection) {
    if (member.userId.isEmpty) continue;
    byUid[member.userId] = member;
  }

  final merged = byUid.values.toList()
    ..sort((a, b) => a.userId.compareTo(b.userId));
  return merged;
}
