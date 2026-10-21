#!/usr/bin/env node
'use strict';

/**
 * revert_google_places.js — takes the 2026-10-19 Google Maps import
 * (import_google_places.js, issues_open.md §105) back out of `places`.
 *
 * Which places: only docs the import wrote. It tagged every place it created
 * with createdBy == SEED_AUTHOR (717 on 2026-10-19, all `verified: true`), and
 * `googlePlaceId` is written by nothing else, so a non-seeded doc carrying one
 * is one of the 80 it enriched. Other verified places are never touched.
 *
 * Two modes (the owner picks one):
 *   --seeded-only   B: delete the seeded places only. Needs no export.
 *   --from=<export> A: B, plus put the 80 enriched places back: remove
 *                   googlePlaceId and clear each field that still equals the
 *                   Google value in the export (phone/hours -> null,
 *                   address -> '', name -> the generic "Fuel"/"Garage"/"Parts").
 *                   The import only filled empty fields and generic names, so
 *                   that is the pre-import state, reconstructed from the export
 *                   (no pre-import snapshot exists: no backups on Spark).
 * Either way, a seeded place someone changed since (updatedAt/updatedBy set,
 * or a rider review: ratingCount > 0) is skipped and listed. Not undoable by
 * this script: the Google ratings the import set to 0 on 69 places.
 *
 * Safety:
 *   - Dry run is the DEFAULT: reads only, prints what would change.
 *   - Writes need --apply and --backup=<new file>. Before the first write, every
 *     doc to be deleted (whole doc) and every field to be cleared (old value)
 *     goes into that file. --restore=<file> --apply puts them back.
 *   - Each write carries the doc's read time as a precondition, so a place a
 *     rider reviews mid-run is skipped, not deleted.
 *   - Idempotent: a finished run leaves nothing to do; re-run to pick up skips.
 *
 * Usage (from scripts/):
 *   export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/throttleiqfb-admin.json
 *   FIREBASE_PROJECT_ID=throttleiqfb node revert_google_places.js --seeded-only                 # dry run, B
 *   FIREBASE_PROJECT_ID=throttleiqfb node revert_google_places.js --from=<export.json>          # dry run, A
 *   ... --apply --backup="$HOME/.secrets/throttleiq/places-revert-$(date +%F).json"           # writes
 *   ... --restore=<backup.json> [--apply]                                                         # undo
 */

const fs = require('fs');
const { parseGooglePlace, SEED_AUTHOR } = require('./import_google_places');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const COLLECTION = 'places';
const GENERIC_NAME = { fuel: 'Fuel', garage: 'Garage', parts: 'Parts' };
const CLEARED = { phone: null, hours: null, address: '' };

/** A seeded place someone changed after the import: keep it. */
function editedSinceImport(data) {
  return data.updatedAt != null || data.updatedBy != null || (data.ratingCount || 0) > 0;
}

/**
 * Pure planning step. `existing` is [{id, data}] for every place doc; `rows` is
 * the Apify export, or null for --seeded-only (then nothing is cleared).
 * Returns { deletes: [id], skipped: [{id, name, reason}],
 *           clears: [{id, category, fields: {field: current Google value}}] }.
 */
function planRevert(rows, existing) {
  const google = new Map();
  for (const row of rows || []) {
    const c = parseGooglePlace(row);
    if (c) google.set(c.googlePlaceId, c);
  }

  const deletes = [];
  const skipped = [];
  const clears = [];
  for (const { id, data } of existing) {
    if (data.createdBy === SEED_AUTHOR) {
      if (editedSinceImport(data)) {
        const reason = data.ratingCount > 0 ? `${data.ratingCount} rider review(s)` : `updated by ${data.updatedBy || '?'}`;
        skipped.push({ id, name: data.name, reason });
      } else {
        deletes.push(id);
      }
      continue;
    }
    if (!rows || !data.googlePlaceId) continue;
    const c = google.get(data.googlePlaceId) || {};
    const fields = { googlePlaceId: data.googlePlaceId };
    // shortcut: a value that was already there and equals Google's (same name, same phone) also matches;
    // without a snapshot that can't be told apart, so the dry run lists every field and the backup keeps it.
    for (const f of ['phone', 'hours', 'address']) {
      if (c[f] && data[f] === c[f]) fields[f] = data[f];
    }
    if (c.name && data.name === c.name && GENERIC_NAME[data.category]) fields.name = data.name;
    clears.push({ id, category: data.category, fields });
  }
  return { deletes, skipped, clears };
}

