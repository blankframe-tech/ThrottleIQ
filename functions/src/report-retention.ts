import { FieldValue } from "firebase-admin/firestore";

/**
 * Retention for report evidence (owner decision 2026-10-21). A chat or post
 * report's `snapshot` (copy of the reported content, see firestore.rules
 * `snapshotIsReal`) and a system report's `originalText` are removed
 * REPORT_SNAPSHOT_RETENTION_DAYS after the admin closed the report
 * (`reviewedAt`, DOCS/moderation_policy.md step 4). The report itself stays
 * as the audit trail. privacy.html §8 and moderation_policy.md §5 state it.
 *
 * Account deletion (account-erasure.ts) keeps a PENDING report about the
 * deleted rider intact, uid included, so it can still be reviewed, and flags
 * it `reportedAccountDeleted`. Once such a report is closed, the next run
 * anonymises it like a closed one at deletion time (anonymizedReportPatch).
 *
 * Runs from the existing daily cleanup, `purgeOldGpsTracks`
 * (track-retention.ts). Needs the Blaze plan. NOT deployed yet: SECURITY.md.
 */

export const REPORT_SNAPSHOT_RETENTION_DAYS = 90;

/** Stands in for the deleted rider's uid (same as DELETED_PARTICIPANT). */
const DELETED_RIDER_UID = "deleted-rider";

/** Updates per batch; under Firestore's 500-write cap. */
const PAGE = 400;

/** A report filed while it is still waiting for review. Missing = pending. */
export function isPendingReport(data: FirebaseFirestore.DocumentData): boolean {
  return (data.status ?? "pending") === "pending";
}

/**
 * Strips a deleted rider's uid from a closed report about them. The text in
 * `snapshot` stays until the retention purge.
 */
export function anonymizedReportPatch(
  data: FirebaseFirestore.DocumentData
): Record<string, unknown> {
  return {
    reportedId: "",
    originalText: "",
    reportedAccountDeleted: FieldValue.delete(),
    ...(data.snapshot ? { "snapshot.senderId": DELETED_RIDER_UID } : {}),
  };
}

/**
 * Deletes the evidence copy from reports closed before the window, and
 * anonymises closed reports about riders who deleted their account. Returns
 * the number of reports changed.
 */
export async function purgeOldReportSnapshots(
  db: FirebaseFirestore.Firestore,
  now: Date = new Date()
): Promise<number> {
  const cutoff = now.getTime() - REPORT_SNAPSHOT_RETENTION_DAYS * 86_400_000;
  const updates = new Map<string, [FirebaseFirestore.DocumentReference, Record<string, unknown>]>();

  const gone = await db.collection("reports").where("reportedAccountDeleted", "==", true).get();
  for (const doc of gone.docs) {
    if (!isPendingReport(doc.data())) updates.set(doc.ref.path, [doc.ref, anonymizedReportPatch(doc.data())]);
  }

  // shortcut: reads every report reviewed before the cutoff on each run;
  // fine at beta volume, add a purged flag + composite index past ~10k reports.
  const old = await db.collection("reports").where("reviewedAt", "<", new Date(cutoff)).get();
  for (const doc of old.docs) {
    if (doc.get("snapshot") === undefined && !doc.get("originalText")) continue;
    // Reopened (e.g. an appeal): pending keeps its evidence (moderation_policy §5).
    if (isPendingReport(doc.data())) continue;
    // Deleting the whole map replaces a pending snapshot.senderId patch.
    const anonymize = updates.get(doc.ref.path)?.[1] ?? {};
    delete anonymize["snapshot.senderId"];
    updates.set(doc.ref.path, [
      doc.ref,
      { ...anonymize, snapshot: FieldValue.delete(), originalText: FieldValue.delete() },
    ]);
  }

  const all = [...updates.values()];
  for (let i = 0; i < all.length; i += PAGE) {
    const batch = db.batch();
    for (const [ref, patch] of all.slice(i, i + PAGE)) batch.update(ref, patch);
    await batch.commit();
  }
  return all.length;
}
