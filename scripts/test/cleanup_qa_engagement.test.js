'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { planForRide } = require('../cleanup_qa_engagement.js');

test('removes seeded comments and lowers the parent tally by exactly that many', () => {
  const p = planForRide({
    rideId: 'real-ride',
    rideData: { comments: 5 },
    seeded: { comments: ['a', 'b', 'c'], likes: [] },
  });
  assert.deepEqual(p.removals, [
    { sub: 'comments', id: 'a' }, { sub: 'comments', id: 'b' }, { sub: 'comments', id: 'c' },
  ]);
  assert.equal(p.update.comments, 2);
});

test('never drives a tally negative', () => {
  const p = planForRide({ rideId: 'r', rideData: { comments: 1 }, seeded: { comments: ['a', 'b'], likes: [] } });
  assert.equal(p.update.comments, 0);
});

test('a ride with nothing seeded produces no change', () => {
  const p = planForRide({ rideId: 'r', rideData: { comments: 4 }, seeded: { comments: [], likes: [] } });
  assert.deepEqual(p.removals, []);
  assert.deepEqual(p.update, {});
  assert.equal(p.clearDeadLikes, false);
});

test('the dead likes field is cleared only on qashare_* rides that carry it', () => {
  assert.equal(planForRide({ rideId: 'qashare_1', rideData: { likes: 9 }, seeded: {} }).clearDeadLikes, true);
  assert.equal(planForRide({ rideId: 'qashare_2', rideData: { upvotes: 3 }, seeded: {} }).clearDeadLikes, false);
  // A real rider's ride is never touched, even if it has a `likes` field.
  assert.equal(planForRide({ rideId: '5a905c0a', rideData: { likes: 9 }, seeded: {} }).clearDeadLikes, false);
});

test('legacy seeded likes are removed but do not change the comments tally', () => {
  const p = planForRide({ rideId: 'r', rideData: { comments: 2 }, seeded: { comments: [], likes: ['x'] } });
  assert.deepEqual(p.removals, [{ sub: 'likes', id: 'x' }]);
  assert.equal(p.update.comments, undefined);
});