/** The update that puts one enriched place back. `deleteField` is FieldValue.delete(). */
function restorePatch({ category, fields }, deleteField) {
  const patch = { googlePlaceId: deleteField };
  for (const f of Object.keys(CLEARED)) if (f in fields) patch[f] = CLEARED[f];
  if (fields.name) patch.name = GENERIC_NAME[category];
  return patch;
}

// shortcut: top-level Timestamps only; place docs have no nested ones. Upgrade if a nested timestamp field appears.
function encodeDoc(data, Timestamp) {
  return Object.fromEntries(Object.entries(data).map(([k, v]) =>
    [k, v instanceof Timestamp ? { __timestamp: [v.seconds, v.nanoseconds] } : v]));
}
function decodeDoc(data, Timestamp) {
  return Object.fromEntries(Object.entries(data).map(([k, v]) =>
    [k, v && Array.isArray(v.__timestamp) ? new Timestamp(...v.__timestamp) : v]));
}

/** Backup entries: what --restore writes back. `docs` maps id -> data as read. */
function backupEntries(plan, docs, Timestamp) {
  return [
    ...plan.deletes.map((id) => ({ id, action: 'delete', data: encodeDoc(docs.get(id), Timestamp) })),
    ...plan.clears.map((c) => ({ id: c.id, action: 'clear', data: c.fields })),
  ];
}

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function readJson(path) {
  try {
    return JSON.parse(fs.readFileSync(path, 'utf8'));
  } catch (err) {
    return fail(`Could not read ${path}: ${err.message}`);
  }
}

