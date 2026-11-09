#!/usr/bin/env node
'use strict';

/**
 * reclip_shared_routes.js — one-off: re-clip the route lines on shared rides
 * and public routes with the current privacy-zone clipper.
 *
 * Older builds hid a circle centred on the ride's start and end. The app now
 * centres that circle on a secret decoy point, different for every place a
 * rider starts or ends (see app/lib/features/social/domain/utilities/
 * privacy_zone_clipper.dart and privacy_zone_salt.dart, which this file
 * mirrors). Lines shared before that build still use the old shape,
 * so this rewrites them:
 *
 *   - rides/{id}.polyline: re-clipped from the rider's full track at
 *     users/{uid}/rides/{id}/track when the track was backed up; otherwise
 *     the stored (already clipped) line is clipped again around its own
 *     ends, which hides a further 330-1600 m off each end.
 *   - users/{uid}/routes/{id}.polyline where isPublic == true: going public
 *     already replaced the full trail with the clipped one, so these are
 *     always clipped again around their own ends.
 *
 * The decoy comes from the rider's salt and place anchors at
 * users/{uid}/private/privacy (fields `zoneSalt` and `anchors`, the app's
 * own). A rider with no salt yet gets one, and a place with no anchor yet
 * gets one, the same way the app would create them on their next share.
 *
 * Run it AFTER the build with the new clipper is on Play, and pass
 * --before=<date that build shipped>: docs created on or after that date
 * were clipped by the new build and are skipped. Run it once: a second run
 * would clip the fallback lines again (shorter, never less private).
 *
 * Safety:
 *   - Dry run is the DEFAULT: reads only, prints counts.
 *   - The service-account key's project_id must be 'throttleiqfb'.
 *   - Writes need --apply, --before, --backup=<file> (the old polylines, and
 *     which riders get a new salt or new anchors, are written there first)
 *     and a typed confirmation.
 *
 * Usage (from scripts/):
 *   node oneoff/reclip_shared_routes.js --service-account=/path/to/key.json --before=2026-09-20
 *   node oneoff/reclip_shared_routes.js --service-account=/path/to/key.json \
 *     --before=<build ship date> --apply --backup=reclip-backup.json
 */

const fs = require('node:fs');
const crypto = require('node:crypto');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'RECLIP ROUTES';
const PAGE = 300;
const BATCH = 400;

// ── Clipper (mirrors privacy_zone_clipper.dart and polyline_simplify.dart) ──

const PRIVACY_ZONE_M = 200;
const JITTER_SPAN_M = 150;
const MAX_EXTRA_TRIM_M = 50;
const MAX_POINTS = 1000;
const EARTH_RADIUS_M = 6371000; // geo_math.dart haversine
const EQUATOR_RADIUS_M = 6378137; // latlong2 Distance.offset

const rad = (d) => (d * Math.PI) / 180;
const deg = (r) => (r * 180) / Math.PI;

const MIN_OFFSET_M = 130;
const MAX_OFFSET_M = 600;
const ANCHOR_REUSE_M = 1000;

function offsetMetersFor(seed) {
  const u = (Math.floor(Math.abs(seed) / JITTER_SPAN_M) % 1000) / 1000;
  const lo2 = MIN_OFFSET_M * MIN_OFFSET_M;
  return Math.sqrt(lo2 + u * (MAX_OFFSET_M * MAX_OFFSET_M - lo2));
}
const bearingFor = (seed) => (Math.floor(Math.abs(seed) / (JITTER_SPAN_M * 1000)) % 360) - 180;
const radiusFor = (seed) => offsetMetersFor(seed) + PRIVACY_ZONE_M + (Math.abs(seed) % JITTER_SPAN_M);

function haversine(a, b) {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(Math.min(1, h)));
}

