'use strict';

/**
 * Pure partner-API security helpers (src/partner-api/core.ts): rider keys,
 * rider tokens, road-sample ids, the webhook address check and the rate
 * limiter. No emulator needed.
 */

process.env.PARTNER_RIDER_SECRET = 'test-only-secret-0123456789abcdef0123456789';

const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../lib/partner-api/core');

test('riderKeyOf is keyed: not sha256 of the id, and different per partner and per secret', () => {
  const k = core.riderKeyOf('maya', 'mayabi-42');
  assert.match(k, /^[0-9a-f]{32}$/);
  assert.notEqual(k, core.sha256('maya:mayabi-42').slice(0, 32));
  assert.equal(core.riderKeyOf('maya', 'mayabi-42'), k);
  assert.notEqual(core.riderKeyOf('other', 'mayabi-42'), k);
  const saved = process.env.PARTNER_RIDER_SECRET;
  process.env.PARTNER_RIDER_SECRET = 'another-secret-0123456789abcdef0123456789';
  try {
    assert.notEqual(core.riderKeyOf('maya', 'mayabi-42'), k);
  } finally {
    process.env.PARTNER_RIDER_SECRET = saved;
  }
});

test('a missing or short secret fails closed', () => {
  const saved = process.env.PARTNER_RIDER_SECRET;
  try {
    delete process.env.PARTNER_RIDER_SECRET;
    assert.throws(() => core.riderKeyOf('maya', 'x'));
    process.env.PARTNER_RIDER_SECRET = 'short';
    assert.throws(() => core.riderKeyOf('maya', 'x'));
  } finally {
    process.env.PARTNER_RIDER_SECRET = saved;
  }
});

test('rider tokens verify, and refuse tampering, other partners and expiry', () => {
  const now = Date.parse('2026-11-08T00:00:00Z');
  const { token, expiresAt } = core.mintRiderToken('maya', 'mayabi-42', now);
  assert.equal(new Date(expiresAt).getTime(), now + core.RIDER_TOKEN_TTL_MS);
  assert.deepEqual(core.verifyRiderToken(token, now + 1000), { partnerId: 'maya', riderRef: 'mayabi-42' });

  const [prefix, body, sig] = token.split('.');
  const forged = Buffer.from(JSON.stringify({ p: 'maya', r: 'mayabi-43', e: now + 1e9 })).toString('base64url');
  assert.throws(() => core.verifyRiderToken(`${prefix}.${forged}.${sig}`, now), core.AuthError);
  assert.throws(() => core.verifyRiderToken(`${prefix}.${body}.${sig.slice(0, -2)}AA`, now), core.AuthError);
  assert.throws(() => core.verifyRiderToken(token, now + core.RIDER_TOKEN_TTL_MS + 1), core.AuthError);
  assert.throws(() => core.verifyRiderToken('garbage', now), core.AuthError);
  assert.throws(() => core.verifyRiderToken('', now), core.AuthError);

  // Signed with maya's derived key, so it can't be replayed as another partner.
  const other = Buffer.from(JSON.stringify({ p: 'other', r: 'mayabi-42', e: now + 1e9 })).toString('base64url');
  assert.throws(() => core.verifyRiderToken(`${prefix}.${other}.${sig}`, now), core.AuthError);
});

test('road-sample ids differ per cell, are stable for retries, and reveal no ride id', () => {
  const a = core.sampleIdOf('maya', 'trip_77', 'wh0r3qs');
  const b = core.sampleIdOf('maya', 'trip_77', 'wh0r3qt');
  assert.notEqual(a, b);
  assert.equal(core.sampleIdOf('maya', 'trip_77', 'wh0r3qs'), a);
  assert.ok(!a.includes('trip_77') && !a.includes('maya'));
  assert.match(a, /^[0-9a-f]{32}$/);
});

test('isPublicAddress refuses loopback, private, link-local, CGNAT and mapped addresses', () => {
  for (const ip of ['127.0.0.1', '10.1.2.3', '172.16.0.1', '192.168.1.1', '169.254.169.254', '100.64.0.1', '0.0.0.0', '224.0.0.1', '::1', '::', 'fe80::1', 'fd00::1', '::ffff:127.0.0.1', 'not-an-ip']) {
    assert.equal(core.isPublicAddress(ip), false, ip);
  }
  for (const ip of ['8.8.8.8', '203.112.1.1', '2606:4700:4700::1111']) {
    assert.equal(core.isPublicAddress(ip), true, ip);
  }
});

test('checkRate allows up to the limit per minute, then throws, and resets next minute', () => {
  core.clearRateLimits();
  const t = Date.parse('2026-11-08T00:00:10Z');
  for (let i = 0; i < 3; i++) core.checkRate('rider:x', 3, t);
  assert.throws(() => core.checkRate('rider:x', 3, t), core.RateLimitError);
  core.checkRate('rider:y', 3, t); // other buckets unaffected
  core.checkRate('rider:x', 3, t + 60_000);
});
