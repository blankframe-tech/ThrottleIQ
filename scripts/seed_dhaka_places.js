#!/usr/bin/env node
'use strict';

/**
 * seed_dhaka_places.js — pre-populate the `places` directory with Dhaka's
 * petrol pumps, motorcycle garages and parts sellers, so a rider who opens
 * Places in Dhaka sees a useful directory on first launch instead of an empty
 * list waiting for someone else to contribute.
 *
 * Source: OpenStreetMap, via the public Overpass API. This is the same source
 * the in-app "Import nearby" button already uses
 * (`app/lib/features/poi_directory/data/services/overpass_service.dart`) — the
 * difference is scope. The app asks for a radius around the rider's own
 * position and attributes what it finds to that rider; this script asks for a
 * whole bounding box over Dhaka once, and attributes what it finds to a system
 * sentinel so nothing shows up in anyone's "My places".
 *
 * ---------------------------------------------------------------------------
 * This script CREATES documents. It never updates or deletes one.
 * ---------------------------------------------------------------------------
 *
 * Safety design (deliberately the same posture as reset_beta_data.js):
 *   - --dry-run is the DEFAULT. Nothing is written without
 *     --yes-i-really-mean-it.
 *   - Refuses to run unless FIREBASE_PROJECT_ID is exactly 'throttleiqfb', and
 *     refuses again if the resolved credentials point at another project.
 *   - Idempotent and resumable: every document carries its OSM id, and the
 *     script skips any osmId already present in Firestore before writing. An
 *     interrupted run leaves fewer to write next time; a completed run re-run
 *     writes nothing.
 *   - Every seeded document carries `createdBy: 'system:osm-seed-dhaka'`, so
 *     the whole batch is one query away for a future re-seed or rollback.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node seed_dhaka_places.js
 *   FIREBASE_PROJECT_ID=throttleiqfb node seed_dhaka_places.js --yes-i-really-mean-it
 *
 * Suggested flow — look at the data before you commit it to production:
 *   node seed_dhaka_places.js --out=dhaka.json      # fetch + report, no writes
 *   <read dhaka.json, delete anything that is junk>
 *   node seed_dhaka_places.js --from=dhaka.json --yes-i-really-mean-it
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point at a service-account JSON
 * key with Firebase Admin rights — but only for a real write or the dedup
 * check. `--out=` never touches Firestore, so the data can be fetched and
 * reviewed from any machine with no key at all. See scripts/README.md.
 */

// Required lazily inside main(), after --help and the project guard, so those
// still give a useful message on a machine where `npm install` has not run.
let admin;

const fs = require('fs');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** The only project this script will ever touch. */
const EXPECTED_PROJECT_ID = 'throttleiqfb';

/** Firestore's write batch limit is 500; commit at 400 for retry headroom. */
const BATCH_COMMIT_SIZE = 400;

/** Firestore `whereIn` caps at 30 values per query. */
const WHERE_IN_CHUNK = 30;

const COLLECTION = 'places';

/**
 * Attribution for everything this script writes.
 *
 * Not a real uid, and deliberately not uid-shaped. Two things depend on that:
 * `getPlacesByOwner` / `myPlacesProvider` back the "My places" list by
 * `createdBy == <uid>`, so a sentinel keeps 4,000 imported pumps out of every
 * rider's own list; and a re-seed or rollback is a single
 * `where('createdBy', '==', SEED_AUTHOR)` query rather than a hand-kept list of
 * document ids.
 */
const SEED_AUTHOR = 'system:osm-seed-dhaka';

/**
 * Dhaka metro, as south,west,north,east — the order Overpass' `bbox` filter
 * wants.
 *
 * Wider than the city's administrative boundary on purpose: it takes in Uttara
 * and the airport in the north, Keraniganj across the river, and the
 * Narayanganj/Savar fringes where a rider leaving Dhaka actually needs to know
 * where the next pump is. An administrative `area[...]` filter would be tidier
 * on paper and would cut exactly the edges that matter for a ride out of town.
 *
 * Override with --bbox=s,w,n,e to seed another city.
 */
const DHAKA_BBOX = { south: 23.65, west: 90.3, north: 23.92, east: 90.52 };

const OVERPASS_ENDPOINT = 'https://overpass-api.de/api/interpreter';

