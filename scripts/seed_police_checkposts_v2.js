#!/usr/bin/env node
'use strict';

/**
 * seed_police_checkposts_v2.js — populates the `places` collection in ThrottleIQ
 * with additional frequent DMP traffic checkposts and enforcement points in Dhaka.
 *
 * Batch 2 — 25 new locations across areas not covered by seed_police_checkposts.js:
 *   - Uttara / Abdullahpur / Kamarpara / Dhaur (northern city entry)
 *   - Malibagh / Mouchak / Rampura / Badda / Khilgaon (eastern corridor)
 *   - Lalbagh / Kotwali / Bangshal / Chawkbazar / Nababpur (old Dhaka)
 *   - Wari / Postogola / Demra / Jurain / Matuail (southern entry)
 *   - Basabo / Kamalapur / Sayedabad (Motijheel division)
 *   - Tejgaon / Begunbari / Nakhalpara (Tejgaon division)
 *   - Bosila / Mohammadpur Asad Ave (western)
 *   - Gulshan 2 / Baridhara Notun Bazar (Gulshan division)
 *
 * Safety posture:
 *   - --dry-run is the DEFAULT.
 *   - --yes-i-really-mean-it is required to write to Firestore.
 *   - Refuses to run unless project is 'throttleiqfb'.
 *   - Idempotent: checks existing osmId / name before inserting.
 *   - Attribution: createdBy: 'system:dmp-checkpost-seed-v2'.
 */

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const COLLECTION = 'places';
const SEED_AUTHOR = 'system:dmp-checkpost-seed-v2';

// ---------------------------------------------------------------------------
// Geohash encoding (Precision 9 matching ThrottleIQ GeohashUtils)
// ---------------------------------------------------------------------------
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function geohashEncode(lat, lng, precision = 9) {
  let latMin = -90.0, latMax = 90.0;
  let lngMin = -180.0, lngMax = 180.0;
  let hash = '';
  let isEven = true;
  let bits = 0, bit = 0;

  while (hash.length < precision) {
    if (isEven) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { bit |= 1 << (4 - bits); lngMin = mid; }
      else { lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { bit |= 1 << (4 - bits); latMin = mid; }
      else { latMax = mid; }
    }
    isEven = !isEven;
    if (bits < 4) { bits += 1; }
    else { hash += BASE32[bit]; bits = 0; bit = 0; }
  }
  return hash;
}

