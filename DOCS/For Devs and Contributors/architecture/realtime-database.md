# Realtime Database (live movement channel)

Firestore stays the source of truth for everything structural: the live
session (`liveSessions/{token}`: status, battery, `shareable`, `expiresAt`),
the group ride (`groupRides/{id}`, its roster and membership arrays) and chat
messages. Firebase Realtime Database (RTDB) carries only the high-frequency,
throwaway movement data, over one WebSocket per client:

| Feature | RTDB path | Writer cadence | Firestore it replaces |
|---|---|---|---|
| Partner live viewer | `/live_shares/{token}` | 1 Hz while sharing and riding | position fields of `liveSessions/{token}` (still written every 10 s as the fallback) |
| Group rides | `/group_rides/{rideId}/locations/{uid}` | every 2 s when moved ≥ 5 m, 30 s heartbeat | `groupRides/{id}/memberLocations/{uid}` (demoted to a 2 min heartbeat while RTDB is healthy) |
| Chat typing | `/chat_presence/{chatId}/{uid}` | on keystroke, throttled to 1 per 3 s; `false` after 4 s idle | nothing (new) |

Rules: `database.rules.json` (repo root). Emulator: port 9000
(`firebase.json`).

## Data contract

Every location payload (live share and group ride) has the same shape:

```json
{
  "lat": 23.81, "lng": 90.41,       // required, range-checked
  "ts": {".sv": "timestamp"},       // required, MUST be the server timestamp
  "seq": 17,                        // required, per-writer counter, +1 per write
  "speedMs": 8.3,                   // optional
  "headingDeg": 271.0,              // optional
  "accuracyM": 6.0                  // optional
}
```

- `ts` is forced to the server clock by the rules (`newData.val() === now`),
  so a reader computes staleness as `serverNow - ts` with no phone-clock
  skew (same reasoning as `liveSessions.updatedAt`, §78.7).
- `seq` is the verification hook: a reader that sees `seq` jump by more than
  one has missed updates, and a reader that sees it go backwards has an
  out-of-order delivery. `RealtimeDeliveryStats` (app) and `LiveViewerCore`
  (viewer) both count these.
- No other keys are accepted.

### `/live_shares/{token}`

```json
{ "uid": "<owner uid>", "expiresAt": 1791000000000, "location": { …payload… } }
```

- Token is the same 32-char `Random.secure()` token as `liveSessions/{token}`.
- Readable by anyone (the viewer never signs in) while `expiresAt > now`.
  `/live_shares` itself is not readable, so tokens cannot be enumerated.
- Created by the owner (`uid == auth.uid`), then only ever written/removed by
  that owner. `uid` is immutable. `expiresAt` may be at most 24 h + 1 min out.
- Removed by the app on "Stop sharing now" and on ride end. The viewer also
  gates on the Firestore session (`shareable`, `expiresAt`), so a leftover
  node is never shown on its own.

### `/group_rides/{rideId}`

```json
{
  "meta": { "creatorId": "<uid>" },
  "banned": { "<uid>": true },
  "locations": { "<uid>": { …payload… } }
}
```

RTDB rules cannot read Firestore, so membership is not checked against the
roster. The model is the same bearer model `groupRides/{id}` already uses for
`get` (§90.D4): a ride id is only learnable by being on the ride or holding
its join code.

- `meta` is create-once by the ride's creator (written by
  `GroupRideRepository.createGroupRide`). The app ignores the RTDB channel for
  a ride whose `meta.creatorId` does not match Firestore's `creatorId`, so a
  member who raced to claim `meta` gains nothing.
- `banned/{uid}` is written by the creator when they kick someone
  (`removeMember`). A banned rider can neither read locations nor write one.
- `locations/{uid}` is writable only by that uid (or deletable by the
  creator), only once `meta` exists.
- The creator removes the whole node when the ride ends or is deleted.

Residual risk vs Firestore's `memberLocations` rules: someone who learned the
ride id (e.g. was given the join code) but never joined can read positions
without joining. A Cloud Function mirroring `memberIds` into RTDB would close
this; it isn't done because functions are not deployed on this project's plan.

### `/chat_presence/{chatId}/{uid}`

```json
{ "typing": true, "ts": {".sv": "timestamp"} }
```

- Only for deterministic DM ids (`<uidA>_<uidB>`). A participant is whoever's
  uid is one half of the id; legacy random-id chats get no typing indicator.
- A reader shows "typing…" only while `typing == true` and `serverNow - ts <
  6 s`, so a writer that died mid-word stops showing within 6 s. The writer
  also registers `onDisconnect().remove()`.

## Connection budget

The project is on the Spark plan: **100 simultaneous RTDB connections**.
The app therefore holds its RTDB socket open only while something needs it
(`RealtimeConnectionManager` ref-counts users: live share, group map, chat
room) and calls `goOffline()` 30 s after the last one releases. The web viewer
is one connection per open tab.

## Fallback

If RTDB is not configured (`RTDB_URL` dart-define empty) or the socket has
been disconnected for more than 15 s, the app keeps using the Firestore paths
at their original cadence. Readers always merge both sources and show
whichever position is newer. Nothing depends on RTDB being up.

## Verification layers

1. **Rules suite** — `scripts/test/rtdb/rtdb_rules.test.js`, against the RTDB
   emulator: who may read/write each path, and every shape the rules refuse.
2. **WebSocket delivery suite** — `scripts/test/rtdb/rtdb_delivery.test.js`:
   two real SDK clients over the emulator's WebSocket. Asserts ordered,
   gap-free delivery of a 1 Hz stream (seq), p95 latency under a bound,
   `.info/connected` going false/true across `goOffline()`/`goOnline()`,
   `onDisconnect().remove()` firing, and a writer's queued updates arriving
   after reconnect.
3. **Viewer logic** — `public/live-viewer-core.js` is pure and tested by
   `scripts/test/live_viewer_core.test.js` (freshest-source merge, staleness,
   seq gap counting, transport badge).
4. **App unit tests** — `app/test/core/realtime/` and the feature tests, run
   against `InMemoryRealtimeStore`: throttling, revoke ordering, fallback
   policy, connection ref-counting, typing debounce.
5. **On-device emulator test** — `app/integration_test/realtime_emulator_test.dart`
   drives the real `firebase_database` plugin against the emulator.
6. **Runtime health** — `RealtimeHealthMonitor` (app) tracks
   `.info/connected`, write-ack latency and seq gaps; the group map and the
   viewer show a "Live" / "Delayed" badge from it.
7. **Production smoke** — `scripts/verify_realtime.js` writes a short 1 Hz
   stream to a throwaway `/live_shares` node and listens to it from a second,
   unauthenticated client, then reports latency and loss.

Run 1–3 with `npm run test:rtdb` from `scripts/`.

## Setup (one-time, not done yet)

1. Firebase console → Build → Realtime Database → Create database
   (location `asia-southeast1` is closest to Dhaka), start in **locked mode**.
2. `firebase deploy --only database` to push `database.rules.json`.
3. Build the app with `--dart-define=RTDB_URL=https://<instance>.firebasedatabase.app`.
   Hosting's `/__/firebase/init.json` picks up `databaseURL` on its own, so
   the viewer needs no change.
4. `node scripts/verify_realtime.js --url=<same URL>` against production.
