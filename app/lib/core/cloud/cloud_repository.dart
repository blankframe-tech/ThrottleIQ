import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/daos/bike_dao.dart';
import '../database/daos/ride_dao.dart';
import '../database/daos/ride_point_dao.dart';
import 'ride_track_codec.dart';

class CloudRepository {
  static final CloudRepository _instance = CloudRepository._internal();

  factory CloudRepository() => _instance;

  CloudRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final RideDao _rideDao = RideDao();
  late final RidePointDao _pointDao = RidePointDao();
  late final BikeDao _bikeDao = BikeDao();

  /// Deletes a bike's remote copy, and the rides hanging off it.
  ///
  /// Local deletion alone was never enough: the bike doc stayed in Firestore
  /// and [downloadBikes] pulled it straight back. The bike's rides go too, or
  /// [downloadRides] would resurrect orphaned rides pointing at a bike that
  /// no longer exists.
  ///
  /// Best-effort by design — the caller marks the tombstone synced only when
  /// this returns without throwing, so an offline delete is simply retried on
  /// the next sync while the local tombstone keeps the bike gone meanwhile.
  Future<void> deleteBikeRemote(String uid, String bikeId) async {
    final userDoc = _firestore.collection('users').doc(uid);

    final rides = await userDoc
        .collection('rides')
        .where('bike_id', isEqualTo: bikeId)
        .get();

    final batch = _firestore.batch();
    for (final ride in rides.docs) {
      batch.delete(ride.reference);
    }
    batch.delete(userDoc.collection('bikes').doc(bikeId));
    await batch.commit();
  }

  /// Upload unsynced rides to Firestore and mark them as synced.
  ///
  /// Fast path is still one atomic batch — it's a single round trip for the
  /// common case of a handful of rides. The retry loop is what matters: a
  /// batch is all-or-nothing, so before this existed a single ride Firestore
  /// refused took the whole batch down, `updateSyncedStatus` never ran for
  /// *any* of them, and the outer catch in SyncManager swallowed the reason.
  /// The same doomed set — plus every ride recorded afterwards — was then
  /// retried every five minutes forever, so one bad row could strand a
  /// device's entire backlog with nothing in the UI to say so. Falling back
  /// to per-ride writes bounds the damage to the offending ride and, just as
  /// importantly, names it in the log; §11's postmortem is the precedent for
  /// how invisible this class of failure is without that.
  Future<void> uploadRides(String uid, List<Map<String, dynamic>> rides) async {
    if (rides.isEmpty) return;

    final collection = _firestore.collection('users').doc(uid).collection('rides');
    Map<String, dynamic> payload(Map<String, dynamic> ride) => {
          ...ride,
          'syncedAt': FieldValue.serverTimestamp(),
        };

    try {
      final batch = _firestore.batch();
      for (final ride in rides) {
        batch.set(collection.doc(ride['id']), payload(ride));
      }
      await batch.commit();
      for (final ride in rides) {
        await _rideDao.updateSyncedStatus(ride['id'], true);
      }
      return;
    } catch (e) {
      debugPrint(
          '[CloudRepository] batched ride upload failed (${rides.length} rides), '
          'retrying individually: $e');
    }

    // One ride at a time, so a row Firestore won't take can't hold the rest
    // hostage. A ride that fails here stays synced = 0 and is retried next
    // cycle exactly as before — the difference is that its siblings get
    // through and the rider stops silently losing backups.
    for (final ride in rides) {
      try {
        await collection.doc(ride['id']).set(payload(ride));
        await _rideDao.updateSyncedStatus(ride['id'], true);
      } catch (e) {
        debugPrint('[CloudRepository] ride upload rejected for ${ride['id']}: $e');
      }
    }
  }

