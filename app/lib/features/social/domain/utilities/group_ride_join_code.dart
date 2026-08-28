/// Shareable "join code" for a group ride — the Solo/Group-choice screen's
/// Group side gets a friend-picker (invite by @username); this is the other
/// door in: a short code the creator reads out at a fuel stop so a rider
/// nobody has added yet can join without one first becoming the other's
/// friend. See `GroupRideRepository.createGroupRide`/`joinByCode`.
///
/// Deliberately code-based, not GPS-radius discovery: a "list nearby active
/// rides" feed would need either a new geoquery index plus a Cloud Function
/// (blocked on the Spark billing plan, same constraint noted throughout
/// HANDOFF_Document.md) or a Firestore rule permissive enough to let any
/// signed-in rider enumerate other people's live locations before joining —
/// neither is a small addition on top of the existing rules. A code the
/// creator shares verbally solves the same "we just met at a fuel stop"
/// moment without either cost.
library;

import 'dart:math';

/// Upper-case letters and digits only, with the visually ambiguous ones
/// (0/O, 1/I/L) dropped — a code read aloud over engine noise or typed on a
/// cracked, gloved screen shouldn't hinge on telling those apart.
const _joinCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

const int kJoinCodeLength = 6;

/// Generates a random join code for a new group ride.
///
/// Takes an injectable [Random] so tests can assert exact output; real
/// callers get `Random.secure()` — a join code is a bearer token (see the
/// rules comment on `groupRideJoinCodes`), so it should be exactly as hard to
/// guess as the rest of this app's unguessable-token links.
String generateGroupRideJoinCode([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(
    kJoinCodeLength,
    (_) => _joinCodeAlphabet[rng.nextInt(_joinCodeAlphabet.length)],
  ).join();
}

/// Normalizes a rider-typed join code before lookup: upper-cased and
/// whitespace stripped, since a code read aloud often gets typed back with a
/// stray space or in lower case.
String normalizeGroupRideJoinCode(String input) =>
    input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

/// Whether [input], once normalized, is even shaped like a join code — cheap
/// enough to check before spending a Firestore read on an obviously-wrong
/// value (e.g. an empty field, or a pasted invite link).
bool looksLikeGroupRideJoinCode(String input) {
  final normalized = normalizeGroupRideJoinCode(input);
  if (normalized.length != kJoinCodeLength) return false;
  return normalized.split('').every(_joinCodeAlphabet.contains);
}
