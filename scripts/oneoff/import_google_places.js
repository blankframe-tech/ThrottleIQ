#!/usr/bin/env node
'use strict';

/**
 * import_google_places.js — fills gaps in the Dhaka places directory from an
 * Apify Google Maps Scraper export (compass/crawler-google-places), and drops
 * every Google rating (issues_open.md §105: the founder chose not to show them).
 *
 * What one run does:
 *   1. Sets googleRating/googleRatingCount to 0 on every place that has one.
 *      Those values came from a hand-written table with no traceable source.
 *   2. For each Google fuel/garage/parts place within MATCH_RADIUS_M of an
 *      existing place of the same category: fills phone/hours when empty, and
 *      replaces a generic name ("Fuel", "Garage", "Parts") with the real one.
 *   3. Creates every unmatched Google place, attributed to SEED_AUTHOR and
 *      keyed by `googlePlaceId` so a re-run creates nothing twice.
 *
 * Only facts (name, location, address, phone, hours) are copied; no Google
 * rating or review text is stored.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node oneoff/import_google_places.js --from=gmaps.json
 *       Dry run (default): reports what would change, writes nothing.
 *   ... --from=gmaps.json --yes-i-really-mean-it
 *       Writes.
 *
 * Undo: revert_google_places.js (export saved at ~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json).
 */

const fs = require('fs');
const { geohashEncode, DHAKA_BBOX } = require('./seed_dhaka_places');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const COLLECTION = 'places';
const SEED_AUTHOR = 'system:gmaps-seed-dhaka';
const MATCH_RADIUS_M = 60;
const BATCH_COMMIT_SIZE = 400;

/** Google Maps categoryName → PlaceCategory. Anything else is skipped. */
const CATEGORY_MAP = {
  'Gas station': 'fuel',
  'Fuel supplier': 'fuel',
  'Compressed natural gas station': 'fuel',
  'Motorcycle repair shop': 'garage',
  'Motor scooter repair shop': 'garage',
  Mechanic: 'garage',
  'Tire shop': 'garage',
  'Oil change service': 'garage',
  'Bike wash': 'garage',
  'Motorcycle parts store': 'parts',
  'Motorcycle shop': 'parts',
  'Auto parts store': 'parts',
  'Auto parts market': 'parts',
  'Motorsports store': 'parts',
};

const GENERIC_NAMES = new Set(['fuel', 'garage', 'parts']);

function distanceM(aLat, aLng, bLat, bLng) {
  const r = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
}

/** Apify openingHours [{day, hours}] → one short string, or null. */
function hoursFrom(openingHours) {
  if (!Array.isArray(openingHours) || openingHours.length === 0) return null;
  const distinct = new Set(openingHours.map((d) => d.hours));
  if (distinct.size === 1 && openingHours.length === 7) {
    const only = openingHours[0].hours;
    return only === 'Open 24 hours' ? '24/7' : `${only} daily`;
  }
  return openingHours.map((d) => `${String(d.day).slice(0, 3)} ${d.hours}`).join(', ');
}

/** One Apify row → candidate, or null if it is off-topic, closed, or outside Dhaka. */
function parseGooglePlace(row) {
  let category = CATEGORY_MAP[row && row.categoryName];
  if (!category) return null;
  // Google sometimes files a pump under a service category ("Oil change service").
  if (/filling station|cng/i.test(row.title || '')) category = 'fuel';
  if (row.permanentlyClosed || row.temporarilyClosed) return null;
  const lat = row.location && row.location.lat;
  const lng = row.location && row.location.lng;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  const b = DHAKA_BBOX;
  if (lat < b.south || lat > b.north || lng < b.west || lng > b.east) return null;
  const name = typeof row.title === 'string' ? row.title.trim() : '';
  if (!name || typeof row.placeId !== 'string') return null;
  return {
    googlePlaceId: row.placeId,
    name,
    category,
    latitude: lat,
    longitude: lng,
    address: (row.address || '').replace(/, Bangladesh$/, ''),
    phone: row.phone || null,
    hours: hoursFrom(row.openingHours),
  };
}

/**
 * Pure planning step. `existing` is [{id, data}] for every place doc.
 * Returns { resetRatings: [id], updates: [{id, patch}], creates: [candidate] }.
 */
