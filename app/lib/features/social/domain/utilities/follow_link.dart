/// Follow links: the URL a rider's "My QR code" encodes, and the parser that
/// turns a scanned / opened link back into the uid to follow.
///
/// The canonical form is `https://blankframe.tech/ThrottleIQ/u/<uid>` — the
/// same host and `/ThrottleIQ/` path prefix the install posters already use
/// (`https://blankframe.tech/ThrottleIQ/install`). It is an https link, not a
/// custom scheme, so a phone's system camera opens it even when ThrottleIQ is
/// not installed: App Links / Universal Links hand it to the app when it is,
/// and otherwise the web page at that path (public/follow.html) tries the
/// `throttleiq://u/<uid>` scheme and then falls back to the install page.
///
/// Pure Dart, no Flutter or Firebase, so it is unit-tested directly
/// (test/features/social/domain/follow_link_test.dart).
library;

/// Host the canonical follow link lives on.
const String kFollowLinkHost = 'blankframe.tech';

/// Path prefix (before the uid) of the canonical follow link.
const String kFollowLinkPathPrefix = '/ThrottleIQ/u/';

/// Custom URL scheme the app registers on both platforms. Shared with the
/// home-screen widgets (`throttleiq://startride` etc.); follow links use the
/// `u` host so they never collide with those.
const String kAppScheme = 'throttleiq';

/// Host of the custom-scheme follow link (`throttleiq://u/<uid>`).
const String kSchemeFollowHost = 'u';

/// Hosts whose `/ThrottleIQ/u/<uid>` or `/u/<uid>` paths are follow links.
/// `throttleiqfb.web.app` is the Firebase Hosting site that serves the same
/// fallback page (see firebase.json), so a link to it works as well.
const Set<String> kFollowLinkHosts = {
  'blankframe.tech',
  'www.blankframe.tech',
  'throttleiqfb.web.app',
  'throttleiqfb.firebaseapp.com',
};

/// A Firebase Auth uid: 1–128 characters. Real ones are 28 alphanumerics;
/// `-` and `_` are allowed for custom/emulator uids. Anything else (a slash,
/// a space, a query) is rejected rather than being written as a follow edge
/// id.
final RegExp _uidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Whether [uid] is shaped like a uid a follow link may carry.
bool isValidFollowUid(String uid) => _uidPattern.hasMatch(uid);

/// The canonical https follow link for [uid] — what the QR code encodes.
Uri buildFollowLink(String uid) {
  if (!isValidFollowUid(uid)) {
    throw ArgumentError.value(uid, 'uid', 'not a valid uid');
  }
  return Uri(
    scheme: 'https',
    host: kFollowLinkHost,
    path: '$kFollowLinkPathPrefix$uid',
  );
}

/// The custom-scheme form, `throttleiq://u/<uid>`. Used by the web fallback
/// page to hand off to an installed app; also accepted by [parseFollowLink].
Uri buildFollowSchemeLink(String uid) {
  if (!isValidFollowUid(uid)) {
    throw ArgumentError.value(uid, 'uid', 'not a valid uid');
  }
  return Uri(scheme: kAppScheme, host: kSchemeFollowHost, path: '/$uid');
}

/// The uid a follow link points at, or null if [raw] is not a ThrottleIQ
/// follow link.
///
/// Accepts:
///  - `https://blankframe.tech/ThrottleIQ/u/<uid>` (also `http`, `www.`, and
///    any casing of `ThrottleIQ` / `u` — a hand-typed link shouldn't fail on
///    case, though the uid itself is case-sensitive and kept as-is),
///  - `https://throttleiqfb.web.app/u/<uid>` and `/ThrottleIQ/u/<uid>`,
///  - `throttleiq://u/<uid>`,
/// each with an optional trailing slash, query or fragment.
String? parseFollowLink(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  return parseFollowUri(uri);
}

/// [parseFollowLink] for an already-parsed [Uri] (what app_links delivers).
String? parseFollowUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? candidate;
  if (scheme == kAppScheme) {
    // throttleiq://u/<uid> → host "u", path "/<uid>".
    if (uri.host.toLowerCase() == kSchemeFollowHost && segments.length == 1) {
      candidate = segments.single;
    }
  } else if (scheme == 'https' || scheme == 'http') {
    if (!kFollowLinkHosts.contains(uri.host.toLowerCase())) return null;
    final lower = segments.map((s) => s.toLowerCase()).toList();
    if (segments.length == 3 && lower[0] == 'throttleiq' && lower[1] == 'u') {
      candidate = segments[2];
    } else if (segments.length == 2 && lower[0] == 'u') {
      candidate = segments[1];
    }
  }

  if (candidate == null || !isValidFollowUid(candidate)) return null;
  return candidate;
}
