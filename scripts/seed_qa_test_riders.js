#!/usr/bin/env node
'use strict';

/**
 * seed_qa_test_riders.js — creates fabricated QA/test rider accounts so the
 * Social feed, forums and garage screens have realistic-looking content to
 * test against instead of an empty beta app.
 *
 * Creates (by default) 30 Firebase Auth accounts, each with:
 *   - a `users/{uid}` public profile + a claimed `usernames/{handle}`
 *   - one bike in `users/{uid}/bikes`, drawn from a 30-entry Bangladesh
 *     market catalog spanning commuter (Honda CB Shine 125) to high-range
 *     (Kawasaki Z400, KTM RC 390, ...)
 *   - a handful of backdated rides in `users/{uid}/rides`
 *   - a couple of those rides shared to the public feed (top-level `rides`)
 *   - two forum posts each (top-level `forums/{forumId}/posts`) — one in the
 *     bike's own model forum, one in a general topic forum
 *
 * Every document this script writes carries `qaSeed: true` (and every Auth
 * account uses the `@qa-seed.invalid` email domain — `.invalid` is the IANA-
 * reserved TLD for exactly this, RFC 2606). Both make the whole batch easy to
 * find again and safe to tell apart from real riders. See
 * `cleanup_qa_test_riders.js` to remove it.
 *
 * ---------------------------------------------------------------------------
 * This writes fabricated but PUBLICLY VISIBLE content (shared rides, forum
 * posts) into the same 'throttleiqfb' project real beta testers use — there
 * is no separate staging project configured for this repo. Real testers will
 * see these posts in the Social feed and in forums until cleaned up.
 * ---------------------------------------------------------------------------
 *
 * Safety design (same posture as the other scripts here):
 *   - --dry-run is the DEFAULT, and needs no credentials at all: it generates
 *     every rider/bike/ride/post payload in memory and prints a summary plus
 *     one full sample rider, without touching Firebase Auth or Firestore.
 *   - Nothing is created without --yes-i-really-mean-it, which does require
 *     FIREBASE_PROJECT_ID=throttleiqfb and GOOGLE_APPLICATION_CREDENTIALS.
 *   - Idempotent-ish and resumable: each rider's Auth account + docs are
 *     created together; if the run is interrupted, re-running skips any
 *     email that Firebase Auth already has (createUser fails with
 *     'auth/email-already-exists' and that rider is logged as skipped rather
 *     than aborting the run).
 *
 * Usage:
 *   node seed_qa_test_riders.js                              # dry run, no creds needed
 *   FIREBASE_PROJECT_ID=throttleiqfb node seed_qa_test_riders.js --yes-i-really-mean-it
 *
 * Flags:
 *   --dry-run                 Generate + print only (default). No credentials needed.
 *   --yes-i-really-mean-it    Actually create Auth users + Firestore docs.
 *   --count=N                 How many riders to create (default 30, max 30 —
 *                             the catalog has exactly 30 distinct bikes so every
 *                             rider gets a different one).
 *   --non-interactive         Skip the typed confirmation prompt (scripted/CI use).
 *   --help
 */

let admin;

const {
  QA_EMAIL_DOMAIN,
  QA_PASSWORD,
  BIKE_CATALOG,
  TOPICS,
  bikeForumSlug,
  generalForumSlug,
  tierForCc,
} = require('./qa_seed_catalog');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'SEED QA TEST RIDERS';
const BATCH_COMMIT_SIZE = 400;

const RIDER_NAMES = [
  'Tanvir Ahmed', 'Nusrat Jahan', 'Rakibul Islam', 'Farhana Akter', 'Shakil Hasan',
  'Mitu Rahman', 'Imran Hossain', 'Sadia Islam', 'Kamrul Hasan', 'Rumana Akter',
  'Mahmudul Hasan', 'Sabrina Yasmin', 'Arif Hossain', 'Tania Sultana', 'Nayeem Chowdhury',
  'Jannatul Ferdous', 'Habibur Rahman', 'Shirin Akter', 'Rezaul Karim', 'Mahfuza Begum',
  'Sohel Rana', 'Nasrin Sultana', 'Anisur Rahman', 'Farzana Haque', 'Jubayer Ahmed',
  'Sultana Razia', 'Emon Khan', 'Rukhsana Parvin', 'Riyad Hossain', 'Moushumi Akter',
];

