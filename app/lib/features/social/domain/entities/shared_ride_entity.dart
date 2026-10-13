import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/riding_score.dart';
import '../../../../core/utils/ride_speed_invariant.dart';

/// How many rider-taken photos one shared ride may carry.
///
/// The feed card shows the photos beside the route map (each gets half the
/// card width), so this is a product cap rather than a storage one — past
/// three, a rider is posting an album, not a ride.
const int kMaxRidePhotos = 3;

/// Cleans a raw photo-url list into the shape [SharedRideEntity.photoUrls]
/// guarantees: no nulls, no blanks, no duplicates, at most [kMaxRidePhotos],
/// order preserved.
///
/// [legacyPhotoUrl] is the pre-multi-photo single `photoUrl` field. It is used
/// ONLY when [urls] yields nothing, so a ride shared before this change still
/// renders its one photo, while a ride written by the new code (which mirrors
/// its first photo back into `photoUrl` for older app builds) never counts the
/// same image twice.
///
/// Pure and Flutter-free so both the model's read path and the share composer
/// can enforce the cap identically — see
/// `test/features/social/shared_ride_entity_test.dart`.
List<String> normalizeRidePhotoUrls(
  Iterable<String?>? urls, {
  String? legacyPhotoUrl,
}) {
  final out = <String>[];
  for (final url in urls ?? const <String?>[]) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty || out.contains(trimmed)) continue;
    out.add(trimmed);
    if (out.length == kMaxRidePhotos) break;
  }
  if (out.isEmpty) {
    final legacy = legacyPhotoUrl?.trim() ?? '';
    if (legacy.isNotEmpty) out.add(legacy);
  }
  return out;
}

class SharedRideEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String bikeId;
  final String bikeName;
  final String bikeType;
  final DateTime rideDate;
  final double distanceKm;
  final int durationSeconds;
  final double _maxSpeedKmh;
  final List<LatLng> polyline;
  final String? mapSnapshotUrl;
  final int comments;
  final DateTime createdAt;

  /// Who can see this ride: `public` / `followers` / `mutual`. Followers/
  /// mutual visibility is materialized into [allowedUserIds] at share time
  /// (see RideShareRepository.shareRide) since Firestore rules can't run a
  /// per-doc follow-graph lookup for a list query.
  final String audience;
  final List<String> allowedUserIds;
  final String? routeId; // Optional reference to saved route

  /// Rider-taken photos of the ride/bike (distinct from [mapSnapshotUrl],
  /// which is a rendered map trace), newest-first as the rider ordered them.
  /// At most [kMaxRidePhotos]; empty when the ride has no photo.
  ///
  /// Rides shared before multi-photo support carry a single `photoUrl` string
  /// in Firestore instead; [RideShareModel.fromFirestore] folds that into this
  /// list, so nothing downstream has to know which era a ride came from.
  final List<String> photoUrls;

  /// Optional rider-written blurb shown above the media on the feed card.
  /// Absent on rides shared before captions existed, hence nullable.
  final String? caption;

  final int upvotes;
  final int downvotes;

  /// The signed-in rider's own vote on this ride: 1, -1, or null (none).
  /// Entity-only — hydrated from the `votes/{uid}` subcollection at read
  /// time, never stored on the ride doc itself.
  final int? myVote;

  /// Event counts behind [ridingScore]. Null (all three together, never
  /// individually) on a ride shared before this field existed — there's no
  /// honest zero to default to, since "never recorded" and "recorded zero
  /// hard brakes" mean different things and only the former should hide the
  /// score badge rather than show a false 100.
  final int? hardBrakeCount;
  final int? rapidAccelCount;
  final int? highJerkCount;

  /// 0-100 riding score for this ride, or null when the counts behind it
  /// weren't shared (see [hardBrakeCount]). Same formula as the private
  /// per-ride summary — [computeRidingScore] — so a shared ride's badge
  /// always matches what its rider saw right after finishing.
  int? get ridingScore {
    final brakes = hardBrakeCount;
    final accel = rapidAccelCount;
    final jerk = highJerkCount;
    if (brakes == null || accel == null || jerk == null) return null;
    return computeRidingScore(hardBrakes: brakes, rapidAccel: accel, highJerk: jerk);
  }

  const SharedRideEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.bikeId,
    required this.bikeName,
    required this.bikeType,
    required this.rideDate,
    required this.distanceKm,
    required this.durationSeconds,
    required double maxSpeedKmh,
    required this.polyline,
    this.mapSnapshotUrl,
    this.comments = 0,
    required this.createdAt,
    this.audience = 'public',
    this.allowedUserIds = const [],
    this.routeId,
    this.photoUrls = const [],
    this.caption,
    this.upvotes = 0,
    this.downvotes = 0,
    this.myVote,
    this.hardBrakeCount,
    this.rapidAccelCount,
    this.highJerkCount,
  }) : _maxSpeedKmh = maxSpeedKmh;

  /// The ride's lead photo — the first of [photoUrls], or null when it has
  /// none. Kept as the single-photo accessor so callers that only ever want
  /// one image (and the legacy `photoUrl` Firestore field written for older
  /// app builds) have one obvious source.
  String? get photoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  int get durationMinutes => durationSeconds ~/ 60;
  double get avgSpeedKmh =>
      durationSeconds > 0 ? (distanceKm / durationSeconds) * 3600 : 0;

  /// Top speed achieved during the ride. Guaranteed to never be less than
  /// [avgSpeedKmh] for moving rides to preserve physical reality even if
  /// hardware fixes didn't report Doppler speed or legacy data omitted it,
  /// and never above what's physically plausible for a motorcycle — see
  /// [RideSpeedInvariant] (issues §62.8: this used to have no
  /// ceiling at all).
  double get maxSpeedKmh => RideSpeedInvariant.reconcile(
        avgSpeedKmh: avgSpeedKmh,
        rawMaxSpeedKmh: _maxSpeedKmh,
      );

  int get netScore => upvotes - downvotes;

  /// Sentinel so [copyWith] can distinguish "leave myVote alone" from
  /// "set myVote to null" (clearing a vote) — a plain `int? myVote` param
  /// can't tell those apart since both look like `null`.
  static const _unset = Object();

  SharedRideEntity copyWith({
    double? distanceKm,
    int? durationSeconds,
    double? maxSpeedKmh,
    int? comments,
    String? audience,
    List<String>? allowedUserIds,
    List<String>? photoUrls,
    String? caption,
    int? upvotes,
    int? downvotes,
    List<LatLng>? polyline,
    Object? myVote = _unset,
  }) {
    return SharedRideEntity(
      id: id,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      bikeId: bikeId,
      bikeName: bikeName,
      bikeType: bikeType,
      rideDate: rideDate,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      polyline: polyline ?? this.polyline,
      mapSnapshotUrl: mapSnapshotUrl,
      comments: comments ?? this.comments,
      createdAt: createdAt,
      audience: audience ?? this.audience,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      routeId: routeId,
      photoUrls: photoUrls ?? this.photoUrls,
      caption: caption ?? this.caption,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      myVote: identical(myVote, _unset) ? this.myVote : myVote as int?,
      hardBrakeCount: hardBrakeCount,
      rapidAccelCount: rapidAccelCount,
      highJerkCount: highJerkCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        rideDate,
        createdAt,
        distanceKm,
        durationSeconds,
        polyline,
        audience,
        comments,
        upvotes,
        downvotes,
        myVote,
        caption,
        photoUrls,
        hardBrakeCount,
        rapidAccelCount,
        highJerkCount,
      ];
}
