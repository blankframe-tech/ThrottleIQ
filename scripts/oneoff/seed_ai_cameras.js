#!/usr/bin/env node
'use strict';

/**
 * seed_ai_cameras.js — populates the `places` directory with Dhaka's
 * AI Traffic Enforcement Cameras managed by the Dhaka Metropolitan Police (DMP)
 * and Dhaka City Corporations.
 *
 * Each entry is tagged with category 'aiCamera' so it renders as a camera pin
 * on ThrottleIQ's interactive maps and shows up in the POI directory under AI Camera.
 *
 * Detects:
 *   - Driving in the wrong direction
 *   - Ignoring traffic signals or jumping red lights
 *   - Driving onto zebra crossings
 *   - Disobeying stop lines
 *   - Blocking the left lane or illegal parking
 *   - Sudden lane changes and riding without a helmet
 *
 * Associated Apps/Systems:
 *   - Hello DMP App (Citizen services & violation reporting)
 *   - AI Camera Traffic App (Real-time street/traffic monitoring)
 *
 * Safety posture:
 *   - --dry-run is the DEFAULT. Nothing is written without --yes-i-really-mean-it.
 *   - Refuses to run unless FIREBASE_PROJECT_ID is 'throttleiqfb'.
 *   - Idempotent: checks existing osmId/identifiers so re-runs never duplicate.
 *   - Attribution: createdBy: 'system:dmp-ai-camera-seed'.
 */

const fs = require('fs');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const COLLECTION = 'places';
const SEED_AUTHOR = 'system:dmp-ai-camera-seed';

