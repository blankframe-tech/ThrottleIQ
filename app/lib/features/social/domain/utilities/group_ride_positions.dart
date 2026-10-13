import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/realtime/realtime_location.dart';

/// Where a member's marker came from.
enum MemberPositionSource { realtime, firestore, roster }

/// A member's best-known position and how old it is.
class MemberPosition {
  const MemberPosition({
    required this.position,
    required this.source,
    this.updatedAt,
  });

  final LatLng position;
  final MemberPositionSource source;
  final DateTime? updatedAt;
}

/// Picks the fresher of a member's RTDB dot and their Firestore position.
///
/// The Firestore side is resolved exactly as the map always has: the
/// `memberLocations/{uid}` document, falling back to the roster's
/// `currentLat`/`currentLng`, timed by the document's `timestamp` or else the
/// roster's `lastLocationUpdate` (a `serverTimestamp()` reads back null on
/// the writing device until the round-trip lands).
///
/// RTDB `ts` and Firestore `timestamp` are both server-stamped, so they're
/// compared directly. Either can be the newer: a rider on an older build
/// publishes only to Firestore, and while RTDB is healthy the Firestore copy
/// is only a 2-minute heartbeat. On a tie, or when neither has a time, RTDB
/// wins — it is the channel written more often.
MemberPosition? freshestMemberPosition({
  RealtimeLocation? realtime,
  Map<String, dynamic>? firestore,
  double? rosterLat,
  double? rosterLng,
  DateTime? rosterUpdatedAt,
}) {
  MemberPosition? stored;
  final fsLat = (firestore?['lat'] as num?)?.toDouble();
  final fsLng = (firestore?['lng'] as num?)?.toDouble();
  final lat = fsLat ?? rosterLat;
  final lng = fsLng ?? rosterLng;
  if (lat != null && lng != null) {
    final raw = firestore?['timestamp'];
    stored = MemberPosition(
      position: LatLng(lat, lng),
      source: fsLat != null && fsLng != null
          ? MemberPositionSource.firestore
          : MemberPositionSource.roster,
      updatedAt: raw is Timestamp
          ? raw.toDate()
          : raw is DateTime
              ? raw
              : rosterUpdatedAt,
    );
  }

  if (realtime == null) return stored;
  final live = MemberPosition(
    position: LatLng(realtime.lat, realtime.lng),
    source: MemberPositionSource.realtime,
    updatedAt: realtime.serverTime?.toLocal(),
  );
  if (stored == null) return live;

  final liveAt = live.updatedAt;
  final storedAt = stored.updatedAt;
  if (liveAt == null) return storedAt == null ? live : stored;
  if (storedAt == null) return live;
  return storedAt.isAfter(liveAt) ? stored : live;
}
