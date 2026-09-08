#!/usr/bin/env node
'use strict';

/**
 * seed_police_checkposts.js — populates the `places` collection in ThrottleIQ
 * with frequent traffic police checkposts and sergeant enforcement points in Dhaka.
 *
 * Sourced from commuter reports, BD biker communities, and Dhaka Traffic Alert channels.
 *
 * Each entry is tagged with category 'police' (icon: 🚓) so it appears
 * in the POI directory under 'Police / Cop' and on map viewports.
 *
 * Safety posture:
 *   - --dry-run is the DEFAULT.
 *   - --yes-i-really-mean-it is required to write to Firestore.
 *   - Refuses to run unless FIREBASE_PROJECT_ID is 'throttleiqfb'.
 *   - Idempotent: checks existing osmId/slug so re-runs never duplicate.
 *   - Attribution: createdBy: 'system:dmp-checkpost-seed'.
 */

const fs = require('fs');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const COLLECTION = 'places';
const SEED_AUTHOR = 'system:dmp-checkpost-seed';

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
// Police Checkpost Dataset (30 Frequent Enforcement Points in Dhaka)
// ---------------------------------------------------------------------------
const POLICE_CHECKPOSTS = [
  {
    slug: 'polashi-azimpur',
    name: 'DMP Traffic Checkpost - Polashi / Azimpur',
    latitude: 23.7282,
    longitude: 90.3888,
    address: 'Polashi More, Jahir Raihan Sarani (near BUET / Azimpur). Frequent paper & helmet checkpost; active daytime & late evening.',
    hours: 'Morning & Evening Shifts',
  },
  {
    slug: 'farmgate-khamarbari',
    name: 'DMP Traffic Checkpost - Farmgate (Khamarbari)',
    latitude: 23.7580,
    longitude: 90.3875,
    address: 'In front of Krishibid Institute (KGF), Manik Mia / Khamarbari entry. Regular drives for wrong-way riding, tax tokens & helmets.',
    hours: 'Daily Peak Hours',
  },
  {
    slug: 'agargaon-passport-office',
    name: 'DMP Traffic Checkpost - Agargaon (Passport Office)',
    latitude: 23.7745,
    longitude: 90.3792,
    address: 'Old Passport Office Road & Taltola Crossing. Strict checks for driving licenses, bike fitness and modified number plates.',
    hours: 'Daily Morning Shift',
  },
  {
    slug: 'mohakhali-flyover-ramp',
    name: 'DMP Traffic Checkpost - Mohakhali Flyover Descent',
    latitude: 23.7760,
    longitude: 90.4020,
    address: 'Bottom of Mohakhali Flyover (towards Amtoli / Sena Kalyan). Active checks for speed, lane cutting, and registration papers.',
    hours: 'Morning & Evening Rush',
  },
  {
    slug: 'kuril-300-feet-entry',
    name: 'DMP Traffic Checkpost - Kuril 300 Feet Entry',
    latitude: 23.8205,
    longitude: 90.4230,
    address: 'Entry point of Purbachal Express (300 Feet Rd) under Kuril Flyover. Weekend & evening checks for speeding, helmets, and documents.',
    hours: 'Evenings & Weekends',
  },
  {
    slug: 'airport-kawla-footbridge',
    name: 'DMP Traffic Checkpost - Airport Road (Kawla)',
    latitude: 23.8475,
    longitude: 90.4085,
    address: 'Airport Road near Kawla Footbridge & Haji Camp. Highway police & DMP sergeant speed gun checks and lane compliance.',
    hours: '24/7 Monitoring',
  },
  {
    slug: 'uttara-jasimuddin',
    name: 'DMP Traffic Checkpost - Uttara (Jasimuddin)',
    latitude: 23.8642,
    longitude: 90.3995,
    address: 'Jasimuddin Avenue crossing on Dhaka-Mymensingh Highway. Frequent mobile court and motorcycle documentation checks.',
    hours: 'Daily 9am - 8pm',
  },
  {
    slug: 'uttara-house-building',
    name: 'DMP Traffic Checkpost - Uttara House Building',
    latitude: 23.8735,
    longitude: 90.3980,
    address: 'House Building intersection (Sector 7 / 9 Link). Regular paper checking drives for bikes coming into Dhaka.',
    hours: 'Daily 10am - 9pm',
  },
  {
    slug: 'banani-11-bridge',
    name: 'DMP Traffic Checkpost - Banani 11 Bridge',
    latitude: 23.7940,
    longitude: 90.4095,
    address: 'Banani Road 11 Bridge crossing towards Gulshan. High-frequency checkpoint for double-helmet compliance and digital cases.',
    hours: 'Daily 4pm - 10pm',
  },
  {
    slug: 'gulshan-1-police-plaza',
    name: 'DMP Traffic Checkpost - Police Plaza (Gulshan-1)',
    latitude: 23.7755,
    longitude: 90.4130,
    address: 'Bir Uttam Mir Shawkat Sarak near Police Plaza Concord. Checks for modified silencers, license validity, and seatbelts.',
    hours: 'Daily 3pm - 11pm',
  },
  {
    slug: 'hatirjheel-rampra-entry',
    name: 'DMP Traffic Checkpost - Hatirjheel (Rampura Entry)',
    latitude: 23.7620,
    longitude: 90.4215,
    address: 'Rampura Bridge entry into Hatirjheel Ring Road. Strict monitoring for motorcycle overspeeding, stunt riding & licenses.',
    hours: 'Afternoon & Night Shifts',
  },
  {
    slug: 'hatirjheel-fdc-more',
    name: 'DMP Traffic Checkpost - Hatirjheel (FDC More)',
    latitude: 23.7510,
    longitude: 90.3965,
    address: 'FDC More entrance near Sonargaon roundabout. Evening checkpost checking motorbike papers and pillion helmets.',
    hours: 'Daily 6pm - 11pm',
  },
  {
    slug: 'bijoy-sarani-museum',
    name: 'DMP Traffic Checkpost - Bijoy Sarani (Military Museum)',
    latitude: 23.7670,
    longitude: 90.3855,
    address: 'Bijoy Sarani link road beside National Military Museum. Sergeants actively ticketing lane violators and signal jumpers.',
    hours: 'Peak Traffic Hours',
  },
  {
    slug: 'asad-gate-aarong',
    name: 'DMP Traffic Checkpost - Asad Gate (Mirpur Road)',
    latitude: 23.7600,
    longitude: 90.3725,
    address: 'Mirpur Road in front of Aarong / Asad Gate. Frequent daytime checkpost for helmet checks, driving licenses & tax tokens.',
    hours: 'Daily 9am - 6pm',
  },
  {
    slug: 'dhanmondi-27-rapa',
    name: 'DMP Traffic Checkpost - Dhanmondi 27 (Rapa Plaza)',
    latitude: 23.7525,
    longitude: 90.3750,
    address: 'Mirpur Road at Dhanmondi 27 Crossing (near Rapa Plaza). Regular checks for wrong-turn cases and bike fitness certificates.',
    hours: 'Daily Peak Hours',
  },
  {
    slug: 'dhanmondi-32-russell',
    name: 'DMP Traffic Checkpost - Russell Square (Dhanmondi 32)',
    latitude: 23.7510,
    longitude: 90.3780,
    address: 'Russell Square intersection connecting Panthapath & Mirpur Rd. High-visibility sergeant enforcement point.',
    hours: 'Daily 8am - 8pm',
  },
  {
    slug: 'science-lab-city-college',
    name: 'DMP Traffic Checkpost - Science Lab (City College)',
    latitude: 23.7385,
    longitude: 90.3845,
    address: 'Science Laboratory Crossing in front of City College / Priyangon. Intensive bike stopping drives for papers and helmets.',
    hours: 'Daily 10am - 7pm',
  },
  {
    slug: 'shahbagh-bsmmu-gate',
    name: 'DMP Traffic Checkpost - Shahbagh (BSMMU / DU)',
    latitude: 23.7392,
    longitude: 90.3960,
    address: 'Shahbagh Crossing near BSMMU main gate. Strict enforcement against signal disobedience, wrong-way entry, and documents.',
    hours: 'Daily 8am - 10pm',
  },
  {
    slug: 'matsya-bhaban-crossing',
    name: 'DMP Traffic Checkpost - Matsya Bhaban',
    latitude: 23.7315,
    longitude: 90.4040,
    address: 'Matsya Bhaban More towards High Court / Ramna Park. Regular sergeant presence inspecting driver documents and red lights.',
    hours: 'Daily 9am - 8pm',
  },
  {
    slug: 'zero-point-gpo',
    name: 'DMP Traffic Checkpost - Zero Point (GPO / Secretariat)',
    latitude: 23.7285,
    longitude: 90.4080,
    address: 'Zero Point crossing beside GPO and Bangladesh Secretariat. High security VIP zone with strict digital citation enforcement.',
    hours: '24/7 Active Zone',
  },
  {
    slug: 'motijheel-shapla-chottor',
    name: 'DMP Traffic Checkpost - Motijheel Shapla Chottor',
    latitude: 23.7265,
    longitude: 90.4190,
    address: 'Shapla Chottor circle in Motijheel C/A. Regular checking for commercial vehicles, bikes, and valid tax tokens.',
    hours: 'Working Days 9am - 6pm',
  },
  {
    slug: 'sayedabad-janapath',
    name: 'DMP Traffic Checkpost - Sayedabad (Janapath More)',
    latitude: 23.7145,
    longitude: 90.4270,
    address: 'Janapath More under Sayedabad Flyover. Routine inter-district and commuter motorcycle checkpost checking highway permits.',
    hours: 'Daily 8am - 9pm',
  },
  {
    slug: 'jatrabari-chourasta',
    name: 'DMP Traffic Checkpost - Jatrabari Chourasta',
    latitude: 23.7105,
    longitude: 90.4350,
    address: 'Jatrabari Roundabout under Mayor Hanif Flyover interchange. Frequent checkpost for bikes entering Dhaka from Chattogram Highway.',
    hours: '24/7 Shift Checks',
  },
  {
    slug: 'gabtoli-mazar-road',
    name: 'DMP Traffic Checkpost - Gabtoli (Mazar Road)',
    latitude: 23.7845,
    longitude: 90.3470,
    address: 'Mirpur Road at Gabtoli Mazar Road crossing. Police checkpoint targeting inter-district commuters, license validity and helmets.',
    hours: 'Daily 8am - 10pm',
  },
  {
    slug: 'kallyanpur-technical',
    name: 'DMP Traffic Checkpost - Kallyanpur Technical More',
    latitude: 23.7780,
    longitude: 90.3570,
    address: 'Technical intersection, Mirpur Road near Kallyanpur. Regular sergeant checking spot for signal jumping & registration.',
    hours: 'Daily Morning & Evening',
  },
  {
    slug: 'mirpur-10-stadium',
    name: 'DMP Traffic Checkpost - Mirpur 10 (Stadium Road)',
    latitude: 23.8065,
    longitude: 90.3705,
    address: 'Mirpur 10 Roundabout towards Sher-e-Bangla National Cricket Stadium. Frequent bike checking drives for double helmets and fitness.',
    hours: 'Daily 10am - 9pm',
  },
  {
    slug: 'mirpur-1-sony-square',
    name: 'DMP Traffic Checkpost - Mirpur 1 (Sony Square)',
    latitude: 23.7995,
    longitude: 90.3530,
    address: 'Mirpur 1 Circle / Sony Square intersection. Regular evening checkpoint for document verification and wrong-way checks.',
    hours: 'Daily 3pm - 9pm',
  },
  {
    slug: 'mirpur-14-dental',
    name: 'DMP Traffic Checkpost - Mirpur 14 (Dental College)',
    latitude: 23.8115,
    longitude: 90.3820,
    address: 'Mirpur 14 intersection near Dhaka Dental College. Common checkpoint for Cantonment link road speed & helmet enforcement.',
    hours: 'Daily 9am - 7pm',
  },
  {
    slug: 'ecb-chottor-matikata',
    name: 'DMP Traffic Checkpost - ECB Chottor (Cantonment)',
    latitude: 23.8240,
    longitude: 90.3920,
    address: 'ECB Chottor connecting Mirpur DOHS, Kalshi Flyover & Matikata. Heavy checkpoint for helmet violations, papers, and speed.',
    hours: 'Daily 10am - 10pm',
  },
  {
    slug: 'kalshi-flyover-more',
    name: 'DMP Traffic Checkpost - Kalshi More',
    latitude: 23.8220,
    longitude: 90.3765,
    address: 'Kalshi More downramp connecting to Begum Rokeya Sarani. Frequent sergeant checkpoint inspecting descending bikes.',
    hours: 'Daily 4pm - 10pm',
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
    geohash: geohash,
    address: checkpost.address,
    phone: '999', // Emergency & police helpline
    hours: checkpost.hours || 'Peak Hours & Scheduled Shifts',
    photoUrls: [],
    verified: true,
    createdBy: SEED_AUTHOR,
    createdAt: timestamp,
    ratingSum: 0,
    ratingCount: 0,
    osmId: osmId,
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
  console.log(`  ThrottleIQ Police Checkposts Seed — Project: '${projectId}'`);
  console.log(`  Mode: ${writeForReal ? 'WRITING TO FIRESTORE' : 'DRY RUN (pass --yes-i-really-mean-it to commit)'}`);
  console.log(`  Total Checkpost Locations: ${POLICE_CHECKPOSTS.length}`);
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

  // Query existing police checkposts to ensure idempotency
  console.log('\nChecking for existing police records in Firestore...');
  const existingSnapshot = await db
    .collection(COLLECTION)
    .where('category', '==', 'police')
    .get();

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

  for (const post of POLICE_CHECKPOSTS) {
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
    console.log('\nAll police checkposts are already in the database. Nothing to do!');
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
  console.log(`\nSuccessfully created ${toCreate.length} Police Checkpost documents in '${COLLECTION}'!`);
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
  POLICE_CHECKPOSTS,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
};
