import '../../../../l10n/app_localizations.dart';

/// Shown for a number the ride doesn't have, never a made-up value.
const simpleRidesDash = '—';

/// "12.4 km".
String simpleRidesKm(double km) => '${km.toStringAsFixed(1)} km';

/// "1 h 5 min" / "25 min", or a dash when the time wasn't recorded.
String simpleRidesDuration(AppLocalizations l10n, int? seconds) {
  if (seconds == null) return simpleRidesDash;
  final minutes = (seconds / 60).round();
  return minutes >= 60
      ? l10n.simpleRidesDurationHm(minutes ~/ 60, minutes % 60)
      : l10n.simpleRidesDurationM(minutes);
}