const CITIES = [
  { name: 'Dhaka', lat: 23.8103, lng: 90.4125 },
  { name: 'Chattogram', lat: 22.3569, lng: 91.7832 },
  { name: 'Sylhet', lat: 24.8949, lng: 91.8687 },
  { name: 'Rajshahi', lat: 24.3745, lng: 88.6042 },
  { name: "Cox's Bazar", lat: 21.4272, lng: 92.0058 },
  { name: 'Bogura', lat: 24.8465, lng: 89.3773 },
  { name: 'Cumilla', lat: 23.4607, lng: 91.1809 },
  { name: 'Khulna', lat: 22.8456, lng: 89.5403 },
  { name: 'Rangpur', lat: 25.7439, lng: 89.2752 },
  { name: 'Mymensingh', lat: 24.7471, lng: 90.4203 },
];

// ---------------------------------------------------------------------------
// Small deterministic-ish helpers (Math.random is fine — this is a plain
// Node script, not a Workflow script).
// ---------------------------------------------------------------------------

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomFloat(min, max, decimals = 1) {
  const v = Math.random() * (max - min) + min;
  return Number(v.toFixed(decimals));
}

function pick(arr) {
  return arr[randomInt(0, arr.length - 1)];
}

function daysAgo(n) {
  const d = new Date();
  d.setTime(d.getTime() - n * 24 * 60 * 60 * 1000);
  return d;
}

const TIER_STATS = {
  commuter: {
    avgSpeed: [30, 42], maxSpeed: [65, 85], mileage: [45, 60],
    rideDistKm: [5, 35], totalDistKm: [1500, 9000],
  },
  midrange: {
    avgSpeed: [40, 55], maxSpeed: [95, 125], mileage: [32, 45],
    rideDistKm: [8, 70], totalDistKm: [2500, 15000],
  },
  highrange: {
    avgSpeed: [50, 70], maxSpeed: [120, 180], mileage: [16, 28],
    rideDistKm: [15, 120], totalDistKm: [3000, 20000],
  },
};

const TIER_COMMENT = {
  commuter: 'Handles Dhaka traffic and potholes without any drama, and fuel costs stay low.',
  midrange: 'Good balance of power for overtaking on the highway and still manageable in city traffic.',
  highrange: 'Definitely have to respect the power on wet roads during monsoon, but an absolute blast on the highway.',
};

// ---------------------------------------------------------------------------
// Rider generation — builds the full in-memory payload for one rider. No
// network calls happen here, which is what makes --dry-run credential-free.
// ---------------------------------------------------------------------------

function slugifyHandleBase(name) {
  return name.split(' ')[0].toLowerCase().replace(/[^a-z0-9]/g, '');
}

