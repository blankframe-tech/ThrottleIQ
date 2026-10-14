import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

/// Multi-device conflict policy for rides, bikes, maintenance and fuel logs
/// (founder decision C4, 2026-10-14): the copy with the newer `updated_at`
/// wins. `updated_at` is the UTC time of the row's last local edit, kept by
/// the models and the v28 `*_touch_updated_at` triggers (DatabaseHelper).
///
/// - A copy without `updated_at` (written by a build before schema v28)
///   counts as the oldest: it never replaces a stamped copy.
/// - Deletions are not decided here; tombstones (`deleted_*`) do that.
/// - The order is the phones' wall clocks: a phone whose clock is far
///   ahead wins every conflict it is part of.
class LastWriterWins {
  LastWriterWins._();

  static DateTime? stamp(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// Whether [remote] holds a newer edit than [local].
  static bool remoteIsNewer(
      Map<String, dynamic>? remote, Map<String, dynamic> local) {
    final r = stamp(remote?['updated_at']);
    if (r == null) return false;
    final l = stamp(local['updated_at']);
    return l == null || r.isAfter(l);
  }

  /// Writes [payload] to [ref] unless the remote copy is newer. Read and
  /// write are one transaction, so a newer copy another device writes in
  /// between is never overwritten. Returns the remote data when it won (the
  /// caller adopts it locally), null when [payload] was written.
  static Future<Map<String, dynamic>?> setUnlessRemoteNewer(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> payload,
  ) =>
      firestore.runTransaction((tx) async {
        final remote = (await tx.get(ref)).data();
        if (remoteIsNewer(remote, payload)) return remote;
        tx.set(ref, payload);
        return null;
      });

  /// Overwrites local row `row['id']` of [table] with [row] (a remote copy
  /// already in local column form) and marks it synced, but only while the
  /// row still carries [localUpdatedAt]: an edit made after it was read is
  /// never clobbered. [onlyIfSynced] also skips a row with unsynced changes.
  /// Returns whether the row was written.
  static Future<bool> adopt(
    DatabaseExecutor db,
    String table,
    Map<String, dynamic> row, {
    required Object? localUpdatedAt,
    bool onlyIfSynced = false,
  }) async {
    final n = await db.update(
      table,
      {...row, 'synced': 1},
      where:
          'id = ? AND updated_at IS ?${onlyIfSynced ? ' AND synced = 1' : ''}',
      whereArgs: [row['id'], localUpdatedAt],
    );
    return n > 0;
  }
}