function destination(from, meters, bearingDeg) {
  const h = rad(bearingDeg);
  const a = meters / EQUATOR_RADIUS_M;
  const lat1 = rad(from.lat);
  const lat2 = Math.asin(Math.sin(lat1) * Math.cos(a) + Math.cos(lat1) * Math.sin(a) * Math.cos(h));
  const lng2 = rad(from.lng) + Math.atan2(Math.sin(h) * Math.sin(a) * Math.cos(lat1), Math.cos(a) - Math.sin(lat1) * Math.sin(lat2));
  return { lat: deg(lat2), lng: deg(lng2) };
}

const hiddenCentre = (endpoint, seed) => destination(endpoint, offsetMetersFor(seed), bearingFor(seed));

function clipPolyline(pts, seed, extraTrimM = 0, endSeed = seed) {
  if (pts.length < 3) return [];
  const startCentre = hiddenCentre(pts[0], seed);
  const endCentre = hiddenCentre(pts[pts.length - 1], endSeed);
  const rStart = radiusFor(seed) + extraTrimM;
  const rEnd = radiusFor(endSeed) + extraTrimM;
  const hidden = (p) => haversine(p, startCentre) <= rStart || haversine(p, endCentre) <= rEnd;
  let i = 0;
  while (i < pts.length && hidden(pts[i])) i++;
  let j = pts.length - 1;
  while (j >= i && hidden(pts[j])) j--;
  return i > j ? [] : pts.slice(i, j + 1);
}

function rdp(pts, xs, ys, tol) {
  const keep = new Array(pts.length).fill(false);
  keep[0] = keep[pts.length - 1] = true;
  const stack = [0, pts.length - 1];
  while (stack.length) {
    const b = stack.pop();
    const a = stack.pop();
    const dx = xs[b] - xs[a];
    const dy = ys[b] - ys[a];
    const len2 = dx * dx + dy * dy;
    let maxD = -1;
    let idx = -1;
    for (let i = a + 1; i < b; i++) {
      let t = len2 === 0 ? 0 : ((xs[i] - xs[a]) * dx + (ys[i] - ys[a]) * dy) / len2;
      t = Math.min(1, Math.max(0, t));
      const ex = xs[i] - (xs[a] + t * dx);
      const ey = ys[i] - (ys[a] + t * dy);
      const d = ex * ex + ey * ey;
      if (d > maxD) { maxD = d; idx = i; }
    }
    if (idx !== -1 && maxD > tol * tol) {
      keep[idx] = true;
      stack.push(a, idx, idx, b);
    }
  }
  return pts.filter((_, i) => keep[i]);
}

function simplifyPolyline(pts, toleranceM = 5, maxPoints = MAX_POINTS) {
  if (pts.length <= 2) return pts;
  const cosLat = Math.cos(rad(pts[0].lat));
  const xs = pts.map((p) => p.lng * cosLat * 111320);
  const ys = pts.map((p) => p.lat * 111320);
  let tol = toleranceM;
  let out = rdp(pts, xs, ys, tol);
  for (let i = 0; i < 8 && out.length > maxPoints; i++) {
    tol *= 2;
    out = rdp(pts, xs, ys, tol);
  }
  if (out.length <= maxPoints) return out;
  const step = (out.length - 1) / (maxPoints - 1);
  const thinned = [];
  for (let i = 0; i < maxPoints - 1; i++) thinned.push(out[Math.floor(i * step)]);
  thinned.push(out[out.length - 1]);
  return thinned;
}

const secureRandom = () => crypto.randomInt(0, 2 ** 31) / 2 ** 31;

/** The polyline as the current app would share it (clip, random extra trim, thin). */
const clipForSharing = (pts, seed, random = secureRandom, endSeed = seed) =>
  simplifyPolyline(clipPolyline(pts, seed, random() * MAX_EXTRA_TRIM_M, endSeed));

// ── Per-place seeds (mirrors privacy_zone_salt.dart) ─────────────────────────

