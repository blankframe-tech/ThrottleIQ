# Plan: ride-screen actions menu, minimize, and the "ride in progress" strip

## REVIEW (2026-10-17) of the uncommitted implementation on `main`

**Status (2026-10-17): items 1–11 fixed, plus the strip's "Directions to bike" now reuses `PlaceLaunchActions.openDirectionsTo` (Apple Maps fallback, failure snackbar). The known limits below are still open.**
It covers all 5 plan sections. `flutter analyze` on the touched files is clean. Not run yet: `scripts/check.sh`
(full tests and rules suite) and a device test. Fix these before committing:

**Must fix**
1. **Stale parking pin comes back** (`parking_pin_provider.dart`). The provider is lazy and its status listener
   only fires on changes. If a ride ends while the provider was never built (e.g. the app restarts and the
   restored ride is discarded), `parking_pin` stays in prefs. The next paused ride then loads it, and
   "Directions to bike" points at an old spot. Fix: `fireImmediately: true`, and clear when the status
   isn't `paused`. Also drop a loaded pin whose `at` is earlier than the current ride's start.
2. **Load/clear race**: `_load()` is async, so a `clear()` that lands first can be undone when `_load`
   finishes. Fix: a `_cleared` or generation guard in `_load`. Test: build → clear → expect null after the load settles.
3. **Checkpoint snackbar hangs offline** (`ride_actions_menu.dart:87`). `collection.add()` only completes on a
   server ack, so on mobile data dead zones the rider gets no feedback. Fix: don't await. Fire the write with
   `unawaited` and `catchError`, then show "Checkpoint saved (syncs when online)" right away.
4. **New checkpoint is invisible.** It breaks the documented rule in `places_provider.dart:95`: adding a place must
   call `ref.invalidate(nearbyPlacesProvider)`. Without it, the Places tab (where Minimize lands) and the
   live-ride markers (`liveRidePlacesProvider`, which refetches only every 5 km) don't show the pin.
   Fix: invalidate, and add an optimistic insert into `liveRidePlacesProvider`.
5. **The time isn't visible anywhere.** You asked for "auto location and time", but `createdAt` is never shown
   for places. Fix: show "Reported 2:14 PM · expires in 23 h" on police places that have `createdAt`/`expiresAt`
   (radar banner row and place detail).
6. **The localized name is written into a public doc.** `name: context.l10n.copCheckpoint` saves Bangla for
   BN users, and English riders then see it. Fix: a fixed `'Cop checkpoint'` constant.

**Should fix**
7. Parking pin with `transitionPending`: `pauseRide()` returns early, so the pin is set but the ride never
   pauses, and resuming later clears it silently. Fix: only drop when `status == active && !transitionPending`,
   or check the status after the pause.
8. Rules: `expiresAt` accepts any timestamp (year 9999, the past). Bound it with
   `expiresAt > request.time && expiresAt <= request.time + duration.value(2, 'd')` and add a rules test.
9. Strip: hard-coded `Colors.amber` and `Colors.red` should be `palette.warning` and `palette.danger`. Its own
   `formatDuration` duplicates `SpeedFormatter.durationFromDuration`, which the cockpit clock uses.
10. Gate the strip's crash redirect with `showCrashOverlay(detected: next)` so it matches the cockpit. It does
    nothing today (`crashAlertsEnabled = false`), but will matter once the alarm ships.
11. Missing tests: `RideActionsMenu` (no fix → snackbar; parking pin → drop + pause; minimize → `/home/places`,
    or `/home/stats` when Places is off).

**Known limits (accept or ticket)**: no dedupe or abuse check on reports, and any rider can add a permanent
police pin mid-ride. When minimized, turn-by-turn guidance and the alert flashes are hidden. Non-shell routes
don't show the strip. A Firestore TTL policy on `places.expiresAt` is still pending your approval (prod).

**Next steps**: fix 1–6 → fix 7–11 → `scripts/check.sh` once → device run (verification list below)
→ update `DOCS/Handoff for agents and Todos/features.md` → commit on `main` when asked.

---

> After approval, step 0 copies this file to
> `DOCS/Handoff for agents and Todos/plan_ride_minimize_menu.md` (the local md the user asked for).

