# ThrottleIQ v2 — Social/Community Rework: Handoff & Forward Plan

_Last updated: 2026-07-22 · Branch: `feat/v2-social` · App version: `2.0.0-beta.3+5`_

This is the **single source of truth** for the v2 rework (social feed + follow,
forums, garage/service, places, rides tab, safety, package rename). It captures
what is done and tested, what is in progress, and exactly what remains — enough
to resume with zero prior conversation context.

> Sibling docs: `todosanddone.md` (honest works/next status), `features.md`
> (as-built feature map), `future2.md` (follow-model decision — now settled),
> `RELEASE_NOTES.md`. This doc supersedes `todo_now.md` (which was the Phase 2–4
> spec) for anything v2.

---

## 0. TL;DR — where things stand

- **`main`** holds the shipped **v2 editorial BW redesign** → released as
  `v2.0.0-beta.3+5` (signed APK on GitHub). That is the last fully built,
  device-verified state.
- **`feat/v2-social`** (this branch) holds new work **not yet buildable on
  Android** — the package rename intentionally breaks the Gradle build until
  fresh Firebase config lands (see §1). Everything here is `flutter analyze`
  clean but **not runtime-tested**.
- Three epics complete on this branch: **package rename (code side)**,
  **Phase A (profile + follow backend + share-bug fix)**, and **Epic B
  (social UI: share screen, feed rework, voting)**.
- **9 epics remain** (§5). Build order is dependency-first. §1 (Firebase
  reconfig) is still open — confirmed still blocked as of this session:
  `google-services.json` still has the old package name, though
  `GoogleService-Info.plist` has already been updated to the new bundle id.

---

## 1. ⛔ CRITICAL BLOCKER — Firebase reconfiguration (user action)

The package/bundle id was renamed `com.throttleiq.throttleiq` → **`com.bft.throttleiq`**
to match the Play Console listing. `google-services.json` and
`GoogleService-Info.plist` are keyed to the *old* id, so:

