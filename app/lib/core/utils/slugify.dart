/// Deterministic Firestore-doc-id-safe slug for a bike forum.
///
/// One forum per brand (e.g. `bikeForumSlug('Yamaha')` -> `'yamaha'`), or one
/// per specific brand+model (e.g. `bikeForumSlug('Yamaha', model: 'MT-15')`
/// -> `'yamaha__mt-15'`). Lowercases and collapses whitespace to underscores so
/// the same brand/model text always resolves to the same forum doc id,
/// regardless of how a caller capitalizes or spaces it — this must stay
/// deterministic, since it's used as the Firestore document id and repeated
/// calls (e.g. from every rider who owns the same bike) must land on the same
/// forum rather than creating duplicates.
///
/// Brand and model segments are joined with `__` (double underscore) rather
/// than the single `_` used for internal whitespace within a segment — this
/// keeps the brand/model boundary unambiguous so distinct (brand, model)
/// pairs can never collide on the same slug (e.g. brand='Royal Enfield',
/// model='Classic 350' vs. brand='Royal', model='Enfield Classic 350').
/// `_slugifyPart` collapses repeated underscores and strips leading/trailing
/// ones so a segment with its own underscores can't manufacture a fake `__`
/// boundary.
String bikeForumSlug(String brand, {String? model}) {
  final parts = [
    brand,
    if (model != null && model.trim().isNotEmpty) model,
  ];
  return parts.map(_slugifyPart).join('__');
}

String _slugifyPart(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
