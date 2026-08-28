import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Weather at a ride's start time/place, from Open-Meteo — free, keyless,
/// no signup. Stands in for a paid weather vendor the same way Cloudinary
/// stands in for Firebase Storage (see `cloudinary_upload_service.dart`):
/// no account/billing decision needed to ship this.
///
/// Uses the **forecast** endpoint with `past_days`, not the archive/
/// reanalysis endpoint — the archive API is ERA5 reanalysis data with a
/// multi-day ingestion lag, so a ride that just finished wouldn't have
/// weather available there yet. The forecast endpoint's recent-past hours
/// are near-real-time.
typedef RideWeather = ({int weatherCode, double tempC});

class WeatherService {
  final Dio _dio;
  WeatherService({Dio? dio}) : _dio = dio ?? Dio();

  static const _endpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Best-effort only — returns null on any failure (offline, timeout,
  /// unexpected response shape) rather than throwing. Weather is an
  /// enrichment on the road-speed sample, not something a ride can fail to
  /// save over; see `ride_recording_provider.dart`'s `_bestEffortWrite` for
  /// the same philosophy applied to the write side.
  Future<RideWeather?> fetchForRide({
    required double lat,
    required double lng,
    required DateTime at,
  }) async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            _endpoint,
            queryParameters: {
              'latitude': lat,
              'longitude': lng,
              'hourly': 'temperature_2m,weathercode',
              'past_days': 2,
              'forecast_days': 1,
              'timezone': 'auto',
            },
          )
          .timeout(const Duration(seconds: 6));

      final hourly = response.data?['hourly'] as Map<String, dynamic>?;
      final times = (hourly?['time'] as List?)?.cast<String>();
      final temps = (hourly?['temperature_2m'] as List?)?.cast<num>();
      final codes = (hourly?['weathercode'] as List?)?.cast<num>();
      if (times == null || temps == null || codes == null || times.isEmpty) {
        return null;
      }

      // Nearest hourly bucket to `at` — Open-Meteo's timestamps are local
      // (via timezone=auto), unlike `at`, which is whatever the device
      // clock produced; DateTime.parse leaves both naive/local, so a direct
      // comparison is close enough for hour-level bucketing.
      var closestIndex = 0;
      var closestGap = const Duration(days: 999);
      for (var i = 0; i < times.length; i++) {
        final t = DateTime.tryParse(times[i]);
        if (t == null) continue;
        final gap = t.difference(at).abs();
        if (gap < closestGap) {
          closestGap = gap;
          closestIndex = i;
        }
      }

      return (
        weatherCode: codes[closestIndex].toInt(),
        tempC: temps[closestIndex].toDouble(),
      );
    } catch (e) {
      debugPrint('[WeatherService] fetchForRide failed: $e');
      return null;
    }
  }
}