/** Overpass is a free, shared, rate-limited service. Be a good citizen. */
const OVERPASS_TIMEOUT_SECONDS = 180;
const OVERPASS_HTTP_TIMEOUT_MS = 240000;
const OVERPASS_RETRIES = 3;
const OVERPASS_RETRY_BACKOFF_MS = 20000;

/**
 * The OSM tags that mean "petrol pump", "garage" and "parts seller", and which
 * `PlaceCategory` each maps to.
 *
 * The first three rows are exactly what `OverpassService` queries in the app,
 * with the same precedence — that parity is what keeps the two importers'
 * categories consistent for any node either of them can see.
 *
 * The rest are seed-only additions, and they are here because the app's
 * narrower set leaves real gaps in Dhaka specifically:
 *   - `shop=motorcycle_repair` is used interchangeably with
 *     `craft=motorcycle_repair` by Bangladeshi mappers.
 *   - `shop=motorcycle_parts` is the actual tag for a pure parts counter;
 *     `shop=motorcycle` usually means a dealership.
 * Seeding these costs nothing and never produces duplicates: dedup is by OSM
 * id, so a node the app's importer can't classify is simply one it will never
 * try to re-create.
 *
 * Order matters — first match wins, so the motorcycle-specific tags are
 * checked before the generic fuel one for the rare node carrying both.
 */
const TAG_RULES = [
  { key: 'craft', value: 'motorcycle_repair', category: 'garage', inApp: true },
  { key: 'shop', value: 'motorcycle', category: 'parts', inApp: true },
  { key: 'shop', value: 'motorcycle_repair', category: 'garage', inApp: false },
  { key: 'shop', value: 'motorcycle_parts', category: 'parts', inApp: false },
  { key: 'amenity', value: 'fuel', category: 'fuel', inApp: true },
];

/**
 * Display names for a place whose OSM entry has no `name` tag — matching
 * `PlaceCategory.displayName`, which is what the app's importer falls back to
 * in the same situation.
 */
const CATEGORY_DISPLAY_NAME = { fuel: 'Fuel', garage: 'Garage', parts: 'Parts' };

const CATEGORIES = Object.keys(CATEGORY_DISPLAY_NAME);

// ---------------------------------------------------------------------------
// Geohash
//
// A line-for-line port of GeohashUtil.encode
// (app/lib/core/utils/geohash_util.dart), at the precision-9 default
// GeohashUtils.encode applies — the two must agree exactly or seeded places
// fall outside the prefix ranges getPlacesByGeohash queries, and a rider's map
// viewport silently misses them.
//
// Ported rather than pulled from npm on purpose: a third-party geohash package
// would agree with this on the standard algorithm, but "agrees today" is not
// the same guarantee as "is the same code", and this is 20 lines.
// ---------------------------------------------------------------------------

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function geohashEncode(lat, lng, precision = 9) {
  let latMin = -90.0;
  let latMax = 90.0;
  let lngMin = -180.0;
  let lngMax = 180.0;
  let hash = '';
  let isEven = true;
  let bits = 0;
  let bit = 0;

  while (hash.length < precision) {
    if (isEven) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        bit |= 1 << (4 - bits);
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        bit |= 1 << (4 - bits);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bits < 4) {
      bits += 1;
    } else {
      hash += BASE32[bit];
      bits = 0;
      bit = 0;
    }
  }
  return hash;
}

// ---------------------------------------------------------------------------
// Overpass
// ---------------------------------------------------------------------------

/**
 * Builds the Overpass QL for one bounding box.
 *
 * `nwr` (node/way/relation) rather than the app's `node`: a great many of
 * Dhaka's petrol stations are mapped as building/area polygons, not points, and
 * a node-only query silently misses every one of them. `out center;` gives each
 * way and relation a single representative coordinate, which is all a place
 * pin needs.
 */
function buildQuery(bbox, categories) {
  const box = `${bbox.south},${bbox.west},${bbox.north},${bbox.east}`;
  const clauses = TAG_RULES.filter((rule) => categories.includes(rule.category))
    .map((rule) => `  nwr["${rule.key}"="${rule.value}"](${box});`)
    .join('\n');
  return `[out:json][timeout:${OVERPASS_TIMEOUT_SECONDS}];\n(\n${clauses}\n);\nout center;\n`;
}