## Context
Today `ActiveRideScreen` (`/ride/active`) takes over the whole app while a ride records. The rider can't
check Places or anything else mid-ride, and has no quick way to mark a cop checkpoint or remember where
the bike is parked. This plan adds:
1. A **⋮ dropdown** at the top right of the cockpit with three items: **Cop checkpoint here**, **Parking pin**, **Minimize**.
2. **Minimize** goes to the Places tab (or Rides if Places is off). Every tab stays usable. A pinned strip
   on all shell screens says a ride is recording, and tapping it returns to the cockpit.

Decisions the user made:
- **Parking pin** is device-only. It saves a "my bike is here" pin with lat/lng and time, then pauses the
  ride. It shows on the live map and on the strip with a Directions button. It clears on resume or end.
- **Cop checkpoint** is a public `police` place at the current GPS fix, with time = `createdAt`. The rider
  chooses **"Expires in 24 h"** or **"Permanent"**.
- **Minimize** goes to `/home/places`, with `/home/stats` as the fallback.

## What already exists (reuse)
- Pause: `RideRecordingNotifier.pauseRide()` (`ride_recording_provider.dart:1130`). It is latched and safe on a double tap.
- Position: `rideRecordingProvider.select((s) => s.currentPosition)`. Uid: `currentUserProvider`.
- Places write: `PlaceRepository().addPlace(PlaceEntity…)`, `GeohashUtils.encode` (pattern in `add_place_screen.dart:181-226`). `PlaceCategory.police` already exists and already feeds the Highway Radar.
- Every map and radar read goes through `PlaceRepository.nearbyViaGeohashRanges` (`place_repository.dart`). That is the single place to filter out expired pins.
- Directions: `googleMapsDirectionsUri` (`poi_directory/domain/place_directions.dart`) plus `url_launcher`.
- Persistence: `shared_preferences`, already a dependency (pattern in `core/cloud/pull_watermark.dart`).
- Record tab: `record_screen.dart:86` already redirects to `/ride/active` while riding, so the Record tab acts as a second "back to ride" button.
- `rideRecordingProvider` isn't autoDispose, and recording runs in the notifier plus the foreground service, so leaving the screen doesn't stop the ride.

## Changes

### 1. Actions menu: new `features/ride/presentation/widgets/ride_actions_menu.dart`
A `ConsumerWidget` holding a `PopupMenuButton<_RideAction>` (`Icons.more_vert`, tooltip, `palette.textPrimary`).
It goes into the top-bar `Row` in `active_ride_screen.dart:539`, after the live-share `IconButton`. The logic
lives in this file to keep the 1175-line screen from growing.
- **Cop checkpoint here**
  - `currentPosition` is null: show the snackbar "No GPS fix yet".
  - Otherwise: open a small bottom sheet with two `ListTile`s, *Expires in 24 h* (first) and *Permanent*.
  - Then call `addPlace(PlaceEntity(id: '', name: l10n.copCheckpoint, category: police, lat/lng, geohash, address: '', createdBy: uid, createdAt: now, expiresAt: now + 24h | null))`.
  - Show a snackbar on success or failure. Firestore queues the write offline, so no extra handling.
- **Parking pin**: `parkingPinProvider.notifier.drop(position)`, then `pauseRide()`. With no fix, show the same snackbar.
- **Minimize**: `context.go(modules.places ? '/home/places' : '/home/stats')`. `_endingRide` stays untouched: status stays active, so the screen's idle redirect never fires.

### 2. Expiring checkpoints: `expiresAt` on places
- `PlaceEntity`: add `final DateTime? expiresAt`, plus `bool isExpiredAt(DateTime now) => expiresAt != null && !now.isBefore(expiresAt!)`, and add it to `props`.
- `PlaceModel`: add the field and thread it through `fromEntity`, `toEntity`, `fromFirestore` (`Timestamp?`) and `copyWith`. `toFirestore` writes `'expiresAt'` only when non-null, the same as `tags`, so other docs keep their current shape.
- `nearbyViaGeohashRanges`: add `DateTime? now` (for tests) and `if (place.isExpiredAt(now)) continue;` inside the dedupe loop. One filter covers the Places map, the Highway Radar, and the live-ride markers. "My places" still lists the rider's own expired pins, which is fine as history.
- `firestore.rules` `places` create: add `&& (!('expiresAt' in request.resource.data) || (request.resource.data.expiresAt is timestamp && request.resource.data.category == 'police'))`.
- Optional, needs the user's go-ahead because it touches prod: a Firestore TTL policy on `places.expiresAt` so expired docs get deleted server-side. This is gcloud config, not code.

