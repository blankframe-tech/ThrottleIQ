/// Client mirror of `photoUrlAllowed()` in firestore.rules (issues §33.4,
/// §90.D10): the only hosts a denormalized avatar URL may point at, because
/// every viewer's device fetches it automatically. Keep the two in lockstep —
/// a URL this accepts but the rules refuse makes the whole write fail.
final RegExp _allowedPhotoUrl = RegExp(
    r'^https://(res\.cloudinary\.com/vjvcigkt/|lh[3-6]\.googleusercontent\.com/)');

/// Whether [url] is empty/null or on an allow-listed avatar host.
bool isAllowedPhotoUrl(String? url) =>
    url == null ||
    url.isEmpty ||
    (url.length <= 1000 && _allowedPhotoUrl.hasMatch(url));

/// [url] if the rules would accept it, otherwise `''` — so an avatar from an
/// unexpected host degrades to the initials fallback instead of failing the
/// write it rides along with.
String safePhotoUrl(String? url) => isAllowedPhotoUrl(url) ? (url ?? '') : '';
