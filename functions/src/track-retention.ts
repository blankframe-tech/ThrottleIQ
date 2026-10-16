import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";

/**
 * Cloud retention for raw GPS trails (critique 2026-10-14, section 5): the
 * chunked `users/{uid}/rides/{rideId}/track/{chunk}` docs are deleted once
 * they are older than TRACK_RETENTION_MONTHS. The ride summary doc (distance,
 * duration, speeds) is kept, and so is the trail on the rider's phone; the
 * app already treats a ride with no cloud track as "no polyline to pull".
 *
 * Age is the chunk's `syncedAt` (server time of the upload, written on every
 * chunk since trails first synced, 2026-08-01). A ride uploaded late is kept
 * a little longer, never purged early.
 *
 * Needs the COLLECTION_GROUP index on `track.syncedAt` (firestore.indexes.json)
 * and the Blaze plan for Cloud Scheduler. NOT deployed yet: see SECURITY.md.
 */

export const TRACK_RETENTION_MONTHS = 12;

/** Deletes per batch; well under Firestore's 500-write cap. */
const PAGE = 400;

/** Only ride trails; any other `track` collection is left alone. */
const RIDE_TRACK = /^users\/[^/]+\/rides\/[^/]+\/track\/[^/]+$/;

/** Deletes trail chunks older than the retention window. Returns the count. */
export async function purgeOldTrackChunks(
  db: FirebaseFirestore.Firestore,
  now: Date = new Date()
): Promise<number> {
  const cutoff = new Date(now);
  cutoff.setMonth(cutoff.getMonth() - TRACK_RETENTION_MONTHS);

  let deleted = 0;
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collectionGroup("track")
      .where("syncedAt", "<", cutoff)
      .orderBy("syncedAt")
      .limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    last = snap.docs[snap.docs.length - 1];

    const batch = db.batch();
    let n = 0;
    for (const doc of snap.docs) {
      if (!RIDE_TRACK.test(doc.ref.path)) continue;
      batch.delete(doc.ref);
      n++;
    }
    if (n > 0) await batch.commit();
    deleted += n;
    if (snap.size < PAGE) break;
  }
  return deleted;
}

/** Daily at 03:30 Dhaka time. A run that times out is finished by the next. */
export const purgeOldGpsTracks = onSchedule(
  { schedule: "30 3 * * *", timeZone: "Asia/Dhaka", timeoutSeconds: 540 },
  async () => {
    const n = await purgeOldTrackChunks(getFirestore());
    logger.info(`purgeOldGpsTracks: deleted ${n} track chunk(s) older than ${TRACK_RETENTION_MONTHS} months`);
  }
);
