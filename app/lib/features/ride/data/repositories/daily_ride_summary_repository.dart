import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/daos/auto_detection_dao.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/calculators/auto_detection_policy.dart';
import '../../domain/calculators/auto_ride_reconciler.dart';
import '../../domain/calculators/daily_ride_summary.dart';

/// Builds [DailyRideSummary]s from local data: the day's ride rows plus the
/// stretches of background detections no ride row covers.
///
/// **Riverpod-free on purpose**: the auto-tracking task-handler isolate calls
/// [showEndOfDayIfDue] too, and that isolate has no `ProviderContainer`. Both
/// isolates reach the same SQLite file through their own connections (see
/// `AutoDetectionDao`'s doc comment); this only reads.
///
/// Nothing here writes to a detection or its fixes — summarising is a view,
/// recomputed each time, so a ride recorded or deleted later is reflected.
class DailyRideSummaryRepository {
  DailyRideSummaryRepository({
    AutoDetectionDao? detectionDao,
    RideDao? rideDao,
    AutoRideReconciler? reconciler,
  })  : _detectionDao = detectionDao ?? AutoDetectionDao(),
        _rideDao = rideDao ?? RideDao(),
        _reconciler = reconciler ?? AutoRideReconciler();

  final AutoDetectionDao _detectionDao;
  final RideDao _rideDao;
  final AutoRideReconciler _reconciler;

  /// Local hour after which the day counts as over for the notification.
  /// Matches the 9pm `NotificationService.scheduleDailySummary` trigger.
  static const endOfDayHour = 21;

  /// SharedPreferences key: the `yyyy-mm-dd` the end-of-day summary was last
  /// shown for. Read with `reload()` — either isolate may have written it.
  static const prefsLastShownDay = 'auto_tracking_eod_summary_day';

  /// The summary for the local calendar day containing [day].
  Future<DailyRideSummary> summaryFor(String userId, DateTime day) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    return summarizeDay(day: from, segments: await _segments(userId, from, to));
  }

  /// The last [days] days, newest first, today included. Empty days are
  /// included too; the caller decides whether to show them.
  Future<List<DailyRideSummary>> recentDays(
    String userId, {
    int days = 14,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    return [
      for (var i = 0; i < days; i++)
        await summaryFor(
            userId, DateTime(today.year, today.month, today.day - i)),
    ];
  }

  /// Shows today's summary notification once, after [endOfDayHour]. Returns
  /// whether it was shown. Silent (and not marked shown) on a day with no
  /// rides, so a ride later that evening still gets its summary.
  Future<bool> showEndOfDayIfDue(String userId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    if (at.hour < endOfDayHour) return false;
    final dayKey = _dayKey(at);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(prefsLastShownDay) == dayKey) return false;

    final summary = await summaryFor(userId, at);
    if (summary.isEmpty) return false;
    try {
      await NotificationService.instance.showDailySummary(
        rideCount: summary.rideCount,
        distanceKm: summary.distanceM / 1000,
        rideMinutes: summary.rideSeconds ~/ 60,
        notRecordedCount: summary.detectedRideCount,
      );
    } catch (e) {
      debugPrint('[daily-summary] notification failed: $e');
      return false;
    }
    await prefs.setString(prefsLastShownDay, dayKey);
    return true;
  }

  /// SharedPreferences key: the `yyyy-mm-dd` the fix-retention purge last ran.
  static const prefsLastPurgeDay = 'auto_tracking_fix_purge_day';

  /// Drops raw fixes of summarized detections older than the retention window
  /// ([AutoDetectionDao.purgeOldSummarizedFixes], 14 days — the same span as
  /// [recentDays], so every day the UI lists keeps its totals). Runs at most
  /// once per local day; returns how many detections were purged.
  Future<int> purgeOldFixesIfDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final dayKey = _dayKey(at);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(prefsLastPurgeDay) == dayKey) return 0;
    final purged = await _detectionDao.purgeOldSummarizedFixes(at);
    await prefs.setString(prefsLastPurgeDay, dayKey);
    return purged;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<List<DaySegment>> _segments(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final segments = <DaySegment>[];

    for (final r in await _rideDao.getCompletedBetween(userId, from, to)) {
      final start = DateTime.tryParse(r['start_time'] as String? ?? '');
      if (start == null) continue;
      final duration = (r['duration_s'] as num?)?.toInt() ?? 0;
      final end = DateTime.tryParse(r['end_time'] as String? ?? '') ??
          start.add(Duration(seconds: duration));
      segments.add(DaySegment(
        source: DaySegmentSource.recorded,
        start: start,
        end: end,
        distanceM: (r['distance_m'] as num?)?.toDouble() ?? 0,
        movingSeconds: (r['moving_s'] as num?)?.toInt() ?? 0,
        durationSeconds: duration,
        maxSpeedMs: (r['max_speed_ms'] as num?)?.toDouble() ?? 0,
      ));
    }

    final detections =
        await _detectionDao.summaryDetectionsBetween(userId, from, to);
    if (detections.isEmpty) return segments;

    // Every ride window, active ones included (end null = still recording):
    // a fix inside one is the rider's own recording and must never be
    // counted a second time (§90.C3).
    final windows = [
      for (final w in await _rideDao.rideWindows(userId))
        (start: w.start, end: w.end),
    ];

    for (final d in detections) {
      final staged = [
        for (final r in await _detectionDao.fixesFor(d['id'] as String))
          stagedFixFromRow(r),
      ];
      for (final run in runsClearOfRides<StagedFix>(
          staged, (f) => f.timestamp, windows)) {
        final m = _reconciler.measure(run);
        if (m == null) continue;
        segments.add(DaySegment(
          source: DaySegmentSource.detected,
          start: run.first.timestamp,
          end: run.last.timestamp,
          distanceM: m.distanceM,
          movingSeconds: m.movingSeconds,
          durationSeconds: m.durationSeconds,
          maxSpeedMs: m.maxSpeedMs,
          startPoint: (lat: run.first.lat, lng: run.first.lng),
          endPoint: (lat: run.last.lat, lng: run.last.lng),
        ));
      }
    }
    return segments;
  }
}

/// An `auto_fixes` row as the replay's input shape.
StagedFix stagedFixFromRow(Map<String, dynamic> r) => (
      timestamp: DateTime.parse(r['timestamp'] as String),
      lat: (r['lat'] as num).toDouble(),
      lng: (r['lng'] as num).toDouble(),
      speedMs: (r['speed_ms'] as num?)?.toDouble() ?? 0,
      accuracyM: (r['accuracy_m'] as num?)?.toDouble(),
      altitudeM: (r['altitude_m'] as num?)?.toDouble(),
      headingDeg: (r['heading_deg'] as num?)?.toDouble(),
    );