  /// Upload unsynced bikes to Firestore and mark them as synced
  Future<void> uploadBikes(String uid, List<Map<String, dynamic>> bikes) async {
    final batch = _firestore.batch();
    for (final bike in bikes) {
      final docRef = _firestore.collection('users').doc(uid).collection('bikes').doc(bike['id']);
      batch.set(docRef, {
        ...bike,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Mark all bikes as synced in local DB
    for (final bike in bikes) {
      await _updateBikeSyncedStatus(bike['id'], true);
    }
  }

  /// Upload unsynced maintenance logs to Firestore and mark them as synced
  Future<void> uploadMaintenance(String uid, List<Map<String, dynamic>> logs) async {
    final batch = _firestore.batch();
    for (final log in logs) {
      final docRef = _firestore.collection('users').doc(uid).collection('maintenance').doc(log['id']);
      batch.set(docRef, {
        ...log,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Mark all maintenance logs as synced in local DB
    for (final log in logs) {
      await _updateMaintenanceSyncedStatus(log['id'], true);
    }
  }

  /// Pulls bikes that exist in this rider's `users/{uid}/bikes` Firestore
  /// collection but not yet in the local DB, and inserts them locally.
  ///
  /// Until this existed, sync was upload-only: uploadBikes() pushed local
  /// writes to Firestore, but nothing ever pulled them back down. A rider
  /// signing into a second device (or reinstalling) got an empty local DB
  /// and this never noticed the cloud copy already had their bikes — the
  /// bug reported as "added bikes on the simulator, the real device install
  /// didn't have them." Runs on every sync cycle (see SyncManager), which
  /// makes it self-healing for reinstalls too, not just first login.
  ///
  /// Only inserts ids missing locally — never overwrites a local row, so an
  /// in-flight local edit that hasn't uploaded yet can't be clobbered by a
  /// stale cloud copy of the same id (ids are client-generated UUIDs, never
  /// reused across devices for different bikes).
  ///
  /// Returns true if any new bikes were pulled down (so the caller knows to
  /// invalidate garageProvider).
  Future<bool> downloadBikes(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final localIds = (await db.query('bikes', columns: ['id']))
        .map((r) => r['id'] as String)
        .toSet();
    // Bikes this device deleted must never come back. "Missing locally" is
    // exactly what a deleted bike looks like, so without consulting the
    // tombstones this loop faithfully re-created every bike the rider had
    // just removed — which is precisely how the delete appeared not to work.
    final deletedIds = await _bikeDao.deletedIds();
    final snap = await _firestore.collection('users').doc(uid).collection('bikes').get();

    final hasLocalActive = localIds.isNotEmpty &&
        (await db.query('bikes', where: 'is_active = 1', limit: 1)).isNotEmpty;
    var pulledAnyActive = false;
    var pulledAny = false;

    for (final doc in snap.docs) {
      if (localIds.contains(doc.id) || deletedIds.contains(doc.id)) continue;
      final data = Map<String, dynamic>.from(doc.data())..remove('syncedAt');
      // A local file path from a *different* device is meaningless here —
      // rather than let the UI try (and fail) to load a nonexistent file.
      data['image_path'] = null;
      // Never let a downloaded bike silently become "the" active bike
      // alongside (or instead of) one already active locally; if nothing is
      // active locally yet, let exactly the first pulled-down bike take it.
      final wasActive = data['is_active'] == 1;
      data['is_active'] =
          (wasActive && !hasLocalActive && !pulledAnyActive) ? 1 : 0;
      data['synced'] = 1;
      try {
        await db.insert('bikes', data, conflictAlgorithm: ConflictAlgorithm.replace);
        pulledAny = true;
      } catch (e) {
        // Same per-doc isolation as downloadRides, and it matters more here:
        // this runs first in the sync cycle, so an unguarded throw took the
        // ride and maintenance downloads down with it.
        debugPrint('[CloudRepository] bike download skipped for ${doc.id}: $e');
        continue;
      }
      if (data['is_active'] == 1) pulledAnyActive = true;
    }
    return pulledAny;
  }

  /// Same "pull anything missing locally" shape as [downloadBikes], for
  /// maintenance logs.
  Future<bool> downloadMaintenance(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final localIds = (await db.query('maintenance_logs', columns: ['id']))
        .map((r) => r['id'] as String)
        .toSet();
    final snap =
        await _firestore.collection('users').doc(uid).collection('maintenance').get();

    var pulledAny = false;
    for (final doc in snap.docs) {
      if (localIds.contains(doc.id)) continue;
      final data = Map<String, dynamic>.from(doc.data())..remove('syncedAt');
      data['synced'] = 1;
      try {
        await db.insert('maintenance_logs', data, conflictAlgorithm: ConflictAlgorithm.replace);
        pulledAny = true;
      } catch (e) {
        debugPrint('[CloudRepository] maintenance download skipped for ${doc.id}: $e');
      }
    }
    return pulledAny;
  }

  /// Same "pull anything missing locally" shape as [downloadBikes], for ride
  /// *metadata* rows (the `rides` table). Deliberately does not pull
  /// `ride_points` (the GPS trail) — those were never uploaded in the first
  /// place (uploadRides only ever pushed the `rides` row), so a ride
  /// recovered this way lists in history with its stats but an empty map.
  /// Fixing that is a real gap but a materially bigger one (GPS trails are
  /// much larger payloads) — flagged here rather than silently left
  /// unaddressed.
  Future<bool> downloadRides(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final localIds =
        (await db.query('rides', columns: ['id'])).map((r) => r['id'] as String).toSet();
    final snap = await _firestore.collection('users').doc(uid).collection('rides').get();

    var pulledAny = false;
    for (final doc in snap.docs) {
      if (localIds.contains(doc.id)) continue;
      final data = Map<String, dynamic>.from(doc.data())..remove('syncedAt');
      data['synced'] = 1;
      try {
        await db.insert('rides', data, conflictAlgorithm: ConflictAlgorithm.replace);
        pulledAny = true;
      } catch (e) {
        // Per-doc, deliberately. `rides.bike_id` is a FOREIGN KEY and
        // database_helper turns `PRAGMA foreign_keys` ON, so a ride whose
        // bike never made it down (deleted locally, so skipped by
        // downloadBikes' tombstone check) throws here. Unguarded, that one
        // row aborted the whole loop and every remaining doc was silently
        // skipped — and since Firestore returns docs in id order, the same
        // arbitrary subset landed every cycle and the count never moved.
        debugPrint('[CloudRepository] ride download skipped for ${doc.id}: $e');
      }
    }
    return pulledAny;
  }

  /// Uploads a ride's GPS trail as chunked `track` documents.
  ///
  /// Ride *metadata* has synced since 2026-07-23, but the point-by-point
  /// track never had — so a rider reinstalling the app got their ride list
  /// back with no lines on any map. This closes that.
  ///
  /// Idempotent: chunk documents are keyed by index and written with `set`,
  /// so re-running overwrites rather than duplicating. Deliberately called
  /// *after* the ride itself is synced, so a trail can never reference a ride
  /// doc that doesn't exist yet.
  Future<void> uploadRideTrack(String uid, String rideId) async {
    final rows = await _pointDao.getForRide(rideId);
    final chunks = chunkTrack(rows);
    if (chunks.isEmpty) return;

    final trackRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .doc(rideId)
        .collection('track');

    // One batch per Firestore commit limit. Chunks are large documents, so
    // this stays well under the 500-op cap in practice, but the loop makes
    // that explicit rather than incidental.
    final batch = _firestore.batch();
    for (var i = 0; i < chunks.length; i++) {
      batch.set(trackRef.doc('$i'), {
        'index': i,
        'points': chunks[i],
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Pulls a ride's trail back down, on demand.
  ///
  /// Called when a ride's summary/share screen needs a polyline and the local
  /// DB has none — never eagerly for every ride, since a full history could be
  /// hundreds of thousands of points. Returns true if anything was written.
  Future<bool> downloadRideTrack(String uid, String rideId) async {
    final existing = await _pointDao.getForRide(rideId);
    if (existing.isNotEmpty) return false; // Local data wins; never clobber it.

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .doc(rideId)
        .collection('track')
        .get();
    if (snap.docs.isEmpty) return false;

    // Sort numerically by index — doc ids are strings, so Firestore's own
    // ordering would place '10' before '2' and scramble the trail.
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ai = (a.data()['index'] as num?)?.toInt() ??
            int.tryParse(a.id) ??
            0;
        final bi = (b.data()['index'] as num?)?.toInt() ??
            int.tryParse(b.id) ??
            0;
        return ai.compareTo(bi);
      });

    final rows = flattenTrack([
      for (final doc in docs) (doc.data()['points'] as List<dynamic>? ?? const []),
    ]);
    if (rows.isEmpty) return false;

    await _pointDao.insertBatch([
      for (final row in rows) {...row, 'ride_id': rideId},
    ]);
    return true;
  }

  /// Store user profile data in Firestore
  Future<void> updateUserProfile(String uid, {required String displayName, String? photoUrl}) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Export ride data as JSON file to Downloads folder
  Future<File> exportToJSON(Map<String, dynamic> ride, List<Map<String, dynamic>> ridePoints) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) throw Exception('Downloads directory not available');

    final rideId = ride['id'] as String;
    final fileName = 'ride_${rideId}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${directory.path}/$fileName');

    final jsonData = {
      'ride': ride,
      'points': ridePoints,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(jsonData), flush: true);
    return file;
  }

  /// Export ride polyline as GPX file to Downloads folder
  Future<File> exportToGPX(Map<String, dynamic> ride, List<Map<String, dynamic>> ridePoints) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) throw Exception('Downloads directory not available');

    final rideId = ride['id'] as String;
    final fileName = 'ride_${rideId}_${DateTime.now().millisecondsSinceEpoch}.gpx';
    final file = File('${directory.path}/$fileName');

    final gpxContent = _generateGPX(ride, ridePoints);
    await file.writeAsString(gpxContent, flush: true);
    return file;
  }

  /// Generate GPX XML string from ride data
  String _generateGPX(Map<String, dynamic> ride, List<Map<String, dynamic>> ridePoints) {
    final startTime = ride['startTime'] as String;
    final endTime = ride['endTime'] as String?;
    final distanceKm = (ride['distanceM'] as num) / 1000;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="ThrottleIQ" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>Motorcycle Ride</name>');
    buffer.writeln('    <time>${startTime}</time>');
    buffer.writeln('    <bounds minlat="0" minlon="0" maxlat="0" maxlon="0" />');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>Ride Track</name>');
    buffer.writeln('    <desc>Distance: ${distanceKm.toStringAsFixed(2)} km</desc>');
    buffer.writeln('    <trkseg>');

    for (final point in ridePoints) {
      final lat = point['lat'] as num;
      final lng = point['lng'] as num;
      final timestamp = point['timestamp'] as String;
      final elevation = point['altitudeM'] as num?;

      buffer.write('      <trkpt lat="$lat" lon="$lng">');
      if (elevation != null) buffer.write('<ele>$elevation</ele>');
      buffer.writeln('<time>$timestamp</time></trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Update bike synced status in local database
  Future<void> _updateBikeSyncedStatus(String bikeId, bool synced) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'bikes',
      {'synced': synced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bikeId],
    );
  }

  /// Update maintenance log synced status in local database
  Future<void> _updateMaintenanceSyncedStatus(String maintenanceId, bool synced) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'maintenance_logs',
      {'synced': synced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [maintenanceId],
    );
  }
}