async function fetchOverpass(query, endpoint) {
  let lastError;
  for (let attempt = 1; attempt <= OVERPASS_RETRIES; attempt += 1) {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), OVERPASS_HTTP_TIMEOUT_MS);
      let response;
      try {
        response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            // Overpass asks that automated clients identify themselves so an
            // operator can get in touch instead of just blocking the IP.
            'User-Agent': 'ThrottleIQ-seed-script (+https://github.com/The-Abraar)',
          },
          body: new URLSearchParams({ data: query }).toString(),
          signal: controller.signal,
        });
      } finally {
        clearTimeout(timer);
      }

      if (response.status === 429 || response.status === 504) {
        // The documented "you are being rate limited" / "the query timed out
        // server-side" pair. Both are worth retrying; nothing else is.
        throw new Error(`Overpass returned ${response.status} (rate limit / gateway timeout)`);
      }
      if (!response.ok) {
        const body = (await response.text()).slice(0, 400);
        throw Object.assign(
          new Error(`Overpass returned HTTP ${response.status}: ${body}`),
          { fatal: true }
        );
      }
      const json = await response.json();
      return Array.isArray(json.elements) ? json.elements : [];
    } catch (err) {
      lastError = err;
      if (err.fatal || attempt === OVERPASS_RETRIES) break;
      const wait = OVERPASS_RETRY_BACKOFF_MS * attempt;
      warn(`    ! ${err.message}`);
      warn(`    ! retrying in ${wait / 1000}s (attempt ${attempt + 1}/${OVERPASS_RETRIES})`);
      await sleep(wait);
    }
  }
  throw lastError;
}

/**
 * The category for a set of OSM tags, or null when nothing matches. Mirrors
 * `OverpassService._categoryFor`'s precedence for the tags they share.
 */
function categoryFor(tags) {
  for (const rule of TAG_RULES) {
    if (tags[rule.key] === rule.value) return rule.category;
  }
  return null;
}

/** Mirrors `OverpassService._addressFrom`. */
function addressFrom(tags) {
  return ['addr:housenumber', 'addr:street', 'addr:city']
    .map((key) => tags[key])
    .filter((value) => typeof value === 'string' && value.trim() !== '')
    .join(', ');
}

/**
 * One raw Overpass element → one candidate, or null if it can't be placed.
 *
 * Mirrors `OverpassService.parseElement`, with the two differences the wider
 * query forces: the osm id is prefixed with the element's real type (`way/123`,
 * not `node/123`) so it stays a stable, correct reference, and a way's or
 * relation's coordinate comes from the `center` object `out center;` adds.
 */
function parseElement(element) {
  const tags = element.tags || {};
  const category = categoryFor(tags);
  if (!category) return null;

  const lat = element.lat ?? (element.center && element.center.lat);
  const lon = element.lon ?? (element.center && element.center.lon);
  if (typeof lat !== 'number' || typeof lon !== 'number') return null;
  if (element.id === undefined || element.id === null) return null;

  const name = typeof tags.name === 'string' ? tags.name.trim() : '';
  // Bangla-only names are common in Dhaka and are the *better* label for a
  // rider there, so `name` wins outright; `name:en` is only a fallback for an
  // entry that has an English name and no default one.
  const englishName = typeof tags['name:en'] === 'string' ? tags['name:en'].trim() : '';

  return {
    osmId: `${element.type}/${element.id}`,
    name: name || englishName || CATEGORY_DISPLAY_NAME[category],
    category,
    latitude: lat,
    longitude: lon,
    address: addressFrom(tags),
    phone: tags.phone || tags['contact:phone'] || null,
    hours: tags.opening_hours || null,
    // Kept out of the Firestore document; useful when eyeballing --out= JSON.
    _named: Boolean(name || englishName),
  };
}

/**
 * Collapses the same real-world place mapped twice — typically once as a node
 * and once as the building way around it. Keyed on category plus coordinates
 * rounded to ~11 m plus a normalised name, which is tight enough not to merge
 * two genuinely adjacent pumps on the same road.
 *
 * Nodes win over ways: a mapper placing a point has usually put it on the
 * forecourt entrance, which is a better pin than a building centroid.
 */
