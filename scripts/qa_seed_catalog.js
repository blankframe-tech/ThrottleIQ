'use strict';

/**
 * qa_seed_catalog.js — data and id-derivation shared by
 * seed_qa_test_riders.js and cleanup_qa_test_riders.js.
 *
 * Pulled out on purpose: cleanup needs the *exact same* set of forum ids the
 * seed script could have written to, so it can query each
 * `forums/{forumId}/posts` subcollection directly (a plain single-field
 * query, always auto-indexed) instead of a `collectionGroup('posts')` query
 * (which needs a composite index this project doesn't have — found the hard
 * way running cleanup against a real canary batch: FAILED_PRECONDITION,
 * "requires a COLLECTION_GROUP_ASC index for collection posts and field
 * qaSeed"). Keeping one copy of the catalog is what guarantees the two
 * scripts can't drift apart on that set.
 */

const QA_EMAIL_DOMAIN = 'qa-seed.invalid';
const QA_PASSWORD = 'QaSeed!2026';

// 30 real Bangladesh-market motorcycles, commuter to high-range. Tier is
// derived from `cc` at use time (see tierForCc), not stored here, so it
// stays a single source of truth.
const BIKE_CATALOG = [
  { brand: 'Honda', model: 'CB Shine 125', year: 2022, cc: 125 },
  { brand: 'Bajaj', model: 'Discover 125', year: 2021, cc: 125 },
  { brand: 'TVS', model: 'Metro Plus 100', year: 2020, cc: 100 },
  { brand: 'Hero', model: 'Splendor Plus', year: 2021, cc: 100 },
  { brand: 'Yamaha', model: 'Saluto 125', year: 2019, cc: 125 },
  { brand: 'Suzuki', model: 'Hayate EP', year: 2020, cc: 110 },
  { brand: 'Runner', model: 'Turbo 100', year: 2019, cc: 100 },
  { brand: 'Lifan', model: 'KP100', year: 2018, cc: 100 },
  { brand: 'Walton', model: 'Fizor 125', year: 2022, cc: 125 },
  { brand: 'Bajaj', model: 'CT 100', year: 2020, cc: 100 },
  { brand: 'Yamaha', model: 'FZS-Fi V3', year: 2022, cc: 149 },
  { brand: 'Honda', model: 'CB150R Streetfire', year: 2021, cc: 150 },
  { brand: 'Suzuki', model: 'Gixxer 155', year: 2021, cc: 155 },
  { brand: 'Bajaj', model: 'Pulsar NS160', year: 2022, cc: 160 },
  { brand: 'TVS', model: 'Apache RTR 160 4V', year: 2022, cc: 160 },
  { brand: 'Yamaha', model: 'MT-15', year: 2023, cc: 155 },
  { brand: 'Honda', model: 'X-Blade 160', year: 2021, cc: 160 },
  { brand: 'Bajaj', model: 'Pulsar 150', year: 2020, cc: 150 },
  { brand: 'TVS', model: 'Apache RTR 165RP', year: 2023, cc: 165 },
  { brand: 'Suzuki', model: 'Gixxer SF 155', year: 2022, cc: 155 },
  { brand: 'Yamaha', model: 'R15 V4', year: 2023, cc: 155 },
  { brand: 'Suzuki', model: 'GSX-R150', year: 2021, cc: 147 },
  { brand: 'KTM', model: 'Duke 250', year: 2022, cc: 250 },
  { brand: 'Honda', model: 'CBR250RR', year: 2022, cc: 250 },
  { brand: 'Kawasaki', model: 'Ninja 300', year: 2021, cc: 296 },
  { brand: 'Royal Enfield', model: 'Classic 350', year: 2022, cc: 349 },
  { brand: 'Royal Enfield', model: 'Himalayan 411', year: 2021, cc: 411 },
  { brand: 'Yamaha', model: 'YZF-R3', year: 2023, cc: 321 },
  { brand: 'KTM', model: 'RC 390', year: 2023, cc: 373 },
  { brand: 'Kawasaki', model: 'Z400', year: 2023, cc: 399 },
];

const TOPICS = ['Road Trips', 'Maintenance', 'Mileage Talk', 'Mods & Accessories'];

/** Port of app/lib/core/utils/slugify.dart's `_slugifyPart`, so seeded forum
 * ids collide with whatever the app itself would derive for the same
 * brand/model — see that file's doc comment for why this must stay exact. */
function slugifyPart(value) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, '_')
    .replace(/[^a-z0-9_]/g, '')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function bikeForumSlug(brand, model) {
  const parts = [brand];
  if (model && model.trim()) parts.push(model);
  return parts.map(slugifyPart).join('__');
}

function generalForumSlug(topic) {
  return slugifyPart(topic);
}

function tierForCc(cc) {
  if (cc <= 125) return 'commuter';
  if (cc <= 165) return 'midrange';
  return 'highrange';
}

/** Every forum id the seed script could ever write a post into — the full
 * set cleanup needs to check. Deterministic and exhaustive because
 * BIKE_CATALOG/TOPICS are the only inputs to bikeForumSlug/generalForumSlug
 * anywhere in the seed script. */
function allSeedableForumIds() {
  const ids = new Set();
  for (const bike of BIKE_CATALOG) ids.add(bikeForumSlug(bike.brand, bike.model));
  for (const topic of TOPICS) ids.add(generalForumSlug(topic));
  return [...ids];
}

module.exports = {
  QA_EMAIL_DOMAIN,
  QA_PASSWORD,
  BIKE_CATALOG,
  TOPICS,
  slugifyPart,
  bikeForumSlug,
  generalForumSlug,
  tierForCc,
  allSeedableForumIds,
};