### 3. Parking pin: new `features/ride/presentation/providers/parking_pin_provider.dart`
- `StateNotifierProvider<ParkingPinNotifier, ({LatLng point, DateTime at})?>`.
- Persist in SharedPreferences key `parking_pin` as `"lat,lng,epochMs"`. Load it in the constructor, because a paused ride survives an app kill via `restoreInterruptedRide`.
- `drop(LatLng)` writes the pin. `clear()` removes it.
- `ref.listen(rideRecordingProvider.select((s) => s.status))`: clear when the status becomes `active` (resume), `idle` or `completed`.
- Show it in `_RouteMap`'s `MarkerLayer` (`active_ride_screen.dart:120`) as a 🅿️ marker in the same style as the place markers.

### 4. "Ride in progress" strip: new `features/ride/presentation/widgets/ride_in_progress_bar.dart`
- It watches a narrow select: `(status, elapsed.inSeconds, distanceM)`. It renders nothing unless the status is `active` or `paused`.
- Layout: a full-width `Material` row with a red dot (amber when paused), "Recording ride · 12.4 km · 0:32:10" (or "Ride paused · …"), and a chevron.
  - Tap: `context.go('/ride/active')`.
  - When paused and a parking pin exists: add a trailing **Directions to bike** `TextButton`, which calls `launchUrl(googleMapsDirectionsUri(...), mode: externalApplication)`.
  - Wrap it in `Semantics(button: true, label: …)`. Minimum height 48.
- **Safety**: `ref.listen` on `crashDetected` going false → true calls `context.go('/ride/active')`. The crash countdown overlay (`_CrashOverlayGate`) only lives in the cockpit, so it would never show while the app is minimized.
- Mount it in `AppShell` (`shared/widgets/app_shell.dart`): `bottomNavigationBar` becomes `Column(mainAxisSize: min, [RideInProgressBar(), <existing nav container>])`. It sits above the nav on every tab and never covers a screen's AppBar. Full-screen routes outside the shell (summary, share) don't show it; that's acceptable.

### 5. l10n (`app_en.arb` + `app_bn.arb`, then `flutter gen-l10n`)
New keys:

| Area | Keys |
|---|---|
| Menu | `rideActionsTooltip`, `copCheckpointHere`, `copCheckpoint`, `parkingPinHere`, `minimizeRide` |
| Checkpoint sheet | `checkpointExpiresInDay`, `checkpointPermanent` |
| Snackbars | `checkpointSaved`, `checkpointSaveFailed`, `noGpsFixYet` |
| Strip | `rideRecordingBar(distance, duration)`, `ridePausedBar(distance, duration)`, `directionsToBike` |

Append the BN strings to `bn_pending_review.txt` in the current batch.

## Tests (smallest set that covers the new logic)
- `test/features/poi_directory/data/repositories/place_nearby_query_test.dart`: an expired place is dropped, while permanent and not-yet-expired places are kept (pass `now`).
- `PlaceModel` round-trip with and without `expiresAt`. `toFirestore` leaves the key out when it's null.
- `test/features/ride/.../parking_pin_provider_test.dart`: drop persists and reloads (`SharedPreferences.setMockInitialValues`), and the pin clears on paused→active and on →idle.
- `test/shared/app_shell_test.dart`: the strip is hidden when idle, shows when active, and a tap goes to `/ride/active`.
- `scripts/test/rules/places_rules.test.js`: create with `expiresAt` on police is allowed; on fuel, or as a non-timestamp, it is denied.

## Verification
1. `scripts/check.sh`: analyze, unit tests and rules tests (the repo's QA gate).
2. On a device (`deploy` skill / `flutter run`):
   - Start a ride, open ⋮ and pick Cop checkpoint → 24 h. A 🚓 shows up on the Places map, and Firestore has a doc with `expiresAt` set.
   - Pick Parking pin. The ride pauses and a 🅿️ appears on the map.
   - Pick Minimize. You land on Places with the strip showing "Ride paused".
   - Tap Directions to bike. Google Maps opens.
   - Switch tabs. The strip stays on every tab.
   - Tap the strip, or the Record tab. You're back in the cockpit, and Resume clears the pin.
   - Kill and relaunch the app while paused. The pin is still there.
3. Onboarding guardian: if the cockpit is a tour slide, check `onboarding_manifest.dart` before pushing.