/** The anchor nearest `p` within 1 km, or null. */
function nearestAnchor(anchors, p) {
  let best = null;
  let bestM = ANCHOR_REUSE_M;
  for (const a of anchors) {
    const m = haversine(a, p);
    if (m <= bestM) { best = a; bestM = m; }
  }
  return best;
}

const roundAnchor = (p) => ({ lat: Math.round(p.lat * 1000) / 1000, lng: Math.round(p.lng * 1000) / 1000 });

/** First 31 bits of HMAC-SHA256(key: salt as decimal text, msg: "lat,lng" to 3 dp). */
function seedForAnchor(salt, anchor) {
  const mac = crypto.createHmac('sha256', String(salt)).update(`${anchor.lat.toFixed(3)},${anchor.lng.toFixed(3)}`).digest();
  return mac.readUInt32BE(0) & 0x7fffffff;
}

/** [startSeed, endSeed]; appends an anchor to `anchors` for a place not seen before. */
function seedsWith(salt, anchors, start, end) {
  const seedAt = (p) => {
    let a = nearestAnchor(anchors, p);
    if (!a) { a = roundAnchor(p); anchors.push(a); }
    return seedForAnchor(salt, a);
  };
  return [seedAt(start), seedAt(end)];
}

/** Anchors from the stored list of {lat, lng}; malformed rows dropped. */
const readAnchors = (raw) => (Array.isArray(raw) ? raw : [])
  .filter((m) => m && typeof m.lat === 'number' && typeof m.lng === 'number')
  .map((m) => ({ lat: m.lat, lng: m.lng }));

// ── Firestore shapes ─────────────────────────────────────────────────────────

/** {lat, lng} points from a stored `polyline` array; malformed entries dropped. */
function readPolyline(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((p) => p && Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lng)))
    .map((p) => ({ lat: Number(p.lat), lng: Number(p.lng) }));
}

/**
 * The full track from `track` chunk docs (ride_track_codec.dart): each doc is
 * {index, points: [lat, lng, ts, speed, accel, ...]}. Sorted by the numeric
 * index, a trailing partial block dropped.
 */
function decodeTrack(chunkDocs) {
  const docs = [...chunkDocs].sort((a, b) => (a.index ?? 0) - (b.index ?? 0));
  const out = [];
  for (const d of docs) {
    const flat = Array.isArray(d.points) ? d.points : [];
    for (let i = 0; i + 5 <= flat.length; i += 5) out.push({ lat: Number(flat[i]), lng: Number(flat[i + 1]) });
  }
  return out;
}

/**
 * The new polyline for one doc. `track` is the full trail (rides only, may be
 * empty); `stored` is what the doc holds now. Prefers the trail, since the
 * stored line has already lost its true ends. `salt` and `anchors` are the
 * rider's; a new anchor is appended to `anchors`.
 */
function reclip({ stored, track = [], salt, anchors, random = secureRandom }) {
  const source = track.length >= 3 ? 'track' : 'stored';
  const line = source === 'track' ? track : stored;
  if (line.length < 3) return { polyline: [], source };
  const [startSeed, endSeed] = seedsWith(salt, anchors, line[0], line[line.length - 1]);
  return { polyline: clipForSharing(line, startSeed, random, endSeed), source };
}

/** Millis of a Firestore Timestamp / Date / ISO string, or null. */
function millisOf(v) {
  if (v == null) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  const t = Date.parse(v);
  return Number.isNaN(t) ? null : t;
}

/** True when a doc created at `createdAt` should be re-clipped for `beforeMs`. */
function inScope(createdAt, beforeMs) {
  if (beforeMs == null) return true;
  const t = millisOf(createdAt);
  return t == null || t < beforeMs; // no date: an old doc, re-clip it
}

// ── CLI ──────────────────────────────────────────────────────────────────────

function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

