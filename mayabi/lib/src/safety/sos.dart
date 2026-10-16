/// SOS links the app opens with `url_launcher`. The rider presses Send or
/// Call herself, so these work with no data connection (plain cellular SMS)
/// and nothing goes out without her. The automatic path (no answer to "Are
/// you OK?") is `ThrottleIqClient.sendAlert`, which reaches Maya ops.
library;

/// Bangladesh's national emergency service (police, fire, ambulance).
const kBangladeshEmergencyNumber = '999';

/// A `tel:` link, keeping a leading `+` and dropping spaces, dashes and
/// brackets (`+880 1X-XXXX-XXXX`). Null when nothing dialable is left.
Uri? telUri(String raw) {
  final n = _dialable(raw);
  return n == null ? null : Uri(scheme: 'tel', path: n);
}

String? _dialable(String raw) {
  final t = raw.trim();
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return t.startsWith('+') ? '+$digits' : digits;
}

/// An `sms:` link to every dialable number in [phones] with [body] filled
/// in; null when none is dialable. The body is percent-encoded by hand:
/// `Uri.queryParameters` writes spaces as `+`, which Messages shows as is.
///
/// shortcut: the iOS multi-recipient form (`sms:/open?addresses=`) is not
/// device-verified yet; check it on an iPhone before relying on 2+ contacts.
Uri? sosSmsUri(List<String> phones, String body, {required bool iOS}) {
  final numbers = phones.map(_dialable).whereType<String>();
  if (numbers.isEmpty) return null;
  final to = numbers.join(',');
  final text = Uri.encodeComponent(body);
  return Uri.parse(
      iOS ? 'sms:/open?addresses=$to&body=$text' : 'sms:$to?body=$text');
}

/// A Google Maps pin for a position.
String mapLink(double lat, double lng) =>
    'https://maps.google.com/?q=${lat.toStringAsFixed(7)},${lng.toStringAsFixed(7)}';

/// The SOS text: [intro] (in the rider's language), then the live link and
/// the map pin when there are any. Labels default to English; pass Bangla
/// ones from the app's strings (see mayabi/README.md).
String sosMessage({
  required String intro,
  String? liveUrl,
  double? lat,
  double? lng,
  String liveLabel = 'Live location',
  String mapLabel = 'Last known spot',
}) =>
    [
      intro,
      if (liveUrl != null) '$liveLabel: $liveUrl',
      if (lat != null && lng != null) '$mapLabel: ${mapLink(lat, lng)}',
    ].join('\n');
