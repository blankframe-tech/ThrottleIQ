import * as functionsV1 from "firebase-functions/v1";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { createHash } from "node:crypto";

/**
 * Cleans up a rider's Firestore profile once their Firebase Auth account is
 * actually gone.
 *
 * issues §62 (follow-up audit): `AuthNotifier.deleteAccount()` used
 * to delete the Firestore profile + username claim from the CLIENT, then
 * wipe every local SQLite record, and only THEN attempt `user.delete()` —
 * the one step most likely to fail (`FirebaseAuthException` with
 * `'requires-recent-login'`, which fires whenever the session is more than
 * ~5 minutes old, describing almost any real "open Settings and delete my
 * account" flow). That failure was silently swallowed by `AsyncValue.guard`
 * (it stores the error in `state` but doesn't rethrow), so the app already
 * destroyed the Firestore profile and all local ride/bike/maintenance
 * history, then reported success and navigated to the login screen, while
 * the Auth account — now with no error surfaced — was left intact and able
 * to sign back in to what looks like a normal, empty account.
 *
 * The client fix (auth_provider.dart) now deletes the Auth account FIRST —
 * if that fails, nothing else has been touched — and only wipes local data
 * once it succeeds. But once `user.delete()` succeeds the client is no
 * longer authenticated as that uid, and firestore.rules requires exactly
 * that to delete `users/{uid}`/`usernames/{handle}` — so the client
 * structurally cannot reliably clean those up itself anymore. This trigger
 * takes over that job server-side, with Admin SDK privileges (which bypass
 * firestore.rules entirely), running exactly when — and only when — the
 * Auth account is actually deleted, regardless of what the client's own
 * connectivity/timing looked like.
 *
 * Uses the v1 `functions.auth.user().onDelete()` trigger rather than a v2
 * blocking `identity` function deliberately: it needs no Identity Platform
 * upgrade (a project-level change this pass has no way to make or verify),
 * and "clean up after the fact" is exactly this trigger's designed purpose.
 *
 * Community content the rider authored inside other people's spaces — forum
 * posts and replies, place reviews, places they contributed, comments on other
 * riders' rides — is ANONYMIZED rather than deleted (product decision,
 * 2026-09-20, issues §83.15): the identifying fields are cleared and the body
 * is kept, so a forum thread other riders are mid-conversation in doesn't grow
 * holes and a POI nobody else can re-add doesn't vanish from the directory.
 * That erases the personal data while leaving the community artefact, which is
 * the same trade Reddit and Discourse make.
 *
 * Still NOT covered, and still needing a decision: chat messages the rider
 * sent (a 1:1 DM is arguably the other participant's record too) and
 * group-ride membership rows.
 *
 * NOT yet deployed by this pass — requires `firebase deploy --only
 * functions` before it actually runs. Until deployed, a successful account
 * deletion leaves the Firestore profile/username claim orphaned (a lesser,
 * non-destructive regression versus the CRITICAL bug this fixes — the
 * rider's own data is gone either way once they've confirmed deletion, and
 * an orphaned profile doc is a cleanup gap, not a false "your data is
 * gone" that turned out to be true only for the parts that didn't need to
 * be).
 */
/** Byline shown where a deleted rider's authored content is kept. */
const DELETED_RIDER = "Deleted rider";

/** Firestore caps a write batch at 500 operations. */
const ANONYMIZE_BATCH = 400;

