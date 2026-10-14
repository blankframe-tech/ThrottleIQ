import 'dart:convert';

import '../../../features/ride/domain/entities/impact_event_types.dart';
import '../database_helper.dart';

/// Impacts saved by shadow-mode crash detection (`impact_events`, schema
/// v28) and the rider's answers about them.
///
/// Rows go when their ride goes: RideDao's delete paths and
/// DatabaseHelper.deleteUserData remove them in the same transaction as the
/// ride's points, without calling this DAO (no DAO calls inside a
/// transaction — issues_fixed.md §7).
class ImpactEventDao {
  Future<void> insert(Map<String, Object?> row) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('impact_events', row);
  }

  Future<List<Map<String, Object?>>> getForRide(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('impact_events',
        where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'at ASC');
  }

  /// Possible falls on [rideId] the rider hasn't answered yet, oldest first.
  Future<List<Map<String, Object?>>> pendingQuestions(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('impact_events',
        where: 'ride_id = ? AND tier >= 1 AND label IS NULL',
        whereArgs: [rideId],
        orderBy: 'at ASC');
  }

  /// Records the rider's answer and queues the row for sync. [consent] is
  /// the research setting at this moment (CrashResearchConsent).
  Future<void> setLabel(
    String id, {
    required ImpactLabel label,
    required bool consent,
    Map<String, Object?>? detail,
    DateTime? now,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'impact_events',
      {
        'label': label.wire,
        'label_detail':
            detail == null || detail.isEmpty ? null : jsonEncode(detail),
        'label_source': 'rider',
        'labeled_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
        'consent_research': consent ? 1 : 0,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// A fall the rider reports that the detector missed: the only way recall
  /// can be measured. Stored as tier -1, label [ImpactLabel.missed].
  Future<void> reportMissed({
    required String id,
    required String rideId,
    required String userId,
    required DateTime at,
    required bool consent,
    PhonePlacement placement = PhonePlacement.unknown,
    double? lat,
    double? lng,
    Map<String, Object?>? detail,
    DateTime? now,
  }) async {
    final stamp = (now ?? DateTime.now()).toUtc().toIso8601String();
    final db = await DatabaseHelper.instance.database;
    await db.insert('impact_events', {
      'id': id,
      'ride_id': rideId,
      'user_id': userId,
      'at': at.toUtc().toIso8601String(),
      'tier': -1,
      'reason': 'riderReport',
      'lat': lat,
      'lng': lng,
      'placement_declared': placement.wire,
      'label': ImpactLabel.missed.wire,
      'label_detail':
          detail == null || detail.isEmpty ? null : jsonEncode(detail),
      'label_source': 'rider',
      'labeled_at': stamp,
      'consent_research': consent ? 1 : 0,
      'synced': 0,
      'created_at': stamp,
    });
  }

  /// Unsynced rows of [userId] with their bike's details (for the central
  /// record's bike class), oldest first, at most [limit].
  Future<List<Map<String, Object?>>> unsyncedForUser(String userId,
      {int limit = 50}) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT e.*, b.cc AS bike_cc, b.brand AS bike_brand,
             b.model AS bike_model, b.is_ebike AS bike_is_ebike
        FROM impact_events e
        LEFT JOIN rides r ON r.id = e.ride_id
        LEFT JOIN bikes b ON b.id = r.bike_id
       WHERE e.user_id = ? AND e.synced = 0
       ORDER BY e.created_at ASC
       LIMIT ?
    ''', [userId, limit]);
  }

  /// Marks [id] synced only if it wasn't relabelled since it was read
  /// ([labeledAt] as uploaded), so an answer given mid-upload isn't lost.
  Future<void> markSynced(String id, {String? labeledAt}) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'impact_events',
      {'synced': 1},
      where: "id = ? AND COALESCE(labeled_at, '') = ?",
      whereArgs: [id, labeledAt ?? ''],
    );
  }

  /// Applies a change of the research setting to every answered row of
  /// [userId] and re-queues them. Returns how many rows changed.
  Future<int> setConsentForUser(String userId, bool consent) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      'impact_events',
      {'consent_research': consent ? 1 : 0, 'synced': 0},
      where: 'user_id = ? AND label IS NOT NULL AND consent_research != ?',
      whereArgs: [userId, consent ? 1 : 0],
    );
  }
}
