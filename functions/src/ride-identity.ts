/**
 * Server-side reconciliation of the denormalized rider identity on shared
 * rides (docs/Issues.md §24.9).
 *
 * `rides/{rideId}` stores `userName`/`userPhotoUrl` alongside `userId` so a
 * feed card can render without an extra profile read per row. `firestore.rules`
 * pins `userId` (create requires it to equal `request.auth.uid`, and update
 * forbids reassigning it), but the two display fields are free-form: a client
 * can post a ride under its own uid while claiming someone else's name and
 * avatar. That is a feed-card impersonation, not an account-level one, but it
 * is still worth closing.
 *
 * A rules-level fix was tried first and rejected: the four call sites that
 * populate these fields don't source them the same way (some read FirebaseAuth's
 * displayName/photoURL, some read the users/{uid} profile doc's separately
 * settable displayName/photoUrl, one passes empty strings), so any rule strict
 * enough to bind would have rejected legitimate shares. Reconciling server-side
 * sidesteps the client-trust problem entirely — the client may write whatever
 * it likes, and this overwrites it from the authoritative profile doc.
 *
 * Trade-off, stated plainly: there is a brief window between the client's write
 * and this trigger firing during which a spoofed name is visible in the feed.
 * Closing that window completely would mean dropping the denormalized fields
 * and joining against users/{uid} at read time.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Firestore handle, resolved lazily rather than at module load.
 *
 * `admin.initializeApp()` lives in crash-notifications.ts, and index.ts's
 * `export *` order decides which module's top level runs first — grabbing
 * `admin.firestore()` at import time here would throw if this module happened
 * to load first. Resolving inside the trigger sidesteps the ordering question
 * entirely, and the guard means it still works if this ever becomes the only
 * module deployed.
 */
function firestore(): admin.firestore.Firestore {
  if (admin.apps.length === 0) admin.initializeApp();
  return admin.firestore();
}

/** What a ride's identity fields should be, per the profile doc. */
interface CanonicalIdentity {
  userName: string;
  userPhotoUrl: string;
}

async function canonicalIdentityFor(
  uid: string
): Promise<CanonicalIdentity | null> {
  const profile = await firestore().collection('users').doc(uid).get();
  if (!profile.exists) return null;

  const data = profile.data() ?? {};
  const displayName = data.displayName;
  const photoUrl = data.photoUrl;

  return {
    userName: typeof displayName === 'string' ? displayName : '',
    userPhotoUrl: typeof photoUrl === 'string' ? photoUrl : '',
  };
}

/**
 * Overwrites `userName`/`userPhotoUrl` on a ride from `users/{userId}`.
 *
 * Runs on create and on update. Writes back ONLY when a field actually
 * differs, which is what keeps this from recursing: the correcting write
 * re-triggers the function, the second pass finds both fields already
 * canonical, and it stops there.
 */
export const reconcileRideIdentity = functions.firestore
  .document('rides/{rideId}')
  .onWrite(async (change, context) => {
    const after = change.after;
    // Deletes have nothing to reconcile.
    if (!after.exists) return;

    const ride = after.data() ?? {};
    const uid = ride.userId;
    if (typeof uid !== 'string' || uid === '') {
      // Shouldn't happen — rules require userId on create — but a malformed
      // doc must not crash the trigger for every other ride.
      functions.logger.warn('ride has no usable userId', {
        rideId: context.params.rideId,
      });
      return;
    }

    const canonical = await canonicalIdentityFor(uid);
    if (canonical === null) {
      // No profile doc yet (a ride shared before the profile is written).
      // Leaving the client-supplied values is the lesser evil versus blanking
      // a legitimate rider's name; the next write reconciles it.
      functions.logger.info('no profile doc for ride author; leaving as-is', {
        rideId: context.params.rideId,
      });
      return;
    }

    const patch: Partial<CanonicalIdentity> = {};
    if (ride.userName !== canonical.userName) {
      patch.userName = canonical.userName;
    }
    if (ride.userPhotoUrl !== canonical.userPhotoUrl) {
      patch.userPhotoUrl = canonical.userPhotoUrl;
    }
    if (Object.keys(patch).length === 0) return;

    // Note for anyone reading the logs later: this fires on every legitimate
    // profile-name change too, not only on spoofing, so it is logged at info
    // and without the old value (which may be attacker-supplied text).
    functions.logger.info('reconciled ride identity from profile', {
      rideId: context.params.rideId,
      fields: Object.keys(patch),
    });

    await after.ref.update(patch);
  });