export const onUserAccountDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const db = getFirestore();

  const profileSnap = await db.collection("users").doc(uid).get();
  const username = profileSnap.exists
    ? (profileSnap.data()?.username as string | undefined)
    : undefined;

  if (username) {
    try {
      await db.collection("usernames").doc(username.toLowerCase()).delete();
    } catch (e) {
      logger.warn(`onUserAccountDeleted: failed to release username for ${uid}`, e);
    }
  }

  try {
    await db.collection("livePointers").doc(uid).delete();
  } catch (e) {
    logger.warn(`onUserAccountDeleted: failed to delete livePointers for ${uid}`, e);
  }

  // Everything else the rider owns. Each step is isolated so one failure
  // doesn't strand the rest; all of them are idempotent, so a retry is safe.
  //
  // `recursiveDelete` rather than `.delete()`: deleting a Firestore document
  // does NOT delete its subcollections. A plain `users/{uid}.delete()` left
  // the rider's cloud ride history, GPS tracks, bikes, maintenance logs,
  // emergency contacts (third-party PII), badges, notifications and blocks
  // all in place, orphaned under a parent that no longer exists.
  const ownedQueries: Array<[string, FirebaseFirestore.Query]> = [
    // Shared rides on the social feed, with their likes/votes/comments.
    ["rides", db.collection("rides").where("userId", "==", uid)],
    ["liveSessions", db.collection("liveSessions").where("uid", "==", uid)],
    ["crashNotifications", db.collection("crashNotifications").where("uid", "==", uid)],
    // Follow edges in both directions, so counts elsewhere stop including
    // a rider who no longer exists.
    ["follows (out)", db.collection("follows").where("followerUid", "==", uid)],
    ["follows (in)", db.collection("follows").where("followeeUid", "==", uid)],
  ];

  for (const [label, query] of ownedQueries) {
    try {
      const snap = await query.get();
      for (const doc of snap.docs) {
        await db.recursiveDelete(doc.ref);
      }
    } catch (e) {
      logger.error(`onUserAccountDeleted: failed to delete ${label} for ${uid}`, e);
    }
  }

  // Content in other people's spaces: strip the identity, keep the artefact.
  // Each entry is [label, query, fields to blank]. `userName` becomes a
  // tombstone rather than an empty string so a rendered post reads "Deleted
  // rider" instead of an empty byline.
  //
  // INDEXES: the three `collectionGroup` queries below filter on a single
  // equality field, which Firestore's automatic single-field indexes cover at
  // collection-group scope — no entry in firestore.indexes.json is needed.
  // Confirm that against the console the first time this is deployed; a
  // missing index surfaces as FAILED_PRECONDITION with a create-index link,
  // and the per-query try/catch below means one such failure degrades this to
  // "that content stayed identified" rather than aborting the whole deletion.
  const anonymizeQueries: Array<
    [string, FirebaseFirestore.Query, Record<string, unknown>]
  > = [
    [
      "forum posts",
      db.collectionGroup("posts").where("userId", "==", uid),
      { userId: "", userName: DELETED_RIDER, userPhotoUrl: "" },
    ],
    [
      "forum replies",
      db.collectionGroup("replies").where("userId", "==", uid),
      { userId: "", userName: DELETED_RIDER, userPhotoUrl: "" },
    ],
    [
      "ride comments",
      db.collectionGroup("comments").where("userId", "==", uid),
      { userId: "", userName: DELETED_RIDER, userPhotoUrl: "" },
    ],
    [
      "place reviews",
      db.collection("reviews").where("userId", "==", uid),
      { userId: "" },
    ],
    [
      "places contributed",
      db.collection("places").where("createdBy", "==", uid),
      { createdBy: "" },
    ],
  ];

  for (const [label, query, patch] of anonymizeQueries) {
    try {
      const snap = await query.get();
      // Chunked into batches — a prolific rider can have more authored docs
      // than the 500-write batch limit.
      for (let i = 0; i < snap.docs.length; i += ANONYMIZE_BATCH) {
        const batch = db.batch();
        for (const doc of snap.docs.slice(i, i + ANONYMIZE_BATCH)) {
          batch.update(doc.ref, patch);
        }
        await batch.commit();
      }
      if (snap.size > 0) {
        logger.info(
          `onUserAccountDeleted: anonymized ${snap.size} ${label} for ${uid}`
        );
      }
    } catch (e) {
      logger.error(
        `onUserAccountDeleted: failed to anonymize ${label} for ${uid}`,
        e
      );
    }
  }

  // Cloudinary media. MUST run before the profile is recursively deleted —
  // the ledger it reads lives at users/{uid}/cloudinaryAssets.
  await destroyCloudinaryAssets(uid, db);

  try {
    await db.recursiveDelete(db.collection("users").doc(uid));
  } catch (e) {
    logger.error(`onUserAccountDeleted: failed to delete profile for ${uid}`, e);
  }
});

