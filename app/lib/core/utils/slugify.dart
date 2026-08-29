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
    if (model != null && model.trim().isNotEmpty) normalizeModelFamily(brand, model),
  ];
  return parts.map(_slugifyPart).join('__');
}

/// Collapses a bike model name to its forum "family" name where multiple
/// generations of one popular model would otherwise fragment the community
/// across a near-empty forum per version.
///
/// Currently only Yamaha's FZ-S/FZS commuter naked bike, which ships in the
/// Bangladesh market across v1 through v4 plus "Fi" trims all under one
/// popular name — `FZS v2`, `FZ-S V3`, `FZS-Fi V3`, etc. all resolve to the
/// single `Yamaha FZS` forum rather than one each. Hard-coded to this one
/// model on purpose: it's a one-off convergence rule, not a general
/// versioning scheme every brand/model needs.
String normalizeModelFamily(String brand, String model) {
  if (brand.trim().toLowerCase() == 'yamaha' &&
      RegExp(r'^fz-?s', caseSensitive: false).hasMatch(model.trim())) {
    return 'FZS';
  }
  return model;
}

String _slugifyPart(String value) {
  return value
      .trim()
      .toLowerCase()
      // Whitespace, `-`, and `_` are all "word separators" here — collapse
      // any run of them to one `_` *before* stripping invalid chars, so
      // 'mt-15', 'MT 15', and 'MT_15' all converge on the same slug instead
      // of hyphen-vs-space producing two different forum ids for the same
      // bike.
      .replaceAll(RegExp(r'[\s_-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Deterministic slug for a general (non-bike) topic forum, e.g.
/// `generalForumSlug('Two-Strokes')` -> `'two_strokes'`. Single-segment —
/// no brand/model boundary to protect, so it reuses [_slugifyPart] directly.
String generalForumSlug(String topic) => _slugifyPart(topic);