// ---------------------------------------------------------------------------
// Police Checkpost Dataset — Batch 2 (25 enforcement points)
// ---------------------------------------------------------------------------
const POLICE_CHECKPOSTS_V2 = [
  // ── Uttara / Abdullahpur / Dhaur (northern city entry) ──────────────────
  {
    slug: 'abdullahpur-bridge-entry',
    name: 'DMP Traffic Checkpost - Abdullahpur Bridge',
    latitude: 23.8955,
    longitude: 90.3985,
    address: 'Abdullahpur Bridge & Tongi Diversion Road. Primary northern city entry — checks for bike fitness certificates, helmets, and highway permits.',
    hours: '24/7 Shift Checks',
  },
  {
    slug: 'kamarpara-uttara-north',
    name: 'DMP Traffic Checkpost - Kamarpara (Uttara North)',
    latitude: 23.9050,
    longitude: 90.3960,
    address: 'Kamarpara Bazar entry junction, Uttara Division. Document checks for motorcycles & three-wheelers entering the city from the north.',
    hours: 'Daily 7am - 10pm',
  },
  {
    slug: 'dhaur-bridge-uttara',
    name: 'DMP Traffic Checkpost - Dhaur Bridge (Uttara Outskirts)',
    latitude: 23.9145,
    longitude: 90.4085,
    address: 'Dhaur Bridge north of Abdullahpur on the city boundary. Inter-district motorcycle checkpoint with DMP highway patrol co-operation.',
    hours: 'Daily 8am - 10pm',
  },
  {
    slug: 'uttara-sector3-roundabout',
    name: 'DMP Traffic Checkpost - Uttara Sector 3 Roundabout',
    latitude: 23.8775,
    longitude: 90.3958,
    address: 'Sector 3 circle on Dhaka–Mymensingh Highway near Rajuk Commercial Zone. Frequent licence & helmet drive by Uttara Traffic Division.',
    hours: 'Daily 10am - 9pm',
  },

  // ── Malibagh / Mouchak / Rampura / Badda / Khilgaon ────────────────────
  {
    slug: 'malibagh-railgate-crossing',
    name: 'DMP Traffic Checkpost - Malibagh Railgate',
    latitude: 23.7550,
    longitude: 90.4225,
    address: 'Malibagh Chowdhurypara Railgate level crossing. Bikes stopped at gate — licence, helmet, and registration checks.',
    hours: 'Daily Morning & Evening Rush',
  },
  {
    slug: 'mouchak-5way-crossing',
    name: 'DMP Traffic Checkpost - Mouchak Crossing',
    latitude: 23.7490,
    longitude: 90.4165,
    address: 'Mouchak 5-way crossing connecting Malibagh, Rampura, Shantinagar & Khilgaon. Sergeant checkpoint for signal violations and lane discipline.',
    hours: 'Daily 9am - 9pm',
  },
  {
    slug: 'rampura-bridge-south-foot',
    name: 'DMP Traffic Checkpost - Rampura Bridge (South)',
    latitude: 23.7582,
    longitude: 90.4310,
    address: 'South foot of Rampura Bridge over Balu River toward Badda. Overspeeding motorcycle checks & document inspection at bridge descent.',
    hours: 'Afternoon & Night Shifts',
  },
  {
    slug: 'badda-link-road-nadda',
    name: 'DMP Traffic Checkpost - Badda Link Road (Nadda)',
    latitude: 23.7848,
    longitude: 90.4298,
    address: 'Nadda intersection on Badda Link Road, Tejgaon–Gulshan corridor. Sergeant checkpoint for wrong-way bikes & commercial vehicle compliance.',
    hours: 'Daily Peak Hours',
  },
  {
    slug: 'khilgaon-flyover-east',
    name: 'DMP Traffic Checkpost - Khilgaon Flyover (East Ground)',
    latitude: 23.7425,
    longitude: 90.4300,
    address: 'Ground level at Khilgaon Flyover east end (Taltola side). Police post monitoring flyover-adjacent lane discipline and licence checks.',
    hours: 'Daily 8am - 8pm',
  },

  // ── Lalbagh / Kotwali / Bangshal / Chawkbazar / Nababpur (old Dhaka) ────
  {
    slug: 'chawkbazar-north-gate-old-dhaka',
    name: 'DMP Traffic Checkpost - Chawkbazar North Gate',
    latitude: 23.7200,
    longitude: 90.3995,
    address: 'North Gate of Chawkbazar junction (Islampur Rd & North-South Rd). Document checking in busy old Dhaka commercial zone.',
    hours: 'Daily 9am - 7pm',
  },
  {
    slug: 'bangshal-road-junction-kotwali',
    name: 'DMP Traffic Checkpost - Bangshal Road Junction',
    latitude: 23.7230,
    longitude: 90.4010,
    address: 'Bangshal Road & Nazimuddin Road junction near Kotwali Traffic Division. Regular bike and vehicle inspection point.',
    hours: 'Daily 9am - 5pm',
  },
  {
    slug: 'nababpur-sadarghat-approach',
    name: 'DMP Traffic Checkpost - Nababpur (Sadarghat Approach)',
    latitude: 23.7155,
    longitude: 90.3985,
    address: 'Nababpur Road approaching Sadarghat. Sergeant post for bikes carrying oversized goods and unlicensed riders in old Dhaka.',
    hours: 'Morning & Daytime Shifts',
  },

  // ── Wari / Postogola / Matuail / Demra / Jurain (southern entry) ────────
  {
    slug: 'postogola-bridge-north-approach',
    name: 'DMP Traffic Checkpost - Postogola Bridge (North Approach)',
    latitude: 23.7055,
    longitude: 90.4195,
    address: 'Postogola Bridge northern approach (Shyampur side). Checkpoint for bikes & vehicles entering Dhaka from south — fitness, tax token, licence.',
    hours: '24/7 Shift Checks',
  },
  {
    slug: 'jurain-shyampur-crossing',
    name: 'DMP Traffic Checkpost - Jurain / Shyampur Crossing',
    latitude: 23.7080,
    longitude: 90.4380,
    address: 'Jurain Bazar crossing on Shyampur Road (Jatrabari–Demra corridor). Mobile checkpost for motorcycle documents and helmet compliance.',
    hours: 'Daily Morning & Evening',
  },
  {
    slug: 'demra-staff-quarter-road',
    name: 'DMP Traffic Checkpost - Demra Staff Quarter',
    latitude: 23.7168,
    longitude: 90.4610,
    address: 'Demra Staff Quarter intersection on Demra Road. Sergeant presence for tax token, fitness certificate, and pillion helmet enforcement.',
    hours: 'Daily 9am - 8pm',
  },
  {
    slug: 'matuail-uloop-highway',
    name: 'DMP Traffic Checkpost - Matuail U-Loop (Highway)',
    latitude: 23.7005,
    longitude: 90.4440,
    address: 'Matuail U-loop exit on Dhaka–Chittagong Highway (Wari Division). Strict document inspection for bikes & trucks on the highway.',
    hours: 'Daily 8am - 10pm',
  },

  // ── Basabo / Kamalapur / Sayedabad (Motijheel division) ─────────────────
  {
    slug: 'basabo-kamalapur-backgate',
    name: 'DMP Traffic Checkpost - Basabo Road (Kamalapur Back Gate)',
    latitude: 23.7328,
    longitude: 90.4370,
    address: 'Basabo Road junction near Kamalapur Railway Station back gate. Motijheel Division checkpoint for document verification on commuter routes.',
    hours: 'Daily 8am - 8pm',
  },
  {
    slug: 'kamalapur-station-road-junction',
    name: 'DMP Traffic Checkpost - Kamalapur Station Road',
    latitude: 23.7352,
    longitude: 90.4260,
    address: 'Station Road & Airport Road junction at Kamalapur. Checks for bikes & CNGs — registration, driver licence, and unauthorised route violations.',
    hours: 'Daily Morning & Evening Rush',
  },

  // ── Tejgaon / Begunbari / Nakhalpara ────────────────────────────────────
  {
    slug: 'begunbari-tejgaon-traffic-box',
    name: 'DMP Traffic Checkpost - Begunbari (Tejgaon)',
    latitude: 23.7648,
    longitude: 90.4005,
    address: 'Begunbari Beel Road crossing beside DMP Tejgaon traffic box. Crackdown zone for illegal U-turns, lane violations, and bike registration.',
    hours: 'Daily Peak Hours',
  },
  {
    slug: 'nakhalpara-wireless-gate',
    name: 'DMP Traffic Checkpost - Nakhalpara Wireless Gate',
    latitude: 23.7710,
    longitude: 90.4070,
    address: 'Wireless Gate intersection, Nakhalpara. Tejgaon–Gulshan boundary checkpoint; licence & signal-jump enforcement.',
    hours: 'Daily 8am - 9pm',
  },
  {
    slug: 'tejgaon-industrial-area-entry',
    name: 'DMP Traffic Checkpost - Tejgaon Industrial Area Entry',
    latitude: 23.7685,
    longitude: 90.3920,
    address: 'Entry to Tejgaon Industrial Area from Bijoy Sarani / Farmgate side. Checks for commercial bikes, unlicensed CNGs, and expired tax tokens.',
    hours: 'Working Days 9am - 6pm',
  },

  // ── Bosila / Mohammadpur (western) ───────────────────────────────────────
  {
    slug: 'bosila-buriganga-bridge-approach',
    name: 'DMP Traffic Checkpost - Bosila (Buriganga Bridge)',
    latitude: 23.7138,
    longitude: 90.3592,
    address: 'Bosila Bridge over Buriganga River — Dhaka–Keraniganj corridor. Strict checkpoint for bikes crossing into/out of old Dhaka via Keraniganj.',
    hours: 'Daily 7am - 11pm',
  },
  {
    slug: 'mohammadpur-asad-ave-satmasjid',
    name: 'DMP Traffic Checkpost - Mohammadpur (Asad Ave / Satmasjid Rd)',
    latitude: 23.7648,
    longitude: 90.3668,
    address: 'Asad Avenue & Satmasjid Road crossing, Mohammadpur. Frequent helmet and licence spot-checks for bikes heading toward Mirpur and Bosila.',
    hours: 'Daily 9am - 8pm',
  },

  // ── Gulshan Division ─────────────────────────────────────────────────────
  {
    slug: 'gulshan-2-circle',
    name: 'DMP Traffic Checkpost - Gulshan 2 Circle',
    latitude: 23.7921,
    longitude: 90.4152,
    address: 'Gulshan Avenue Circle (Gulshan-2). High-visibility diplomatic zone — strict licence, registration, and signal compliance enforcement.',
    hours: 'Daily 9am - 10pm',
  },
  {
    slug: 'baridhara-notun-bazar',
    name: 'DMP Traffic Checkpost - Baridhara Notun Bazar',
    latitude: 23.8010,
    longitude: 90.4265,
    address: 'Notun Bazar crossing, Baridhara — connector to Purbachal & Vatara. Crackdown on modified exhausts, helmets, and lane discipline.',
    hours: 'Evening & Night Shifts',
  },
];

