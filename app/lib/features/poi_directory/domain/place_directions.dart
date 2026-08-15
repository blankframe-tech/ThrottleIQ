/// Builds the map-app URLs behind a place's "Directions" button.
///
/// **Why ThrottleIQ hands this off instead of navigating itself.** The
/// in-app turn-by-turn (`routes/domain/turn_instruction.dart`) reads turns
/// *geometrically* off a polyline the rider has already ridden. That works
/// because the recorded GPS trail already describes the road. Riding to a
/// petrol pump the rider has never been to is the opposite problem: there is
/// no trail, so it needs a routing engine — road graph, one-ways, live
/// traffic, and rerouting when a turn is missed. Google Maps already does all
/// of that, offline-capable, for free, and it is what a rider in Dhaka
/// already has open on the handlebar mount. Reimplementing it against a
/// routing API would cost a key, a bill, a Data Safety disclosure, and would
/// still be worse.
///
/// Everything here is pure string-building so it can be unit-tested without
/// platform channels — the launch itself is one call in the widget.
library;

/// Coordinates formatted the way every maps URL scheme expects: plain decimal
/// degrees, no locale grouping, enough precision to identify a forecourt
/// (~1 cm at 7dp, far past GPS accuracy — the extra digits cost nothing and
/// avoid rounding a pump onto the wrong side of a divided road).
String formatCoord(double value) => value.toStringAsFixed(7);

/// Universal Google Maps directions link.
///
/// Uses the documented cross-platform `google.com/maps/dir/?api=1` form rather
/// than the legacy `comgooglemaps://` scheme, because this one resolves
/// correctly in all three cases that matter: the Google Maps app if installed
/// (both platforms deep-link it), the browser if not, and Apple's app on iOS
/// via the user's own default-app setting. `travelmode=driving` is the closest
/// mode to a motorcycle that the API offers — there is no motorcycle mode in
/// the URL API, and driving gives the road-legal route a bike wants, unlike
/// walking or cycling which will happily send a rider down a footpath.
///
/// [label] is deliberately NOT put in the URL: the `dir/?api=1` form treats a
/// text destination as a *search query*, so passing "Shell Petrol Pump" could
/// resolve to a different branch than the one the rider tapped. Coordinates
/// are unambiguous, which matters more than a pretty pin label.
Uri googleMapsDirectionsUri({
  required double latitude,
  required double longitude,
}) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${formatCoord(latitude)},${formatCoord(longitude)}',
    'travelmode': 'driving',
  });
}

/// Apple Maps directions link, used as the iOS fallback when the Google Maps
/// URL can't be opened at all.
///
/// `dirflg=d` is driving. `q` here is only the pin's caption — unlike the
/// Google form above, Apple's `ll` parameter is what actually fixes the
/// destination, so a label is safe to include and makes the pin readable.
Uri appleMapsDirectionsUri({
  required double latitude,
  required double longitude,
  String? label,
}) {
  return Uri.https('maps.apple.com', '/', {
    'daddr': '${formatCoord(latitude)},${formatCoord(longitude)}',
    'll': '${formatCoord(latitude)},${formatCoord(longitude)}',
    'dirflg': 'd',
    if (label != null && label.trim().isNotEmpty) 'q': label.trim(),
  });
}

/// A `tel:` URI for a place's phone number.
///
/// Strips spaces, dashes and parentheses — Bangladeshi numbers are commonly
/// written `+880 1X-XXXX-XXXX` in the places directory, and the dialler wants
/// them unpunctuated. A leading `+` is kept (it's what makes an international
/// number dial correctly); any other non-digit is dropped. Returns null when
/// nothing dialable is left, so the caller can hide the button rather than
/// offering one that opens an empty dialler.
Uri? telUri(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return Uri(scheme: 'tel', path: hasPlus ? '+$digits' : digits);
}
