import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/daos/bike_dao.dart';
import '../database/daos/ride_dao.dart';
import '../database/daos/ride_point_dao.dart';
import '../services/cloudinary_upload_service.dart';
import '../utils/bike_image_resolver.dart';
import 'maintenance_settings_sync.dart';
import '../database/daos/maintenance_dao.dart';
import '../database/daos/fuel_log_dao.dart';
import '../../features/maintenance/data/models/fuel_log_model.dart';
import 'last_writer_wins.dart';
import 'pull_watermark.dart';
import 'ride_track_codec.dart';

class CloudRepository {
  static final CloudRepository _instance = CloudRepository._internal();

  factory CloudRepository() => _instance;

  CloudRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final RideDao _rideDao = RideDao();
  late final RidePointDao _pointDao = RidePointDao();
  late final BikeDao _bikeDao = BikeDao();
  CloudinaryUploadService? _uploadService;

  CloudinaryUploadService get _cloudinaryUploadService =>
      _uploadService ??= CloudinaryUploadService();

  @visibleForTesting
  void setCloudinaryUploadServiceForTesting(CloudinaryUploadService? service) {
    _uploadService = service;
  }

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
  ///
  /// Only reached by an explicit "delete bike and all its rides" — the
  /// default is now archiving, which deletes nothing. Each ride's `track`
  /// chunks go too (Firestore never deletes a subcollection with its parent,
  /// so they used to be orphaned), and the deletes are committed in chunks
  /// because a single batch fails outright past 500 writes — which a bike
  /// with a long history reached easily once track chunks are counted.
  Future<void> deleteBikeRemote(String uid, String bikeId) async {
    final userDoc = _firestore.collection('users').doc(uid);

    final rides = await userDoc
        .collection('rides')
        .where('bike_id', isEqualTo: bikeId)
        .get();

    // Children before parents, and the bike last: if a later chunk fails,
    // the retry re-queries by bike_id and still finds the rides it missed.
    final refs = <DocumentReference>[];
    for (final ride in rides.docs) {
      final track = await ride.reference.collection('track').get();
      refs.addAll(track.docs.map((d) => d.reference));
    }
    refs.addAll(rides.docs.map((d) => d.reference));
    // Its maintenance settings backup (issues §88.2) — otherwise orphaned.
    refs.add(MaintenanceSettingsSync.docRef(_firestore, uid, bikeId));
    refs.add(userDoc.collection('bikes').doc(bikeId));
    await _deleteInChunks(refs);
  }

  /// Firestore caps a batch at 500 writes; 400 leaves headroom.
  static const deleteChunkSize = 400;

  /// Splits [refs] into batches of at most [deleteChunkSize], in order.
  /// Pulled out so the chunking itself is testable without Firestore.
  @visibleForTesting
  static List<List<T>> chunkForDelete<T>(List<T> refs) => [
        for (var i = 0; i < refs.length; i += deleteChunkSize)
          refs.sublist(i, (i + deleteChunkSize).clamp(0, refs.length)),
      ];

