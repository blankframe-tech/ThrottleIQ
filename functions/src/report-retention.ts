import { FieldValue } from "firebase-admin/firestore";

/**
 * Retention for report evidence (owner decision 2026-10-21). A chat or post
 * report's `snapshot` (copy of the reported content, see firestore.rules
 * `snapshotIsReal`) and a system report's `originalText` are removed
 * REPORT_SNAPSHOT_RETENTION_DAYS after the admin closed the report
 * (`reviewedAt`, DOCS/General/Files for Stores/moderation_policy.md step 4). The report itself stays
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

/** Docs read and updated per page; under Firestore's 500-write cap. */
const PAGE = 400;

/**
 * How long one daily run may keep paging: the scheduler's 540 s timeout less
 * a margin, so a large backlog stops cleanly and the next run finishes it.
 */
export const PURGE_BUDGET_MS = 480_000;

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
  now: Date = new Date(),
  deadline: number = Date.now() + PURGE_BUDGET_MS
): Promise<number> {
  const cutoff = new Date(now.getTime() - REPORT_SNAPSHOT_RETENTION_DAYS * 86_400_000);
  let changed = 0;

  // Old evidence first. A closed report about a deleted rider gets the
  // anonymisation in the same write, which also drops its
  // reportedAccountDeleted flag, so the second pass skips it.
  // shortcut: re-reads every report reviewed before the cutoff on each run
  // (paged, so memory is bounded); add a purged flag + composite index past ~10k reports.
  changed += await pagedUpdate(
    db.collection("reports").where("reviewedAt", "<", cutoff).orderBy("reviewedAt"),
    deadline,
    (data) => {
      if (data.snapshot === undefined && !data.originalText) return null;
      // Reopened (e.g. an appeal): pending keeps its evidence (moderation_policy §5).
      if (isPendingReport(data)) return null;
      const anonymize = data.reportedAccountDeleted === true ? anonymizedReportPatch(data) : {};
      // Deleting the whole map replaces the snapshot.senderId patch.
      delete anonymize["snapshot.senderId"];
      return { ...anonymize, snapshot: FieldValue.delete(), originalText: FieldValue.delete() };
    }
  );

  changed += await pagedUpdate(
    db.collection("reports").where("reportedAccountDeleted", "==", true),
    deadline,
    (data) => (isPendingReport(data) ? null : anonymizedReportPatch(data))
  );
  return changed;
}

/**
 * Pages through `query` PAGE docs at a time, writing `patchOf(data)` (null =
 * skip) in one batch per page. Stops early once `deadline` (epoch ms) has
 * passed; the next daily run picks up the rest. Returns the docs updated.
 */
async function pagedUpdate(
  query: FirebaseFirestore.Query,
  deadline: number,
  patchOf: (data: FirebaseFirestore.DocumentData) => Record<string, unknown> | null
): Promise<number> {
  let updated = 0;
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (Date.now() < deadline) {
    const snap = await (last ? query.startAfter(last) : query).limit(PAGE).get();
    if (snap.empty) break;
    last = snap.docs[snap.docs.length - 1];
    const batch = query.firestore.batch();
    let n = 0;
    for (const doc of snap.docs) {
      const patch = patchOf(doc.data());
      if (patch === null) continue;
      batch.update(doc.ref, patch);
      n++;
    }
    if (n > 0) await batch.commit();
    updated += n;
    if (snap.size < PAGE) break;
  }
  return updated;
}
