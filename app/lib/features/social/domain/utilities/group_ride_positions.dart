import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Where a member's marker came from.
enum MemberPositionSource { firestore, roster }

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

/// A member's position: the `memberLocations/{uid}` document, falling back
/// to the roster's `currentLat`/`currentLng`, timed by the document's
/// `timestamp` or else the roster's `lastLocationUpdate` (a
/// `serverTimestamp()` reads back null on the writing device until the
/// round-trip lands). Null when the member has never published anything.
MemberPosition? freshestMemberPosition({
  Map<String, dynamic>? firestore,
  double? rosterLat,
  double? rosterLng,
  DateTime? rosterUpdatedAt,
}) {
  final fsLat = (firestore?['lat'] as num?)?.toDouble();
  final fsLng = (firestore?['lng'] as num?)?.toDouble();
  final lat = fsLat ?? rosterLat;
  final lng = fsLng ?? rosterLng;
  if (lat == null || lng == null) return null;
  final raw = firestore?['timestamp'];
  return MemberPosition(
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
