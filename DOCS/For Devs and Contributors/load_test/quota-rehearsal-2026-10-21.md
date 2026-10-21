# Quota rehearsal, 2026-10-21

What a spent Spark quota looks like to a client, measured on a throwaway project: `throttleiq-quota-lab-20261021`, Spark with billing disabled, asia-south1. The run used `scripts/loadtest/quota_rehearsal.js` with the `firebase` JS SDK 10.14.1 and a fresh client per operation. Production was not touched. Issues §104.6.

## Verdict

- **The app's quota probe works.** `count()` is a direct server call. Once the read quota is spent it answers `resource-exhausted`, and so do transactions. That is what pauses sync in `SyncManager`.
- **Nothing is lost.** Past the write limit, a write is either queued by the SDK (no answer, pending) or still accepted. It is never rejected. Writes behind a rules `get()` keep working after the read quota is spent.
- **Only some reads stop.** Gets and listeners go through the realtime stream, and they kept being served from the server 8 minutes after the read quota ran out. That means 100,169 reads were counted on a 50,000-read day. Only unary calls were refused: `count()` (`RunAggregationQuery`) and the reads inside transactions (`BatchGetDocuments`). In the app, browsing mostly keeps working. Uploads, comments, votes, joins and other transactions fail.
- **Cloud Monitoring alerting works on Spark.** The policy in `scripts/monitoring/firestore-quota-alert.yaml` was created in the billing-disabled lab project. Its 80% read and write incidents opened 6-7 minutes after each threshold was crossed.
- **Refused requests never show up in `firestore.googleapis.com/api/request_count`.** Only `OK` unary calls appeared there, and no `RESOURCE_EXHAUSTED` entry showed after 7 minutes. Streaming calls aren't listed at all. The planned "requests refused" condition could therefore never fire. It was replaced by "used up" conditions at 99% of the daily reads and writes.

## Results

Spark limits per day: 50,000 reads, 20,000 writes. Each operation ran on a fresh client, with a 20 s deadline.

| Operation | Healthy | Read quota spent | Read and write quota spent |
|---|---|---|---|
| `count()` on `config` (the app's probe) | count = 1 | `resource-exhausted` | `resource-exhausted` |
| query `get` | 50 docs from the server | 50 docs from the server | 50 docs from the server |
| listener, first event | 5 docs from the server | 5 docs from the server | 5 docs from the server |
| doc `get` | from the server | from the server | from the server |
| plain `set` | acknowledged | acknowledged | acknowledged once, pending once |
| `set` behind a rules `get()` | acknowledged | acknowledged | pending once, acknowledged once |
| transaction (read + write) | committed | `resource-exhausted` | `resource-exhausted` |

Spending the quota:
- **Reads:** 200 queries of 500 docs went through the realtime stream, and none was refused. The read limit showed only on unary calls.
- **Writes:** a batch is refused whole. A 500-write batch stayed pending at about 19,500 writes, and single writes stayed pending once the day's total reached 20,000. Writes near the limit were inconsistent (one accepted, the next pending). Both outcomes are safe.

Metrics in the lab after the run: `document/read_ops_count` 100,169, `document/write_ops_count` 19,510 (still catching up). `api/request_count` had only `OK` for `BatchGetDocuments`, `Commit` and `RunAggregationQuery`.

## Not checked

- Whether realtime reads are refused later in the day. They were still served 8 minutes in.
- The native Android and iOS SDKs. They share the JS SDK's design (realtime stream for gets and listeners, direct calls for `count()` and transactions), but they weren't run here.
- Production real usage (7 days to 2026-10-21): 1,454-7,166 reads a day (3-14% of the limit), 57-881 writes, at most 13 deletes.
