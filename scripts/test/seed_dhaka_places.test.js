'use strict';

/**
 * Unit tests for the pure parts of seed_dhaka_places.js — the OSM→place
 * mapping, the geohash port and the dedup pass.
 *
 * Deliberately no network and no Firestore: everything asserted here is a pure
 * function, which is the same reason `OverpassService.parseElement` is public
 * rather than private on the Dart side.
 *
 * Run with:  node --test scripts/test/
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
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
} = require('../seed_dhaka_places.js');

// ---------------------------------------------------------------------------
// Geohash
// ---------------------------------------------------------------------------

test('geohashEncode matches the app\'s Dart implementation', () => {
  // Reference values produced by GeohashUtils.encode
  // (app/lib/features/poi_directory/data/utils/geohash_utils.dart) at its
  // precision-9 default. The full check was 4,004 points — 2,000 random inside
  // the Dhaka box, 2,000 random worldwide, plus the origin, both poles at the
  // antimeridian and central Dhaka — with zero mismatches; these are the
  // fixtures that keep it that way.
  //
  // This has to agree exactly. A seeded place whose geohash disagrees with what
  // the client would compute falls outside the prefix range
  // getPlacesByGeohash queries, so it exists in Firestore and is invisible on
  // the map — the worst kind of wrong, because nothing errors.
  const cases = [
    [23.757764886304216, 90.44676798461435, 'wh0r4hvr4'],
    [23.666992956110736, 90.32087928323276, 'wh0nxk3wj'],
    [23.67644073188458, 90.44316207148661, 'wh0qdn4tq'],
    [23.91593835183828, 90.46714063490171, 'wh2249u0m'],
    [23.8103, 90.4125, 'wh0r3qs35'], // central Dhaka
    [0.0, 0.0, 's00000000'],
    [90.0, 180.0, 'zzzzzzzzz'],
    [-90.0, -180.0, '000000000'],
  ];

  for (const [lat, lng, expected] of cases) {
    assert.equal(geohashEncode(lat, lng, 9), expected, `${lat},${lng}`);
  }
});

test('geohashEncode honours precision and stays prefix-consistent', () => {
  // Shorter geohashes must be prefixes of longer ones for the same point —
  // that property is what makes the app's prefix-range viewport query work.
  const full = geohashEncode(23.8103, 90.4125, 9);
  for (let p = 1; p <= 9; p += 1) {
    const short = geohashEncode(23.8103, 90.4125, p);
    assert.equal(short.length, p);
    assert.equal(full.startsWith(short), true, `precision ${p}`);
  }
});

// ---------------------------------------------------------------------------
// Categorisation
// ---------------------------------------------------------------------------

test('categoryFor maps the three OSM tag families the app uses', () => {
  assert.equal(categoryFor({ amenity: 'fuel' }), 'fuel');
  assert.equal(categoryFor({ craft: 'motorcycle_repair' }), 'garage');
  assert.equal(categoryFor({ shop: 'motorcycle' }), 'parts');
});

test('categoryFor maps the seed-only tags too', () => {
  assert.equal(categoryFor({ shop: 'motorcycle_repair' }), 'garage');
  assert.equal(categoryFor({ shop: 'motorcycle_parts' }), 'parts');
});

test('a motorcycle tag beats a co-occurring fuel tag', () => {
  // Same precedence as OverpassService._categoryFor: the more specific
  // motorcycle classification wins for a node that carries both.
  assert.equal(categoryFor({ amenity: 'fuel', craft: 'motorcycle_repair' }), 'garage');
  assert.equal(categoryFor({ amenity: 'fuel', shop: 'motorcycle_parts' }), 'parts');
});

test('categoryFor rejects everything else', () => {
  assert.equal(categoryFor({}), null);
  assert.equal(categoryFor({ amenity: 'cafe' }), null); // recreation is not seeded
  assert.equal(categoryFor({ shop: 'car_repair' }), null);
  assert.equal(categoryFor({ amenity: 'charging_station' }), null);
});

// ---------------------------------------------------------------------------
// Address
// ---------------------------------------------------------------------------

test('addressFrom joins the addr:* parts it has, and only those', () => {
  assert.equal(
    addressFrom({ 'addr:housenumber': '12', 'addr:street': 'Gulshan Ave', 'addr:city': 'Dhaka' }),
    '12, Gulshan Ave, Dhaka'
  );
  assert.equal(addressFrom({ 'addr:city': 'Dhaka' }), 'Dhaka');
  assert.equal(addressFrom({}), '');
  // Blank and non-string values are dropped rather than producing ", , ".
  assert.equal(addressFrom({ 'addr:street': '   ', 'addr:city': 'Dhaka' }), 'Dhaka');
});

// ---------------------------------------------------------------------------
// parseElement
// ---------------------------------------------------------------------------

test('parseElement maps a named node', () => {
  const candidate = parseElement({
    type: 'node',
    id: 123,
    lat: 23.8,
    lon: 90.4,
    tags: {
      amenity: 'fuel',
      name: 'Padma Filling Station',
      'addr:street': 'Mirpur Rd',
      phone: '+8801711000000',
      opening_hours: '24/7',
    },
  });

  assert.deepEqual(
    { ...candidate },
    {
      osmId: 'node/123',
      name: 'Padma Filling Station',
      category: 'fuel',
      latitude: 23.8,
      longitude: 90.4,
      address: 'Mirpur Rd',
      phone: '+8801711000000',
      hours: '24/7',
      _named: true,
    }
  );
});

test('parseElement takes a way\'s coordinate from out center', () => {
  // Most of Dhaka's petrol stations are mapped as area polygons, not points, so
  // this path is the majority of the fuel category — not an edge case.
  const candidate = parseElement({
    type: 'way',
    id: 456,
    center: { lat: 23.75, lon: 90.39 },
    tags: { amenity: 'fuel', name: 'Jamuna Fuel' },
  });

  assert.equal(candidate.osmId, 'way/456');
  assert.equal(candidate.latitude, 23.75);
  assert.equal(candidate.longitude, 90.39);
});

test('parseElement falls back to the category name when OSM has none', () => {
  const candidate = parseElement({
    type: 'node',
    id: 7,
    lat: 23.8,
    lon: 90.4,
    tags: { craft: 'motorcycle_repair' },
  });
  assert.equal(candidate.name, 'Garage');
  assert.equal(candidate._named, false);
});

test('a Bangla name is kept in preference to name:en', () => {
  // In Dhaka the local-script name is the more useful label for a rider, so
  // `name` wins; name:en is only a fallback for an entry with no `name` at all.
  const bangla = parseElement({
    type: 'node',
    id: 8,
    lat: 23.8,
    lon: 90.4,
    tags: { amenity: 'fuel', name: 'মেঘনা পেট্রোল পাম্প', 'name:en': 'Meghna Petrol Pump' },
  });
  assert.equal(bangla.name, 'মেঘনা পেট্রোল পাম্প');

  const englishOnly = parseElement({
    type: 'node',
    id: 9,
    lat: 23.8,
    lon: 90.4,
    tags: { amenity: 'fuel', 'name:en': 'Meghna Petrol Pump' },
  });
  assert.equal(englishOnly.name, 'Meghna Petrol Pump');
  assert.equal(englishOnly._named, true);
});

test('parseElement rejects elements it cannot place', () => {
  assert.equal(parseElement({ type: 'node', id: 1, lat: 23.8, lon: 90.4, tags: {} }), null);
  // No coordinates at all — a way returned without `out center`.
  assert.equal(
    parseElement({ type: 'way', id: 2, tags: { amenity: 'fuel' } }),
    null
  );
  // Coordinate present but not numeric.
  assert.equal(
    parseElement({ type: 'node', id: 3, lat: '23.8', lon: 90.4, tags: { amenity: 'fuel' } }),
    null
  );
  // A node at 0,0 is a legitimate coordinate and must NOT be rejected as falsy.
  assert.notEqual(
    parseElement({ type: 'node', id: 4, lat: 0, lon: 0, tags: { amenity: 'fuel' } }),
    null
  );
  // ...and neither must id 0.
  assert.equal(
    parseElement({ type: 'node', id: 0, lat: 23.8, lon: 90.4, tags: { amenity: 'fuel' } }).osmId,
    'node/0'
  );
});

// ---------------------------------------------------------------------------
// Dedup
// ---------------------------------------------------------------------------

test('dedupeCandidates merges the same place mapped as node and way, keeping the node', () => {
  const { candidates, dropped } = dedupeCandidates([
    {
      osmId: 'way/1',
      name: 'Padma Filling Station',
      category: 'fuel',
      latitude: 23.8,
      longitude: 90.4,
    },
    {
      osmId: 'node/2',
      name: 'Padma Filling Station',
      category: 'fuel',
      latitude: 23.80001,
      longitude: 90.40001,
    },
  ]);

  assert.equal(dropped, 1);
  assert.equal(candidates.length, 1);
  // The node wins: a hand-placed point is usually on the forecourt entrance,
  // which is a better pin than a building centroid.
  assert.equal(candidates[0].osmId, 'node/2');
});

test('dedupeCandidates keeps two genuinely different nearby places', () => {
  const { candidates, dropped } = dedupeCandidates([
    { osmId: 'node/1', name: 'Padma Filling', category: 'fuel', latitude: 23.8, longitude: 90.4 },
    { osmId: 'node/2', name: 'Meghna Filling', category: 'fuel', latitude: 23.8, longitude: 90.4 },
    // Same name, same spot, different category — a garage attached to a pump.
    { osmId: 'node/3', name: 'Padma Filling', category: 'garage', latitude: 23.8, longitude: 90.4 },
  ]);

  assert.equal(dropped, 0);
  assert.equal(candidates.length, 3);
});

test('dedupeCandidates normalises whitespace and case in names', () => {
  const { candidates } = dedupeCandidates([
    { osmId: 'node/1', name: 'Padma  Filling', category: 'fuel', latitude: 23.8, longitude: 90.4 },
    { osmId: 'way/2', name: 'padma filling', category: 'fuel', latitude: 23.8, longitude: 90.4 },
  ]);
  assert.equal(candidates.length, 1);
});

// ---------------------------------------------------------------------------
// Firestore document shape
// ---------------------------------------------------------------------------

test('toPlaceDocument writes exactly PlaceModel.toFirestore\'s fields', () => {
  // A seeded place and a rider-submitted one must be the same shape, so
  // PlaceModel.fromFirestore needs no special case for either. The field list
  // is checked, not just the values, because a *missing* key is what silently
  // reads back as a default.
  const doc = toPlaceDocument(
    {
      osmId: 'node/123',
      name: 'Padma Filling Station',
      category: 'fuel',
      latitude: 23.8103,
      longitude: 90.4125,
      address: 'Mirpur Rd',
      phone: null,
      hours: null,
    },
    { verified: true, createdAt: 'TIMESTAMP' }
  );

  assert.deepEqual(Object.keys(doc).sort(), [
    'address',
    'category',
    'createdAt',
    'createdBy',
    'geohash',
    'hours',
    'latitude',
    'longitude',
    'name',
    'osmId',
    'phone',
    'photoUrls',
    'ratingCount',
    'ratingSum',
    'verified',
  ]);

  assert.equal(doc.geohash, 'wh0r3qs35');
  assert.equal(doc.createdBy, SEED_AUTHOR);
  assert.equal(doc.verified, true);
  assert.deepEqual(doc.photoUrls, []);
  assert.equal(doc.ratingSum, 0);
  assert.equal(doc.ratingCount, 0);
  assert.equal(doc.phone, null);
  assert.equal(doc.hours, null);
});

test('the seed author is a sentinel, not a plausible uid', () => {
  // "My places" is `createdBy == <uid>`. If this ever collided with a real
  // Firebase uid, that rider would inherit every seeded pump in Dhaka. A colon
  // cannot appear in a Firebase uid.
  assert.match(SEED_AUTHOR, /^system:/);
});

test('toPlaceDocument can be told to leave places unverified', () => {
  const doc = toPlaceDocument(
    { osmId: 'node/1', name: 'X', category: 'fuel', latitude: 23.8, longitude: 90.4 },
    { verified: false, createdAt: 'TIMESTAMP' }
  );
  assert.equal(doc.verified, false);
  assert.equal(doc.address, ''); // never undefined — Firestore rejects that
});

// ---------------------------------------------------------------------------
// Query construction
// ---------------------------------------------------------------------------

test('buildQuery asks for nodes, ways and relations in the given box', () => {
  const query = buildQuery(DHAKA_BBOX, ['fuel', 'garage', 'parts']);

  assert.match(query, /^\[out:json\]\[timeout:\d+\];/);
  assert.match(query, /out center;/);
  assert.match(query, /nwr\["amenity"="fuel"\]\(23\.65,90\.3,23\.92,90\.52\);/);
  assert.match(query, /nwr\["craft"="motorcycle_repair"\]/);
  assert.match(query, /nwr\["shop"="motorcycle"\]/);
  // Node-only would miss every petrol station mapped as a polygon.
  assert.equal(query.includes('node['), false);
});

test('buildQuery honours a category filter', () => {
  const query = buildQuery(DHAKA_BBOX, ['fuel']);
  assert.match(query, /"amenity"="fuel"/);
  assert.equal(query.includes('motorcycle'), false);
});

test('parseBbox accepts a valid box and rejects the ways it can be wrong', () => {
  assert.deepEqual(parseBbox('23.65,90.3,23.92,90.52'), {
    south: 23.65,
    west: 90.3,
    north: 23.92,
    east: 90.52,
  });
  assert.throws(() => parseBbox('23.65,90.3,23.92'), /four numbers/);
  assert.throws(() => parseBbox('a,b,c,d'), /four numbers/);
  assert.throws(() => parseBbox('23.92,90.3,23.65,90.52'), /south must be less than north/);
  assert.throws(() => parseBbox('23.65,90.52,23.92,90.3'), /west must be less than east/);
  assert.throws(() => parseBbox('-91,90.3,23.92,90.52'), /within ±90/);
  assert.throws(() => parseBbox('23.65,90.3,23.92,181'), /within ±180/);
});

test('the default box covers central Dhaka and its ride-out fringes', () => {
  const inside = (lat, lon) =>
    lat >= DHAKA_BBOX.south &&
    lat <= DHAKA_BBOX.north &&
    lon >= DHAKA_BBOX.west &&
    lon <= DHAKA_BBOX.east;

  assert.equal(inside(23.8103, 90.4125), true, 'central Dhaka');
  assert.equal(inside(23.7925, 90.4078), true, 'Gulshan');
  assert.equal(inside(23.8759, 90.3795), true, 'Uttara');
  assert.equal(inside(23.7104, 90.4074), true, 'Old Dhaka / Sadarghat');
  assert.equal(inside(23.6238, 90.4995), false, 'Narayanganj town is outside');
});