// ---------------------------------------------------------------------------
// Document Builder
// ---------------------------------------------------------------------------
function toPlaceDocument(checkpost, timestamp) {
  const osmId = `dmp:checkpost:${checkpost.slug}`;
  const geohash = geohashEncode(checkpost.latitude, checkpost.longitude, 9);

  return {
    name: checkpost.name,
    category: 'police',
    latitude: checkpost.latitude,
    longitude: checkpost.longitude,
    geohash,
    address: checkpost.address,
    phone: '999',
    hours: checkpost.hours || 'Peak Hours & Scheduled Shifts',
    photoUrls: [],
    verified: true,
    createdBy: SEED_AUTHOR,
    createdAt: timestamp,
    ratingSum: 0,
    ratingCount: 0,
    osmId,
    authority: 'Dhaka Metropolitan Police (DMP) Traffic Division',
    enforcementType: 'Traffic Police Checkpost / Case Citation Point',
    commonChecks: [
      'Driving License & Smart Card validity',
      'Motorcycle Registration Certificate & Tax Token',
      'Rider & Pillion Helmet compliance (Section 66)',
      'Wrong-way driving & illegal turnings (Section 89)',
      'Signal jumping and zebra crossing violations (Section 87)',
      'Modified exhaust / excessive noise checks',
    ],
    reportingSource: 'Community Reported & DMP Active Traffic Corridors',
  };
}