/** Runs `ops` [{id, run(writer)}] through one BulkWriter, no retries. Returns [done, skipped]. */
async function writeAll(db, ops) {
  const writer = db.bulkWriter();
  writer.onWriteError(() => false); // a failed precondition means someone changed the doc: skip it
  const done = [];
  const skipped = [];
  const writes = ops.map((op) => op.run(writer)
    .then(() => done.push(op.id))
    .catch((e) => skipped.push(`${op.id} (${e.code || e.message})`)));
  await writer.close(); // flushes; awaiting the writes first would hang below 20 ops
  await Promise.all(writes);
  return [done, skipped];
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (name) => (args.find((a) => a.startsWith(`--${name}=`)) || '').slice(name.length + 3);
  const from = opt('from');
  const backup = opt('backup');
  const restore = opt('restore');
  const seededOnly = args.includes('--seeded-only');
  const writing = args.includes('--apply');
  if ([from, seededOnly, restore].filter(Boolean).length !== 1) {
    fail('Pick one: --seeded-only (delete the 717 only), --from=<apify export .json> (also clear the 80 enriched), or --restore=<backup .json>.');
  }
  if (writing && !restore && !backup) fail('--apply needs --backup=<new file> (outside the repo: it holds Google data).');
  if (backup && fs.existsSync(backup)) fail(`${backup} already exists; pick a new file.`);
  if (process.env.FIREBASE_PROJECT_ID !== EXPECTED_PROJECT_ID) {
    fail(`FIREBASE_PROJECT_ID must be '${EXPECTED_PROJECT_ID}'.`);
  }
  const emulator = process.env.FIRESTORE_EMULATOR_HOST;
  if (!emulator) {
    const key = readJson(process.env.GOOGLE_APPLICATION_CREDENTIALS || fail('Set GOOGLE_APPLICATION_CREDENTIALS to the service-account key.'));
    if (key.project_id !== EXPECTED_PROJECT_ID) fail(`The key is for '${key.project_id}', not '${EXPECTED_PROJECT_ID}'.`);
  }

  const admin = require('firebase-admin');
  admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });
  const db = admin.firestore();
  const { Timestamp, FieldValue } = admin.firestore;
  const ref = (id) => db.collection(COLLECTION).doc(id);
  const target = emulator ? `emulator ${emulator}` : 'PRODUCTION';

  if (restore) {
    const entries = readJson(restore);
    if (!Array.isArray(entries)) fail(`${restore} is not a backup written by this script.`);
    console.log(`  ${writing ? 'WRITING' : 'DRY RUN'} (${target}) — restore ${entries.length} places from ${restore}`);
    console.log(`  Recreate deleted:  ${entries.filter((e) => e.action === 'delete').length} (a doc that exists again is skipped)`);
    console.log(`  Put fields back:   ${entries.filter((e) => e.action === 'clear').length}`);
    if (!writing) return console.log('\n  Nothing written. Re-run with --apply to write.');
    const [done, skipped] = await writeAll(db, entries.map((e) => ({
      id: e.id,
      run: (w) => (e.action === 'delete' ? w.create(ref(e.id), decodeDoc(e.data, Timestamp)) : w.update(ref(e.id), e.data)),
    })));
    console.log(`  Restored ${done.length}; skipped ${skipped.length}`);
    for (const s of skipped) console.log(`    - ${s}`);
    return;
  }

  const rows = from ? readJson(from) : null;
  if (from && !Array.isArray(rows)) fail(`${from} is not a JSON array (export the dataset as JSON).`);

  const snap = await db.collection(COLLECTION).get();
  const existing = snap.docs.map((d) => ({ id: d.id, data: d.data() }));
  const plan = planRevert(rows, existing);

  console.log(`  ${writing ? 'WRITING' : 'DRY RUN'} (${target}) — ${from ? 'A: seeded + enriched' : 'B: seeded only'}; ${existing.length} places${rows ? `, ${rows.length} Google rows` : ''}`);
  console.log(`  Seeded places to delete:        ${plan.deletes.length} (717 imported)`);
  console.log(`  Seeded places skipped (edited): ${plan.skipped.length}`);
  for (const s of plan.skipped) console.log(`    - ${s.id}  ${s.name}  (${s.reason})`);
  if (from) {
    console.log(`  Enriched places to clear:       ${plan.clears.length} (80 enriched)`);
    for (const c of plan.clears) {
      const what = Object.entries(c.fields).map(([f, v]) => (f === 'name' ? `name "${v}" -> "${GENERIC_NAME[c.category]}"` : f));
      console.log(`    - ${c.id}  ${what.join(', ')}`);
    }
  }
  console.log('  Not undoable here: Google ratings set to 0 by the import.');
  if (!writing) return console.log('\n  Nothing written. Re-run with --apply --backup=<new file> to write.');
  if (plan.deletes.length + plan.clears.length === 0) return console.log('  Nothing to do.');

  const docs = new Map(snap.docs.map((d) => [d.id, d]));
  const entries = backupEntries(plan, new Map(existing.map((p) => [p.id, p.data])), Timestamp);
  fs.writeFileSync(backup, JSON.stringify(entries, null, 1), { flag: 'wx', mode: 0o600 });
  console.log(`  Backup: ${backup} (undo: --restore=${backup} --apply)`);
  const at = (id) => ({ lastUpdateTime: docs.get(id).updateTime });
  const [done, skipped] = await writeAll(db, [
    ...plan.deletes.map((id) => ({ id, run: (w) => w.delete(ref(id), at(id)) })),
    ...plan.clears.map((c) => ({ id: c.id, run: (w) => w.update(ref(c.id), restorePatch(c, FieldValue.delete()), at(c.id)) })),
  ]);
  console.log(`  Wrote ${done.length}; skipped ${skipped.length} (changed during the run; re-run to retry)`);
  for (const s of skipped) console.log(`    - ${s}`);
  console.log('  Done. A second dry run should report 0 to delete and 0 to clear.');
}

module.exports = { planRevert, restorePatch, editedSinceImport, encodeDoc, decodeDoc, backupEntries };

if (require.main === module) {
  main().catch((err) => fail(err.stack || err.message));
}
