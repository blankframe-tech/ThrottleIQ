import '../../../l10n/app_localizations.dart';

/// `320 m` / `4.2 km`, the one distance wording every route surface uses.
///
/// Unit names stay Latin ("m"/"km") in both languages on purpose — the same
/// decision as `core/i18n/numeric_locale.dart` makes for digits, so a readout
/// glanced at from a bike reads identically whichever language the app is in.
String routeDistanceLabel(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// An arrival time from a number of seconds, or the em-dash placeholder when
/// there isn't one — see `kMinEtaSpeedMs` for when that happens.
String routeEtaLabel(AppLocalizations l, int? seconds) {
  if (seconds == null) return '—';
  if (seconds < 60) return l.etaUnderAMinute;
  final minutes = (seconds / 60).round();
  if (minutes < 60) return l.etaMinutes(minutes);
  return l.etaHoursMinutes(minutes ~/ 60, minutes % 60);
}
