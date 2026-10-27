import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { getDatabase, type Database } from "firebase-admin/database";
import * as logger from "firebase-functions/logger";
import { createHash } from "node:crypto";
import { isOwnedPublicId } from "./cloudinary-ownership";
import { anonymizedReportPatch, isPendingReport } from "./report-retention";

/**
 * The body of `onUserAccountDeleted` (account-deletion.ts), split out so the
 * emulator suite (test/emulator/) can run it against a real Firestore + RTDB
 * without going through the Auth trigger. Not re-exported from index.ts: it
 * is a plain function, not a Cloud Function.
 */

/** Byline shown where a deleted rider's authored content is kept. */
export const DELETED_RIDER = "Deleted rider";

/**
 * Stands in for a deleted rider's uid in a chat they were in (participants,
 * lastMessage.senderId, their messages' senderId). The app shows it as
 * "Deleted rider" (kDeletedChatParticipant in chat_entity.dart). Never a real
 * uid: Firebase uids have no '-'.
 */
export const DELETED_PARTICIPANT = "deleted-rider";

/** Firestore caps a write batch at 500 operations. */
const ANONYMIZE_BATCH = 400;

/** Two writes per forum follow (delete + followerCount decrement). */
const FORUM_FOLLOW_BATCH = 200;

/** Where the per-deletion completion marker is written (issues §101.S4). */
export const ACCOUNT_DELETIONS = "accountDeletions";

export interface CloudinaryCredentials {
  cloud: string;
  apiKey: string;
  apiSecret: string;
}

export interface ErasureOptions {
  /**
   * The Realtime Database to clean up. `undefined` (the default) resolves the
   * project's default instance; `null` skips RTDB entirely.
   */
  rtdb?: Database | null;
  /**
   * Cloudinary Admin API credentials (account-deletion.ts reads them from
   * functions secrets). Missing or empty skips the media sweep.
   */
  cloudinary?: CloudinaryCredentials;
}

export interface ErasureResult {
  /** Labels of the steps that threw. Empty means a complete erasure. */
  failedSteps: string[];
  /** True when no RTDB instance could be resolved, so RTDB was not touched. */
  rtdbSkipped: boolean;
}

/**
 * Erases (or anonymizes) everything the rider `uid` left behind, then
 * records the outcome at `accountDeletions/{uid}`.
 *
 * Each step is isolated so one failure doesn't strand the rest, and every
 * step is idempotent, so a re-run is safe. A failed step is no longer just a
 * log line: its label lands in the marker's `failedSteps`, and `ok` is false,
 * so a re-run or an audit can tell a complete erasure from a partial one
 * (issues §101.S4). firestore.rules' catch-all denies clients that
 * collection; only the Admin SDK writes it.
 */
