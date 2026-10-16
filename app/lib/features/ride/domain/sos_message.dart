/// The pure half of the ride SOS sheet: the SMS link that pre-fills the
/// rider's messages app. The rider still presses Send, so this works with no
/// backend and no data connection (plain cellular SMS) — unlike the crash
/// alert path, whose delivery is still mocked (`functions/src/crash-core.ts`).
library;

import '../../poi_directory/domain/place_directions.dart';

/// Bangladesh's national emergency service (police, fire, ambulance).
const kBangladeshEmergencyNumber = '999';

/// An `sms:` link to every dialable number in [phones] with [body] filled in.
/// Null when no number survives cleanup, so the caller hides the action.
///
/// The body goes through [Uri.encodeComponent] by hand: `Uri`'s
/// `queryParameters` encodes spaces as `+`, which Messages shows literally.
///
/// shortcut: the iOS multi-recipient form (`sms:/open?addresses=`) is not
/// device-verified yet; check it on an iPhone before relying on 2+ contacts.
Uri? sosSmsUri(List<String> phones, String body, {required bool iOS}) {
  final numbers = phones.map((p) => telUri(p)?.path).whereType<String>();
  if (numbers.isEmpty) return null;
  final to = numbers.join(',');
  final text = Uri.encodeComponent(body);
  return Uri.parse(
      iOS ? 'sms:/open?addresses=$to&body=$text' : 'sms:$to?body=$text');
}

/// A Google Maps pin link for the rider's last fix.
String sosMapLink(double latitude, double longitude) =>
    'https://maps.google.com/?q=${formatCoord(latitude)},${formatCoord(longitude)}';
