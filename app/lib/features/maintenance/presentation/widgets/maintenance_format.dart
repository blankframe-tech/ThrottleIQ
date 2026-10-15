/// Shared formatting for the maintenance screens.
library;

const double kmToMi = 0.621371;

/// SharedPreferences key for the km/mi choice on the maintenance page. Public
/// so notification text (maintenance_alerts) honours the same choice.
const kMaintenanceImperialPrefKey = 'maintenance_imperial_units';

String distLabel(double km, bool imperial) {
  final value = imperial ? km * kmToMi : km;
  return '${value.toStringAsFixed(0)} ${imperial ? 'mi' : 'km'}';
}

String formatServiceDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

/// A ৳ amount without the symbol: whole taka from 10 up, one decimal below
/// (a 6 km errand's chain-lube share is ৳0.4, not "৳0").
String formatTaka(double amount) =>
    amount >= 10 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1);

/// A per-km/per-mi rate, which is usually a few taka or less.
String formatTakaRate(double rate) =>
    rate >= 100 ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2);

/// `12,480` — thousands separators for odometer-sized numbers.
String groupThousands(num value) {
  final digits = value.round().abs().toString();
  final b = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// [distLabel] with thousands separators: `12,480 km`.
String distLabelLong(double km, bool imperial) {
  final value = imperial ? km * kmToMi : km;
  return '${groupThousands(value)} ${imperial ? 'mi' : 'km'}';
}