  Future<void> _deleteInChunks(List<DocumentReference> refs) async {
    for (final chunk in chunkForDelete(refs)) {
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Upload unsynced rides to Firestore and mark them as synced.
  ///
  /// Last-writer-wins (C4): each ride is written unless the cloud copy is a
  /// newer edit, which then replaces the local row instead. See
  /// [_uploadLastWriterWins].
  Future<void> uploadRides(String uid, List<Map<String, dynamic>> rides) async {
    if (rides.isEmpty) return;
    final columns = await _columns('rides');
    await _uploadLastWriterWins(uid, 'rides', 'rides', rides, ridePayload,
        (remote) => rideOverwriteRow(remote, columns));
  }

  /// Uploads [rows] of [table] to `users/{uid}/[collection]` one at a time,
  /// each in a transaction that first reads the cloud copy (C4):
  /// - cloud copy older, missing, or from a pre-v28 build (no
  ///   `updated_at`): written, and the row marked synced unless it was
  ///   edited again meanwhile (its `updated_at` moved);
  /// - cloud copy newer (edited on another device): not overwritten; it
  ///   replaces the local row via [toLocal] instead, unless the row was
  ///   edited again meanwhile.
  ///
  /// Per row on purpose, as the per-item fallback of the old batch was: a
  /// single row Firestore refused used to take the whole batch down and
  /// strand a device's backlog (§11). A row that fails stays synced = 0 and
  /// is retried next cycle; its siblings get through, and the log names it.
  Future<void> _uploadLastWriterWins(
    String uid,
    String collection,
    String table,
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> Function(Map<String, dynamic>) payload,
    Map<String, dynamic>? Function(Map<String, dynamic> remote) toLocal,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final col = _firestore.collection('users').doc(uid).collection(collection);
    for (final row in rows) {
      final id = row['id'] as String;
      try {
        final remote =
            await LastWriterWins.setUnlessRemoteNewer(_firestore, col.doc(id), {
          ...payload(row),
          'syncedAt': FieldValue.serverTimestamp(),
        });
        if (remote == null) {
          await db.update(table, {'synced': 1},
              where: 'id = ? AND updated_at IS ?',
              whereArgs: [id, row['updated_at']]);
          continue;
        }
        final local = toLocal({...remote, 'id': id});
        if (local != null) {
          await LastWriterWins.adopt(db, table, local,
              localUpdatedAt: row['updated_at']);
        }
        debugPrint('[CloudRepository] $collection/$id: a newer copy from '
            'another device replaced this one');
      } catch (e) {
        debugPrint('[CloudRepository] $collection upload rejected for $id: $e');
      }
    }
  }

  Future<Set<String>> _columns(String table) async {
    final db = await DatabaseHelper.instance.database;
    return (await db.rawQuery('PRAGMA table_info($table)'))
        .map((row) => row['name'] as String)
        .toSet();
  }

  /// `id -> {updated_at, synced}` of every local row of [table], for the
  /// download passes' last-writer-wins check.
  static Future<Map<String, Map<String, Object?>>> _localStamps(
          Database db, String table) async =>
      {
        for (final r
            in await db.query(table, columns: ['id', 'updated_at', 'synced']))
          r['id'] as String: r,
      };

  /// Whether a downloaded [remote] doc should replace the existing local
  /// row [local] (C4): only when it is a newer edit and the local row has
  /// no unsynced changes. A row with unsynced changes is left to the upload,
  /// whose transaction decides which copy is newer.
  @visibleForTesting
  static bool downloadReplacesLocal(
          Map<String, dynamic> remote, Map<String, Object?> local) =>
      local['synced'] == 1 &&
      LastWriterWins.remoteIsNewer(remote, Map<String, dynamic>.from(local));

  /// A ride document as a local row: only the columns this build has,
  /// marked synced, times as UTC. A document from a pre-v28 build has
  /// device-local times with no offset; they are read in this phone's zone,
  /// which is the best guess there is (B13).
  @visibleForTesting
  static Map<String, dynamic> rideRowFromCloud(
      Map<String, dynamic> doc, Set<String> columns) {
    final row = knownRideColumnsOnly(doc, columns)..['synced'] = 1;
    for (final k in const ['start_time', 'end_time', 'created_at']) {
      if (row.containsKey(k)) row[k] = DatabaseHelper.toUtcIso(row[k]);
    }
    return row;
  }

  /// [rideRowFromCloud] for replacing an existing row: keeps this device's
  /// own trail bookkeeping and map snapshot file.
  @visibleForTesting
  static Map<String, dynamic> rideOverwriteRow(
          Map<String, dynamic> doc, Set<String> columns) =>
      rideRowFromCloud(doc, columns)
        ..remove('track_synced')
        ..remove('map_snapshot_path');

  /// A local ride row as it should be written to Firestore.
  ///
  /// `track_synced` is this device's own bookkeeping (has *my* copy of the
  /// trail gone up?) and means nothing to another device. It's also a column
  /// older app versions don't have, and [downloadRides] inserts cloud fields
  /// verbatim, so shipping it would make every new ride fail to download on
  /// a device that hasn't updated yet.
  /// `route_id`/`route_name` are only sent when the ride actually followed a
  /// saved route (schema v17, issues §78.21). An ordinary ride's document
  /// therefore looks exactly as it did before those columns existed, so a
  /// device still on an older build keeps downloading it — the same rule
  /// [bikePayload] applies to `archived`, and for the same reason.
  @visibleForTesting
  static Map<String, dynamic> ridePayload(Map<String, dynamic> ride) {
    final out = Map<String, dynamic>.from(ride)..remove('track_synced');
    if (out['route_id'] == null) {
      out.remove('route_id');
      out.remove('route_name');
    }
    // Same rule for the v25 overspeed count: a legacy ride (NULL) keeps the
    // document shape it always had; a counted ride uploads it like the other
    // event counts.
    if (out['overspeed_count'] == null) out.remove('overspeed_count');
    // And for the v26 cornering/g/elevation figures, each on its own: a
    // ride can have elevation (backfilled) but no lean (never measured).
    for (final key in rideV26PayloadKeys) {
      if (out[key] == null) out.remove(key);
    }
    return out;
  }

  /// The schema v26 ride columns, dropped from the payload when NULL.
  @visibleForTesting
  static const rideV26PayloadKeys = [
    'max_lean_deg',
    'peak_lateral_g',
    'peak_accel_g',
    'peak_brake_g',
    'elevation_gain_m',
    'elevation_loss_m',
  ];

  /// Drops keys with no matching column, so a document written by a newer
  /// build still lands (minus the fields this one can't store) rather than
  /// being skipped whole. See [downloadRides].
  @visibleForTesting
  static Map<String, dynamic> knownRideColumnsOnly(
          Map<String, dynamic> data, Set<String> columns) =>
      {
        for (final entry in data.entries)
          if (columns.contains(entry.key)) entry.key: entry.value,
      };

  /// A local bike row as it should be written to Firestore.
  ///
  /// `archived` is only sent when set. A not-archived bike looks exactly as it
  /// did before the column existed, so a device on an older app version — whose
  /// [downloadBikes] inserts cloud fields verbatim into a table without that
  /// column — keeps downloading it. `set` replaces the whole doc, so unarchiving
  /// removes the field, which reads back as 0.
  @visibleForTesting
  static Map<String, dynamic> bikePayload(Map<String, dynamic> bike) {
    final out = Map<String, dynamic>.from(bike);
    if (out['archived'] != 1) out.remove('archived');
    // Same rule for the archive clock: only sent for an archived bike.
    if (out['archived'] != 1 || out['archived_at'] == null) {
      out.remove('archived_at');
    }
    return out;
  }

  /// Upload unsynced bikes to Firestore and mark them as synced.
  ///
  /// If a bike has a local photo, it is uploaded to Cloudinary first so the
  /// photo survives app rebuilds and multi-device logins.
  ///
  /// Last-writer-wins and one bike at a time, like [uploadRides].
  Future<void> uploadBikes(String uid, List<Map<String, dynamic>> bikes) async {
    if (bikes.isEmpty) return;

    final bikesToUpload = <Map<String, dynamic>>[];
    for (final rawBike in bikes) {
      final bike = Map<String, dynamic>.from(rawBike);
      final imagePath = bike['image_path'] as String?;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          !BikeImageResolver.isRemoteUrl(imagePath)) {
        final resolved = BikeImageResolver.resolvePathSync(imagePath);
        if (resolved != null && File(resolved).existsSync()) {
          try {
            final cloudUrl = await _cloudinaryUploadService.upload(
              File(resolved),
              folder: 'bikes/$uid',
            );
            bike['image_path'] = cloudUrl;
            await _bikeDao.updateImagePath(bike['id'] as String, cloudUrl);
          } catch (e) {
            debugPrint(
                '[CloudRepository] bike image upload to Cloudinary failed: $e');
            // Keep local path in local DB, but avoid pushing a useless local path to Firestore.
            bike['image_path'] = null;
          }
        } else {
          // File does not exist locally, avoid pushing dead local path to Firestore.
          bike['image_path'] = null;
        }
      }
      bikesToUpload.add(bike);
    }

    final columns = await _columns('bikes');
    await _uploadLastWriterWins(uid, 'bikes', 'bikes', bikesToUpload,
        bikePayload, (remote) => bikeOverwriteRow(remote, columns));
  }

  /// Upload unsynced maintenance logs to Firestore and mark them as synced.
  /// Last-writer-wins, see [_uploadLastWriterWins].
  Future<void> uploadMaintenance(
      String uid, List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) return;
    await _uploadLastWriterWins(uid, 'maintenance', 'maintenance_logs', logs,
        (log) => log, maintenanceOverwriteRow);
  }

