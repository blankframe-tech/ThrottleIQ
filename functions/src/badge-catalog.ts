/**
 * The milestone badge ids the app awards, mirrored from
 * `badgeFamilies` in app/lib/core/utils/badges.dart.
 *
 * `users/{uid}/earnedBadges/{badgeId}` is owner-writable (firestore.rules),
 * so its doc ids are client-chosen. Counting only ids on this list keeps a
 * client from bloating `stats/badges` with arbitrary keys (a Firestore doc
 * caps at 1 MiB) and keeps challenge badges, which share the collection, out
 * of the milestone rarity figures.
 *
 * Keep in lockstep with badges.dart. The app's
 * test/features/stats/badge_catalog_parity_test.dart reads this file and
 * fails if a rung is missing here.
 *
 * Pure (no firebase import) so `npm test` can cover it.
 */
export const MILESTONE_BADGE_IDS: readonly string[] = [
  'first_ride',
  'rides_10',
  'rides_25',
  'rides_50',
  'rides_100',
  'rides_250',
  'km_100',
  'km_500',
  'km_1000',
  'km_2500',
  'km_5000',
  'long_ride_50',
  'long_ride_100',
  'long_ride_200',
  'long_ride_400',
  'long_ride_800',
  'saddle_1h',
  'saddle_2h',
  'saddle_4h',
  'saddle_8h',
  'ton_up',
  'speed_140',
  'speed_demon',
  'night_1',
  'night_5',
  'night_25',
  'night_50',
  'early_1',
  'early_5',
  'early_25',
  'streak_3',
  'streak_7',
  'streak_14',
  'streak_30',
  'smooth_80',
  'smooth_operator',
  'smooth_95',
  'smooth_98',
];

const MILESTONE_SET = new Set(MILESTONE_BADGE_IDS);

/** Whether a badge id counts toward the rarity figures. */
export function isCountedBadgeId(badgeId: unknown): badgeId is string {
  return typeof badgeId === 'string' && MILESTONE_SET.has(badgeId);
}

/**
 * Owner count per milestone badge, from the doc ids of every
 * `earnedBadges` doc. Unknown ids are ignored; every known id is present
 * (zero when nobody owns it), so a full recompute also clears stale keys.
 *
 * Doc ids, not the `badgeId` field: the path is what makes one rider own a
 * badge at most once, and it is what the incremental trigger keys on too.
 */
export function tallyBadgeOwners(
  badgeIds: Iterable<string>
): Record<string, number> {
  const owners: Record<string, number> = {};
  for (const id of MILESTONE_BADGE_IDS) owners[id] = 0;
  for (const id of badgeIds) {
    if (isCountedBadgeId(id)) owners[id] += 1;
  }
  return owners;
}
