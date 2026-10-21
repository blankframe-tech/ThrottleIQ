#!/usr/bin/env node
'use strict';

/**
 * seed_police_checkposts_v3.js — populates the `places` collection in ThrottleIQ
 * with 35 additional frequent DMP & Highway traffic checkposts / mamla hotspots
 * across Dhaka and outer fringe gateways.
 *
 * Batch 3 — 35 locations crowdsourced from:
 *   - Traffic Alert BD
 *   - Dhaka Traffic Alert (DTA)
 *   - BikeBD Community
 *   - Waze Bangladesh Community hazard/police reports
 *
 * Corridors covered:
 *   - Highway & gateway choke points (Aminbazar, Signboard, Kanchpur, 300ft Balu Bridge, Kanchan Bridge)
 *   - Uttara, Airport & Purbachal (Diabari, Kakoli, Khilkhet, Airport Stn, Azampur, Bashundhara, Madani Ave, Shahjadpur)
 *   - Dhanmondi, Mohammadpur & Beribadh (Zigatola, Kalabagan, Rayerbazar, Town Hall, Hazaribagh)
 *   - Mirpur Sector Corridors (Mirpur 11 Purobi, Mirpur 12 Ceramic, Mirpur 2 Cricket Academy)
 *   - Rampura, Banasree & Khilgaon (Aftabnagar Main Gate, Banasree Farazi, Khilgaon Taltola, Mugda Medical)
 *   - Old Dhaka & South Bridges (Babubazar Bridge Nayabazar, Victoria Park Sadarghat, Golapbagh Flyover, Dholaikhal)
 *   - Central Hubs (Tejgaon Nabisco, Panthapath Square Hospital, Shantinagar, Gulshan 1 Link, Indira Road, Kakrail)
 *
 * Safety posture:
 *   - --dry-run is the DEFAULT.
 *   - --yes-i-really-mean-it is required to commit to Firestore.
 *   - Refuses to run unless project is 'throttleiqfb'.
 *   - Idempotent: checks existing osmId and name before inserting.
 *   - Attribution: createdBy: 'system:dmp-checkpost-seed-v3'.
 */

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const COLLECTION = 'places';
const SEED_AUTHOR = 'system:dmp-checkpost-seed-v3';

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
// Police Checkpost Dataset — Batch 3 (35 crowdsourced enforcement points)
// ---------------------------------------------------------------------------
const POLICE_CHECKPOSTS_V3 = [
  // ── 1. Highway & City Gateway Chokepoints ──────────────────────────────
  {
    slug: 'aminbazar-bridge-toll',
    name: 'DMP Traffic Checkpost - Aminbazar Bridge & Toll Plaza',
    latitude: 23.7850,
    longitude: 90.3340,
    address: 'Aminbazar Bridge approach & Savar boundary. High-security checkpost for vehicles & bikes entering from Savar/North Bengal; morning & evening document checks.',
    hours: '24/7 Monitoring & Shifts',
  },
  {
    slug: 'signboard-sanarpar-highway',
    name: 'DMP / Highway Police Checkpost - Signboard / Sanarpar',
    latitude: 23.6890,
    longitude: 90.4850,
    address: 'Dhaka–Chattogram Highway at Signboard / Sanarpar bottleneck. Heavy joint checking for tax tokens, fitness certificates, and double helmets at Narayanganj border.',
    hours: 'Daily Morning & Evening',
  },
  {
    slug: 'kanchpur-bridge-fork',
    name: 'Highway Police Checkpost - Kanchpur Bridge Fork',
    latitude: 23.7030,
    longitude: 90.5180,
    address: 'Fork between Chattogram & Sylhet Highways past Kanchpur Bridge. Strategic checkpost for long-distance motorcycle tourers, speed, and document compliance.',
    hours: 'Daily 8am - 10pm',
  },
  {
    slug: 'purbachal-300ft-balu-bridge',
    name: 'DMP Traffic Checkpost - 300 Feet (Balu Bridge)',
    latitude: 23.8350,
    longitude: 90.4670,
    address: 'Purbachal Expressway at Balu River Bridge crossing. Heavily active on weekend afternoons for motorcycle speed guns, stunting checks, and document verification.',
    hours: 'Weekends & Evenings',
  },
  {
    slug: 'purbachal-300ft-kanchan-bridge',
    name: 'DMP / Highway Police Checkpost - Kanchan Bridge Toll',
    latitude: 23.8560,
    longitude: 90.5280,
    address: 'Kanchan Toll Plaza on Purbachal Expressway at Shitalakshya River crossing. Eastern perimeter checkpost for weekend and late-evening commuter and bike traffic.',
    hours: 'Afternoon & Night Shifts',
  },

  // ── 2. Uttara, Airport & Purbachal Corridors ───────────────────────────
  {
    slug: 'diabari-sector18-depot',
    name: 'DMP Traffic Checkpost - Diabari (Metro Rail Depot)',
    latitude: 23.8820,
    longitude: 90.3680,
    address: 'Diabari open road network, Sector 18 (near Metro Depot). Regular weekend and evening crackdowns on modified silencers, stunt riding, and helmet compliance.',
    hours: 'Fridays, Saturdays & Evenings',
  },
  {
    slug: 'banani-kakoli-intersection',
    name: 'DMP Traffic Checkpost - Banani Kakoli Crossing',
    latitude: 23.7935,
    longitude: 90.4035,
    address: 'Kakoli crossing at Kemal Ataturk Ave & Airport Road junction. High-frequency sergeant post checking bus-lane violations, wrong turnings, and motorcycle papers.',
    hours: 'Daily 8am - 10pm',
  },
  {
    slug: 'khilkhet-footbridge-nikunja2',
    name: 'DMP Traffic Checkpost - Khilkhet (Nikunja-2 Footbridge)',
    latitude: 23.8300,
    longitude: 90.4190,
    address: 'Dhaka–Mymensingh Highway under Khilkhet pedestrian bridge (Nikunja-2 entry). Sergeants regularly flag bikes using the service lane or making unauthorized turns.',
    hours: 'Daily Peak Hours',
  },
  {
    slug: 'airport-railway-haji-camp',
    name: 'DMP Traffic Checkpost - Airport Railway Station / Haji Camp',
    latitude: 23.8520,
    longitude: 90.4075,
    address: 'U-Turn opposite Airport Railway Station and Haji Camp. Frequent daytime checkpost checking wrong-way riding, registration papers, and driving licenses.',
    hours: 'Daily 8am - 8pm',
  },
  {
    slug: 'azampur-uttara-rajlakshmi',
    name: 'DMP Traffic Checkpost - Azampur (Uttara Sector 7)',
    latitude: 23.8685,
    longitude: 90.3990,
    address: 'Highway service road junction near Rajlakshmi Complex / Azampur footbridge. Routine motorcycle stopping spot for helmet compliance and tax token checks.',
    hours: 'Daily 10am - 8pm',
  },
  {
    slug: 'bashundhara-main-gate-pragati',
    name: 'DMP Traffic Checkpost - Bashundhara Main Gate',
    latitude: 23.8150,
    longitude: 90.4245,
    address: 'Main entry archway of Bashundhara R/A on Pragati Sarani. Routine student and commuter checkpoint for driving licenses and helmet use.',
    hours: 'Daily 9am - 7pm',
  },
  {
    slug: 'madani-avenue-100ft-road',
    name: 'DMP Traffic Checkpost - Madani Avenue (100 Feet Road)',
    latitude: 23.7970,
    longitude: 90.4410,
    address: 'Madani Avenue corridor toward United International University (UIU). Frequent weekend and evening checkpoint checking speed, modified exhausts, and papers.',
    hours: 'Daily 4pm - 10pm',
  },
  {
    slug: 'shahjadpur-suvastu-pragati',
    name: 'DMP Traffic Checkpost - Shahjadpur (Suvastu Nazar Valley)',
    latitude: 23.7930,
    longitude: 90.4255,
    address: 'Pragati Sarani near Suvastu Nazar Valley shopping mall. Sergeant enforcement spot monitoring the North Badda to Notun Bazar corridor.',
    hours: 'Daily Peak Hours',
  },

  // ── 3. Dhanmondi, Mohammadpur & West Embankment (Beribadh) ─────────────
  {
    slug: 'zigatola-dhanmondi15-crossing',
    name: 'DMP Traffic Checkpost - Zigatola / Dhanmondi 15',
    latitude: 23.7380,
    longitude: 90.3725,
    address: 'Zigatola Bus Stand crossing connecting Dhanmondi 15 and Hazaribagh. Heavy student and delivery motorcycle route with frequent paper check drives.',
    hours: 'Daily 10am - 8pm',
  },
  {
    slug: 'kalabagan-sobhanbagh-mirpur-rd',
    name: 'DMP Traffic Checkpost - Kalabagan / Sobhanbagh',
    latitude: 23.7460,
    longitude: 90.3785,
    address: 'Mirpur Road opposite Kalabagan Krira Chakra & Sobhanbagh Mosque. Sergeant post actively ticketing signal jumpers and checking bike documentation.',
    hours: 'Daily 9am - 6pm',
  },
  {
    slug: 'rayerbazar-beribadh-memorial',
    name: 'DMP Traffic Checkpost - Rayerbazar Beribadh',
    latitude: 23.7490,
    longitude: 90.3540,
    address: 'Western Embankment Road (Beribadh) near Martyred Intellectuals Memorial. Evening and night checkpoint checking bikes arriving from Keraniganj / Bosila.',
    hours: 'Daily 6pm - 11pm',
  },
  {
    slug: 'mohammadpur-town-hall-tajmahal',
    name: 'DMP Traffic Checkpost - Mohammadpur Town Hall',
    latitude: 23.7620,
    longitude: 90.3620,
    address: 'Taj Mahal Road at Mohammadpur Town Hall market crossing. Common daytime spot for double-helmet enforcement and vehicle fitness verification.',
    hours: 'Daily 10am - 8pm',
  },
  {
    slug: 'hazaribagh-tannery-beribadh',
    name: 'DMP Traffic Checkpost - Hazaribagh Tannery Mor',
    latitude: 23.7290,
    longitude: 90.3640,
    address: 'Tannery Mor on Beribadh embankment near Kamrangirchar connection. Evening checkpoint for bike papers, driving licenses, and headlight checks.',
    hours: 'Daily 5pm - 10pm',
  },

  // ── 4. Mirpur Sector Corridors ─────────────────────────────────────────
  {
    slug: 'mirpur11-purobi-cinema',
    name: 'DMP Traffic Checkpost - Mirpur 11 (Purobi Cinema)',
    latitude: 23.8190,
    longitude: 90.3660,
    address: 'Begum Rokeya Sarani at Mirpur 11 crossing (Purobi Cinema Hall). Transit point with active traffic box personnel conducting document verification.',
    hours: 'Daily 9am - 9pm',
  },
  {
    slug: 'mirpur12-ceramic-dohs',
    name: 'DMP Traffic Checkpost - Mirpur 12 (Ceramic More)',
    latitude: 23.8290,
    longitude: 90.3625,
    address: 'Ceramic More junction connecting Mirpur 12 to Pallabi & Mirpur DOHS. Evening checkpost inspecting motorcycle registration and rider licenses.',
    hours: 'Daily 4pm - 10pm',
  },
  {
    slug: 'mirpur2-cricket-academy',
    name: 'DMP Traffic Checkpost - Mirpur 2 (Cricket Academy Gate)',
    latitude: 23.8040,
    longitude: 90.3610,
    address: 'Mirpur 2 roundabout toward National Cricket Academy and Zoo Road. Spot-checks for bikes traveling between Mirpur-1 and Mirpur-10.',
    hours: 'Daily 10am - 7pm',
  },

  // ── 5. Rampura, Banasree & Khilgaon ────────────────────────────────────
  {
    slug: 'aftabnagar-main-gate-rampura',
    name: 'DMP Traffic Checkpost - Aftabnagar Main Gate',
    latitude: 23.7650,
    longitude: 90.4280,
    address: 'Entry gate of Aftabnagar across from Rampura TV Center / DIT Road. Regular checkpost inspecting bikes entering the residential sector for helmets & papers.',
    hours: 'Daily 3pm - 9pm',
  },
  {
    slug: 'banasree-south-farazi-hospital',
    name: 'DMP Traffic Checkpost - Banasree (Farazi Hospital)',
    latitude: 23.7610,
    longitude: 90.4390,
    address: 'Banasree Main Road junction near Farazi Hospital. Frequent sergeant checkpoint inspecting neighborhood bikes, delivery riders, and tax tokens.',
    hours: 'Daily 10am - 8pm',
  },
  {
    slug: 'khilgaon-taltola-market',
    name: 'DMP Traffic Checkpost - Khilgaon Taltola Market',
    latitude: 23.7485,
    longitude: 90.4285,
    address: 'Central Khilgaon intersection beside Taltola Market connecting to Goran. Routine paper check drives by Motijheel Traffic Division.',
    hours: 'Daily Morning & Evening Rush',
  },
  {
    slug: 'mugda-medical-hospital-crossing',
    name: 'DMP Traffic Checkpost - Mugda Medical College Hospital',
    latitude: 23.7315,
    longitude: 90.4320,
    address: 'Crossing outside Mugda Medical College Hospital connecting Khilgaon, Maniknagar, and Sayedabad. Traffic box checkpoint.',
    hours: 'Daily 8am - 8pm',
  },

  // ── 6. Old Dhaka & South Bridges ───────────────────────────────────────
  {
    slug: 'babubazar-bridge-nayabazar',
    name: 'DMP Traffic Checkpost - Babubazar Bridge (Nayabazar)',
    latitude: 23.7120,
    longitude: 90.4045,
    address: 'Northern foot of Babubazar Bridge (2nd Buriganga Bridge) at Nayabazar. Major entry point from Keraniganj with daily vehicle and bike paper inspections.',
    hours: '24/7 Shift Checks',
  },
  {
    slug: 'victoria-park-sadarghat',
    name: 'DMP Traffic Checkpost - Victoria Park (Bahadur Shah Park)',
    latitude: 23.7095,
    longitude: 90.4120,
    address: 'Bahadur Shah Park roundabout beside Jagannath University & Sadarghat launch terminal. Heavy transit zone with regular sergeant enforcement.',
    hours: 'Daily 8am - 9pm',
  },
  {
    slug: 'golapbagh-biswa-road-flyover',
    name: 'DMP Traffic Checkpost - Golapbagh (Hanif Flyover Downramp)',
    latitude: 23.7170,
    longitude: 90.4305,
    address: 'Under Mayor Hanif Flyover descent at Golapbagh Biswa Road (Dhalpur side). Sergeants intercept bikes descending from the flyover for documents.',
    hours: 'Daily 8am - 9pm',
  },
  {
    slug: 'dholaikhal-dayaganj-crossing',
    name: 'DMP Traffic Checkpost - Dholaikhal / Dayaganj',
    latitude: 23.7115,
    longitude: 90.4190,
    address: 'Dayaganj intersection near Dholaikhal automotive market. Known for engine and chassis number matching checks, ownership papers, and tax tokens.',
    hours: 'Working Days 10am - 6pm',
  },

  // ── 7. Central Hubs & Commercial Areas ─────────────────────────────────
  {
    slug: 'tejgaon-nabisco-more',
    name: 'DMP Traffic Checkpost - Tejgaon Nabisco More',
    latitude: 23.7695,
    longitude: 90.3985,
    address: 'Shaheed Tajuddin Ahmad Sarani at Nabisco crossing. Heavy commercial junction connecting Tejgaon, Mohakhali, and Hatirjheel with frequent sergeant drives.',
    hours: 'Daily Peak Hours',
  },
  {
    slug: 'panthapath-square-hospital',
    name: 'DMP Traffic Checkpost - Panthapath (Square Hospital)',
    latitude: 23.7518,
    longitude: 90.3840,
    address: 'Panthapath junction in front of Square Hospital & Bashundhara City. Active traffic sergeants ticketing for zebra-crossing halts and signal obedience.',
    hours: 'Daily 8am - 10pm',
  },
  {
    slug: 'shantinagar-twin-towers',
    name: 'DMP Traffic Checkpost - Shantinagar (Twin Towers)',
    latitude: 23.7410,
    longitude: 90.4125,
    address: 'Shantinagar intersection beside Twin Towers Concord connecting Kakrail to Malibagh. Active traffic box with manual and digital citation issuance.',
    hours: 'Daily 9am - 8pm',
  },
  {
    slug: 'gulshan1-shooting-club-link',
    name: 'DMP Traffic Checkpost - Shooting Club Link (Gulshan-1)',
    latitude: 23.7740,
    longitude: 90.4180,
    address: 'Bir Uttam Mir Shawkat Sarak near National Shooting Club. Key connector between Mohakhali and Gulshan-1 with frequent motorcycle checking.',
    hours: 'Daily 3pm - 10pm',
  },
  {
    slug: 'indira-road-panthapath-link',
    name: 'DMP Traffic Checkpost - Indira Road (Farmgate West)',
    latitude: 23.7565,
    longitude: 90.3830,
    address: 'Indira Road connecting Farmgate to Panthapath / Manik Mia Ave. Sergeants set up checks catching bikes bypassing the main Farmgate crossing.',
    hours: 'Daily 9am - 7pm',
  },
  {
    slug: 'kakrail-mosque-chief-justice',
    name: 'DMP Traffic Checkpost - Kakrail (Chief Justice Residence)',
    latitude: 23.7365,
    longitude: 90.4060,
    address: 'Kakrail More towards High Court / Supreme Court VIP corridor. High-security checking point with strict digital and sergeant case enforcement.',
    hours: '24/7 Monitored Zone',
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
    reportingSource: 'Community Reported (Traffic Alert BD, Waze, DTA)',
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
  console.log(`  ThrottleIQ Police Checkposts Seed v3 — Project: '${projectId}'`);
  console.log(`  Mode: ${writeForReal ? 'WRITING TO FIRESTORE' : 'DRY RUN (pass --yes-i-really-mean-it to commit)'}`);
  console.log(`  New locations in this batch: ${POLICE_CHECKPOSTS_V3.length}`);
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

  for (const post of POLICE_CHECKPOSTS_V3) {
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
    console.log('\nAll v3 checkposts are already in the database. Nothing to do!');
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
  console.log(`\nSuccessfully created ${toCreate.length} Police Checkpost v3 documents in '${COLLECTION}'!`);
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
  POLICE_CHECKPOSTS_V3,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
};
