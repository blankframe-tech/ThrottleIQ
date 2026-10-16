'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { emailLookupId, planForProfile, duplicateLookups } = require('../migrate_emails_private.js');

test('lookup id matches the app and the rules (lowercase hex sha256)', () => {
  // Same vector as app/test/features/profile/email_lookup_id_test.dart.
  assert.equal(emailLookupId('alice@example.com'), 'ff8d9819fc0e12bf0d24892e45987e249a28dce836a85cad60e28eaaa8c6d976');
  assert.equal(emailLookupId('  Alice@Example.COM '), emailLookupId('alice@example.com'));
});

test('a profile with a verified email moves it to the private doc and the lookup', () => {
  assert.deepEqual(planForProfile('u1', { displayName: 'A', email: 'Alice@Example.com', emailLower: 'alice@example.com' }, 'alice@example.com'), {
    uid: 'u1',
    account: { email: 'Alice@Example.com', emailLower: 'alice@example.com' },
    lookupId: emailLookupId('alice@example.com'),
  });
});

test('emailLower alone is enough', () => {
  const p = planForProfile('u1', { emailLower: 'alice@example.com' }, 'alice@example.com');
  assert.equal(p.account.email, 'alice@example.com');
  assert.equal(p.lookupId, emailLookupId('alice@example.com'));
});

test('an unverified or different Auth email keeps the private copy but gets no lookup (N3)', () => {
  for (const verified of [null, undefined, 'someone-else@example.com']) {
    const p = planForProfile('u1', { email: 'alice@example.com' }, verified);
    assert.deepEqual(p.account, { email: 'alice@example.com', emailLower: 'alice@example.com' });
    assert.equal(p.lookupId, null);
  }
});

test('an empty or non-string email is stripped without a lookup', () => {
  assert.deepEqual(planForProfile('u1', { email: '', emailLower: null }), { uid: 'u1', account: null, lookupId: null });
});

test('a profile without email fields is left alone (re-runs are no-ops)', () => {
  assert.equal(planForProfile('u1', { displayName: 'A' }), null);
});

test('the same email on two profiles is reported', () => {
  const plans = [
    planForProfile('u1', { email: 'a@x.com' }, 'a@x.com'),
    planForProfile('u2', { email: 'A@x.com' }, 'a@x.com'),
    planForProfile('u3', { email: 'b@x.com' }, 'b@x.com'),
  ];
  assert.deepEqual(duplicateLookups(plans), [['u1', 'u2']]);
});
