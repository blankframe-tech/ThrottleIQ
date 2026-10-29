'use strict';

/**
 * Unit tests for the pure helpers behind the Cloud Functions (issues §90.B9,
 * §90.D2, §90.D12). Runs against the compiled output: `npm test` builds
 * first. No emulator or credentials needed.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const { isOwnedPublicId } = require('../lib/cloudinary-ownership');
const { bestName } = require('../lib/rider-name');

const UID = 'Ab3dEf9hIjKlMnOpQrStUvWxYz12';

test('isOwnedPublicId accepts every folder kind the app uploads to', () => {
  for (const id of [
    `avatars/${UID}/x1y2z3`,
    `bikes/${UID}/abc`,
    `rideShares/${UID}/abc`,
    `places/${UID}/abc`,
    `voiceNotes/${UID}/groupRide123/clip`,
  ]) {
    assert.equal(isOwnedPublicId(id, UID), true, id);
  }
});

test('isOwnedPublicId refuses another rider\'s asset', () => {
  assert.equal(isOwnedPublicId('avatars/someoneElse/x', UID), false);
  // uid as a prefix of a longer uid must not match.
  assert.equal(isOwnedPublicId(`avatars/${UID}extra/x`, UID), false);
  // uid in the wrong position.
  assert.equal(isOwnedPublicId(`avatars/x/${UID}/y`, UID), false);
});

test('isOwnedPublicId refuses malformed or traversal ids', () => {
  for (const id of [
    '',
    'x',
    `avatars/${UID}`,
    `avatars/${UID}/`,
    `avatars/${UID}//x`,
    `avatars/${UID}/../victim/x`,
    `../avatars/${UID}/x`,
    `ava-tars/${UID}/x`,
    `/${UID}/x`,
    'a'.repeat(600),
  ]) {
    assert.equal(isOwnedPublicId(id, UID), false, JSON.stringify(id));
  }
  for (const id of [null, undefined, 42, {}, ['avatars', UID, 'x']]) {
    assert.equal(isOwnedPublicId(id, UID), false);
  }
});

test('isOwnedPublicId refuses an empty or odd uid', () => {
  assert.equal(isOwnedPublicId('avatars//x', ''), false);
  assert.equal(isOwnedPublicId('avatars/.*/x', '.*'), false);
});

test('bestName mirrors UserProfileEntity.bestName', () => {
  assert.equal(bestName({ nickname: ' Speedy ', displayName: 'Abrar' }), 'Speedy');
  assert.equal(bestName({ nickname: '  ', displayName: ' Abrar ' }), 'Abrar');
  assert.equal(bestName({ displayName: '', username: 'abrar_1' }), '@abrar_1');
  assert.equal(bestName({}), 'Rider');
  assert.equal(bestName({ displayName: 42, username: '' }), 'Rider');
});

// issues §101.S5: crash-alert claim rules.
const {
  shouldClaim,
  shouldClaimEscalation,
  CLAIM_LEASE_MS,
} = require('../lib/crash-claim');

const NOW = Date.parse('2026-10-07T12:00:00.000Z');
const FRESH = new Date(NOW - 30 * 1000).toISOString();
const STALE = new Date(NOW - CLAIM_LEASE_MS - 1000).toISOString();

test('shouldClaim takes a pending crash notification', () => {
  assert.equal(shouldClaim('pending', undefined, NOW), true);
});

test('shouldClaim refuses a fresh processing claim and retakes a stale one', () => {
  assert.equal(shouldClaim('processing', FRESH, NOW), false);
  assert.equal(shouldClaim('processing', STALE, NOW), true);
  // Exactly at the lease boundary counts as abandoned.
  assert.equal(
    shouldClaim('processing', new Date(NOW - CLAIM_LEASE_MS).toISOString(), NOW),
    true
  );
  // A claim with no readable timestamp can never expire, so it is retaken.
  assert.equal(shouldClaim('processing', undefined, NOW), true);
  assert.equal(shouldClaim('processing', 'not a date', NOW), true);
});

test('shouldClaim refuses every handled status', () => {
  for (const status of [
    'contacted',
    'mock_not_sent',
    'no_contacts',
    'acknowledged',
    'escalating',
    'escalated',
    undefined,
    null,
  ]) {
    assert.equal(shouldClaim(status, STALE, NOW), false, String(status));
  }
});

test('shouldClaimEscalation takes contacted, retakes only a stale escalating', () => {
  assert.equal(shouldClaimEscalation('contacted', undefined, NOW), true);
  assert.equal(shouldClaimEscalation('escalating', FRESH, NOW), false);
  assert.equal(shouldClaimEscalation('escalating', STALE, NOW), true);
  for (const status of [
    'pending',
    'processing',
    'mock_not_sent',
    'no_contacts',
    'acknowledged',
    'escalated',
  ]) {
    assert.equal(shouldClaimEscalation(status, STALE, NOW), false, status);
  }
});

// Security sweep 2026-10-30 C1: the 60 s default could stop the erasure
// half-way with no marker and no second attempt.
test('onUserAccountDeleted runs up to 540 s and is retried on failure', () => {
  // The v1 auth trigger reads the project id while building its metadata.
  process.env.GCLOUD_PROJECT ??= 'demo-throttleiq';
  const { onUserAccountDeleted } = require('../lib/account-deletion');
  assert.equal(onUserAccountDeleted.__endpoint.timeoutSeconds, 540);
  assert.equal(onUserAccountDeleted.__endpoint.eventTrigger.retry, true);
});

// Security sweep 2026-10-30 C5: per-rider crash-alert rate limit.
const { admitAlert, ALERT_LIMIT, ALERT_WINDOW_MS } = require('../lib/crash-claim');

test('admitAlert admits up to the limit inside the window, then refuses', () => {
  let sent = undefined;
  for (let i = 0; i < ALERT_LIMIT; i++) {
    sent = admitAlert(sent, NOW + i);
    assert.ok(Array.isArray(sent), `alert ${i + 1} admitted`);
  }
  assert.equal(sent.length, ALERT_LIMIT);
  assert.equal(admitAlert(sent, NOW + ALERT_LIMIT), null);
});

test('admitAlert forgets sends older than the window and ignores junk', () => {
  const old = Array(ALERT_LIMIT).fill(NOW - ALERT_WINDOW_MS);
  assert.deepEqual(admitAlert(old, NOW), [NOW]);
  assert.deepEqual(admitAlert(['x', null, {}], NOW), [NOW]);
  assert.deepEqual(admitAlert('not a list', NOW), [NOW]);
});
