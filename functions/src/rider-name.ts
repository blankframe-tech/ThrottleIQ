/**
 * Mirror of `UserProfileEntity.bestName` in the app
 * (app/lib/features/profile/domain/entities/user_profile_entity.dart):
 * nickname → displayName → @username → "Rider". Keep the two in lockstep.
 *
 * Pure (no firebase import) so `npm test` can cover it.
 */
export function bestName(profile: Record<string, unknown>): string {
  const nickname = profile.nickname;
  if (typeof nickname === "string" && nickname.trim().length > 0) {
    return nickname.trim();
  }
  const displayName = profile.displayName;
  if (typeof displayName === "string" && displayName.trim().length > 0) {
    return displayName.trim();
  }
  const username = profile.username;
  if (typeof username === "string" && username.length > 0) {
    return `@${username}`;
  }
  return "Rider";
}