export async function deleteUserData(
  db: FirebaseFirestore.Firestore,
  uid: string,
  opts: ErasureOptions = {}
): Promise<ErasureResult> {
  const failedSteps: string[] = [];

  async function step<T>(label: string, fn: () => Promise<T>): Promise<T | undefined> {
    try {
      return await fn();
    } catch (e) {
      failedSteps.push(label);
      logger.error(`onUserAccountDeleted: step "${label}" failed for ${uid}`, e);
      return undefined;
    }
  }

  // By the claim's own uid, not the profile's `username`: a re-run after the
  // profile was deleted (or a stale handle on it) must still release it.
  await step("release username", async () => {
    const claims = await db.collection("usernames").where("uid", "==", uid).get();
    await Promise.all(claims.docs.map((doc) => doc.ref.delete()));
  });

  // ---- Gather what the RTDB cleanup needs, BEFORE the Firestore docs that
  // name it are deleted below. RTDB has no index on `uid` (and adding one is
  // a rules change), so the paths are derived from Firestore instead.

  // Live-share tokens: the doc ids of liveSessions, plus the ones the
  // pointers (livePointers, handleLinks) name. All are deleted further down.
  const tokens = new Set<string>();
  const handleLinks: FirebaseFirestore.DocumentReference[] = [];
  await step("read live share tokens", async () => {
    const [sessions, pointer, links] = await Promise.all([
      db.collection("liveSessions").where("uid", "==", uid).get(),
      db.collection("livePointers").doc(uid).get(),
      db.collection("handleLinks").where("uid", "==", uid).get(),
    ]);
    for (const doc of sessions.docs) tokens.add(doc.id);
    for (const doc of [pointer, ...links.docs]) {
      const pointed = doc.get("token");
      if (typeof pointed === "string" && pointed.length > 0) tokens.add(pointed);
    }
    for (const doc of links.docs) handleLinks.push(doc.ref);
  });

  // Every group ride the rider created, joined, or was invited to.
  const rides = new Map<string, FirebaseFirestore.DocumentData>();
  await step("read group rides", async () => {
    const rideCol = db.collection("groupRides");
    const snaps = await Promise.all([
      rideCol.where("memberIds", "array-contains", uid).get(),
      rideCol.where("invitedIds", "array-contains", uid).get(),
      rideCol.where("creatorId", "==", uid).get(),
    ]);
    for (const snap of snaps) {
      for (const doc of snap.docs) rides.set(doc.id, doc.data());
    }
  });

  const chatIds: string[] = [];
  await step("read chats", async () => {
    const snap = await db
      .collection("chats")
      .where("participants", "array-contains", uid)
      .get();
    for (const doc of snap.docs) chatIds.push(doc.id);
  });

  await step("delete livePointers", () =>
    db.collection("livePointers").doc(uid).delete()
  );
  // The password link holds the rider's last known location.
  await step("delete handleLinks", () =>
    Promise.all(handleLinks.map((ref) => ref.delete()))
  );

  // ---- Realtime Database (issues §101.S4): the 1 Hz live-share channel, the
  // rider's last group-ride position, and their typing flags.
  let rtdb: Database | null = null;
  if (opts.rtdb !== undefined) {
    rtdb = opts.rtdb;
  } else {
    try {
      // A project without a default RTDB instance (no databaseURL in
      // FIREBASE_CONFIG) throws here, and must still get the Firestore half
      // of the erasure.
      rtdb = getDatabase();
    } catch (e) {
      logger.warn(
        `onUserAccountDeleted: no Realtime Database instance; RTDB data for ${uid} was not touched`,
        e
      );
    }
  }
  const rtdbSkipped = rtdb === null;

  if (rtdb) {
    const db2 = rtdb;
    if (tokens.size > 0) {
      await step("rtdb live_shares", () =>
        rtdbRemove(db2,
          Object.fromEntries([...tokens].map((t) => [`live_shares/${t}`, null]))
        )
      );
    }
    if (rides.size > 0) {
      await step("rtdb group_rides", () =>
        rtdbRemove(db2,
          Object.fromEntries(
            [...rides].map(([rideId, data]) =>
              // A ride the rider created is ended below, which is what the
              // client's endGroupRide does too: the whole movement channel
              // goes with it. On anyone else's ride only their own row goes.
              data.creatorId === uid
                ? [`group_rides/${rideId}`, null]
                : [`group_rides/${rideId}/locations/${uid}`, null]
            )
          )
        )
      );
    }
    if (chatIds.length > 0) {
      await step("rtdb chat_presence", () =>
        rtdbRemove(db2,
          Object.fromEntries(chatIds.map((c) => [`chat_presence/${c}/${uid}`, null]))
        )
      );
    }
  }

  // ---- Group rides (issues §101.S4). Mirrors the client's leaveGroupRide /
  // endGroupRide server-side. A ride with other riders in it is ENDED, never
  // deleted: deleting a ride other people are part of is a product decision.
  for (const [rideId, data] of rides) {
    const rideRef = db.collection("groupRides").doc(rideId);
    const creator = data.creatorId === uid;
    await step(creator ? `groupRides/${rideId} (creator)` : `groupRides/${rideId}`, () =>
      db.runTransaction(async (txn) => {
        const snap = await txn.get(rideRef);
        if (!snap.exists) return;
        // A ride created before the roster moved to its own subcollection
        // carries an inline `members` array with the rider's name and photo.
        const legacy = snap.get("members");
        txn.update(rideRef, {
          ...(creator
            ? {
                // The ride stays (and keeps creatorId, how a retry finds
                // it); the creator's byline goes.
                creatorName: DELETED_RIDER,
                // Same fields as the client's _endedFields().
                ...(snap.get("status") !== "completed"
                  ? { status: "completed", endedAt: FieldValue.serverTimestamp() }
                  : {}),
              }
            : {
                memberIds: FieldValue.arrayRemove(uid),
                invitedIds: FieldValue.arrayRemove(uid),
              }),
          ...(Array.isArray(legacy)
            ? {
                members: legacy.filter(
                  (m) => !(m && typeof m === "object" && m.userId === uid)
                ),
              }
            : {}),
        });
        txn.delete(rideRef.collection("members").doc(uid));
        txn.delete(rideRef.collection("memberLocations").doc(uid));
        txn.delete(rideRef.collection("invitations").doc(uid));
      })
    );
  }

  // ---- Forum follows (issues §101.S4): interest data, and each one is a +1
  // on forums/{forumId}.followerCount that has to come off again.
  await step("forum_follows", async () => {
    const snap = await db.collection("forum_follows").where("userId", "==", uid).get();
    for (let i = 0; i < snap.docs.length; i += FORUM_FOLLOW_BATCH) {
      const chunk = snap.docs.slice(i, i + FORUM_FOLLOW_BATCH);
      const forumIds = chunk.map((doc) => forumIdOf(doc, uid));
      const forumRefs = forumIds
        .filter((id): id is string => id !== null)
        .map((id) => db.collection("forums").doc(id));
      // A forum deleted since the follow must not fail the batch (update on
      // a missing doc does), nor be recreated as an empty ghost (set merge).
      const forums = forumRefs.length > 0 ? await db.getAll(...forumRefs) : [];
      const existing = new Set(forums.filter((f) => f.exists).map((f) => f.id));
      const batch = db.batch();
      chunk.forEach((doc, j) => {
        batch.delete(doc.ref);
        const forumId = forumIds[j];
        if (forumId !== null && existing.has(forumId)) {
          batch.update(db.collection("forums").doc(forumId), {
            followerCount: FieldValue.increment(-1),
          });
        }
      });
      await batch.commit();
    }
  });

  // Everything else the rider owns.
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
    // Opt-in research copies of answered impacts (shadow-mode crash
    // detection). Their private originals go with users/{uid} below.
    ["crashEvents", db.collection("crashEvents").where("ownerUid", "==", uid)],
    // Follow edges in both directions, so counts elsewhere stop including
    // a rider who no longer exists.
    ["follows (out)", db.collection("follows").where("followerUid", "==", uid)],
    ["follows (in)", db.collection("follows").where("followeeUid", "==", uid)],
    // Find-by-email lookup (B2): emailLookup/{sha256(email)} -> {uid}.
    ["emailLookup", db.collection("emailLookup").where("uid", "==", uid)],
  ];

  for (const [label, query] of ownedQueries) {
    await step(`delete ${label}`, async () => {
      const snap = await query.get();
      for (const doc of snap.docs) {
        await db.recursiveDelete(doc.ref);
      }
    });
  }

  // Notifications the rider sent into other riders' inboxes (follow, ride
  // invite, joined...): each carries fromName/fromPhotoUrl. Needs the
  // `notifications.fromUid` COLLECTION_GROUP index (see INDEXES below).
  await step("delete sent notifications", async () => {
    const snap = await db.collectionGroup("notifications").where("fromUid", "==", uid).get();
    for (let i = 0; i < snap.docs.length; i += ANONYMIZE_BATCH) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + ANONYMIZE_BATCH)) batch.delete(doc.ref);
      await batch.commit();
    }
  });

  // Votes on shared rides and forum posts live at `.../votes/{uid}` as
  // `{value, uid}` (needs the `votes.uid` COLLECTION_GROUP index). Each vote
  // is removed in a transaction that takes its +1 back off the parent's
  // upvotes/downvotes, so the counters keep matching the vote docs.
  await step("delete votes", async () => {
    const snap = await db.collectionGroup("votes").where("uid", "==", uid).get();
    for (const doc of snap.docs) await removeVote(db, doc.ref);
  });

  // Build-29 clients still write `{value}` only, and Firestore can't query a
  // missing field, so those votes are only found by doc id in a full scan.
  // shortcut: reads every vote doc in the project; delete this step once
  // config/app.minBuild passes the release that writes `uid` and
  // scripts/oneoff/backfill_vote_uid.js has run.
  await step("delete legacy votes", async () => {
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let page = db.collectionGroup("votes").orderBy(FieldPath.documentId()).limit(500);
      if (last) page = page.startAfter(last);
      const snap = await page.get();
      if (snap.empty) break;
      last = snap.docs[snap.docs.length - 1];
      for (const doc of snap.docs) {
        if (doc.id === uid) await removeVote(db, doc.ref);
      }
    }
  });

  // Chats (owner decision 2026-10-21): the other rider keeps the
  // conversation; the deleted rider's side is anonymised. One step per chat,
  // so one failure doesn't strand the rest.
  for (const chatId of chatIds) {
    await step(`anonymize chat ${chatId}`, () => anonymizeChat(db, chatId, uid));
  }

  // Content in other people's spaces: strip the identity, keep the artefact.
  // Each entry is [label, query, fields to blank]. `userName` becomes a
  // tombstone rather than an empty string so a rendered post reads "Deleted
  // rider" instead of an empty byline.
  //
  // INDEXES (issues §101.S2): the `collectionGroup` queries below need a
  // COLLECTION_GROUP-scope single-field index on `userId` for `posts`,
  // `replies` and `comments`, on `senderId` for `voiceNotes` (and the one
  // above on `fromUid` for `notifications`). Firestore does NOT maintain single-field
  // indexes at collection-group scope by default (only at collection scope),
  // so without them each query fails with FAILED_PRECONDITION. Those three
  // entries belong in firestore.indexes.json `fieldOverrides`, each also
  // restating the default COLLECTION-scope ASC/DESC/CONTAINS indexes (an
  // override replaces the defaults for that field), and only take effect once
  // deployed with `firebase deploy --only firestore:indexes`. Until then each
  // such step fails, and the failure is recorded in the accountDeletions marker's
  // `failedSteps` ("anonymize forum posts" etc.), not just logged. The
  // Firestore emulator does not enforce indexes, so tests cannot catch this.
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
      // Group-ride voice clips. The audio URL names the rider's uid
      // (voiceNotes/{uid}/...) and the file goes in the Cloudinary sweep, so
      // it is blanked like a chat message's text.
      "voice notes",
      db.collectionGroup("voiceNotes").where("senderId", "==", uid),
      { senderId: DELETED_PARTICIPANT, senderName: DELETED_RIDER, senderPhotoUrl: "", audioUrl: "" },
    ],
    [
      "places contributed",
      db.collection("places").where("createdBy", "==", uid),
      { createdBy: "" },
    ],
  ];

  for (const [label, query, patch] of anonymizeQueries) {
    await step(`anonymize ${label}`, async () => {
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
        logger.info(`onUserAccountDeleted: anonymized ${snap.size} ${label} for ${uid}`);
      }
    });
  }

  // Place reviews are kept, detached from the rider (privacy.html §9), but
  // their id `{uid}_{placeId}` names the rider, so each moves to an auto id.
  // Moving rather than deleting leaves the place's ratingSum/ratingCount true.
  await step("anonymize place reviews", async () => {
    const snap = await db.collection("reviews").where("userId", "==", uid).get();
    for (const doc of snap.docs) {
      await db.runTransaction(async (txn) => {
        const cur = await txn.get(doc.ref);
        if (!cur.exists) return;
        txn.set(db.collection("reviews").doc(), { ...cur.data(), userId: "" });
        txn.delete(doc.ref);
      });
    }
  });

  // Reports about the rider (owner decision 2026-10-21). A pending one is
  // kept whole, uid and evidence copy (`snapshot`, chat-moderation's
  // `originalText`) included, so it can still be reviewed; it is flagged, and
  // report-retention.ts anonymises it once it is closed. A closed one loses
  // the uid now; its copied text goes 90 days after review. Reports the
  // deleted rider filed stay untouched, as before.
  await step("anonymize reports", async () => {
    const snap = await db.collection("reports").where("reportedId", "==", uid).get();
    for (let i = 0; i < snap.docs.length; i += ANONYMIZE_BATCH) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + ANONYMIZE_BATCH)) {
        batch.update(
          doc.ref,
          isPendingReport(doc.data())
            ? { reportedAccountDeleted: true }
            : anonymizedReportPatch(doc.data())
        );
      }
      await batch.commit();
    }
  });

  // Cloudinary media. MUST run before the profile is recursively deleted —
  // the ledger it reads lives at users/{uid}/cloudinaryAssets.
  failedSteps.push(...(await destroyCloudinaryAssets(uid, db, opts.cloudinary)));

  await step("delete profile", () =>
    db.recursiveDelete(db.collection("users").doc(uid))
  );

  const ok = failedSteps.length === 0;
  if (!ok) {
    logger.error(
      `onUserAccountDeleted: PARTIAL erasure for ${uid}; failed steps: ${failedSteps.join(", ")}`
    );
  }
  try {
    await db.collection(ACCOUNT_DELETIONS).doc(uid).set({
      completedAt: FieldValue.serverTimestamp(),
      failedSteps,
      ok,
      rtdbSkipped,
    });
  } catch (e) {
    logger.error(`onUserAccountDeleted: failed to write the completion marker for ${uid}`, e);
  }

  return { failedSteps, rtdbSkipped };
}