// ---------------------------------------------------------------------------
// Geohash encoding (Precision 9 standard matching ThrottleIQ GeohashUtils)
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
// Camera Dataset (32 Key Dhaka Intersections)
// ---------------------------------------------------------------------------
const AI_CAMERAS = [
  {
    slug: 'hotel-intercontinental',
    name: 'AI Camera - Hotel InterContinental (Shahbagh)',
    latitude: 23.7431,
    longitude: 90.3970,
    address: 'Kazi Nazrul Islam Ave & Minto Rd, Shahbagh. DMP AI PTZ Camera: monitors red lights, stop lines, wrong-way driving, helmet compliance.',
  },
  {
    slug: 'pan-pacific-sonargaon',
    name: 'AI Camera - Pan Pacific Sonargaon',
    latitude: 23.7505,
    longitude: 90.3941,
    address: 'SAARC Fountain & Kazi Nazrul Islam Ave, Karwan Bazar. DMP AI PTZ Camera: monitors signal jumping, zebra crossings, illegal parking.',
  },
  {
    slug: 'banglamotor',
    name: 'AI Camera - Banglamotor',
    latitude: 23.7468,
    longitude: 90.3948,
    address: 'Banglamotor Intersection, Kazi Nazrul Islam Ave. DMP AI PTZ Camera: monitors lane violations, stop lines, helmet compliance.',
  },
  {
    slug: 'bijoy-sarani',
    name: 'AI Camera - Bijoy Sarani',
    latitude: 23.7663,
    longitude: 90.3872,
    address: 'Bijoy Sarani & Begum Rokeya Sarani Crossing. DMP AI PTZ Camera: automated detection of signal jumping & wrong-way driving.',
  },
  {
    slug: 'jahangir-gate',
    name: 'AI Camera - Jahangir Gate',
    latitude: 23.7744,
    longitude: 90.3905,
    address: 'Jahangir Gate (Cantonment Entry), Mohakhali - Airport Rd. DMP AI PTZ Camera: speed/signal/lane compliance monitoring.',
  },
  {
    slug: 'farmgate',
    name: 'AI Camera - Farmgate',
    latitude: 23.7571,
    longitude: 90.3900,
    address: 'Farmgate 4-Way Crossing (Khamarbari / Ananda Cinema). DMP AI PTZ Camera: detects zebra crossing obstruction & red lights.',
  },
  {
    slug: 'karwan-bazar',
    name: 'AI Camera - Karwan Bazar',
    latitude: 23.7528,
    longitude: 90.3927,
    address: 'Karwan Bazar Intersection, Kazi Nazrul Islam Ave. DMP AI PTZ Camera: detects stop line breaches, left lane blocking, wrong-way.',
  },
  {
    slug: 'abdul-gani-road',
    name: 'AI Camera - Abdul Gani Road',
    latitude: 23.7289,
    longitude: 90.4075,
    address: 'Abdul Gani Rd & Zero Point, Secretariat Area. DMP AI PTZ Camera: high-security traffic enforcement & illegal parking detection.',
  },
  {
    slug: 'airport-road',
    name: 'AI Camera - Airport Road (HSIA)',
    latitude: 23.8516,
    longitude: 90.4076,
    address: 'Hazrat Shahjalal International Airport Roundabout & Expressway Entry. DMP AI PTZ Camera: lane cutting, helmet & speed monitoring.',
  },
  {
    slug: 'shahbagh-square',
    name: 'AI Camera - Shahbagh Square',
    latitude: 23.7388,
    longitude: 90.3957,
    address: 'Shahbagh Crossing (BSMMU / Dhaka University Entry). DMP AI PTZ Camera: detects red-light jumping & zebra crossing violations.',
  },
  {
    slug: 'high-court-crossing',
    name: 'AI Camera - High Court Crossing',
    latitude: 23.7284,
    longitude: 90.4035,
    address: 'High Court Crossing & Kadam Fountain, Topkhana Rd. DMP AI PTZ Camera: monitors signal compliance & pedestrian crossings.',
  },
  {
    slug: 'matsya-bhaban',
    name: 'AI Camera - Matsya Bhaban',
    latitude: 23.7317,
    longitude: 90.4042,
    address: 'Matsya Bhaban Intersection, Kakrail - Shahbagh Link. DMP AI PTZ Camera: automated case filing for wrong-way & red light.',
  },
  {
    slug: 'kakrail-mosque',
    name: 'AI Camera - Kakrail Mosque Crossing',
    latitude: 23.7374,
    longitude: 90.4061,
    address: 'Kakrail Mosque Crossing & Hare Road. DMP AI PTZ Camera: automated violation detection for signals & stop lines.',
  },
  {
    slug: 'police-bhaban',
    name: 'AI Camera - Police Bhaban (Ramna)',
    latitude: 23.7226,
    longitude: 90.4078,
    address: 'Police Bhaban Crossing, Phoenix Rd / Fulbaria. DMP Headquarters Zone AI PTZ Camera.',
  },
  {
    slug: 'old-ramna-thana',
    name: 'AI Camera - Old Ramna Thana Crossing',
    latitude: 23.7408,
    longitude: 90.4048,
    address: 'Old Ramna Thana Crossing, Kakrail. DMP AI PTZ Camera: detects unauthorized turns & red light jumping.',
  },
  {
    slug: 'rampura-traffic-box',
    name: 'AI Camera - Rampura Traffic Box',
    latitude: 23.7612,
    longitude: 90.4227,
    address: 'Rampura Bridge & DIT Road Intersection. DMP AI PTZ Camera: detects lane obstruction & red light violations.',
  },
  {
    slug: 'mirpur-2-heart-foundation',
    name: 'AI Camera - Mirpur-2 (National Heart Foundation)',
    latitude: 23.8041,
    longitude: 90.3627,
    address: 'Mirpur-2 near National Heart Foundation, Mirpur Rd. DMP AI PTZ Camera: monitors wrong-way driving & signal jumping.',
  },
  {
    slug: 'gabtoli-crossing',
    name: 'AI Camera - Gabtoli Crossing',
    latitude: 23.7828,
    longitude: 90.3444,
    address: 'Gabtoli Terminal & Mirpur Road Entry/Exit. DMP AI PTZ Camera: detects wrong-way, lane cutting & bus stopping violations.',
  },
  {
    slug: 'shaheed-tajuddin-sarani',
    name: 'AI Camera - Shaheed Tajuddin Ahmad Sarani',
    latitude: 23.7675,
    longitude: 90.4011,
    address: 'Shaheed Tajuddin Ahmad Sarani & Nabiketa Crossing, Tejgaon. DMP AI PTZ Camera: speed & red light enforcement.',
  },
  {
    slug: 'mohakhali-terminal',
    name: 'AI Camera - Mohakhali Bus Terminal',
    latitude: 23.7778,
    longitude: 90.4004
,
    address: 'Mohakhali Terminal & Flyover Base Intersection. DMP AI PTZ Camera: detects left lane blocking & illegal parking.',
  },
  {
    slug: 'gulshan-1-circle',
    name: 'AI Camera - Gulshan-1 Circle',
    latitude: 23.7788,
    longitude: 90.4162,
    address: 'Gulshan-1 Circle & Pragati Sarani Link. DMP AI PTZ Camera: automated roundabout traffic enforcement.',
  },
  {
    slug: 'gulshan-2-circle',
    name: 'AI Camera - Gulshan-2 Circle',
    latitude: 23.7925,
    longitude: 90.4167,
    address: 'Gulshan-2 Circle & Madani Avenue. DMP AI PTZ Camera: high-resolution plate & helmet detection.',
  },
  {
    slug: 'banani-11',
    name: 'AI Camera - Banani 11 (Kemal Ataturk)',
    latitude: 23.7937,
    longitude: 90.4050,
    address: 'Kemal Ataturk Ave & Banani Road 11 Crossing. DMP AI PTZ Camera: signal & pedestrian zebra crossing monitoring.',
  },
  {
    slug: 'asad-gate',
    name: 'AI Camera - Asad Gate',
    latitude: 23.7597,
    longitude: 90.3734,
    address: 'Asad Gate Intersection, Mirpur Rd & Mohammadpur Entry. DMP AI PTZ Camera: detects red-light & lane blocking.',
  },
  {
    slug: 'manik-mia-avenue',
    name: 'AI Camera - Manik Mia Avenue',
    latitude: 23.7608,
    longitude: 90.3789,
    address: 'Manik Mia Ave & Mirpur Rd (National Parliament Area). DMP AI PTZ Camera: automated signal & helmet detection.',
  },
  {
    slug: 'science-lab',
    name: 'AI Camera - Science Lab',
    latitude: 23.7390,
    longitude: 90.3837,
    address: 'Science Lab Intersection, Mirpur Rd & Elephant Rd. DMP AI PTZ Camera: detects stop lines, red lights & zebra crossings.',
  },
  {
    slug: 'nilkhet-crossing',
    name: 'AI Camera - Nilkhet Crossing',
    latitude: 23.7331,
    longitude: 90.3869,
    address: 'Nilkhet 4-Way Crossing (Dhaka University & New Market). DMP AI PTZ Camera: monitors pedestrian crossing & signals.',
  },
  {
    slug: 'purana-paltan',
    name: 'AI Camera - Purana Paltan',
    latitude: 23.7314,
    longitude: 90.4128,
    address: 'Purana Paltan Intersection & Topkhana Rd. DMP AI PTZ Camera: automated detection for stop lines & wrong-way.',
  },
  {
    slug: 'mogbazar-crossroads',
    name: 'AI Camera - Mogbazar Crossroads',
    latitude: 23.7492,
    longitude: 90.4069,
    address: 'Mogbazar - Mouchak Flyover Level Crossing. DMP AI PTZ Camera: detects red lights & reckless lane changes.',
  },
  {
    slug: 'mirpur-10-circle',
    name: 'AI Camera - Mirpur-10 Roundabout',
    latitude: 23.8069,
    longitude: 90.3687,
    address: 'Mirpur 10 Golchokkor, Begum Rokeya Sarani. DMP AI PTZ Camera: automated roundabout signal enforcement.',
  },
  {
    slug: 'kuril-flyover',
    name: 'AI Camera - Kuril Flyover (Bishwa Road)',
    latitude: 23.8184,
    longitude: 90.4194,
    address: 'Kuril Interchange & Pragati Sarani Link. DMP AI PTZ Camera: monitors expressway entry/exit & lane compliance.',
  },
  {
    slug: 'uttara-house-building',
    name: 'AI Camera - Uttara House Building',
    latitude: 23.8732,
    longitude: 90.3982,
    address: 'Uttara Sector 7 / House Building Crossing, Dhaka-Mymensingh Hwy. DMP AI PTZ Camera: speed & signal enforcement.',
  },
];