- **Android builds fail** (`google-services` Gradle plugin: "No matching client
  found for package name 'com.bft.throttleiq'") until the new
  `google-services.json` is in place.
- Firebase Auth/Firestore/Storage will not work on the renamed app at runtime
  until reconfigured.

**Do this in the `throttleiqfb` Firebase console:**
1. Add **Android** app, package `com.bft.throttleiq`, register release SHA-1
   `85:42:B8:AD:19:1E:6B:74:FC:85:27:4F:48:9D:BC:CE:4B:00:2F:10` (+ debug SHA-1
   for Google Sign-In in debug). Download `google-services.json` →
   `app/android/app/google-services.json` (replace).
2. Add **iOS** app, bundle `com.bft.throttleiq`. Download
   `GoogleService-Info.plist` → `app/ios/Runner/GoogleService-Info.plist`
   (replace).
3. Hand back to the coder agent to finish:
   - regenerate `app/lib/firebase_options.dart` appIds (they change on
     re-registration — do **not** guess them; use the new files or
     `flutterfire configure`),
   - make `DefaultFirebaseOptions.currentPlatform` platform-aware (it currently
     hard-returns `ios`, a latent bug — Android worked only because
     project-level keys overlap),
   - update the iOS reversed-client-id URL scheme in `Info.plist`.

Until step 1 is done, **do not attempt an Android release build** from this
branch.

---

## 2. What was DONE & TESTED

### 2a. Editorial BW redesign — SHIPPED (on `main`, released beta.3)
Full structural restructure to match `designs/ThrottleIQ Editorial BW.html`
(warm paper base, black "ink" panels, big rounded cards, Space Grotesk + Inter,
blue primary accent + orange attention). Six screens rebuilt against the mockup
and **verified live on the iOS simulator**: Record, Active Ride, Ride Summary,
Insights ("Your Journey"), Garage, Maintenance. Shared component library at
`app/lib/shared/widgets/editorial.dart`. Released as `v2.0.0-beta.3+5` with a
signed APK. _(Active Ride compiled clean but was not screenshotted live — needs
an in-progress GPS ride.)_

### 2b. Package rename (code side) — DONE, blocked on §1
Commit `0c84535`. Every active reference is now `com.bft.throttleiq`: Gradle
`applicationId`+`namespace`, Kotlin source dir moved to
`android/app/src/main/kotlin/com/bft/throttleiq/`, AndroidManifest
foreground-service name, all iOS `PRODUCT_BUNDLE_IDENTIFIER` (app + RunnerTests),
`GoogleService-Info.plist` BUNDLE_ID, `firebase_options` `iosBundleId`,
flutter_map userAgent strings, SETUP docs. (`google-services.json` deliberately
untouched — comes from §1.)

### 2c. Phase A — profile + follow backend — DONE, analyze-clean
Commit `fa5af24`. **Not runtime-tested** (blocked by §1). See §3–§4.

### 2d. Share-bug fix — DONE
The reported "sharing shows an error / doesn't share" bug: `shareRide` threw
`Exception('Polyline too short after privacy zone clipping')` on short or
near-home rides (privacy clip consumed the whole track). It now shares with **no
route line** instead of throwing (`ride_share_repository.dart`). The end→share
UX rebuild (photo + audience picker) is Phase B.

### Verification status legend used throughout
- **✅ verified** — exercised on device/sim.
- **🟡 analyze-clean** — `flutter analyze` passes; not run on device.
- **⬜ not started.**

---

## 3. Key architecture decisions (v2)

- **Open follow, not follow-requests.** Decided 2026-07-22 (supersedes the
  request-based idea in `future2.md`). Follow anyone instantly; visibility is
  controlled per-share by audience tier.
- **Audience tiers: public / followers / mutual.** Because **Firestore security
  rules are NOT query filters** (a list query whose rule needs a per-doc
  `exists()`/`get()` is rejected wholesale), followers/mutual visibility is
  **materialized at share time** into the ride's `allowedUserIds` array (the
  author's follower or mutual uids). The feed reads it with
  `where('allowedUserIds', arrayContains: myUid)`. Each real feed query lines up
  with exactly one rule clause (`audience=='public'` | `allowedUserIds`
  array-contains me | `userId==me`). Trade-off: audience is a snapshot at share
  time (new followers don't retroactively gain access) — acceptable/common.
- **Follow counts via `count()` aggregation**, not denormalized counters — so no
  write ever touches another user's doc, and there's nothing to spoof.
- **Unique @usernames via a reservation collection** `usernames/{handleLower}` →
  `{uid}`, claimed in a transaction. Gives global uniqueness + O(1) handle→uid
  lookup without exposing the whole users collection.
- **Votes**: net score is **derived client-side** (`upvotes - downvotes`), not
  stored — so there's no orderable score field to spoof. Feed ranking sorts a
  recent window client-side. Per-user vote doc at `rides/{id}/votes/{uid}`;
  ride-doc `upvotes`/`downvotes` bump under a bounded ±1 rule.
- **User profile doc is now public-read** (any authed user) to enable
  search/follow; writes stay owner-only and every subcollection keeps its own
  owner-only rule. Email is intentionally searchable (user requirement).

---

## 4. Firestore data model (after Phase A)

Rules: `firestore.rules`. Indexes: `firestore.indexes.json`.

| Collection | Purpose | Read | Write |
|---|---|---|---|
| `users/{uid}` (root fields) | Public profile: displayName, username, usernameLower, nickname, bio, photoUrl, email, emailLower | any authed | owner |
| `users/{uid}/{rides,bikes,maintenance,emergencyContacts,...}` | Owner-only mirrors/contacts | owner | owner |
| `usernames/{handleLower}` | `{uid}` reservation for unique @handles | any authed | create-if-free / owner delete |
| `follows/{followerUid}_{followeeUid}` | Follow edge | any authed | follower only |
| `rides/{rideId}` | Shared-ride feed post + `audience`, `allowedUserIds`, `upvotes`, `downvotes`, `likes`, `comments` | `rideVisibleTo()` | owner + bounded counter bumps |
| `rides/{rideId}/{likes,votes,comments}` | Engagement | `rideVisibleTo(parent)` | own doc / authed create |
| `forums/{forumId}` + `/posts/{postId}/replies/...` | Bike/topic forums | authed | owner + bounded counters |
| `forum_follows/{uid}_{forumId}` | Forum membership | owner | owner |
| `places/{placeId}`, `reviews/{uid}_{placeId}` | POI directory + reviews | authed | owner + bounded rating |
| `liveSessions/{token}`, `crashNotifications/{id}` | Live share / crash | token / owner | owner |

New indexes added: `rides` (`audience`+`createdAt`), `rides`
(`allowedUserIds` array-contains + `createdAt`).

---

## 5. Forward plan — remaining epics (dependency order)

Legend: ✅ done · 🔜 next · ⬜ later. Package rename = "H" (done early, blocked on §1).

### A. Profile + follow backend — ✅ done (§2c)

### B. Social UI — ✅ done, analyze-clean (not runtime-tested)
- `RideShareModel`/`SharedRideEntity` caught up to the rules shape from Phase
  A: `isPrivate` bool replaced with `audience` (`public`/`followers`/`mutual`,
  clean cutover — no prod data on this collection yet), plus `photoUrl`,
  `upvotes`, `downvotes`, and an entity-only `myVote` (hydrated from
  `votes/{uid}`, never persisted — mirrors `isLikedByCurrentUser`).
- `RideShareRepository`: `shareRide` now takes `audience` + optional
  `photoUrl` and materializes `allowedUserIds` internally via
  `FollowRepository.getFollowers`/`getMutuals`. Added `uploadRidePhoto`
  (`rideShares/{uid}/{rideId}.jpg`), `getPublicRides`/`getSharedToMe`/
  `getMyRides` (each lines up with one `rideVisibleTo()` clause, replacing
  the old single `isPrivate`-filtered query + dead `getFriendsFeed`), and
  `vote`/`getMyVote` (bounded ±1-per-field transaction matching the rules'
  vote clause exactly).
- New `ride_share_screen.dart` (route `/ride/share/:rideId`): optional photo
  picker (gallery, mirrors `add_edit_bike_screen.dart`'s pattern) + audience
  pill picker, reached from `ride_summary_screen.dart`'s Share button (its
  old inline `_shareRide`/sharing state is gone — the button just navigates).
- `ride_feed_provider.dart`: `rideFeedProvider` unions the three queries
  above, dedupes by id, sorts by `netScore` desc then `createdAt` desc.
  `RideFeedNotifier` (renamed from `RideLikeNotifier`) adds an optimistic
  `vote()` alongside the existing `toggleLike()`.
- `social_screen.dart`: feed card's single heart replaced with an
  upvote/downvote arrow pair + net score, shows `photoUrl` when present via
  `cached_network_image`. Added a "Find riders" entry above the feed opening
  a search sheet (`ProfileRepository.searchByUsername`/`searchByEmail`,
  merged on one field) with a follow/unfollow toggle per result
  (`FollowRepository`/`follow_providers.dart` — no new profile-view screen,
  out of scope here).
- `storage.rules` **created** (didn't exist before — avatar upload was
  running unbacked by any rule) and registered in `firebase.json`: owner-write
  / any-authed-read for `avatars/{uid}.jpg` and `rideShares/{uid}/{rideId}.jpg`.
- `firestore.indexes.json`: dropped the stale `isPrivate+createdAt` index,
  added `userId+createdAt` (for `getMyRides`).
- Not yet deployed: `firebase deploy --only firestore:rules,firestore:indexes,storage`
  needs to run before any of this is live (same deploy step §7 already calls
  out, storage rules are new to that list).

### C. Forums — ⬜
- Normalize slugs so `mt-15` / `MT 15` / `MT-15` collapse to one forum: fix
  `lib/core/utils/slugify.dart` `_slugifyPart` to treat `-`, `_`, whitespace as
  one separator.
- Add **general (non-bike) forums**: `f/maintenance`, `f/skills`,
  `f/two-strokes`, `f/dirt-bikes`, `f/spark-plug`… (needs a `general` ForumType
  or single-segment slug alongside brand/model).
- Forums home: **list, not buttons/chips** (`forums_home_screen.dart`).
- **Upvote/downvote on posts** (posts already carry an unused `likes` int; add
  vote fields + rules mirroring rides).
- **Avatars**: show `userPhotoUrl` on posts/replies with a **GitHub-style default
  avatar** (initials) when absent. Use `UserProfileEntity.initials`. Replies
  currently store no photo — add it.

### D. Garage / Service — ⬜
- **Odometer** optional field on add-bike: new `odometerKm` on `BikeEntity` +
  `bike_model.dart` + `bikes` table column → **DB migration v4→v5** in
  `database_helper.dart` `_onUpgrade`; add form field + `addBike` param.
- **Move "add bike"** below the bike list (currently top round `_InkAddButton`).
- **Top round "+" → user menu** (avatar/menu opening the profile edit + "my
  places"). Repurpose `garage_screen.dart` header.
- **Service moves INTO garage**: a button per bike card; parameterize
  `MaintenanceScreen` by `bikeId` (currently hard-wired to `activeBikeProvider`)
  or `setActiveBike` before navigating. Service page to match the design HTML's
  service page. This frees the bottom-nav "Service" slot for Places (Epic E).

### E. Nav + Places — ⬜
- **Bottom nav**: drop **Service** tab, add **Places** tab; rename **Insights →
  "Rides"** (`app_shell.dart` `_tabs`/items — current order: Social, Insights,
  Record, Service, Garage). Remove Places from the Social hub tabs.
- **Map-pin add**: a `flutter_map` location-picker widget (none exists today;
  `add_place_screen.dart` only captures current GPS). Let user drop/drag a pin.
- **POI auto-import** (BOTH, per decision): pull nearby fuel/parts/garage POIs
  from **OSM Overpass API** (net-new data source; OSM is display-tiles only
  today) and surface/auto-add to `places`.
- **Owned places**: derive via `places where createdBy == uid` (add an
  `ownerId`/use `createdBy`); link from the user menu/profile. Don't trust a
  spoofable array on the profile.

### F. Rides tab (formerly Insights) — ⬜
- **Graphs**: `fl_chart` is in `pubspec.yaml` but **never imported** — add real
  charts (distance/speed over time, etc.) to the renamed Rides tab.
- **More badges** + a discount-hook foundation (badges → future partner
  discounts on parts/service). Dead `ChallengeRepository` already models
  `earnedBadges` — reuse rather than rebuild.

### G. Safety — ⬜
- Make crash detection trigger **only in extreme cases**. Root cause of
  over-triggering: `event_detector.dart` `_crashAccelThreshold = 8.0` is
  commented "g (>80 m/s²)" but compared directly against `accel.abs()` in **m/s²**
  — so it trips at ~8 m/s² instead of ~80. Raise it to a true high-g value
  (primary sensitivity knob); user will fine-tune with real rides. Trigger also
  requires jerk spike + speed-drop in a 2s window.

### H. Package rename — ✅ code done (§2b), ⛔ blocked on §1 to build/ship.

---

## 6. Known code facts / gotchas (verified during audit)

- `firebase_options.currentPlatform` hard-returns `ios` — fix when reconfiguring
  (§1). 
- `fl_chart` dependency present but unused anywhere.
- Slug helper `bikeForumSlug` does **not** unify `-` vs `_` (Epic C).
- Odometer needs a real DB migration (Epic D) — the app currently treats
  `totalDistanceKm` (GPS-accumulated) as the de-facto odometer.
- **Dead code** (never wired to UI): `RouteRepository`, `ChallengeRepository`
  (has `earnedBadges` — reuse for Epic F), `GroupRideRepository`. Their
  Firestore rules for `groupRides`/`challenges` don't exist, so they'd be denied.
- Placeholder in AndroidManifest: `com.bft.throttleiq.LocationForegroundService`
  is declared but there is **no matching `.kt` source** — pre-existing; harmless
  unless started.

---

## 7. How to resume / verify

1. Complete §1 (Firebase). Then from the coder side: regenerate
   `firebase_options`, make `currentPlatform` platform-aware, update iOS URL
   scheme.
2. `cd app && flutter pub get && flutter analyze` (should stay clean).
3. Deploy backend when convenient: `firebase deploy --only firestore:rules,firestore:indexes,storage`
   (rules + indexes updated through Epic B; `storage.rules` is new — first deploy).
4. Build to verify: `flutter run` (sim) or the signed release APK flow (JAVA_HOME
   = Android Studio JBR, key.properties present).
5. Continue at **Epic C** (§5). Commit per epic on `feat/v2-social`; do not push
   until asked; keep `main` releasable.
