import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/realtime/realtime_location.dart';
import '../../../../core/realtime/realtime_location_publisher.dart';
import '../../../../core/realtime/realtime_providers.dart';

/// How often a rider's dot may move on everyone's group map over RTDB.
const Duration kGroupRideRealtimeInterval = Duration(seconds: 2);

/// Below this movement since the last RTDB write, a tick is skipped…
const double kGroupRideRealtimeMinMoveMeters = 5;

/// …unless this long has passed, so a parked rider still reads as present.
const Duration kGroupRideRealtimeHeartbeat = Duration(seconds: 30);

/// The RTDB half of a group ride: `/group_rides/{rideId}` carries the moving
/// dots; the ride itself, its roster and membership stay in Firestore
/// (`GroupRideRepository`). See
/// DOCS/For Devs and Contributors/architecture/realtime-database.md.
///
/// Every method is best-effort and never throws: RTDB is the fast path,
/// never the only one, so a refused or failed write here must not fail the
/// Firestore operation it rides along with.
class GroupRideLiveChannel {
  GroupRideLiveChannel(this._realtime);

  final RealtimeServices _realtime;

  bool get isEnabled => _realtime.isEnabled;

  static String _ridePath(String rideId) => 'group_rides/$rideId';
  static String locationPath(String rideId, String uid) =>
      'group_rides/$rideId/locations/$uid';

  /// Claims `meta.creatorId` for a ride the caller just created. The rules
  /// make this create-once, so it must happen before anyone else learns the
  /// ride id — `createGroupRide` calls it right after its batch commits.
  Future<void> claimRide(String rideId, String creatorId) => _bestEffort(
        'claim $rideId',
        () => _realtime.store
            .set('${_ridePath(rideId)}/meta', {'creatorId': creatorId}),
      );

  /// `meta.creatorId` as RTDB has it, or null if unclaimed/unreadable. The
  /// map only trusts this channel when it matches Firestore's `creatorId` —
  /// see [isGroupRideChannelTrusted].
  Future<String?> creatorOf(String rideId) async {
    if (!isEnabled) return null;
    try {
      final raw = await _realtime.store
          .watch('${_ridePath(rideId)}/meta')
          .first
          .timeout(kRealtimeAckTimeout);
      return raw is Map ? raw['creatorId'] as String? : null;
    } catch (e) {
      debugPrint('[GroupRideLive] meta read for $rideId failed: $e');
      return null;
    }
  }

  /// Every member's latest RTDB position, keyed by uid. Malformed entries are
  /// dropped, not fatal.
  Stream<Map<String, RealtimeLocation>> watchLocations(String rideId) {
    if (!isEnabled) return const Stream.empty();
    return _realtime.store.watch('${_ridePath(rideId)}/locations').map((raw) {
      final out = <String, RealtimeLocation>{};
      if (raw is Map) {
        for (final entry in raw.entries) {
          final loc = RealtimeLocation.tryParse(entry.value);
          if (loc != null) out[entry.key.toString()] = loc;
        }
      }
      return out;
    });
  }

  /// A throttled publisher for this rider's own dot.
  RealtimeLocationPublisher publisherFor(
    String rideId,
    String uid, {
    @visibleForTesting DateTime Function()? clock,
  }) =>
      RealtimeLocationPublisher(
        store: _realtime.store,
        path: locationPath(rideId, uid),
        minInterval: kGroupRideRealtimeInterval,
        minMoveMeters: kGroupRideRealtimeMinMoveMeters,
        heartbeat: kGroupRideRealtimeHeartbeat,
        clock: clock,
        onAck: _realtime.health.recordAck,
      );

  Future<void> removeLocation(String rideId, String uid) => _bestEffort(
        'remove location $uid on $rideId',
        () => _realtime.store.remove(locationPath(rideId, uid)),
      );

  /// A kick: the rider can no longer read or write positions on this ride,
  /// and their dot is removed.
  Future<void> ban(String rideId, String uid) async {
    await _bestEffort(
      'ban $uid on $rideId',
      () => _realtime.store.set('${_ridePath(rideId)}/banned/$uid', true),
    );
    await removeLocation(rideId, uid);
  }

  /// The ride ended or was deleted: drop the whole RTDB node. Creator only —
  /// anyone else's attempt is refused by the rules, harmlessly.
  Future<void> removeRide(String rideId) => _bestEffort(
        'remove $rideId',
        () => _realtime.store.remove(_ridePath(rideId)),
      );

  Future<void> _bestEffort(String label, Future<void> Function() op) async {
    if (!isEnabled) return;
    try {
      await op().timeout(kRealtimeAckTimeout);
    } on TimeoutException {
      debugPrint('[GroupRideLive] $label not acked yet — queued');
    } catch (e) {
      debugPrint('[GroupRideLive] $label failed: $e');
    }
  }
}

/// Whether to believe the RTDB channel for a ride: only when its `meta`
/// was claimed by the same rider Firestore says created it. A mismatch means
/// someone else claimed it first (the rules can't check Firestore), and the
/// map falls back to Firestore positions only.
bool isGroupRideChannelTrusted({
  required String? realtimeCreatorId,
  required String firestoreCreatorId,
}) =>
    realtimeCreatorId != null && realtimeCreatorId == firestoreCreatorId;
