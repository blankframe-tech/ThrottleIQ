import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';

const String _prefsOverspeedKmh = 'settings_overspeed_kmh';

final overspeedLimitProvider =
    StateNotifierProvider<OverspeedLimitNotifier, double>((ref) {
  return OverspeedLimitNotifier();
});

class OverspeedLimitNotifier extends StateNotifier<double> {
  OverspeedLimitNotifier() : super(SensorConstants.defaultOverspeedKmh) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsOverspeedKmh);
    if (saved != null) {
      state = saved.clamp(
        SensorConstants.minOverspeedKmh,
        SensorConstants.maxOverspeedKmh,
      );
    }
  }

  Future<void> setLimit(double kmh) async {
    final clamped = kmh.clamp(
      SensorConstants.minOverspeedKmh,
      SensorConstants.maxOverspeedKmh,
    );
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsOverspeedKmh, clamped);
  }

  /// Speed threshold in m/s for domain calculators.
  double get thresholdMs => state / 3.6;
}
