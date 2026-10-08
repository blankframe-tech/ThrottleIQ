/// Shared numeric-input parser (issues §101.R4).
///
/// Riders type numbers three ways in Bangladesh: Western digits, Bangla
/// digits (U+09E6..U+09EF, from Ridmik/Avro keyboards) and '12,000' /
/// '1,20,000' style grouping. A comma is a thousands separator when the
/// grouping is well formed and a decimal point when it is the only comma
/// ('12,5'). Anything not finite, or outside [min]/[max], is null.
final RegExp _grouped = RegExp(r'^\d{1,3}(,\d{2,3})*,\d{3}(\.\d+)?$');
final RegExp _plain = RegExp(r'^\d+(\.\d+)?$');

double? parseLocalizedNumber(String value, {double? min, double? max}) {
  final buf = StringBuffer();
  for (final c in value.trim().runes) {
    if (c >= 0x09E6 && c <= 0x09EF) {
      buf.writeCharCode(0x30 + (c - 0x09E6));
    } else if (c == 0x20 || c == 0x5F || c == 0xA0) {
      continue; // spaces and underscores are ignored
    } else {
      buf.writeCharCode(c);
    }
  }
  var s = buf.toString();
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  }
  if (_grouped.hasMatch(s)) {
    s = s.replaceAll(',', '');
  } else if (!s.contains('.') && ','.allMatches(s).length == 1) {
    s = s.replaceAll(',', '.');
  }
  if (!_plain.hasMatch(s)) return null;
  final parsed = double.tryParse(s);
  if (parsed == null || !parsed.isFinite) return null;
  final n = negative ? -parsed : parsed;
  if (min != null && n < min) return null;
  if (max != null && n > max) return null;
  return n;
}

/// Whole numbers only: '12.5' is null, '12.0' is 12.
int? parseLocalizedInt(String value, {int? min, int? max}) {
  final n = parseLocalizedNumber(value,
      min: min?.toDouble(), max: max?.toDouble());
  if (n == null || n != n.truncateToDouble() || n.abs() > 9e15) return null;
  return n.toInt();
}
