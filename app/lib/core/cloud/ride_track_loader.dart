import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../database/daos/ride_point_dao.dart';
import 'cloud_repository.dart';

/// Pulls a ride's trail down from the cloud; see
/// [CloudRepository.downloadRideTrack]. Returns true if anything was written.
typedef RideTrackDownloader = Future<bool> Function(String uid, String rideId);

/// A ride's GPS trail, from wherever it is.
///
/// Local points win. When there are none — a ride restored onto a new phone
/// or a reinstall, whose metadata came down with the sync but whose trail
/// never does eagerly — the trail is fetched from the cloud and the local
/// table read again. [CloudRepository.downloadRideTrack] existed for this but
/// was never called, so every such ride showed a blank map, an empty share
/// card, an unsaveable route and an empty export (claude_sol §1.3.1). One
/// helper so those four screens can't drift apart again.
class RideTrackLoader {
  RideTrackLoader._();

  /// Points for [rideId], oldest first; empty if neither this device nor the
  /// cloud has any, or the download failed (logged, never thrown — every
  /// caller has a sensible empty state, none has a use for the error).
  ///
  /// [uid], [pointDao] and [download] default to the signed-in rider, the
  /// real DAO and [CloudRepository]; tests pass their own.
  static Future<List<Map<String, dynamic>>> load(
    String rideId, {
    String? uid,
    RidePointDao? pointDao,
    RideTrackDownloader? download,
  }) async {
    final dao = pointDao ?? RidePointDao();
    final local = await dao.getForRide(rideId);
    if (local.isNotEmpty) return local;

    try {
      final owner = uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (owner == null) return local;
      final fetch = download ?? CloudRepository().downloadRideTrack;
      if (!await fetch(owner, rideId)) return local;
      return dao.getForRide(rideId);
    } catch (e) {
      debugPrint('[RideTrackLoader] track download failed for $rideId: $e');
      return local;
    }
  }
}