/**
 * Anonymises the rider's side of one chat. Their message texts are blanked,
 * not kept: public/privacy.html §9 lists messages among the records deleted
 * with the account. The other rider's messages and the doc id stay (moving
 * the doc would re-fire chat moderation on every copied message). A chat with
 * no live participant left is deleted outright. Idempotent: the rider's
 * messages go first and `participants`, which is how a retry finds this chat,
 * changes last.
 */
async function anonymizeChat(
  db: FirebaseFirestore.Firestore,
  chatId: string,
  uid: string
): Promise<void> {
  const chatRef = db.collection("chats").doc(chatId);
  const theirs = await chatRef.collection("messages").where("senderId", "==", uid).get();
  for (let i = 0; i < theirs.docs.length; i += ANONYMIZE_BATCH) {
    const batch = db.batch();
    for (const doc of theirs.docs.slice(i, i + ANONYMIZE_BATCH)) {
      batch.update(doc.ref, { senderId: DELETED_PARTICIPANT, text: "" });
    }
    await batch.commit();
  }

  const nobodyLeft = await db.runTransaction(async (txn) => {
    const snap = await txn.get(chatRef);
    if (!snap.exists) return false;
    const before: unknown[] = snap.get("participants") ?? [];
    const participants = before.map((p) => (p === uid ? DELETED_PARTICIPANT : p));
    if (participants.every((p) => p === DELETED_PARTICIPANT)) return true;
    // A transaction, so a message the other rider sends meanwhile can't have
    // its inbox preview overwritten.
    const lastFromRider = snap.get("lastMessage.senderId") === uid;
    txn.update(chatRef, {
      participants,
      ...(lastFromRider
        ? { "lastMessage.senderId": DELETED_PARTICIPANT, "lastMessage.text": "" }
        : {}),
      // Legacy chats may carry denormalised profile copies keyed by uid.
      [`participantNames.${uid}`]: FieldValue.delete(),
      [`participantPhotos.${uid}`]: FieldValue.delete(),
    });
    return false;
  });
  if (nobodyLeft) await db.recursiveDelete(chatRef);
}