function dedupeCandidates(candidates) {
  const byKey = new Map();
  let dropped = 0;
  for (const candidate of candidates) {
    const key = [
      candidate.category,
      candidate.latitude.toFixed(4),
      candidate.longitude.toFixed(4),
      candidate.name.toLowerCase().replace(/\s+/g, ' ').trim(),
    ].join('|');
    const existing = byKey.get(key);
    if (!existing) {
      byKey.set(key, candidate);
      continue;
    }
    dropped += 1;
    if (existing.osmId.startsWith('way/') && candidate.osmId.startsWith('node/')) {
      byKey.set(key, candidate);
    }
  }
  return { candidates: [...byKey.values()], dropped };
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

function parseBbox(raw) {
  const parts = raw.split(',').map((s) => Number(s.trim()));
  if (parts.length !== 4 || parts.some((n) => !Number.isFinite(n))) {
    throw new Error(`--bbox needs four numbers: south,west,north,east (got '${raw}').`);
  }
  const [south, west, north, east] = parts;
  if (south >= north) throw new Error('--bbox south must be less than north.');
  if (west >= east) throw new Error('--bbox west must be less than east.');
  if (south < -90 || north > 90) throw new Error('--bbox latitudes must be within ±90.');
  if (west < -180 || east > 180) throw new Error('--bbox longitudes must be within ±180.');
  return { south, west, north, east };
}

function parseArgs(argv) {
  const opts = {
    confirmed: false,
    help: false,
    bbox: DHAKA_BBOX,
    categories: CATEGORIES,
    unverified: false,
    dedupe: true,
    limit: null,
    out: null,
    from: null,
    endpoint: OVERPASS_ENDPOINT,
  };

  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') {
      opts.help = true;
    } else if (arg === '--yes-i-really-mean-it') {
      opts.confirmed = true;
    } else if (arg === '--dry-run') {
      // The explicit form of the default, so a runbook can spell it out.
    } else if (arg === '--unverified') {
      opts.unverified = true;
    } else if (arg === '--no-dedupe') {
      opts.dedupe = false;
    } else if (arg.startsWith('--bbox=')) {
      opts.bbox = parseBbox(arg.slice('--bbox='.length));
    } else if (arg.startsWith('--categories=')) {
      const wanted = arg
        .slice('--categories='.length)
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
      if (wanted.length === 0) throw new Error('--categories= was given with no values.');
      for (const name of wanted) {
        if (!CATEGORIES.includes(name)) {
          throw new Error(
            `--categories names an unknown category: '${name}'. Known: ${CATEGORIES.join(', ')}`
          );
        }
      }
      opts.categories = wanted;
    } else if (arg.startsWith('--limit=')) {
      const n = Number(arg.slice('--limit='.length));
      if (!Number.isInteger(n) || n <= 0) throw new Error('--limit must be a positive integer.');
      opts.limit = n;
    } else if (arg.startsWith('--out=')) {
      opts.out = arg.slice('--out='.length);
      if (!opts.out) throw new Error('--out= needs a file path.');
    } else if (arg.startsWith('--from=')) {
      opts.from = arg.slice('--from='.length);
      if (!opts.from) throw new Error('--from= needs a file path.');
    } else if (arg.startsWith('--endpoint=')) {
      opts.endpoint = arg.slice('--endpoint='.length);
      if (!opts.endpoint) throw new Error('--endpoint= needs a URL.');
    } else {
      throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
    }
  }

  if (opts.from && opts.out) {
    throw new Error('--from= and --out= are opposites; pass one or the other.');
  }

  if (opts.out && opts.confirmed) {
    throw new Error(
      '--out= only fetches and writes a file for review; it never creates places.\n' +
        '       Drop --yes-i-really-mean-it here, then pass the reviewed file back with\n' +
        '       --from=<file> --yes-i-really-mean-it .'
    );
  }

  return opts;
}

