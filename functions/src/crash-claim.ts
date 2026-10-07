/**
 * Pure claim rules for the crash-alert pipeline (issues §101.S5). No Firebase
 * imports, so test/pure.test.js can cover them without an emulator.
 *
 * Eventarc delivers Firestore events at least once, and two Cloud Scheduler
 * runs can overlap. Each handler therefore claims a document in a transaction
 * before it sends anything, by moving it to an in-flight status with a
 * timestamp. A claim older than [CLAIM_LEASE_MS] is treated as abandoned (the
 * instance that held it crashed or timed out) and may be taken again: for an
 * emergency alert, at-least-once beats at-most-once, so a crash after the
 * claim must not silently drop the alert forever.
 */

/** How long an in-flight claim is honoured before it counts as abandoned. */
export const CLAIM_LEASE_MS = 5 * 60 * 1000;

function leaseExpired(claimedAtIso: unknown, nowMs: number): boolean {
  // A claim with no readable timestamp can never expire on its own, so it is
  // treated as already expired rather than as held forever.
  if (typeof claimedAtIso !== "string") return true;
  const claimedAt = Date.parse(claimedAtIso);
  if (Number.isNaN(claimedAt)) return true;
  return nowMs - claimedAt >= CLAIM_LEASE_MS;
}

/**
 * Whether `onCrashNotification` may claim a crash notification: a fresh
 * `pending` one, or one stuck in `processing` past its lease. Every other
 * status (`contacted`, `mock_not_sent`, `no_contacts`, ...) has already been
 * handled.
 */
export function shouldClaim(
  status: unknown,
  claimedAtIso: unknown,
  nowMs: number
): boolean {
  if (status === "pending") return true;
  if (status === "processing") return leaseExpired(claimedAtIso, nowMs);
  return false;
}

/**
 * Whether `escalateCrashAlert` may claim a notification for escalation: a
 * `contacted` one, or one stuck in `escalating` past its lease.
 */
export function shouldClaimEscalation(
  status: unknown,
  escalatingAtIso: unknown,
  nowMs: number
): boolean {
  if (status === "contacted") return true;
  if (status === "escalating") return leaseExpired(escalatingAtIso, nowMs);
  return false;
}
