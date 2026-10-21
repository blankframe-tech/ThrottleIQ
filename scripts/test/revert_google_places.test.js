'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { planImport, toPlaceDocument, SEED_AUTHOR } = require('../import_google_places');
const { planRevert, restorePatch, backupEntries, decodeDoc } = require('../revert_google_places');

const row = (over = {}) => ({
  title: 'Hazipara CNG Filling Station',
  categoryName: 'Gas station',
  location: { lat: 23.757, lng: 90.4172 },
  address: 'DIT Rd, Dhaka 1219, Bangladesh',
  phone: '+880 1875-446038',
  placeId: 'ChIJ_a',
  openingHours: Array.from({ length: 7 }, (_, i) => ({ day: `Day${i}`, hours: 'Open 24 hours' })),
  ...over,
});

const place = (id, data) => ({
  id,
  data: { category: 'fuel', latitude: 23.757, longitude: 90.4172, name: 'Fuel', phone: null, hours: null, address: '', ...data },
});

/** Applies the import's plan the way main() does, so the revert is tested against real import output. */
function imported(rows, existing) {
  const plan = planImport(rows, existing);
  const docs = existing.map((p) => {
    const u = plan.updates.find((x) => x.id === p.id);
    return u ? { id: p.id, data: { ...p.data, ...u.patch } } : p;
  });
  plan.creates.forEach((c, i) => docs.push({ id: `new${i}`, data: toPlaceDocument(c, 'now') }));
  return docs;
}

const DEL = '<delete>';
function applyRevert(rows, docs) {
  const plan = planRevert(rows, docs);
  return docs
    .filter((p) => !plan.deletes.includes(p.id))
    .map((p) => {
      const c = plan.clears.find((x) => x.id === p.id);
      if (!c) return p;
      const data = { ...p.data, ...restorePatch(c, DEL) };
      delete data.googlePlaceId;
      return { id: p.id, data };
    });
}

test('import then revert gives back the pre-import places', () => {
  const rows = [row(), row({ placeId: 'ChIJ_far', location: { lat: 23.8, lng: 90.4 } })];
  const before = [place('generic', {}), place('rider', { name: 'Padma Pump', phone: '017', category: 'garage' })];
  const after = imported(rows, before);
  assert.equal(after.length, 3, 'one enriched, one created');

  assert.deepEqual(applyRevert(rows, after), before);
});

test('seeded places a rider reviewed or someone updated are skipped and reported', () => {
  const seeded = (id, extra) => ({ id, data: { ...toPlaceDocument({ googlePlaceId: id, name: id, category: 'fuel', latitude: 23.7, longitude: 90.4 }, 'now'), ...extra } });
  const plan = planRevert([], [
    seeded('clean', {}),
    seeded('reviewed', { ratingCount: 2, ratingSum: 9 }),
    seeded('edited', { updatedAt: 'later', updatedBy: 'uid_admin' }),
  ]);
  assert.deepEqual(plan.deletes, ['clean']);
  assert.deepEqual(plan.skipped.map((s) => [s.id, s.reason]), [['reviewed', '2 rider review(s)'], ['edited', 'updated by uid_admin']]);
});

test('only Google-derived fields are cleared; rider values and other seeds are left alone', () => {
  const plan = planRevert([row()], [
    place('changed', { googlePlaceId: 'ChIJ_a', phone: '+880 999', hours: '24/7', name: 'Padma Pump' }),
    place('missing', { googlePlaceId: 'ChIJ_not_in_export', phone: '017' }),
    place('osm', { createdBy: 'system:osm-seed-dhaka' }),
  ]);
  assert.deepEqual(plan.deletes, []);
  assert.deepEqual(plan.clears, [
    { id: 'changed', category: 'fuel', fields: { googlePlaceId: 'ChIJ_a', hours: '24/7' } },
    { id: 'missing', category: 'fuel', fields: { googlePlaceId: 'ChIJ_not_in_export' } },
  ]);
  assert.deepEqual(restorePatch(plan.clears[0], DEL), { googlePlaceId: DEL, hours: null });
});

test('a reverted collection plans nothing (idempotent)', () => {
  const rows = [row()];
  const reverted = applyRevert(rows, imported(rows, [place('generic', {})]));
  assert.deepEqual(planRevert(rows, reverted), { deletes: [], skipped: [], clears: [] });
  assert.equal(SEED_AUTHOR, 'system:gmaps-seed-dhaka');
});

test('--seeded-only (rows = null) deletes the seeded places and clears nothing', () => {
  const docs = imported([row(), row({ placeId: 'ChIJ_far', location: { lat: 23.8, lng: 90.4 } })], [place('generic', {})]);
  const plan = planRevert(null, docs);
  assert.deepEqual(plan.deletes, ['new0']);
  assert.deepEqual(plan.clears, []);
});

test('the backup keeps whole deleted docs (timestamps intact) and the old values of cleared fields', () => {
  class Ts { constructor(seconds, nanoseconds) { this.seconds = seconds; this.nanoseconds = nanoseconds; } }
  const rows = [row(), row({ placeId: 'ChIJ_far', location: { lat: 23.8, lng: 90.4 } })];
  const docs = imported(rows, [place('generic', {})]).map((p) => (p.id === 'new0' ? { id: p.id, data: { ...p.data, createdAt: new Ts(1760000000, 5) } } : p));
  const entries = JSON.parse(JSON.stringify(backupEntries(planRevert(rows, docs), new Map(docs.map((p) => [p.id, p.data])), Ts)));

  const del = entries.find((e) => e.action === 'delete');
  assert.deepEqual(decodeDoc(del.data, Ts), docs.find((p) => p.id === 'new0').data);
  const clr = entries.find((e) => e.action === 'clear');
  assert.deepEqual(clr, { id: 'generic', action: 'clear', data: { googlePlaceId: 'ChIJ_a', name: 'Hazipara CNG Filling Station', phone: '+880 1875-446038', hours: '24/7', address: 'DIT Rd, Dhaka 1219' } });
});
