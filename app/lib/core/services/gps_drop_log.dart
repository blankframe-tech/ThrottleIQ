import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/sensor_constants.dart';

/// How many GPS fixes each recent ride threw away for poor accuracy (worse
/// than [SensorConstants.maxGpsAccuracyM]), so that threshold can be tuned
/// from real rides before anyone changes it (critique §4, "GPS loss": dense
/// streets may drop enough fixes to under-count distance). Kept on the phone
/// for the last [keep] rides and read only by the bug-report bundle.
class GpsDropLog {
  GpsDropLog._();

  static const prefsKey = 'gps_accuracy_drop_log';
  static const keep = 20;

  /// Appends one ride's counts, newest last. A ride restored after a kill
  /// counts only what was ridden after the restore.
  static Future<void> record(String rideId,
      {required int kept, required int dropped}) async {
    final entries = await recent();
    entries.add({
      'rideId': rideId,
      'kept': kept,
      'dropped': dropped,
      'thresholdM': SensorConstants.maxGpsAccuracyM,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        prefsKey,
        jsonEncode(entries.length > keep
            ? entries.sublist(entries.length - keep)
            : entries));
  }

  /// The logged rides, oldest first; empty when nothing is logged or the
  /// stored value can't be read.
  static Future<List<Map<String, Object?>>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return [];
      return [
        for (final e in jsonDecode(raw) as List)
          Map<String, Object?>.from(e as Map),
      ];
    } catch (e) {
      debugPrint('[GpsDropLog] unreadable log: $e');
      return [];
    }
  }
}