function buildRider(index, bike) {
  const fullName = RIDER_NAMES[index % RIDER_NAMES.length];
  const city = CITIES[index % CITIES.length];
  const tripCity = pick(CITIES.filter((c) => c.name !== city.name));
  const tier = tierForCc(bike.cc);
  const stats = TIER_STATS[tier];

  const handle = `${slugifyHandleBase(fullName)}${String(index + 1).padStart(2, '0')}`;
  const email = `${handle}@${QA_EMAIL_DOMAIN}`;
  const bikeName = `${bike.brand} ${bike.model}`;

  const accountAgeDays = randomInt(120, 540); // 4-18 months old
  const createdAt = daysAgo(accountAgeDays);
  const bikeAddedAt = daysAgo(accountAgeDays - randomInt(0, 3));

  // ---- rides (users/{uid}/rides) ----
  const rideCount = randomInt(4, 8);
  const rides = [];
  let totalDistanceM = 0;
  let lastRideAt = null;
  for (let i = 0; i < rideCount; i++) {
    const rideAgeDays = randomFloat(2, accountAgeDays - 1, 2);
    const startTime = daysAgo(rideAgeDays);
    const distanceKm = randomFloat(...stats.rideDistKm, 1);
    const avgSpeedKmh = randomFloat(...stats.avgSpeed, 1);
    const maxSpeedKmh = randomFloat(Math.max(avgSpeedKmh + 5, stats.maxSpeed[0]), stats.maxSpeed[1], 1);
    const avgSpeedMs = Number((avgSpeedKmh / 3.6).toFixed(2));
    const maxSpeedMs = Number((maxSpeedKmh / 3.6).toFixed(2));
    const durationS = Math.max(60, Math.round((distanceKm * 1000) / avgSpeedMs));
    const movingS = Math.round(durationS * randomFloat(0.85, 0.97, 2));
    const endTime = new Date(startTime.getTime() + durationS * 1000);

    rides.push({
      id: `qaride_${handle}_${i}`,
      bikeId: `qabike_${handle}`,
      startTime,
      endTime,
      distanceM: Math.round(distanceKm * 1000),
      avgSpeedMs,
      maxSpeedMs,
      durationS,
      movingS,
      hardBrakeCount: randomInt(0, tier === 'highrange' ? 4 : 2),
      rapidAccelCount: randomInt(0, tier === 'highrange' ? 6 : 3),
      highJerkCount: randomInt(0, 2),
    });

    totalDistanceM += Math.round(distanceKm * 1000);
    if (!lastRideAt || endTime > lastRideAt) lastRideAt = endTime;
  }
  rides.sort((a, b) => a.startTime - b.startTime);

  // ---- bike (users/{uid}/bikes) ----
  const bikeDoc = {
    id: `qabike_${handle}`,
    brand: bike.brand,
    model: bike.model,
    year: bike.year,
    cc: bike.cc,
    tier,
    totalDistanceM,
    rideCount,
    lastRideAt,
    odometerKm: randomInt(200, 3000),
    createdAt: bikeAddedAt,
  };

  // ---- shared rides (top-level `rides` feed) — 1-2 of the rides above ----
  const shareCount = Math.min(rides.length, randomInt(1, 2));
  const sharedRides = [];
  for (const ride of rides.slice(-shareCount)) {
    const distanceKm = ride.distanceM / 1000;
    sharedRides.push({
      id: `qashare_${handle}_${ride.id}`,
      bikeId: bikeDoc.id,
      bikeName,
      bikeType: `${bike.cc}cc`,
      rideDate: ride.startTime,
      createdAt: ride.endTime,
      distanceKm,
      durationSeconds: ride.durationS,
      maxSpeedKmh: Number((ride.maxSpeedMs * 3.6).toFixed(1)),
      caption: `${distanceKm.toFixed(1)} km ride around ${city.name} on the ${bikeName}.`,
      likes: randomInt(0, 24),
      comments: randomInt(0, 6),
      upvotes: randomInt(0, 18),
      downvotes: randomInt(0, 2),
    });
  }

  // ---- forum posts ----
  const odometer = Math.round(bikeDoc.odometerKm + totalDistanceM / 1000);
  const months = Math.max(1, Math.round(accountAgeDays / 30));
  const mileage = randomFloat(...stats.mileage, 1);
  const tripDistance = randomInt(...stats.rideDistKm.map((v) => v * 2));
  const avgSpeed = randomFloat(...stats.avgSpeed, 1);
  const maxSpeed = randomFloat(...stats.maxSpeed, 1);

  const bikeForumTemplates = [
    {
      title: `${months} months with the ${bikeName} — full review`,
      body: `Been riding my ${bike.brand} ${bike.model} (${bike.cc}cc) around ${city.name} for about ` +
        `${months} months now, clocked ${odometer} km on the odometer. Getting around ${mileage} km/l in ` +
        `mixed city and highway riding. ${TIER_COMMENT[tier]} Overall really happy with the ${bike.brand} ` +
        `after-sales support in ${city.name}. Anyone else running the same bike — what mileage are you getting?`,
    },
    {
      title: `What mileage should I expect from a ${bikeName}?`,
      body: `Just picked up a ${bike.year} ${bike.brand} ${bike.model} and doing mostly ${city.name} city ` +
        `riding with the occasional highway trip. Getting around ${mileage} km/l so far — is that normal for ` +
        `this bike or should I get the carb/injector checked? Riding style is pretty relaxed, mostly under ` +
        `${maxSpeed.toFixed(0)} km/h.`,
    },
    {
      title: `First service done on my ${bikeName} — notes`,
      body: `Just got the first service done on my ${bike.brand} ${bike.model} at ${odometer} km. Chain, oil, ` +
        `and brake pads all checked out fine at the shop in ${city.name}. Anyone have a recommended service ` +
        `interval for this model?`,
    },
  ];

  const generalTopic = pick(TOPICS);
  const generalForumTemplates = {
    'Road Trips': {
      title: `Weekend ride to ${tripCity.name} on the ${bikeName}`,
      body: `Took the ${bike.brand} ${bike.model} out for a ${tripDistance} km round trip to ${tripCity.name} ` +
        `last weekend. Left ${city.name} early morning to beat the traffic. Average speed came out to about ` +
        `${avgSpeed.toFixed(0)} km/h with a top speed of ${maxSpeed.toFixed(0)} km/h on the open stretch. Bike ` +
        `felt planted the whole way, no issues at all. Definitely doing this route again.`,
    },
    'Maintenance': {
      title: `Chain and sprocket check on the ${bikeName}`,
      body: `${odometer} km in on my ${bike.brand} ${bike.model} and the chain was starting to sound a bit ` +
        `dry, so cleaned and lubed it this weekend in ${city.name}. Sprockets still look fine. What KM mark ` +
        `is everyone replacing theirs at?`,
    },
    'Mileage Talk': {
      title: `${mileage} km/l on the ${bikeName} — good or bad?`,
      body: `Been logging fuel fill-ups on my ${bike.brand} ${bike.model} for the last ${months} months, mostly ` +
        `${city.name} city riding. Averaging ${mileage} km/l. Curious how that compares to others on this bike.`,
    },
    'Mods & Accessories': {
      title: `Any recommended mods for the ${bikeName}?`,
      body: `Riding a ${bike.brand} ${bike.model} for daily commute in ${city.name} plus the odd weekend trip. ` +
        `Thinking about a windscreen and some crash guards. Anyone running mods on this bike who can share what ` +
        `actually held up on Bangladeshi roads?`,
    },
  };

  const forumPosts = [
    { forumType: 'bikeModel', forumId: bikeForumSlug(bike.brand, bike.model), forumDisplayName: bikeName, brand: bike.brand, model: bike.model, ...pick(bikeForumTemplates), createdAt: daysAgo(randomFloat(1, accountAgeDays - 1, 2)) },
    { forumType: 'general', forumId: generalForumSlug(generalTopic), forumDisplayName: generalTopic, topic: generalTopic, ...generalForumTemplates[generalTopic], createdAt: daysAgo(randomFloat(1, accountAgeDays - 1, 2)) },
  ];

  return {
    index,
    handle,
    email,
    displayName: fullName,
    bio: `${bikeName} rider based in ${city.name}. QA test account.`,
    photoUrl: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(handle)}`,
    city: city.name,
    createdAt,
    bike: bikeDoc,
    rides,
    sharedRides,
    forumPosts,
  };
}

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------

const log = (...args) => console.log(...args);
const warn = (...args) => console.warn(...args);

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function rule(char = '-') {
  log(char.repeat(66));
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const opts = { confirmed: false, help: false, nonInteractive: false, count: BIKE_CATALOG.length };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--yes-i-really-mean-it') opts.confirmed = true;
    else if (arg === '--dry-run') {
      // explicit form of the default
    } else if (arg === '--non-interactive') opts.nonInteractive = true;
    else if (arg.startsWith('--count=')) opts.count = parseInt(arg.slice('--count='.length), 10);
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  if (!Number.isInteger(opts.count) || opts.count < 1 || opts.count > BIKE_CATALOG.length) {
    throw new Error(`--count must be an integer between 1 and ${BIKE_CATALOG.length} (the catalog size).`);
  }
  return opts;
}

const USAGE = `
seed_qa_test_riders.js — create fabricated QA/test rider accounts with
Bangladesh-market bikes (commuter to high-range), backdated ride history, and
forum posts.

  node seed_qa_test_riders.js
      Dry run (the default). Generates everything in memory and prints a
      summary + one sample rider. No credentials needed, nothing is sent
      anywhere.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node seed_qa_test_riders.js --yes-i-really-mean-it
      Actually create the Auth accounts and Firestore documents. This writes
      PUBLICLY VISIBLE content (shared rides, forum posts) into the live
      '${EXPECTED_PROJECT_ID}' project.

Flags:
  --dry-run                 Generate + print only (default).
  --yes-i-really-mean-it    Required to actually create anything.
  --count=N                 Riders to create, 1-${BIKE_CATALOG.length} (default ${BIKE_CATALOG.length}).
  --non-interactive         Skip the typed confirmation prompt (scripted/CI use).
  --help                    This message.

Environment (only needed for a real run):
  FIREBASE_PROJECT_ID              Must equal '${EXPECTED_PROJECT_ID}'.
  GOOGLE_APPLICATION_CREDENTIALS   Path to a service-account JSON key.

Every account uses the @${QA_EMAIL_DOMAIN} email domain (password: ${QA_PASSWORD})
and every document carries qaSeed: true. See cleanup_qa_test_riders.js to
remove the whole batch.
`;

// ---------------------------------------------------------------------------
// Guards (same shape as reset_beta_data.js / seed_dhaka_places.js)
// ---------------------------------------------------------------------------

function assertProjectEnv() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    fail(`FIREBASE_PROJECT_ID is not set. Set it to '${EXPECTED_PROJECT_ID}' to run for real.`);
  }
  if (projectId !== EXPECTED_PROJECT_ID) {
    fail(`FIREBASE_PROJECT_ID is '${projectId}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  }
  return projectId;
}

