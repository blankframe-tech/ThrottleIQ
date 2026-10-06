import 'package:shared_preferences/shared_preferences.dart';

/// Result of one download pass over a `users/{uid}/…` collection.
typedef PullResult = ({bool pulledAny, DateTime? maxSyncedAt});

/// Per-rider, per-collection "pulled everything up to here" marks (§90.C7).
///
/// Every sync cycle (every 5 minutes, and on every connectivity change) used
/// to `.get()` the rider's whole rides/bikes/maintenance collections — 500
/// rides was ~500 reads a cycle, ~144k a day while the process lived. Now the
/// first pull after sign-in is full, and later ones ask only for documents
/// whose server-set `syncedAt` is newer than the newest one already seen.
///
/// The mark is the server's own timestamp off a document, never this
/// device's clock, so clock skew can't open a gap. [overlap] re-reads a small
/// window behind it anyway; the download path skips ids it already holds, so
/// the overlap costs reads, never duplicates.
///
/// Deletions are unaffected: no download ever deleted a local row, and the
/// tombstones (`deleted_bikes`, `deleted_rides`) that stop a deleted row
/// coming back are consulted on every pull, full or incremental.
class PullWatermark {
  PullWatermark._();

  static const Duration overlap = Duration(minutes: 2);

  /// Used when a full pull saw no `syncedAt` at all (an empty collection, or
  /// only documents written before the field existed): later pulls then pick
  /// up every stamped document, which is all of the new ones.
  static final DateTime floorForUnstamped =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static const collections = ['bikes', 'rides', 'maintenance'];

  static String key(String uid, String collection) =>
      'cloud_pull_watermark_${collection}_$uid';

  /// The `syncedAt >` bound for the next query, or null for a full pull.
  ///
  /// Full when there is no mark yet (first pull since sign-in on this
  /// device), or when nothing of this rider's is on disk for the collection
  /// (a cleared database must be refilled, whatever the mark says).
  static DateTime? queryFloor({
    required DateTime? watermark,
    required bool hasLocalRows,
  }) {
    if (watermark == null || !hasLocalRows) return null;
    final floor = watermark.subtract(overlap);
    return floor.isBefore(floorForUnstamped) ? floorForUnstamped : floor;
  }

  /// The mark after a pull: the newest `syncedAt` seen, never moving
  /// backwards. A full pull that saw no stamps still sets a mark
  /// ([floorForUnstamped]) so the next pull is incremental.
  static DateTime? advance({
    required DateTime? current,
    required DateTime? seen,
    required bool wasFullPull,
  }) {
    var next = current;
    if (seen != null && (next == null || seen.isAfter(next))) next = seen;
    if (next == null && wasFullPull) next = floorForUnstamped;
    return next;
  }

  static Future<DateTime?> read(String uid, String collection) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(key(uid, collection));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static Future<void> write(String uid, String collection, DateTime? at) async {
    if (at == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key(uid, collection), at.millisecondsSinceEpoch);
  }

  /// Forgets [uid]'s marks, so their next sign-in starts with a full pull.
  static Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in collections) {
      await prefs.remove(key(uid, c));
    }
  }
}