  /// Uploads unsynced fuel fill-ups and marks them synced. Last-writer-wins
  /// on the `updated_at` fill-ups have carried since v27.
  Future<void> uploadFuelLogs(
      String uid, List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) return;
    await _uploadLastWriterWins(uid, FuelLogModel.collection, 'fuel_logs', logs,
        FuelLogModel.toCloudPayload, FuelLogModel.fromCloud);
  }

  /// Pulls fuel fill-ups missing locally, or edited later on another device
  /// (C4), skipping ones deleted here and ones whose bike was deleted here.
  /// Same incremental contract as [downloadMaintenance].
  Future<PullResult> downloadFuelLogs(String uid, {DateTime? since}) async {
    final db = await DatabaseHelper.instance.database;
    final local = await _localStamps(db, 'fuel_logs');
    final deletedIds = await FuelLogDao().deletedIds();
    final deletedBikes = await _bikeDao.deletedIds();
    final snap = await _sinceQuery(
            _firestore
                .collection('users')
                .doc(uid)
                .collection(FuelLogModel.collection),
            since)
        .get();
    final maxSyncedAt = newestSyncedAt(snap.docs.map((d) => d.data()));

    var pulledAny = false;
    DateTime? firstFailed;
    for (final doc in snap.docs) {
      final mine = local[doc.id];
      if (deletedIds.contains(doc.id) ||
          (mine != null && !downloadReplacesLocal(doc.data(), mine))) {
        continue;
      }
      final row = FuelLogModel.fromCloud({...doc.data(), 'id': doc.id});
      if (row == null || deletedBikes.contains(row['bike_id'])) continue;
      try {
        if (mine == null) {
          await db.insert('fuel_logs', row,
              conflictAlgorithm: ConflictAlgorithm.replace);
          pulledAny = true;
        } else if (await LastWriterWins.adopt(db, 'fuel_logs', row,
            localUpdatedAt: mine['updated_at'], onlyIfSynced: true)) {
          pulledAny = true;
        }
      } catch (e) {
        debugPrint('[CloudRepository] fuel download skipped for ${doc.id}: $e');
        firstFailed = earlierFailure(firstFailed, doc.data());
      }
    }
    return (
      pulledAny: pulledAny,
      maxSyncedAt: markShortOfFailures(maxSyncedAt, firstFailed),
    );
  }

  /// Deletes a fill-up's remote copy. The caller marks the tombstone synced
  /// only when this returns, so an offline delete retries.
  Future<void> deleteFuelLogRemote(String uid, String logId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection(FuelLogModel.collection)
        .doc(logId)
        .delete();
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
  /// A bike already here is replaced only by a newer edit from another
  /// device, and only while it has no unsynced local change
  /// ([downloadReplacesLocal], C4); this device's active bike and photo stay
  /// its own ([bikeOverwriteRow]).
  ///
  /// Returns whether any new bikes were pulled down (so the caller knows to
  /// invalidate garageProvider) and the newest `syncedAt` seen.
  ///
  /// [since] makes it incremental (§90.C7): only documents whose server-set
  /// `syncedAt` is newer are read. Null is a full pull — see [PullWatermark].
  Future<PullResult> downloadBikes(String uid, {DateTime? since}) async {
    final db = await DatabaseHelper.instance.database;
    final local = await _localStamps(db, 'bikes');
    // Bikes this device deleted must never come back. "Missing locally" is
    // exactly what a deleted bike looks like, so without consulting the
    // tombstones this loop faithfully re-created every bike the rider had
    // just removed — which is precisely how the delete appeared not to work.
    final deletedIds = await _bikeDao.deletedIds();
    // Same newer-schema guard as downloadRides (issues §101.C3): bikes were
    // inserted verbatim, so a field from a newer app version threw.
    final bikeColumns = (await db.rawQuery('PRAGMA table_info(bikes)'))
        .map((row) => row['name'] as String)
        .toSet();
    final snap = await _sinceQuery(
            _firestore.collection('users').doc(uid).collection('bikes'), since)
        .get();
    final maxSyncedAt = newestSyncedAt(snap.docs.map((d) => d.data()));

    final hasLocalActive = local.isNotEmpty &&
        (await db.query('bikes', where: 'is_active = 1', limit: 1)).isNotEmpty;
    var pulledAnyActive = false;
    var pulledAny = false;
    DateTime? firstFailed;

    for (final doc in snap.docs) {
      final mine = local[doc.id];
      if (deletedIds.contains(doc.id)) continue;
      if (mine != null) {
        if (!downloadReplacesLocal(doc.data(), mine)) continue;
        try {
          if (await LastWriterWins.adopt(
              db, 'bikes', bikeOverwriteRow(doc.data(), bikeColumns),
              localUpdatedAt: mine['updated_at'], onlyIfSynced: true)) {
            pulledAny = true;
          }
        } catch (e) {
          debugPrint('[CloudRepository] bike update skipped for ${doc.id}: $e');
          firstFailed = earlierFailure(firstFailed, doc.data());
        }
        continue;
      }
      final data = sanitizeDownloadedBikeData(
        doc.data(),
        hasLocalActive: hasLocalActive,
        pulledAnyActive: pulledAnyActive,
      );
      try {
        await db.insert('bikes', knownRideColumnsOnly(data, bikeColumns),
            conflictAlgorithm: ConflictAlgorithm.replace);
        pulledAny = true;
      } catch (e) {
        // Same per-doc isolation as downloadRides, and it matters more here:
        // this runs first in the sync cycle, so an unguarded throw took the
        // ride and maintenance downloads down with it.
        debugPrint('[CloudRepository] bike download skipped for ${doc.id}: $e');
        firstFailed = earlierFailure(firstFailed, doc.data());
        continue;
      }
      if (data['is_active'] == 1) pulledAnyActive = true;
    }
    // A bike that failed must be fetched again next cycle (issues §101.C3).
    return (
      pulledAny: pulledAny,
      maxSyncedAt: markShortOfFailures(maxSyncedAt, firstFailed),
    );
  }

  /// [collection] filtered to `syncedAt > since`, or unfiltered when [since]
  /// is null. A single-field range filter: served by Firestore's automatic
  /// index, no composite index needed.
  Query<Map<String, dynamic>> _sinceQuery(
          CollectionReference<Map<String, dynamic>> collection,
          DateTime? since) =>
      since == null
          ? collection
          : collection.where('syncedAt',
              isGreaterThan: Timestamp.fromDate(since));

  /// The newest `syncedAt` among [docs], or null if none carries one.
  @visibleForTesting
  static DateTime? newestSyncedAt(Iterable<Map<String, dynamic>> docs) {
    DateTime? newest;
    for (final d in docs) {
      final v = d['syncedAt'];
      final t = v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
      if (t != null && (newest == null || t.isAfter(newest))) newest = t;
    }
    return newest;
  }

  /// The pull watermark to save after a download pass: [maxSyncedAt] when
  /// every doc landed, otherwise just short of the earliest failed doc's
  /// `syncedAt` ([firstFailed]), so the next incremental query
  /// (`syncedAt > mark - overlap`) asks for it again. Without this, one
  /// failed insert was skipped until the next full pull (issues §101.C3).
  @visibleForTesting
  static DateTime? markShortOfFailures(
          DateTime? maxSyncedAt, DateTime? firstFailed) =>
      firstFailed == null
          ? maxSyncedAt
          : firstFailed.subtract(const Duration(milliseconds: 1));

  /// [current] or the `syncedAt` of [failedDoc], whichever is earlier.
  static DateTime? earlierFailure(
      DateTime? current, Map<String, dynamic> failedDoc) {
    final at = newestSyncedAt([failedDoc]);
    if (at != null && (current == null || at.isBefore(current))) return at;
    return current;
  }

  /// Sanitizes downloaded bike document data before inserting it into local SQLite.
  /// Remote URLs (e.g. Cloudinary) are preserved so bike images sync across devices.
  /// Stale local file paths from another device or platform are nulled out.
  @visibleForTesting
  static Map<String, dynamic> sanitizeDownloadedBikeData(
    Map<String, dynamic> docData, {
    required bool hasLocalActive,
    required bool pulledAnyActive,
  }) {
    final data = Map<String, dynamic>.from(docData)..remove('syncedAt');
    // A remote URL (Cloudinary) is valid on any device.
    // A local file path from a different device is meaningless here.
    final remoteImagePath = data['image_path'] as String?;
    if (remoteImagePath != null &&
        BikeImageResolver.isRemoteUrl(remoteImagePath)) {
      data['image_path'] = remoteImagePath;
    } else {
      data['image_path'] = null;
    }
    // Never let a downloaded bike silently become "the" active bike
    // alongside (or instead of) one already active locally; if nothing is
    // active locally yet, let exactly the first pulled-down bike take it.
    final wasActive = data['is_active'] == 1;
    data['is_active'] =
        (wasActive && !hasLocalActive && !pulledAnyActive) ? 1 : 0;
    data['synced'] = 1;
    return data;
  }

  /// A newer bike document (C4) as the update of an existing local row.
  /// Which bike is active is this device's choice, and a photo that is not
  /// a cloud URL (null when the other device's upload failed) would only
  /// wipe this device's own copy, so both stay local.
  @visibleForTesting
  static Map<String, dynamic> bikeOverwriteRow(
      Map<String, dynamic> doc, Set<String> columns) {
    final row = knownRideColumnsOnly(
        sanitizeDownloadedBikeData(doc,
            hasLocalActive: true, pulledAnyActive: true),
        columns)
      ..remove('is_active');
    if (row['image_path'] == null) row.remove('image_path');
    return row;
  }

  /// A newer maintenance document (C4) as the update of an existing local
  /// row. A receipt path from another device is a file that isn't here, so
  /// this device's own receipt is kept unless the cloud has a URL.
  static Map<String, dynamic> maintenanceOverwriteRow(
      Map<String, dynamic> doc) {
    final row = Map<String, dynamic>.from(doc)..remove('syncedAt');
    final receipt = row['receipt_path'];
    if (receipt is! String || !BikeImageResolver.isRemoteUrl(receipt)) {
      row.remove('receipt_path');
    }
    return row;
  }

  /// Same shape as [downloadBikes] (missing rows, plus newer edits from
  /// another device, C4), for maintenance logs.
  ///
  /// [since]: incremental, as for [downloadBikes].
  Future<PullResult> downloadMaintenance(String uid, {DateTime? since}) async {
    final db = await DatabaseHelper.instance.database;
    final local = await _localStamps(db, 'maintenance_logs');
    // Logs deleted on this device must stay deleted (§94.2) — "missing
    // locally" is exactly what a deleted log looks like.
    final deletedIds = await MaintenanceDao().deletedIds();
    final snap = await _sinceQuery(
            _firestore.collection('users').doc(uid).collection('maintenance'),
            since)
        .get();
    final maxSyncedAt = newestSyncedAt(snap.docs.map((d) => d.data()));

    var pulledAny = false;
    DateTime? firstFailed;
    for (final doc in snap.docs) {
      final mine = local[doc.id];
      if (deletedIds.contains(doc.id) ||
          (mine != null && !downloadReplacesLocal(doc.data(), mine))) {
        continue;
      }
      final data = Map<String, dynamic>.from(doc.data())..remove('syncedAt');
      data['synced'] = 1;
      try {
        if (mine == null) {
          await db.insert('maintenance_logs', data,
              conflictAlgorithm: ConflictAlgorithm.replace);
          pulledAny = true;
        } else if (await LastWriterWins.adopt(db, 'maintenance_logs',
            maintenanceOverwriteRow({...doc.data(), 'id': doc.id}),
            localUpdatedAt: mine['updated_at'], onlyIfSynced: true)) {
          pulledAny = true;
        }
      } catch (e) {
        debugPrint(
            '[CloudRepository] maintenance download skipped for ${doc.id}: $e');
        firstFailed = earlierFailure(firstFailed, doc.data());
      }
    }
    // A log this build couldn't store (e.g. one written by a newer schema)
    // must be fetched again later, so the watermark stops short of it.
    // Without this, an older build skipped a v20 visit log and then never
    // pulled it even after upgrading (§95).
    return (
      pulledAny: pulledAny,
      maxSyncedAt: markShortOfFailures(maxSyncedAt, firstFailed),
    );
  }

  /// `uid/bikeId` pairs whose cloud settings doc was already checked this
  /// session. A bike the rider never customised has no doc and would stay
  /// "missing settings" forever, so without this every sync cycle would
  /// spend a read on it.
  final Set<String> _settingsChecked = {};

  /// Restores maintenance settings (tracked checks + running costs) for
  /// owned bikes that have none locally — the reinstall / new-device case
  /// (issues §88.2). Only fills empty tables, never overwrites a local row;
  /// see [MaintenanceSettingsSync]. Must run after [downloadBikes], since a
  /// settings row can't exist without its bike.
  ///
  /// Returns true if anything was written locally.
  Future<bool> downloadMaintenanceSettings(String uid) async {
    var pulledAny = false;
    for (final bikeId
        in await MaintenanceSettingsSync.bikesMissingSettings(uid)) {
      final key = '$uid/$bikeId';
      if (_settingsChecked.contains(key)) continue;
      try {
        final snap =
            await MaintenanceSettingsSync.docRef(_firestore, uid, bikeId).get();
        final data = snap.data();
        if (data != null &&
            await MaintenanceSettingsSync.applyDownloaded(bikeId, data)) {
          pulledAny = true;
        }
        _settingsChecked.add(key);
      } catch (e) {
        // Left unmarked, so the next cycle tries again.
        debugPrint(
            '[CloudRepository] maintenance settings download skipped for $bikeId: $e');
      }
    }
    return pulledAny;
  }

  /// Same shape as [downloadBikes] (missing rows, plus newer edits from
  /// another device, C4), for ride *metadata* rows (the `rides` table).
  /// Deliberately does not pull
  /// `ride_points` (the GPS trail) — those were never uploaded in the first
  /// place (uploadRides only ever pushed the `rides` row), so a ride
  /// recovered this way lists in history with its stats but an empty map.
  /// Fixing that is a real gap but a materially bigger one (GPS trails are
  /// much larger payloads) — flagged here rather than silently left
  /// unaddressed.
  ///
  /// [since]: incremental, as for [downloadBikes]. Rides this device deleted
  /// (`deleted_rides`, §90.C10) are skipped, the same way [downloadBikes]
  /// skips deleted bikes.
  Future<PullResult> downloadRides(String uid, {DateTime? since}) async {
    final db = await DatabaseHelper.instance.database;
    final local = await _localStamps(db, 'rides');
    // Cloud documents are inserted verbatim, so a field written by a NEWER
    // app version than this one is an `INSERT` into a column that doesn't
    // exist here — which used to throw and silently skip the ride. Every
    // column added to `rides` since has needed its own bespoke guard on the
    // upload side; filtering to the columns this build actually has closes
    // the class instead of the instance.
    final rideColumns = (await db.rawQuery('PRAGMA table_info(rides)'))
        .map((row) => row['name'] as String)
        .toSet();
    final deletedIds = await _rideDao.deletedIds();
    // Rides of a bike this device deleted can never insert (FK) and will be
    // removed remotely by deleteBikeRemote, so they must not pin the
    // watermark (issues §101.C3).
    final deletedBikeIds = await _bikeDao.deletedIds();
    final snap = await _sinceQuery(
            _firestore.collection('users').doc(uid).collection('rides'), since)
        .get();
    final maxSyncedAt = newestSyncedAt(snap.docs.map((d) => d.data()));

    var pulledAny = false;
    DateTime? firstFailed;
    for (final doc in snap.docs) {
      final mine = local[doc.id];
      if (deletedIds.contains(doc.id) ||
          (mine != null && !downloadReplacesLocal(doc.data(), mine))) {
        continue;
      }
      final data = {...doc.data(), 'id': doc.id};
      try {
        if (mine == null) {
          await db.insert(
              'rides',
              {
                ...rideRowFromCloud(data, rideColumns),
                // Whatever trail this ride has is already in the cloud — it
                // came from there. Left at the column default (0), the track
                // pass would go on to "upload" a trail this device doesn't
                // hold; harmless (no local points means nothing is written)
                // but a wasted read per downloaded ride.
                'track_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
          pulledAny = true;
        } else if (await LastWriterWins.adopt(
            db, 'rides', rideOverwriteRow(data, rideColumns),
            localUpdatedAt: mine['updated_at'], onlyIfSynced: true)) {
          pulledAny = true;
        }
      } catch (e) {
        // Per-doc, deliberately. `rides.bike_id` is a FOREIGN KEY and
        // database_helper turns `PRAGMA foreign_keys` ON, so a ride whose
        // bike never made it down (deleted locally, so skipped by
        // downloadBikes' tombstone check) throws here. Unguarded, that one
        // row aborted the whole loop and every remaining doc was silently
        // skipped — and since Firestore returns docs in id order, the same
        // arbitrary subset landed every cycle and the count never moved.
        debugPrint('[CloudRepository] ride download skipped for ${doc.id}: $e');
        if (!deletedBikeIds.contains(data['bike_id'])) {
          firstFailed = earlierFailure(firstFailed, doc.data());
        }
      }
    }
    // A failed ride is asked for again next cycle (issues §101.C3).
    return (
      pulledAny: pulledAny,
      maxSyncedAt: markShortOfFailures(maxSyncedAt, firstFailed),
    );
  }

  /// Deletes a maintenance log's remote copy (§94.2). The caller marks the
  /// tombstone synced only when this returns, so an offline delete retries.
  Future<void> deleteMaintenanceRemote(String uid, String logId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .doc(logId)
        .delete();
  }

  /// Deletes a ride's remote copy and its `track` chunks (§90.C10). Same
  /// best-effort contract as [deleteBikeRemote]: the caller marks the
  /// tombstone synced only when this returns, so an offline delete retries.
  Future<void> deleteRideRemote(String uid, String rideId) async {
    final rideRef =
        _firestore.collection('users').doc(uid).collection('rides').doc(rideId);
    final track = await rideRef.collection('track').get();
    await _deleteInChunks([
      ...track.docs.map((d) => d.reference),
      rideRef,
    ]);
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
        final ai =
            (a.data()['index'] as num?)?.toInt() ?? int.tryParse(a.id) ?? 0;
        final bi =
            (b.data()['index'] as num?)?.toInt() ?? int.tryParse(b.id) ?? 0;
        return ai.compareTo(bi);
      });

    final rows = flattenTrack([
      for (final doc in docs)
        (doc.data()['points'] as List<dynamic>? ?? const []),
    ]);
    if (rows.isEmpty) return false;

    await _pointDao.insertBatch([
      for (final row in rows) {...row, 'ride_id': rideId},
    ]);
    return true;
  }

  /// Store user profile data in Firestore
  Future<void> updateUserProfile(String uid,
      {required String displayName, String? photoUrl}) async {
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

  /// Historical speed samples (km/h) for a road segment (a geohash cell —
  /// see `domain/calculators/segment_speed_aggregator.dart`), most recent
  /// first, capped at [limit] so this stays a bounded read as the pool
  /// grows. Read-only: the write side lives in
  /// `ride_recording_provider.dart`'s `_publishSegmentBaselines`, alongside
  /// this app's other fire-and-forget post-ride writes.
  Future<List<double>> fetchRoadSpeedSamples(String segmentId,
      {int limit = 200}) async {
    final snapshot = await _firestore
        .collection('roadSpeedSamples')
        .doc(segmentId)
        .collection('samples')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((d) => (d.data()['speedKmh'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
  }
}