/**
 * Deletes every Cloudinary asset the rider uploaded, from the ledger that
 * `CloudinaryUploadService` writes on each upload (issues §83.15).
 *
 * The app uploads through an *unsigned* preset, which by design cannot
 * authorise a destroy — so this has to be done server-side with the account's
 * API key/secret. Those are read from the environment and are NOT in the repo:
 *
 *   firebase functions:secrets:set CLOUDINARY_API_SECRET
 *   firebase functions:config:set cloudinary.key=... cloudinary.cloud=...
 *
 * With no secret configured this logs and returns, leaving the ledger intact
 * so the sweep can be re-run retroactively once credentials exist. That is a
 * known, recorded gap — not silent success.
 */
async function destroyCloudinaryAssets(
  uid: string,
  db: FirebaseFirestore.Firestore
): Promise<void> {
  const cloud = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;

  let ledger: FirebaseFirestore.QuerySnapshot;
  try {
    ledger = await db
      .collection("users")
      .doc(uid)
      .collection("cloudinaryAssets")
      .get();
  } catch (e) {
    logger.error(`destroyCloudinaryAssets: cannot read ledger for ${uid}`, e);
    return;
  }

  if (ledger.empty) return;

  if (!cloud || !apiKey || !apiSecret) {
    logger.warn(
      `destroyCloudinaryAssets: ${ledger.size} asset(s) for ${uid} were NOT ` +
        "deleted — Cloudinary credentials are not configured. The rider's " +
        "media is still publicly reachable. See issues §83.15."
    );
    return;
  }

  for (const doc of ledger.docs) {
    const publicId = doc.get("publicId") as string | undefined;
    const resourceType = (doc.get("resourceType") as string) || "image";
    if (!publicId) continue;
    try {
      await cloudinaryDestroy({
        cloud,
        apiKey,
        apiSecret,
        publicId,
        resourceType,
      });
    } catch (e) {
      // Logged with the public_id only — that is not PII, and it is what a
      // manual retry needs.
      logger.error(
        `destroyCloudinaryAssets: failed to destroy ${resourceType}/${publicId}`,
        e
      );
    }
  }
}

/** One signed Cloudinary `destroy` call. No SDK — Node 22 has global fetch. */
async function cloudinaryDestroy(opts: {
  cloud: string;
  apiKey: string;
  apiSecret: string;
  publicId: string;
  resourceType: string;
}): Promise<void> {
  const timestamp = Math.floor(Date.now() / 1000);
  // Cloudinary signs the sorted, &-joined params with the secret appended.
  const signature = createHash("sha1")
    .update(`public_id=${opts.publicId}&timestamp=${timestamp}${opts.apiSecret}`)
    .digest("hex");

  const body = new URLSearchParams({
    public_id: opts.publicId,
    timestamp: String(timestamp),
    api_key: opts.apiKey,
    signature,
  });

  const res = await fetch(
    `https://api.cloudinary.com/v1_1/${opts.cloud}/${opts.resourceType}/destroy`,
    { method: "POST", body }
  );
  if (!res.ok) {
    throw new Error(`Cloudinary destroy returned ${res.status}`);
  }
  const json = (await res.json()) as { result?: string };
  // "not found" is success for our purposes — the asset is gone either way.
  if (json.result !== "ok" && json.result !== "not found") {
    throw new Error(`Cloudinary destroy result: ${json.result}`);
  }
}
