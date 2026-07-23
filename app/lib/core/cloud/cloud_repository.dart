import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/daos/ride_dao.dart';
import '../database/daos/ride_point_dao.dart';

class CloudRepository {
  static final CloudRepository _instance = CloudRepository._internal();

  factory CloudRepository() => _instance;

  CloudRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final RideDao _rideDao = RideDao();

  /// Upload unsynced rides to Firestore and mark them as synced
  Future<void> uploadRides(String uid, List<Map<String, dynamic>> rides) async {
    final batch = _firestore.batch();
    for (final ride in rides) {
      final docRef = _firestore.collection('users').doc(uid).collection('rides').doc(ride['id']);
      batch.set(docRef, {
        ...ride,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Mark all rides as synced in local DB
    for (final ride in rides) {
      await _rideDao.updateSyncedStatus(ride['id'], true);
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
    final snap = await _firestore.collection('users').doc(uid).collection('bikes').get();

    final hasLocalActive = localIds.isNotEmpty &&
        (await db.query('bikes', where: 'is_active = 1', limit: 1)).isNotEmpty;
    var pulledAnyActive = false;
    var pulledAny = false;

    for (final doc in snap.docs) {
      if (localIds.contains(doc.id)) continue;
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
      if (data['is_active'] == 1) pulledAnyActive = true;
      data['synced'] = 1;
      await db.insert('bikes', data, conflictAlgorithm: ConflictAlgorithm.replace);
      pulledAny = true;
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
      await db.insert('maintenance_logs', data, conflictAlgorithm: ConflictAlgorithm.replace);
      pulledAny = true;
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
      await db.insert('rides', data, conflictAlgorithm: ConflictAlgorithm.replace);
      pulledAny = true;
    }
    return pulledAny;
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
