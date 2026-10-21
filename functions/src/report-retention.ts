import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";

/**
 * Retention for report evidence (owner decision 2026-10-21): a chat report's
 * `snapshot` (copy of the reported message, see firestore.rules
 * `chatSnapshotIsReal`) is removed REPORT_SNAPSHOT_RETENTION_DAYS after the
 * admin closed the report (`reviewedAt`, DOCS/moderation_policy.md step 4).
 * The report itself stays as the audit trail. Account deletion keeps the
 * snapshot (account-erasure.ts), so this is what bounds it. A default the
 * owner can change; privacy.html and moderation_policy.md state it too.
 *
 * Needs the Blaze plan for Cloud Scheduler. NOT deployed yet: see SECURITY.md.
 */

export const REPORT_SNAPSHOT_RETENTION_DAYS = 180;

/** Updates per batch; under Firestore's 500-write cap. */
const PAGE = 400;

/** Deletes the snapshot from reports closed before the window. Returns the count. */
export async function purgeOldReportSnapshots(
  db: FirebaseFirestore.Firestore,
  now: Date = new Date()
): Promise<number> {
  const cutoff = new Date(now.getTime() - REPORT_SNAPSHOT_RETENTION_DAYS * 86_400_000);
  // shortcut: re-reads every report closed before the cutoff on each run;
  // fine at beta volume, add a purged flag + composite index past ~10k reports.
  const snap = await db.collection("reports").where("reviewedAt", "<", cutoff).get();
  const stale = snap.docs.filter((d) => d.get("snapshot") !== undefined);
  for (let i = 0; i < stale.length; i += PAGE) {
    const batch = db.batch();
    for (const doc of stale.slice(i, i + PAGE)) {
      batch.update(doc.ref, { snapshot: FieldValue.delete() });
    }
    await batch.commit();
  }
  return stale.length;
}

/** Daily at 03:45 Dhaka time. */
export const purgeReportSnapshots = onSchedule(
  { schedule: "45 3 * * *", timeZone: "Asia/Dhaka", timeoutSeconds: 300 },
  async () => {
    const n = await purgeOldReportSnapshots(getFirestore());
    logger.info(`purgeReportSnapshots: removed ${n} snapshot(s) older than ${REPORT_SNAPSHOT_RETENTION_DAYS} days after review`);
  }
);