const USAGE = `
seed_dhaka_places.js — seed the places directory with Dhaka's petrol pumps,
motorcycle garages and parts sellers, from OpenStreetMap via Overpass.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node seed_dhaka_places.js
      Dry run (the default). Fetches, reports what it found and what is new,
      writes nothing.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node seed_dhaka_places.js --yes-i-really-mean-it
      Actually create the place documents.

Review the data before you commit it:
  node seed_dhaka_places.js --out=dhaka.json    (fetch only; no credentials needed)
  node seed_dhaka_places.js --from=dhaka.json --yes-i-really-mean-it

Flags:
  --dry-run                 Fetch and report only (default).
  --yes-i-really-mean-it    Required to write anything.
  --bbox=s,w,n,e            Bounding box. Default is Dhaka metro:
                            ${DHAKA_BBOX.south},${DHAKA_BBOX.west},${DHAKA_BBOX.north},${DHAKA_BBOX.east}
  --categories=a,b,c        Restrict to some of: ${CATEGORIES.join(', ')}.
  --limit=N                 Write at most N new places (for a cautious first run).
  --out=FILE                Write the fetched candidates to FILE as JSON and
                            stop. Touches no Firestore, needs no credentials.
  --from=FILE               Read candidates from FILE instead of querying Overpass.
  --unverified              Create with verified:false, i.e. treat them as
                            pending rider moderation. Default is verified:true —
                            see the note in scripts/README.md.
  --no-dedupe               Skip the node-vs-way merge.
  --endpoint=URL            Alternate Overpass instance.
  --help                    This message.

Environment:
  FIREBASE_PROJECT_ID              Must equal '${EXPECTED_PROJECT_ID}'.
  GOOGLE_APPLICATION_CREDENTIALS   Path to a service-account JSON key. Needed
                                   for the dedup check and for any write.
`;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

const log = (...args) => console.log(...args);
const warn = (...args) => console.warn(...args);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function rule(char = '-') {
  log(char.repeat(66));
}

function plural(n, one, many) {
  return `${n} ${n === 1 ? one : many}`;
}

function countBy(items, key) {
  const counts = {};
  for (const item of items) counts[item[key]] = (counts[item[key]] || 0) + 1;
  return counts;
}

// ---------------------------------------------------------------------------
// Guards — same two-stage check as reset_beta_data.js
// ---------------------------------------------------------------------------

function assertProjectEnv({ needsCredentials }) {
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (!projectId) {
    fail(
      'FIREBASE_PROJECT_ID is not set.\n' +
        '         This script refuses to run without it, so it can never be pointed\n' +
        `         at the wrong project by accident. Set it to '${EXPECTED_PROJECT_ID}'.`
    );
  }

  if (projectId !== EXPECTED_PROJECT_ID) {
    fail(
      `FIREBASE_PROJECT_ID is '${projectId}', not '${EXPECTED_PROJECT_ID}'.\n` +
        '         Refusing to run. This script only ever writes to the ThrottleIQ project.'
    );
  }

  if (needsCredentials && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    warn(
      '  NOTE   GOOGLE_APPLICATION_CREDENTIALS is not set — falling back to whatever\n' +
        '         application-default credentials this machine has. See scripts/README.md.\n'
    );
  }

  return projectId;
}

function assertResolvedProject(app) {
  const resolved =
    (app.options && app.options.projectId) ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT;

  if (!resolved) {
    fail(
      'Could not determine which project the credentials belong to.\n' +
        '         Refusing to run rather than guess.'
    );
  }

  if (resolved !== EXPECTED_PROJECT_ID) {
    fail(
      `The supplied credentials resolve to project '${resolved}', not '${EXPECTED_PROJECT_ID}'.\n` +
        '         GOOGLE_APPLICATION_CREDENTIALS is probably pointing at the wrong\n' +
        '         service-account key. Refusing to run.'
    );
  }
}

// ---------------------------------------------------------------------------
// Firestore
// ---------------------------------------------------------------------------

/**
 * Which of `osmIds` already exist as places. The Node-side twin of
 * `PlaceRepository.getExistingOsmIds`, chunked the same way for the same
 * reason (Firestore's 30-value `whereIn` cap).
 *
 * This is what makes the script idempotent, and it is also what keeps a rider's
 * later "Import nearby" tap in Dhaka from duplicating a seeded place — both
 * sides key off the same osmId.
 */
async function fetchExistingOsmIds(db, osmIds) {
  const found = new Set();
  for (let i = 0; i < osmIds.length; i += WHERE_IN_CHUNK) {
    const chunk = osmIds.slice(i, i + WHERE_IN_CHUNK);
    const snap = await db.collection(COLLECTION).where('osmId', 'in', chunk).get();
    for (const doc of snap.docs) {
      const id = doc.get('osmId');
      if (typeof id === 'string') found.add(id);
    }
    if (i > 0 && i % (WHERE_IN_CHUNK * 20) === 0) {
      log(`    … checked ${i}/${osmIds.length} against Firestore`);
    }
  }
  return found;
}