// ---------------------------------------------------------------------------
// Execution
// ---------------------------------------------------------------------------
async function main() {
  const args = process.argv.slice(2);
  const writeForReal = args.includes('--yes-i-really-mean-it');
  const projectId = process.env.FIREBASE_PROJECT_ID || EXPECTED_PROJECT_ID;

  console.log('='.repeat(70));
  console.log(`  ThrottleIQ Police Checkposts Seed v2 — Project: '${projectId}'`);
  console.log(`  Mode: ${writeForReal ? 'WRITING TO FIRESTORE' : 'DRY RUN (pass --yes-i-really-mean-it to commit)'}`);
  console.log(`  New locations in this batch: ${POLICE_CHECKPOSTS_V2.length}`);
  console.log('='.repeat(70));

  if (projectId !== EXPECTED_PROJECT_ID) {
    console.error(`Refusing to run: project ID must be '${EXPECTED_PROJECT_ID}', got '${projectId}'`);
    process.exit(1);
  }

  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });
  }
  const db = admin.firestore();

  console.log('\nChecking for existing police records in Firestore...');
  const existingSnapshot = await db.collection(COLLECTION).where('category', '==', 'police').get();

  const existingOsmIds = new Set();
  const existingNames = new Set();
  existingSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.osmId) existingOsmIds.add(data.osmId);
    if (data.name) existingNames.add(data.name);
  });
  console.log(`Found ${existingSnapshot.size} existing police document(s).`);

  const toCreate = [];
  const toSkip = [];
  const now = admin.firestore.Timestamp.now();

  for (const post of POLICE_CHECKPOSTS_V2) {
    const expectedOsmId = `dmp:checkpost:${post.slug}`;
    if (existingOsmIds.has(expectedOsmId) || existingNames.has(post.name)) {
      toSkip.push(post);
    } else {
      toCreate.push(toPlaceDocument(post, now));
    }
  }

  console.log(`\nSummary:`);
  console.log(`  - Already present: ${toSkip.length}`);
  console.log(`  - Ready to add:    ${toCreate.length}`);

  if (toCreate.length === 0) {
    console.log('\nAll v2 checkposts are already in the database. Nothing to do!');
    return;
  }

  if (!writeForReal) {
    console.log('\n[DRY RUN] Preview of entries to be created:');
    toCreate.forEach((doc, idx) => {
      console.log(`  ${idx + 1}. [${doc.name}] at (${doc.latitude}, ${doc.longitude}) [geohash: ${doc.geohash}]`);
    });
    console.log('\nRun with --yes-i-really-mean-it to write these to Firestore.');
    return;
  }

  console.log('\nWriting documents to Firestore...');
  const batch = db.batch();
  for (const docData of toCreate) {
    const ref = db.collection(COLLECTION).doc();
    batch.set(ref, docData);
  }
  await batch.commit();
  console.log(`\nSuccessfully created ${toCreate.length} Police Checkpost v2 documents in '${COLLECTION}'!`);
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Execution failed:', err);
    process.exit(1);
  });
}

module.exports = {
  geohashEncode,
  toPlaceDocument,
  POLICE_CHECKPOSTS_V2,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
};
