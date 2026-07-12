class SpeedFormatter {
  static String fromMs(double ms) {
    final kmh = ms * 3.6;
    return '${kmh.toStringAsFixed(0)} km/h';
  }

  static String distanceKm(double meters) {
    final km = meters / 1000;
    if (km < 1) return '${meters.toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(2)} km';
  }

  static String durationFromSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String durationFromDuration(Duration d) =>
      durationFromSeconds(d.inSeconds);
}