/**
 * The Firestore document for one candidate — field-for-field what
 * `PlaceModel.toFirestore()` writes, including the nullable fields, so a seeded
 * place and a rider-submitted one are indistinguishable in shape and
 * `PlaceModel.fromFirestore` needs no special case for either.
 */
function toPlaceDocument(candidate, { verified, createdAt }) {
  return {
    name: candidate.name,
    category: candidate.category,
    latitude: candidate.latitude,
    longitude: candidate.longitude,
    geohash: geohashEncode(candidate.latitude, candidate.longitude, 9),
    address: candidate.address || '',
    phone: candidate.phone || null,
    hours: candidate.hours || null,
    photoUrls: [],
    verified,
    createdBy: SEED_AUTHOR,
    createdAt,
    ratingSum: 0,
    ratingCount: 0,
    osmId: candidate.osmId,
  };
}

async function writePlaces(db, candidates, { verified }) {
  const createdAt = admin.firestore.Timestamp.now();
  let written = 0;
  let commits = 0;

  for (let i = 0; i < candidates.length; i += BATCH_COMMIT_SIZE) {
    const chunk = candidates.slice(i, i + BATCH_COMMIT_SIZE);
    const batch = db.batch();
    for (const candidate of chunk) {
      batch.set(
        db.collection(COLLECTION).doc(),
        toPlaceDocument(candidate, { verified, createdAt })
      );
    }
    await batch.commit();
    written += chunk.length;
    commits += 1;
    log(`    … ${written}/${candidates.length} places created`);
  }

  return { written, commits };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/**
 * Reads and validates a `--from=` candidates file. Split out of main() and run
 * *before* the Firestore connection so a typo'd path or a malformed file fails
 * immediately, rather than after the credential handshake.
 */
function loadCandidatesFile(path) {
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(path, 'utf8'));
  } catch (err) {
    fail(`Could not read ${path}: ${err.message}`);
  }

  const list = Array.isArray(parsed) ? parsed : parsed && parsed.places;
  if (!Array.isArray(list)) {
    fail(
      `${path} is not what this expects.\n` +
        '         Give it either a JSON array of candidates or the exact object\n' +
        '         --out= produced (which has a "places" array).'
    );
  }

  // Trust the file's shape only as far as the fields that must be there — it is
  // expected to have been hand-edited between the fetch and the write.
  const candidates = list.filter(
    (c) =>
      c &&
      typeof c.osmId === 'string' &&
      typeof c.name === 'string' &&
      CATEGORIES.includes(c.category) &&
      Number.isFinite(c.latitude) &&
      Number.isFinite(c.longitude)
  );

  if (candidates.length === 0) {
    fail(
      `${path} has no usable candidates.\n` +
        '         Each entry needs osmId, name, category, latitude and longitude.'
    );
  }

  return { candidates, total: list.length };
}

