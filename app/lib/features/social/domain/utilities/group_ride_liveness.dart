import '../entities/group_ride_entity.dart';

/// How long an `active` group ride may go without any sign of life before the
/// app stops treating it as live.
///
/// "Sign of life" is [GroupRideEntity.lastActiveAt], a heartbeat the ride's
/// creator writes while recording or while the group map is open (see
/// `GroupRideRepository.heartbeat`). Rides written before that field existed
/// fall back to their start time.
///
/// Four hours is well past any gap a healthy ride can produce — the heartbeat
/// ticks every few minutes — yet short enough that a ride whose creator's
/// phone died, or whose app was swiped away mid-ride, drops out of "Riding
/// Now" the same afternoon instead of haunting it forever. That haunting was
/// the bug: `status` only ever flipped to `completed` from the group map's
/// Leave button, so every ride ended any other way (the normal way — tapping
/// End on the ride cockpit) stayed `active` indefinitely.
const Duration kGroupRideInactiveCutoff = Duration(hours: 4);

/// When the ride last showed any activity.
DateTime groupRideLastActivity(GroupRideEntity ride) {
  final candidates = <DateTime>[
    ride.startTime,
    ride.createdAt,
    if (ride.lastActiveAt != null) ride.lastActiveAt!,
  ];
  return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Whether [ride] should be shown as happening right now.
bool isGroupRideLive(
  GroupRideEntity ride, {
  required DateTime now,
  Duration cutoff = kGroupRideInactiveCutoff,
}) {
  if (ride.status != GroupRideStatus.active) return false;
  return now.difference(groupRideLastActivity(ride)) < cutoff;
}

/// An `active` ride that has gone quiet past [cutoff] — one the creator's
/// device should close out (status → completed) so it stops matching the
/// Riding Now query at all.
bool isGroupRideAbandoned(
  GroupRideEntity ride, {
  required DateTime now,
  Duration cutoff = kGroupRideInactiveCutoff,
}) =>
    ride.status == GroupRideStatus.active &&
    !isGroupRideLive(ride, now: now, cutoff: cutoff);