function parseArgs(argv) {
  const opts = { serviceAccount: null, before: null, apply: false, backup: null, nonInteractive: false, help: false };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg.startsWith('--service-account=')) opts.serviceAccount = arg.slice('--service-account='.length);
    else if (arg.startsWith('--before=')) {
      const v = arg.slice('--before='.length);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(v) || Number.isNaN(Date.parse(`${v}T00:00:00+06:00`))) {
        throw new Error(`--before needs a YYYY-MM-DD date, got '${v}'.`);
      }
      opts.before = Date.parse(`${v}T00:00:00+06:00`); // Dhaka midnight
    } else if (arg.startsWith('--backup=')) opts.backup = arg.slice('--backup='.length);
    else if (arg === '--apply') opts.apply = true;
    else if (arg === '--non-interactive') opts.nonInteractive = true;
    else if (arg === '--dry-run') { /* the default */ }
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  if (opts.apply && opts.before == null) throw new Error('--apply needs --before=<date the new build shipped>.');
  if (opts.apply && !opts.backup) throw new Error('--apply needs --backup=<file> for the old polylines.');
  return opts;
}

async function confirm(nonInteractive) {
  if (nonInteractive) return;
  const readline = require('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(`  Type "${CONFIRMATION_PHRASE}" to continue: `);
  rl.close();
  if (answer.trim() !== CONFIRMATION_PHRASE) fail('Confirmation did not match. Nothing was changed.');
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]);
    return;
  }
  if (!opts.serviceAccount) fail('Pass --service-account=/path/to/key.json.');
  let key;
  try {
    key = JSON.parse(fs.readFileSync(opts.serviceAccount, 'utf8'));
  } catch (e) {
    fail(`Cannot read the service-account key: ${e.message}`);
  }
  if (key.project_id !== EXPECTED_PROJECT_ID) {
    fail(`The key is for project '${key.project_id}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  }
  if (opts.backup && fs.existsSync(opts.backup)) fail(`${opts.backup} already exists; pick a new backup file.`);

  const { cert, initializeApp } = require('firebase-admin/app');
  const { getFirestore, FieldPath, FieldValue } = require('firebase-admin/firestore');
  const db = getFirestore(initializeApp({ credential: cert(key), projectId: EXPECTED_PROJECT_ID }));

  const salts = new Map(); // uid -> { salt, created, anchors, known }
  async function privacyFor(uid) {
    if (!salts.has(uid)) {
      const snap = await db.doc(`users/${uid}/private/privacy`).get();
      const v = snap.exists ? snap.get('zoneSalt') : undefined;
      const anchors = readAnchors(snap.exists ? snap.get('anchors') : undefined);
      salts.set(uid, Number.isInteger(v)
        ? { salt: v, created: false, anchors, known: anchors.length }
        : { salt: crypto.randomInt(0, 2 ** 31), created: true, anchors, known: anchors.length });
    }
    const s = salts.get(uid);
    return { salt: s.salt, anchors: s.anchors };
  }

  const todo = []; // { ref, kind, old, polyline, source }
  const counts = { rides: 0, ridesInScope: 0, track: 0, stored: 0, routes: 0, routesInScope: 0 };

  let last = null;
  for (;;) {
    let q = db.collection('rides').orderBy(FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      counts.rides++;
      const data = doc.data();
      const stored = readPolyline(data.polyline);
      if (!data.userId || stored.length === 0 || !inScope(data.createdAt, opts.before)) continue;
      counts.ridesInScope++;
      const chunks = await db.collection(`users/${data.userId}/rides/${doc.id}/track`).get();
      const plan = reclip({ stored, track: decodeTrack(chunks.docs.map((c) => c.data())), ...(await privacyFor(data.userId)) });
      counts[plan.source]++;
      todo.push({ ref: doc.ref, kind: 'ride', createdAt: millisOf(data.createdAt), old: data.polyline, ...plan });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  last = null;
  for (;;) {
    let q = db.collectionGroup('routes').where('isPublic', '==', true).orderBy('timesRidden', 'desc').limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      counts.routes++;
      const data = doc.data();
      const uid = doc.ref.parent.parent?.id;
      const stored = readPolyline(data.polyline);
      if (!uid || stored.length === 0 || !inScope(data.createdAt, opts.before)) continue;
      counts.routesInScope++;
      todo.push({ ref: doc.ref, kind: 'route', createdAt: millisOf(data.createdAt), old: data.polyline, ...reclip({ stored, ...(await privacyFor(uid)) }) });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  todo.sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0)); // oldest shares first
  const oldCutoff = Date.parse('2026-09-20T00:00:00+06:00');
  const newSalts = [...salts.values()].filter((s) => s.created).length;
  const withNewAnchors = [...salts.entries()].filter(([, s]) => s.anchors.length > s.known);
  console.log(`  Shared rides: ${counts.rides} scanned, ${counts.ridesInScope} to re-clip (${counts.track} from the full track, ${counts.stored} from the stored line).`);
  console.log(`  Public routes: ${counts.routes} scanned, ${counts.routesInScope} to re-clip.`);
  console.log(`  Of those, ${todo.filter((t) => (t.createdAt ?? 0) < oldCutoff).length} were shared before 2026-09-20.`);
  console.log(`  ${todo.filter((t) => t.polyline.length === 0).length} lines would clip away entirely (the doc keeps its stats, no map line).`);
  console.log(`  Riders without a salt yet: ${newSalts} (one would be created for each).`);
  console.log(`  Riders who get new place anchors: ${withNewAnchors.length}.`);
  if (!opts.apply) {
    console.log('  Dry run: nothing changed. Re-run with --apply --before=<date> --backup=<file> to write.');
    return;
  }
  if (todo.length === 0) return;
  await confirm(opts.nonInteractive);

  // Backup first: the old lines, and which salts this run creates.
  fs.writeFileSync(opts.backup, JSON.stringify({
    takenAt: new Date().toISOString(),
    docs: todo.map((t) => ({ path: t.ref.path, polyline: t.old })),
    createdSaltsFor: [...salts.entries()].filter(([, s]) => s.created).map(([uid]) => uid),
    addedAnchorsFor: withNewAnchors.map(([uid]) => uid),
  }), { mode: 0o600 });
  console.log(`  Backup written to ${opts.backup}.`);

  // Salts and anchors before lines, so no line is ever written with a decoy
  // that is not stored. create() fails if the rider's device made a salt
  // meanwhile; then re-run. New anchors are appended (arrayUnion), never
  // replacing ones a device added meanwhile.
  const writes = withNewAnchors.concat([...salts.entries()].filter(([, s]) => s.created && s.anchors.length === s.known));
  for (let i = 0; i < writes.length; i += BATCH) {
    const batch = db.batch();
    for (const [uid, s] of writes.slice(i, i + BATCH)) {
      const ref = db.doc(`users/${uid}/private/privacy`);
      if (s.created) batch.create(ref, { zoneSalt: s.salt, anchors: s.anchors });
      else batch.set(ref, { anchors: FieldValue.arrayUnion(...s.anchors.slice(s.known)) }, { merge: true });
    }
    await batch.commit();
  }

  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = db.batch();
    for (const t of todo.slice(i, i + BATCH)) batch.update(t.ref, { polyline: t.polyline });
    await batch.commit();
    console.log(`  Re-clipped ${Math.min(i + BATCH, todo.length)}/${todo.length}`);
  }
  console.log('  Done. Do not run it again over the same docs.');
}

if (require.main === module) {
  main().catch((e) => fail(e.stack || String(e)));
}

module.exports = {
  offsetMetersFor, bearingFor, radiusFor, haversine, hiddenCentre, clipPolyline,
  simplifyPolyline, clipForSharing, nearestAnchor, roundAnchor, seedForAnchor, seedsWith, readAnchors,
  readPolyline, decodeTrack, reclip, inScope, parseArgs,
};