async function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (err) {
    fail(err.message);
  }

  if (opts.help) {
    log(USAGE);
    return;
  }

  // Cheap, local and credential-free, so it happens before anything else.
  const fromFile = opts.from ? loadCandidatesFile(opts.from) : null;

  const writing = opts.confirmed;
  // `--out=` stops before the "what's already seeded?" lookup, so it never
  // touches Firestore — which means the review step works on a laptop with no
  // service-account key anywhere near it. Every other run needs credentials,
  // either to write or to read the existing osmIds it must not duplicate.
  const needsFirestore = !opts.out;

  assertProjectEnv({ needsCredentials: needsFirestore });

  let db = null;
  if (needsFirestore) {
    try {
      admin = require('firebase-admin');
    } catch (err) {
      fail(
        "Cannot load 'firebase-admin'.\n" +
          '         Run `npm install` in the scripts/ directory first. See scripts/README.md.'
      );
    }
    const app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: EXPECTED_PROJECT_ID,
    });
    assertResolvedProject(app);
    db = admin.firestore();
  }

  rule('=');
  log(`  ThrottleIQ places seed — project '${EXPECTED_PROJECT_ID}'`);
  log(
    writing
      ? '  MODE: WRITING FOR REAL. New documents will be created.'
      : '  MODE: dry run (default). Nothing will be written.'
  );
  log(
    `  Area: ${opts.bbox.south},${opts.bbox.west},${opts.bbox.north},${opts.bbox.east}` +
      `   Categories: ${opts.categories.join(', ')}`
  );
  rule('=');
  log('');

  // -------------------------------------------------------------------------
  // 1. Collect candidates
  // -------------------------------------------------------------------------

  let candidates;
  let rawCount;

  if (fromFile) {
    candidates = fromFile.candidates;
    rawCount = fromFile.total;
    const skipped = fromFile.total - candidates.length;
    log(
      `  Read ${opts.from} … ${plural(candidates.length, 'candidate', 'candidates')}`
    );
    if (skipped > 0) {
      warn(
        `    ! skipped ${skipped} entr${skipped === 1 ? 'y' : 'ies'} ` +
          'missing a name, category or coordinates'
      );
    }
  } else {
    process.stdout.write('  Querying Overpass … ');
    let elements;
    try {
      elements = await fetchOverpass(buildQuery(opts.bbox, opts.categories), opts.endpoint);
    } catch (err) {
      log('FAILED');
      fail(
        `${err.message}\n` +
          '         Overpass is a free shared service and does throttle. Wait a few\n' +
          '         minutes and re-run, or pass --endpoint= for a mirror.'
      );
    }
    rawCount = elements.length;
    candidates = elements.map(parseElement).filter(Boolean);
    log(`${plural(rawCount, 'element', 'elements')} → ${candidates.length} usable`);
  }

  if (candidates.length === 0) {
    log('');
    log('  Nothing to seed. Check the bounding box and categories.');
    return;
  }

  if (opts.dedupe) {
    const result = dedupeCandidates(candidates);
    if (result.dropped > 0) {
      log(
        `  Merging duplicates … ${plural(result.dropped, 'entry', 'entries')} ` +
          'mapped twice (node + way)'
      );
    }
    candidates = result.candidates;
  }

  // -------------------------------------------------------------------------
  // 2. Report what came back — the honest look before anything is written
  // -------------------------------------------------------------------------

  const byCategory = countBy(candidates, 'category');
  const unnamed = candidates.filter((c) => c._named === false).length;

  log('');
  log('  Found:');
  for (const category of CATEGORIES) {
    if (!opts.categories.includes(category)) continue;
    log(`    ${category.padEnd(10)} ${String(byCategory[category] || 0).padStart(6)}`);
  }
  if (unnamed > 0) {
    log('');
    log(
      `  ${unnamed} of these have no name in OSM and will be created as ` +
        '"Fuel"/"Garage"/"Parts".'
    );
    log('    That is what the in-app importer does too, but a screenful of');
    log('    identically-named pins is worth knowing about before you write them.');
  }

  // A standing caveat about the source, not a problem with this run.
  log('');
  log('  Note: OSM coverage of Dhaka is uneven — chain petrol stations are mapped');
  log('  well, small independent garages and parts counters much less so. Expect');
  log('  the largest list freely available, not a complete one.');

  if (opts.out) {
    const payload = {
      generatedFor: EXPECTED_PROJECT_ID,
      bbox: opts.bbox,
      categories: opts.categories,
      counts: byCategory,
      places: candidates,
    };
    fs.writeFileSync(opts.out, `${JSON.stringify(payload, null, 2)}\n`);
    log('');
    log(`  Wrote ${candidates.length} candidates to ${opts.out} — nothing was sent to Firestore.`);
    log('  Read it, delete anything that is junk, then:');
    log(`    node seed_dhaka_places.js --from=${opts.out} --yes-i-really-mean-it`);
    log('');
    return;
  }

  // -------------------------------------------------------------------------
  // 3. Skip what is already there
  // -------------------------------------------------------------------------

  let newCandidates = candidates;
  if (db) {
    process.stdout.write('  Checking against existing places … ');
    let existing;
    try {
      existing = await fetchExistingOsmIds(db, candidates.map((c) => c.osmId));
    } catch (err) {
      log('FAILED');
      fail(
        `${err.message}\n` +
          '         Could not read the places collection, so there is no way to tell\n' +
          '         what is already seeded. Refusing to write and risk duplicates.'
      );
    }
    newCandidates = candidates.filter((c) => !existing.has(c.osmId));
    log(
      `${plural(existing.size, 'already present', 'already present')}, ` +
        `${plural(newCandidates.length, 'new', 'new')}`
    );
  }

  if (opts.limit && newCandidates.length > opts.limit) {
    log(
      `  --limit=${opts.limit}: holding back ${newCandidates.length - opts.limit} of ` +
        `${newCandidates.length} new places. Re-run to continue where this leaves off.`
    );
    newCandidates = newCandidates.slice(0, opts.limit);
  }

  // -------------------------------------------------------------------------
  // 4. Write
  // -------------------------------------------------------------------------

  const verified = !opts.unverified;
  let result = { written: 0, commits: 0 };

  log('');
  if (newCandidates.length === 0) {
    log('  Everything found is already in the directory. Nothing to do.');
  } else if (!writing) {
    log(`  ${plural(newCandidates.length, 'place', 'places')} would be created,`);
    log(
      `  as createdBy='${SEED_AUTHOR}', verified:${verified}, ` +
        'geohash precision 9.'
    );
    log('');
    log('  Sample of what would be written:');
    for (const candidate of newCandidates.slice(0, 5)) {
      const doc = toPlaceDocument(candidate, { verified, createdAt: null });
      log(
        `    ${doc.category.padEnd(7)} ${doc.geohash}  ${doc.name}` +
          `${doc.address ? ` — ${doc.address}` : ''}  [${doc.osmId}]`
      );
    }
    if (newCandidates.length > 5) log(`    … and ${newCandidates.length - 5} more`);
  } else {
    log(`  Creating ${plural(newCandidates.length, 'place', 'places')} in 5 seconds.`);
    log('  Ctrl-C now if this is not what you meant.');
    log('  (Interrupting is safe — re-running skips whatever already landed.)');
    log('');
    await sleep(5000);
    try {
      result = await writePlaces(db, newCandidates, { verified });
    } catch (err) {
      log('');
      warn(`  ! Write failed partway: ${err.message}`);
      warn('  ! Re-run the script — already-created places are skipped by osmId.');
      process.exitCode = 1;
      return;
    }
  }

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------

  log('');
  rule('=');
  log(writing ? '  SUMMARY — created' : '  SUMMARY — dry run, nothing was written');
  rule('=');
  log(`  ${'osm elements returned'.padEnd(24)} ${String(rawCount).padStart(8)}`);
  log(`  ${'usable candidates'.padEnd(24)} ${String(candidates.length).padStart(8)}`);
  log(`  ${'new (not already seeded)'.padEnd(24)} ${String(newCandidates.length).padStart(8)}`);
  if (writing) {
    log(`  ${'created'.padEnd(24)} ${String(result.written).padStart(8)}`);
    log(`  ${'batches'.padEnd(24)} ${String(result.commits).padStart(8)}`);
  }
  rule('=');
  log('');

  if (writing) {
    log('  Done. Re-run the dry run to confirm it reads back as 0 new.');
    log('  To undo this batch, delete the places whose');
    log(`  createdBy == '${SEED_AUTHOR}'.`);
  } else {
    log('  This was a DRY RUN — nothing was written.');
    log('  To create these places, re-run with --yes-i-really-mean-it .');
  }
  log('');
}

// Guarded so `require()`ing this file for its pure helpers (see the exports
// below) doesn't fire a live Overpass query and a Firestore connection as a
// side effect.
if (require.main === module) {
  main().catch((err) => {
    console.error('\n  UNEXPECTED FAILURE');
    console.error(err && err.stack ? err.stack : err);
    console.error(
      '\n  Nothing further was attempted. The script is resumable — fix the cause' +
        '\n  and run it again; places already created are skipped by their OSM id.\n'
    );
    process.exit(1);
  });
}

// Exported for the unit test in scripts/test/seed_dhaka_places.test.js — the
// pure mapping functions, which are the part worth testing without a live
// Overpass call or a Firestore connection (the same reasoning that makes
// `OverpassService.parseElement` public rather than private).
module.exports = {
  geohashEncode,
  parseElement,
  categoryFor,
  addressFrom,
  dedupeCandidates,
  toPlaceDocument,
  buildQuery,
  parseBbox,
  SEED_AUTHOR,
  DHAKA_BBOX,
  TAG_RULES,
};
