import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';

/// Top-level so [compute] can hand it to a worker isolate. A share-ride
/// payload carries the ride's full polyline, which can be large enough that
/// encoding it inline on the calling isolate is a visible hitch right when
/// the rider taps "Share" — see DOCS/Handoff for agents and Todos/issues_open.md or issues_fixed.md §65.3.
String _encodeOutboxPayload(Map<String, dynamic> payload) => jsonEncode(payload);

/// `outbox.status` values. See `_createOutboxSql` in [DatabaseHelper].
class OutboxStatus {
  OutboxStatus._();

  /// Waiting for (or between) delivery attempts. The drain loop's only input.
  static const String pending = 'pending';

  /// Given up on automatically — §69.O4. Kept, not deleted, because it is
  /// still the rider's intent: Settings → Sync issues lets them retry or
  /// discard it.
  static const String dead = 'dead';
}

/// One queued cloud write, as it comes back off disk.
class OutboxEntry {
  final String id;

  /// Which handler replays this row — see `OutboxKind` in `outbox_service.dart`.
  /// Kept as a plain string in the DB so an unknown/retired kind read by an
  /// older build is inert data rather than a parse crash.
  final String kind;

  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;

  /// [OutboxStatus.pending] or [OutboxStatus.dead].
  final String status;

  /// How many of [attempts] were rejections that retrying can't fix (see
  /// `isPermanentOutboxError` in `outbox_service.dart`).
  final int permanentFailures;

  bool get isDead => status == OutboxStatus.dead;

  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    required this.nextAttemptAt,
    required this.lastError,
    this.status = OutboxStatus.pending,
    this.permanentFailures = 0,
  });

  factory OutboxEntry.fromRow(Map<String, dynamic> row) {
    final raw = row['payload'] as String?;
    return OutboxEntry(
      id: row['id'] as String,
      kind: row['kind'] as String,
      // A row whose payload can't be decoded is not recoverable by retrying,
      // so it decodes to an empty map and its handler will reject it — which
      // routes it to the permanent-failure path rather than looping forever.
      payload: _decodePayload(raw),
      createdAt: DateTime.parse(row['created_at'] as String),
      attempts: (row['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: row['next_attempt_at'] == null
          ? null
          : DateTime.tryParse(row['next_attempt_at'] as String),
      lastError: row['last_error'] as String?,
      status: row['status'] as String? ?? OutboxStatus.pending,
      permanentFailures: (row['permanent_failures'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> _decodePayload(String? raw) {
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}

/// Storage for the offline write queue. See `_createOutboxSql` in
/// [DatabaseHelper] for why the queue exists at all.
class OutboxDao {
  Future<void> enqueue({
    required String id,
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final encoded = await compute(_encodeOutboxPayload, payload);
    await db.insert(
      'outbox',
      {
        'id': id,
        'kind': kind,
        'payload': encoded,
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 0,
        'next_attempt_at': null,
        'last_error': null,
        // Explicit, so re-queuing a dead intent (e.g. sharing the same ride
        // again) brings it back to life rather than inheriting its old state.
        'status': OutboxStatus.pending,
        'permanent_failures': 0,
      },
      // Replace rather than fail: callers derive deterministic ids for
      // operations that are naturally single-valued (one teardown per live
      // session, one share per ride), so re-queuing supersedes the older
      // intent instead of stacking a duplicate write.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Rows ready to attempt now, oldest intent first. Dead rows are never
  /// due — only [revive] puts one back in line.
  ///
  /// Ordering by `created_at` rather than by id matters: a rider who ends a
  /// ride and then shares it offline expects them replayed in that order, and
  /// the share's Firestore doc is keyed on a ride the end-of-ride write
  /// finalizes.
  Future<List<OutboxEntry>> due({DateTime? now, int limit = 50}) async {
    final db = await DatabaseHelper.instance.database;
    final stamp = (now ?? DateTime.now()).toIso8601String();
    final rows = await db.query(
      'outbox',
      where: "status != 'dead' AND "
          '(next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: [stamp],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<List<OutboxEntry>> all() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('outbox', orderBy: 'created_at ASC');
    return rows.map(OutboxEntry.fromRow).toList();
  }

  /// How many intents are still waiting — drives the "queued" UI badge.
  /// Dead rows aren't waiting on anything but the rider, so they're counted
  /// by [deadCount] instead; counting them here would show "will post when
  /// you're back online" forever for a write that never will.
  Future<int> pendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM outbox WHERE status != 'dead'",
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> pendingCountOfKind(String kind) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM outbox WHERE kind = ? AND status != 'dead'",
      [kind],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Rows the drain loop has given up on, oldest first — Settings → Sync
  /// issues.
  Future<List<OutboxEntry>> dead() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'outbox',
      where: 'status = ?',
      whereArgs: [OutboxStatus.dead],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<int> deadCount() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM outbox WHERE status = 'dead'",
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Puts a dead row back in line with a clean slate, as if just queued —
  /// the rider's "Retry". The counters reset too: otherwise a single further
  /// rejection would kill it again immediately.
  Future<void> revive(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'outbox',
      {
        'status': OutboxStatus.pending,
        'attempts': 0,
        'permanent_failures': 0,
        'next_attempt_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Rewrites a row's payload mid-flight.
  ///
  /// Needed because parts of an operation can succeed non-idempotently before
  /// the whole thing does: a queued share uploads its photos to Cloudinary
  /// (which mints a NEW asset every call) and only then writes the Firestore
  /// doc. Folding the resulting URLs back into the payload means a retry
  /// resumes after the upload instead of re-uploading and orphaning the first
  /// copy.
  Future<void> updatePayload({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final encoded = await compute(_encodeOutboxPayload, payload);
    await db.update(
      'outbox',
      {'payload': encoded},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  /// Records a failed attempt and schedules the next one.
  ///
  /// [permanent] counts it toward `permanent_failures`; [dead] retires the
  /// row. The caller decides both (see `OutboxService._deliver`) so the
  /// give-up policy lives in one place, not split between here and there.
  Future<void> recordFailure({
    required String id,
    required String error,
    required DateTime nextAttemptAt,
    bool permanent = false,
    bool dead = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, next_attempt_at = ?, '
      'last_error = ?, permanent_failures = permanent_failures + ?, '
      'status = ? WHERE id = ?',
      [
        nextAttemptAt.toIso8601String(),
        // Bounded: a stack trace in a queue row is worth nothing and can be
        // arbitrarily long.
        error.length > 500 ? error.substring(0, 500) : error,
        permanent ? 1 : 0,
        dead ? OutboxStatus.dead : OutboxStatus.pending,
        id,
      ],
    );
  }
}