function planImport(rows, existing) {
  const resetRatings = existing
    .filter((p) => (p.data.googleRating || 0) > 0 || (p.data.googleRatingCount || 0) > 0)
    .map((p) => p.id);

  const knownGoogleIds = new Set(existing.map((p) => p.data.googlePlaceId).filter(Boolean));
  const seen = new Set();
  const patches = new Map();
  const creates = [];

  for (const row of rows) {
    const c = parseGooglePlace(row);
    if (!c || seen.has(c.googlePlaceId) || knownGoogleIds.has(c.googlePlaceId)) continue;
    seen.add(c.googlePlaceId);

    let best = null;
    let bestDist = Infinity;
    for (const p of existing) {
      if (p.data.category !== c.category) continue;
      const d = distanceM(c.latitude, c.longitude, p.data.latitude, p.data.longitude);
      if (d < bestDist) {
        best = p;
        bestDist = d;
      }
    }

    if (best && bestDist <= MATCH_RADIUS_M) {
      // First Google place to claim an existing doc wins; later ones nearby are separate businesses.
      if (patches.has(best.id)) {
        creates.push(c);
        continue;
      }
      const patch = { googlePlaceId: c.googlePlaceId };
      if (!best.data.phone && c.phone) patch.phone = c.phone;
      if (!best.data.hours && c.hours) patch.hours = c.hours;
      if (GENERIC_NAMES.has(String(best.data.name || '').trim().toLowerCase())) patch.name = c.name;
      if (!best.data.address && c.address) patch.address = c.address;
      patches.set(best.id, patch);
    } else {
      creates.push(c);
    }
  }

  const updates = [...patches].map(([id, patch]) => ({ id, patch }));
  return { resetRatings, updates, creates };
}

function toPlaceDocument(c, createdAt) {
  return {
    name: c.name,
    category: c.category,
    latitude: c.latitude,
    longitude: c.longitude,
    geohash: geohashEncode(c.latitude, c.longitude, 9),
    address: c.address || '',
    phone: c.phone,
    hours: c.hours,
    photoUrls: [],
    verified: true,
    createdBy: SEED_AUTHOR,
    createdAt,
    ratingSum: 0,
    ratingCount: 0,
    googleRating: 0,
    googleRatingCount: 0,
    googlePlaceId: c.googlePlaceId,
  };
}

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  const from = (args.find((a) => a.startsWith('--from=')) || '').slice('--from='.length);
  const writing = args.includes('--yes-i-really-mean-it');
  if (!from) fail('--from=<apify export .json> is required.');
  if (process.env.FIREBASE_PROJECT_ID !== EXPECTED_PROJECT_ID) {
    fail(`FIREBASE_PROJECT_ID must be '${EXPECTED_PROJECT_ID}'.`);
  }

  let rows;
  try {
    rows = JSON.parse(fs.readFileSync(from, 'utf8'));
  } catch (err) {
    fail(`Could not read ${from}: ${err.message}`);
  }
  if (!Array.isArray(rows)) fail(`${from} is not a JSON array (export the dataset as JSON).`);

  const admin = require('firebase-admin');
  const app = admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: EXPECTED_PROJECT_ID,
  });
  if (app.options.projectId !== EXPECTED_PROJECT_ID) fail('Credentials resolve to the wrong project.');
  const db = admin.firestore();

  const snap = await db.collection(COLLECTION).get();
  const existing = snap.docs.map((d) => ({ id: d.id, data: d.data() }));
  const plan = planImport(rows, existing);

  const byCat = {};
  for (const c of plan.creates) byCat[c.category] = (byCat[c.category] || 0) + 1;
  console.log(`  ${writing ? 'WRITING' : 'DRY RUN'} — ${existing.length} existing places, ${rows.length} Google rows`);
  console.log(`  Google ratings reset to 0: ${plan.resetRatings.length}`);
  console.log(`  Existing places enriched:  ${plan.updates.length} (renamed: ${plan.updates.filter((u) => u.patch.name).length})`);
  console.log(`  New places:                ${plan.creates.length} ${JSON.stringify(byCat)}`);
  if (!writing) {
    console.log('\n  Nothing written. Re-run with --yes-i-really-mean-it to apply.');
    return;
  }

  const createdAt = admin.firestore.Timestamp.now();
  const ops = [
    ...plan.resetRatings.map((id) => (b) =>
      b.update(db.collection(COLLECTION).doc(id), { googleRating: 0, googleRatingCount: 0 })),
    ...plan.updates.map(({ id, patch }) => (b) => b.update(db.collection(COLLECTION).doc(id), patch)),
    ...plan.creates.map((c) => (b) => b.set(db.collection(COLLECTION).doc(), toPlaceDocument(c, createdAt))),
  ];
  for (let i = 0; i < ops.length; i += BATCH_COMMIT_SIZE) {
    const batch = db.batch();
    ops.slice(i, i + BATCH_COMMIT_SIZE).forEach((op) => op(batch));
    await batch.commit();
    console.log(`    … ${Math.min(i + BATCH_COMMIT_SIZE, ops.length)}/${ops.length} writes`);
  }
  console.log('  Done.');
}

module.exports = { parseGooglePlace, planImport, hoursFrom, distanceM, toPlaceDocument, SEED_AUTHOR };

if (require.main === module) {
  main().catch((err) => fail(err.stack || err.message));
}