/** How long one RTDB multi-path remove may take before it counts as failed. */
const RTDB_TIMEOUT_MS = 15000;

/**
 * One atomic multi-path remove (every value null). Bounded, because an RTDB
 * write that never gets acked would otherwise hold the whole function until
 * its own timeout, and the completion marker would never be written.
 */
async function rtdbRemove(
  rtdb: Database,
  paths: Record<string, null>
): Promise<void> {
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      rtdb.ref().update(paths),
      new Promise<never>((_, reject) => {
        timer = setTimeout(
          () => reject(new Error(`RTDB remove timed out after ${RTDB_TIMEOUT_MS} ms`)),
          RTDB_TIMEOUT_MS
        );
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

/**
 * Deletes one vote doc and takes its +1 back off the parent ride/post's
 * tally. A retry finds the vote gone and does nothing; a parent deleted since
 * is not recreated.
 */
async function removeVote(
  db: FirebaseFirestore.Firestore,
  voteRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  const parentRef = voteRef.parent.parent;
  if (!parentRef) return;
  await db.runTransaction(async (txn) => {
    const [vote, parent] = await txn.getAll(voteRef, parentRef);
    if (!vote.exists) return;
    txn.delete(voteRef);
    const value = vote.get("value");
    if (parent.exists && (value === 1 || value === -1)) {
      txn.update(parentRef, {
        [value === 1 ? "upvotes" : "downvotes"]: FieldValue.increment(-1),
      });
    }
  });
}

/** forum_follows ids are `{uid}_{forumId}`; the doc also carries forumId. */
function forumIdOf(doc: FirebaseFirestore.QueryDocumentSnapshot, uid: string): string | null {
  const field = doc.get("forumId");
  if (typeof field === "string" && field.length > 0) return field;
  const prefix = `${uid}_`;
  return doc.id.startsWith(prefix) && doc.id.length > prefix.length
    ? doc.id.slice(prefix.length)
    : null;
}

/**
 * Deletes every Cloudinary asset the rider uploaded, from the ledger that
 * `CloudinaryUploadService` writes on each upload (issues §83.15).
 *
 * The app uploads through an *unsigned* preset, which by design cannot
 * authorise a destroy — so this has to be done server-side with the account's
 * API key/secret, passed in from the functions secrets CLOUDINARY_API_KEY and
 * CLOUDINARY_API_SECRET (account-deletion.ts). They are NOT in the repo.
 *
 * Without them this logs and returns without throwing, and the skip is
 * recorded as a failed step in the marker, not silent success. The ledger is
 * then deleted with the profile, but every asset sits under `<kind>/<uid>/`,
 * so the marker's uid is enough to find the leftovers in the Cloudinary
 * console. There is no automatic folder sweep: a ledger row missed by a
 * failed client write is only found that way too.
 *
 * Returns the labels of the failed steps (empty on success).
 */
async function destroyCloudinaryAssets(
  uid: string,
  db: FirebaseFirestore.Firestore,
  creds: CloudinaryCredentials | undefined
): Promise<string[]> {
  const { cloud, apiKey, apiSecret } = creds ?? { cloud: "", apiKey: "", apiSecret: "" };

  let ledger: FirebaseFirestore.QuerySnapshot;
  try {
    ledger = await db
      .collection("users")
      .doc(uid)
      .collection("cloudinaryAssets")
      .get();
  } catch (e) {
    logger.error(`destroyCloudinaryAssets: cannot read ledger for ${uid}`, e);
    return ["cloudinary ledger"];
  }

  if (ledger.empty) return [];

  if (!cloud || !apiKey || !apiSecret) {
    logger.warn(
      `destroyCloudinaryAssets: ${ledger.size} asset(s) for ${uid} were NOT ` +
        "deleted — Cloudinary credentials are not configured. The rider's " +
        "media is still publicly reachable. See issues §83.15."
    );
    return ["cloudinary (no credentials)"];
  }

  let failed = 0;
  for (const doc of ledger.docs) {
    const publicId = doc.get("publicId") as string | undefined;
    const resourceType = (doc.get("resourceType") as string) || "image";
    if (!publicId) continue;
    // §90.D2: only ever destroy an asset in this rider's own folder. A ledger
    // row naming anyone else's media is skipped (and logged), never trusted.
    if (!isOwnedPublicId(publicId, uid)) {
      logger.warn(
        `destroyCloudinaryAssets: skipped ledger row ${doc.id} for ${uid} — ` +
          "publicId is not under this rider's own folder"
      );
      continue;
    }
    if (resourceType !== "image" && resourceType !== "video" && resourceType !== "raw") {
      logger.warn(
        `destroyCloudinaryAssets: skipped ledger row ${doc.id} — unknown resourceType`
      );
      continue;
    }
    try {
      await cloudinaryDestroy({
        cloud,
        apiKey,
        apiSecret,
        publicId,
        resourceType,
      });
    } catch (e) {
      failed++;
      // Logged with the public_id only — that is not PII, and it is what a
      // manual retry needs.
      logger.error(
        `destroyCloudinaryAssets: failed to destroy ${resourceType}/${publicId}`,
        e
      );
    }
  }
  return failed > 0 ? [`cloudinary destroy (${failed} failed)`] : [];
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
