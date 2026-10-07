# WebSockets (Realtime Database) — to-do

_Written 2026-10-07. Design and data contract:
`DOCS/For Devs and Contributors/architecture/realtime-database.md`. Open issues: `issues_open.md`
§99 and §100._

The code is all in place and tested against the emulators, but it is **inactive in production**.
The app falls back to Firestore unless both of the following are true: an RTDB instance exists, and
the app was built with `RTDB_URL`.

## 1. Go live (blocking)

- [ ] Firebase console → Build → Realtime Database → **Create database**. Location
      `asia-southeast1`, start in **locked mode**. Note the instance URL.
- [ ] `firebase deploy --only database` (pushes `database.rules.json`).
      ⚠️ Until this database exists, a bare `firebase deploy` fails, because `firebase.json` now
      has a `database` target. Use `--only` until then.
- [ ] Add `--dart-define=RTDB_URL=<instance URL>` to every release build path
      (`scripts/deploy.sh`, `scripts/publish_release.sh`, CI, local run configs).
- [ ] `firebase deploy --only hosting`. The live viewer reads `databaseURL` from
      `/__/firebase/init.json` and needs no code change.
- [ ] Production smoke test: `node scripts/verify_realtime.js --url=<instance URL>`. It needs
      admin credentials (ADC or `GOOGLE_APPLICATION_CREDENTIALS`). Expect 0 lost, 0 out-of-order,
      and a p95 latency of a few hundred ms at most.

## 2. Verify on devices

- [ ] Run the on-device emulator test (header of
      `app/integration_test/realtime_emulator_test.dart` has the exact command):
      `firebase emulators:start --only auth,database`, then `flutter test` it on an Android emulator.
- [ ] **Partner viewer:** start a ride → Share live → open the link in a desktop browser.
      - The marker should move about once a second.
      - The badge should read "Live · 1s".
      - With the phone in airplane mode, the badge should drop to "Updates every 10s".
      - "Stop sharing now" should kill the page.
- [ ] **Group ride:** two phones on one ride.
      - Dots should move every ~2 s and the title badge should read "Live".
      - Leave the ride: the dot should disappear for the other rider.
      - Kick a rider: they should lose the map.
      - Use one phone on an older build: it should still be visible, via the Firestore heartbeat.
- [ ] **Chat:** two phones in a 1:1 chat.
      - "typing…" should appear within about 1 s and clear about 4 s after typing stops.
      - Force-quit the typer mid-word: it should clear within 6 s.
- [ ] Check the Firebase console usage tab after a real group ride. Confirm that Firestore writes
      dropped and that RTDB connections stay low (Spark cap: **100 simultaneous**).

## 3. Fix the E2E harness (pre-existing, `issues_open.md` §100)

- [ ] `app/integration_test/e2e_test.dart` never calls `Firebase.initializeApp()` and crashes at
      launch with `[core/no-app]`. Add a `setUpAll` that initializes Firebase with
      `DefaultFirebaseOptions.currentPlatform`, then re-run:
      `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/e2e_test.dart -d <sim>`.

## 4. Hardening (not blocking)

- [ ] **Group-ride read access (§99.2, MEDIUM).** RTDB rules can't read Firestore `memberIds`, so
      anyone holding the ride id or join code can read positions without joining. Fix: a Cloud
      Function that mirrors `groupRides/{id}.memberIds` into `/group_rides/{id}/access/{uid}`.
      Tighten `locations/.read` to require it. Needs a plan that can deploy functions.
- [ ] **`meta` first-writer-wins (§99.3, LOW).** Covered by the same Cloud Function, which could
      write `meta` server-side.
- [ ] **Orphaned `/live_shares` nodes (§99.4, LOW).** If the app is killed mid-share, the node
      stays until `expiresAt`. Two options:
      - Add the RTDB remove to `OutboxService.enqueueLiveSessionTeardown`.
      - Or have a scheduled function sweep nodes where `expiresAt < now`.
- [ ] **Shares longer than 24 h.** The RTDB `expiresAt` is fixed at the first publish. Refresh it
      on the 10 s Firestore tick if very long shares matter.
- [ ] **App Check.** `firebase_app_check` already covers RTDB. When App Check enforcement is
      switched on, enable it for Realtime Database too.
- [ ] **Bangla review (§99.6).** Get a native speaker to review `groupRideRealtimeLive`,
      `groupRideRealtimeDelayed` and `chatTyping` (in `bn_pending_review.txt`).

## 5. Tuning, once there's real data

- [ ] Look at the delivery stats the group map logs on close (`[GroupRideMap] realtime delivery:`).
      Only `missed` is a smoothness measure; any `outOfOrder` is a bug.
- [ ] Revisit the cadences in light of real battery use and the RTDB download quota:
      - group dots: 2 s / 5 m / 30 s heartbeat (`group_ride_live_channel.dart`);
      - live share: 1 Hz (`kLiveRelayInterval`);
      - Firestore thinning: `kFirestoreTickDivisorWhenRealtime = 2`.
- [ ] Consider dropping the Firestore live-share tick further (e.g. 30 s) once the viewer's RTDB path
      has proven itself in production.
- [ ] Optional: a small diagnostics row in Settings that shows `realtimeHealthProvider`. It would
      show connected, ack p95 and transport, for beta testers' bug reports.

## How to re-run the checks

| What | Command (from) |
|---|---|
| Flutter unit/feature tests (includes 74 realtime) | `flutter test` (`app/`) |
| RTDB rules + WebSocket delivery + viewer logic (61) | `npm run test:rtdb:ci` (`scripts/`) |
| Emulator smoke stream | `npm run verify:realtime:emulator` (`scripts/`) |
| Firestore rules (unchanged, 199) | `npm run test:rules:ci` (`scripts/`) |