function assertResolvedProject(app) {
  const resolved = (app.options && app.options.projectId) ||
    process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
  if (resolved !== EXPECTED_PROJECT_ID) {
    fail(`The supplied credentials resolve to project '${resolved}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  }
}

async function confirmRealWrite({ nonInteractive }) {
  if (nonInteractive) {
    warn('  NOTE   --non-interactive: skipping the typed confirmation prompt.\n');
    return;
  }
  const readline = require('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let typed;
  try {
    typed = await rl.question(`  Type '${CONFIRMATION_PHRASE}' to proceed, anything else to abort: `);
  } finally {
    rl.close();
  }
  if (typed.trim() !== CONFIRMATION_PHRASE) {
    fail('Confirmation phrase did not match. Nothing was created.');
  }
  log('');
}

// ---------------------------------------------------------------------------
// Firestore writer for one rider
// ---------------------------------------------------------------------------

async function writeRider(db, auth, admin, rider) {
  const userRecord = await auth.createUser({
    email: rider.email,
    password: QA_PASSWORD,
    displayName: rider.displayName,
    photoURL: rider.photoUrl,
  });
  const uid = userRecord.uid;
  await auth.setCustomUserClaims(uid, { qaSeed: true });

  const batch = db.batch();
  const Timestamp = admin.firestore.Timestamp;

  batch.set(db.collection('usernames').doc(rider.handle), { uid, qaSeed: true });

  batch.set(db.collection('users').doc(uid), {
    displayName: rider.displayName,
    username: rider.handle,
    usernameLower: rider.handle,
    bio: rider.bio,
    photoUrl: rider.photoUrl,
    email: rider.email,
    emailLower: rider.email.toLowerCase(),
    followerCount: 0,
    followingCount: 0,
    visibility: 'public',
    bikesVisibility: 'public',
    publicStats: {
      totalDistanceKm: rider.bike.totalDistanceM / 1000,
      totalRides: rider.rides.length,
      badgeIds: [],
    },
    createdAt: Timestamp.fromDate(rider.createdAt),
    updatedAt: Timestamp.fromDate(rider.createdAt),
    qaSeed: true,
  });

  const bikeRef = db.collection('users').doc(uid).collection('bikes').doc(rider.bike.id);
  batch.set(bikeRef, {
    id: rider.bike.id,
    user_id: uid,
    brand: rider.bike.brand,
    model: rider.bike.model,
    year: rider.bike.year,
    cc: rider.bike.cc,
    image_path: null,
    is_active: 1,
    total_distance_m: rider.bike.totalDistanceM,
    ride_count: rider.bike.rideCount,
    last_ride_at: rider.bike.lastRideAt ? rider.bike.lastRideAt.toISOString() : null,
    odometer_km: rider.bike.odometerKm,
    synced: 1,
    created_at: rider.bike.createdAt.toISOString(),
    syncedAt: Timestamp.fromDate(rider.bike.createdAt),
    // No qaSeed flag here on purpose: CloudRepository.downloadBikes() inserts
    // this doc's fields straight into the local SQLite `bikes` table, which
    // has a fixed column set — an unrecognized key throws there. The parent
    // users/{uid} doc's qaSeed flag is what cleanup_qa_test_riders.js uses to
    // find and recursively purge this whole subtree anyway.
  });

  for (const ride of rider.rides) {
    const rideRef = db.collection('users').doc(uid).collection('rides').doc(ride.id);
    batch.set(rideRef, {
      id: ride.id,
      user_id: uid,
      bike_id: ride.bikeId,
      start_time: ride.startTime.toISOString(),
      end_time: ride.endTime.toISOString(),
      distance_m: ride.distanceM,
      avg_speed_ms: ride.avgSpeedMs,
      max_speed_ms: ride.maxSpeedMs,
      duration_s: ride.durationS,
      moving_s: ride.movingS,
      hard_brake_count: ride.hardBrakeCount,
      rapid_accel_count: ride.rapidAccelCount,
      high_jerk_count: ride.highJerkCount,
      status: 'completed',
      map_snapshot_path: null,
      is_auto: 0,
      bike_confidence: 'high',
      synced: 1,
      created_at: ride.startTime.toISOString(),
      syncedAt: Timestamp.fromDate(ride.endTime),
      // Same reasoning as the bike doc above: no qaSeed flag, since
      // downloadRides() inserts this straight into the local SQLite `rides`
      // table by column name.
    });
  }

  for (const shared of rider.sharedRides) {
    const shareRef = db.collection('rides').doc(shared.id);
    batch.set(shareRef, {
      id: shared.id,
      userId: uid,
      userName: rider.displayName,
      userPhotoUrl: rider.photoUrl,
      bikeId: shared.bikeId,
      bikeName: shared.bikeName,
      bikeType: shared.bikeType,
      rideDate: Timestamp.fromDate(shared.rideDate),
      distanceKm: shared.distanceKm,
      durationSeconds: shared.durationSeconds,
      maxSpeedKmh: shared.maxSpeedKmh,
      polyline: [],
      mapSnapshotUrl: null,
      likes: shared.likes,
      comments: shared.comments,
      createdAt: Timestamp.fromDate(shared.createdAt),
      audience: 'public',
      allowedUserIds: [],
      routeId: null,
      photoUrls: [],
      photoUrl: null,
      caption: shared.caption,
      upvotes: shared.upvotes,
      downvotes: shared.downvotes,
      qaSeed: true,
    });
  }

  // Forum docs are get-or-create, so they need to be resolved (and possibly
  // created) before the batch that references their postCount. Kept outside
  // the main batch since getOrCreateForum-equivalent needs its own read.
  const forumPostRefs = [];
  for (const post of rider.forumPosts) {
    const forumRef = db.collection('forums').doc(post.forumId);
    const forumSnap = await forumRef.get();
    if (!forumSnap.exists) {
      const forumPayload = post.forumType === 'bikeModel'
        ? {
            type: 'bikeModel', brand: post.brand, model: post.model,
            displayName: post.forumDisplayName, followerCount: 0, postCount: 0,
            createdAt: Timestamp.fromDate(rider.createdAt), qaSeedCreatedForum: true,
          }
        : {
            type: 'general', brand: '', model: null, topic: post.topic,
            displayName: post.forumDisplayName, followerCount: 0, postCount: 0,
            createdAt: Timestamp.fromDate(rider.createdAt), qaSeedCreatedForum: true,
          };
      await forumRef.set(forumPayload);
    }
    const postRef = forumRef.collection('posts').doc();
    batch.set(postRef, {
      forumId: post.forumId,
      userId: uid,
      userName: rider.displayName,
      userPhotoUrl: rider.photoUrl,
      title: post.title,
      body: post.body,
      createdAt: Timestamp.fromDate(post.createdAt),
      replyCount: 0,
      upvotes: randomInt(0, 15),
      downvotes: randomInt(0, 2),
      qaSeed: true,
    });
    batch.update(forumRef, { postCount: admin.firestore.FieldValue.increment(1) });
    forumPostRefs.push(postRef);
  }

  await batch.commit();
  return { uid, postCount: forumPostRefs.length };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

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

  const riders = [];
  for (let i = 0; i < opts.count; i++) {
    riders.push(buildRider(i, BIKE_CATALOG[i]));
  }

  const deleting = opts.confirmed; // naming kept consistent with the other scripts' `deleting`/`enabled` flag
  const writing = deleting;

  rule('=');
  log(`  ThrottleIQ QA test rider seed — ${riders.length} rider(s)`);
  log(writing ? '  MODE: WRITING FOR REAL to a live project.' : '  MODE: dry run (default). Nothing will be created.');
  rule('=');
  log('');

  if (!writing) {
    // Dry run needs no credentials — just show what would be created.
    let totalRides = 0, totalShared = 0, totalPosts = 0;
    for (const r of riders) {
      totalRides += r.rides.length;
      totalShared += r.sharedRides.length;
      totalPosts += r.forumPosts.length;
    }
    log(`  Riders:            ${riders.length}`);
    log(`  Bikes:             ${riders.length} (one each, ${new Set(BIKE_CATALOG.slice(0, riders.length).map((b) => tierForCc(b.cc))).size} tiers)`);
    log(`  Backdated rides:   ${totalRides}`);
    log(`  Shared to feed:    ${totalShared}`);
    log(`  Forum posts:       ${totalPosts}`);
    log(`  Email domain:      @${QA_EMAIL_DOMAIN}  (password: ${QA_PASSWORD})`);
    log('');
    rule('-');
    log('  Sample rider:');
    rule('-');
    log(JSON.stringify(riders[0], null, 2));
    log('');
    log('  This was a DRY RUN — nothing was created, no credentials were used.');
    log(`  To actually create these, set FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} and`);
    log('  GOOGLE_APPLICATION_CREDENTIALS, then re-run with --yes-i-really-mean-it.');
    log('');
    return;
  }

  const projectId = assertProjectEnv();
  try {
    admin = require('firebase-admin');
  } catch (err) {
    fail("Cannot load 'firebase-admin'.\n         Run `npm install` in the scripts/ directory first.");
  }
  const app = admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId });
  assertResolvedProject(app);
  const db = admin.firestore();
  const auth = admin.auth();

  await confirmRealWrite({ nonInteractive: opts.nonInteractive });
  log('  Starting in 5 seconds. Ctrl-C now if this is not what you meant.');
  log('  (This creates real Auth accounts and PUBLIC posts other testers will see.)');
  log('');
  await new Promise((resolve) => setTimeout(resolve, 5000));

  let created = 0, skipped = 0, failed = 0;
  for (const rider of riders) {
    process.stdout.write(`  ${rider.handle} (${rider.bike.brand} ${rider.bike.model}) … `);
    try {
      const result = await writeRider(db, auth, admin, rider);
      created += 1;
      log(`created (${rider.rides.length} rides, ${rider.sharedRides.length} shared, ${result.postCount} posts)`);
    } catch (err) {
      if (err && err.code === 'auth/email-already-exists') {
        skipped += 1;
        log('SKIPPED (email already exists — already seeded)');
      } else {
        failed += 1;
        log('FAILED');
        warn(`    ! ${err && err.message ? err.message : err}`);
      }
    }
  }

  log('');
  rule('=');
  log('  SUMMARY');
  rule('=');
  log(`  created  ${created}`);
  log(`  skipped  ${skipped}`);
  log(`  failed   ${failed}`);
  rule('=');
  log('');
  log('  Run cleanup_qa_test_riders.js (dry-run first) when you are done testing.');
  log('');
}

main().catch((err) => {
  console.error('\n  UNEXPECTED FAILURE');
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
});
