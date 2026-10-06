/**
 * Pure helpers for the account-deletion Cloudinary sweep. Kept free of any
 * firebase import so `npm test` can exercise them without credentials.
 */

/** Cloudinary folder kinds look like `avatars`, `rideShares`, `voiceNotes`. */
const KIND = /^[A-Za-z_]+$/;

/**
 * Whether `publicId` names an asset in one of `uid`'s own upload folders —
 * `<kind>/<uid>/<rest>`, the convention every CloudinaryUploadService caller
 * follows (avatars/, bikes/, rideShares/, places/, voiceNotes/).
 *
 * issues §90.D2: the deletion sweep used to destroy every `publicId` in the
 * deleted rider's ledger. Public IDs are visible in every media URL, so a
 * rider could list a victim's avatar in their own ledger, delete their
 * account, and have the sweep destroy the victim's media. firestore.rules now
 * refuses such ledger rows; this is the server-side half, and it also covers
 * any row written before that rule existed.
 *
 * Deliberately stricter than the rule (no empty segments, no `..` anywhere):
 * a false negative only leaves one asset behind and is logged, a false
 * positive destroys someone else's media.
 */
export function isOwnedPublicId(publicId: unknown, uid: string): boolean {
  if (typeof publicId !== "string" || publicId.length === 0 || publicId.length > 512) {
    return false;
  }
  if (typeof uid !== "string" || !/^[A-Za-z0-9_-]+$/.test(uid)) return false;
  if (publicId.includes("..")) return false;
  const parts = publicId.split("/");
  return (
    parts.length >= 3 &&
    KIND.test(parts[0]) &&
    parts[1] === uid &&
    parts.slice(2).every((p) => p.length > 0)
  );
}
