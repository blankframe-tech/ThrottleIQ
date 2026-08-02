/// Who may change a saved route.
///
/// Route documents live at `users/{ownerUid}/routes/{routeId}`, and
/// firestore.rules allow *reads* of a public route to any signed-in rider but
/// *writes* only to the owner. The Discover tab can therefore open somebody
/// else's route read-only, and the detail screen has to hide the controls that
/// would be refused by the rules the moment they were tapped (the public/
/// private toggle, Delete) rather than offering them and failing.
///
/// Kept as plain Dart — no Flutter, no Firestore — so the one rule that
/// decides this is unit-testable and lives in exactly one place.
library;

/// Whether [viewerUid] may edit or delete the route owned by [ownerUid].
///
/// Deliberately total, and false for every uncertain case: a signed-out
/// viewer (`viewerUid == null`), a route whose owner is unknown
/// (`ownerUid == null`, e.g. a document written before `userId` was stored),
/// and empty strings all read as "not the owner". Guessing the other way
/// would put a delete button in front of a rider who cannot use it.
bool canEditRoute({required String? viewerUid, required String? ownerUid}) {
  if (viewerUid == null || viewerUid.isEmpty) return false;
  if (ownerUid == null || ownerUid.isEmpty) return false;
  return viewerUid == ownerUid;
}
