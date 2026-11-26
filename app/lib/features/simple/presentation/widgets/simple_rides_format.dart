import '../../../../l10n/app_localizations.dart';
import '../../../maintenance/presentation/widgets/maintenance_format.dart';

/// Shown for a number the ride doesn't have, never a made-up value.
const simpleRidesDash = '—';

/// "8.5", "120", "1,250": one decimal only for small values. The one
/// number format for km and ৳ on every Simple tab.
String simpleAmount(double v) =>
    v < 10 ? v.toStringAsFixed(1) : groupThousands(v);

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
