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