// ---------------------------------------------------------------------------
// Document Builder
// ---------------------------------------------------------------------------
function toPlaceDocument(camera, timestamp) {
  const osmId = `dmp:ai-camera:${camera.slug}`;
  const geohash = geohashEncode(camera.latitude, camera.longitude, 9);

  return {
    name: camera.name,
    category: 'aiCamera',
    latitude: camera.latitude,
    longitude: camera.longitude,
    geohash: geohash,
    address: camera.address,
    phone: '999', // Emergency & police hotline
    hours: '24/7',
    photoUrls: [],
    verified: true,
    createdBy: SEED_AUTHOR,
    createdAt: timestamp,
    ratingSum: 0,
    ratingCount: 0,
    osmId: osmId,
    // Rich metadata for AI cameras:
    authority: 'Dhaka Metropolitan Police (DMP) & City Corporations',
    violationsDetected: [
      'Driving in the wrong direction',
      'Ignoring traffic signals or jumping red lights',
      'Driving onto zebra crossings',
      'Disobeying stop lines',
      'Blocking the left lane or illegal parking',
      'Sudden lane changes and riding without a helmet',
      'Seatbelt violations and mobile phone use while driving',
    ],
    connectedApps: [
      'Hello DMP App (Citizen services & reporting)',
      'AI Camera Traffic App (Real-time street & traffic monitoring)',
    ],
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
  console.log(`  ThrottleIQ AI Camera Seed — Project: '${projectId}'`);
  console.log(`  Mode: ${writeForReal ? 'WRITING TO FIRESTORE' : 'DRY RUN (pass --yes-i-really-mean-it to commit)'}`);
  console.log(`  Total Camera Locations: ${AI_CAMERAS.length}`);
  console.log('='.repeat(70));

  if (projectId !== EXPECTED_PROJECT_ID) {
    console.error(`Refusing to run: project ID must be '${EXPECTED_PROJECT_ID}', got '${projectId}'`);
    process.exit(1);
  }

  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: EXPECTED_PROJECT_ID,
    });
  }
  const db = admin.firestore();

  // Query existing AI cameras to ensure idempotency
  console.log('\nChecking for existing camera records in Firestore...');
  const existingSnapshot = await db
    .collection(COLLECTION)
    .where('category', '==', 'aiCamera')
    .get();

  const existingOsmIds = new Set();
  const existingNames = new Set();

  existingSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.osmId) existingOsmIds.add(data.osmId);
    if (data.name) existingNames.add(data.name);
  });

  console.log(`Found ${existingSnapshot.size} existing aiCamera document(s).`);

  const toCreate = [];
  const toSkip = [];

  const now = admin.firestore.Timestamp.now();

  for (const cam of AI_CAMERAS) {
    const expectedOsmId = `dmp:ai-camera:${cam.slug}`;
    if (existingOsmIds.has(expectedOsmId) || existingNames.has(cam.name)) {
      toSkip.push(cam);
    } else {
      toCreate.push(toPlaceDocument(cam, now));
    }
  }

  console.log(`\nSummary:`);
  console.log(`  - Already present: ${toSkip.length}`);
  console.log(`  - Ready to add:    ${toCreate.length}`);

  if (toCreate.length === 0) {
    console.log('\nAll cameras are already in the database. Nothing to do!');
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
  console.log(`\nSuccessfully created ${toCreate.length} AI Camera documents in '${COLLECTION}'!`);
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
  AI_CAMERAS,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
};
