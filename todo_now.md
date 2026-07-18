# ThrottleIQ — remaining build plan (Phases 2-4)

This file is the handoff spec for the coder agent. It assumes no prior context
from the planning conversation — everything needed to implement is below.
After this is implemented, a separate review pass will validate it against
this checklist, so keep the file paths/behavior here accurate as you build
(update this file if you deviate, so the review pass isn't checking stale
intent).

## Already done — do not redo

- **Bug fix** (branch `fix/onboarding-infinite-loop`, uncommitted): the
  "add bike → infinite loop" bug. Root cause: `authStateProvider`
  (`lib/features/auth/presentation/providers/auth_provider.dart`) used
  Firebase's `authStateChanges()`, which never re-emits after
  `updateDisplayName()`/`reload()` — so once onboarding's name step ran, the
  router's redirect logic kept a stale "still onboarding" read forever and
  bounced every later navigation back to `/auth/onboarding`, resetting the
  screen (including right after the bike step was submitted). Fixed by
  switching to `userChanges()` + restructuring `lib/core/router/app_router.dart`
  so `redirect` reads auth fresh via `ref.read` on every call instead of a
  closure captured at provider-build time, and a `refreshListenable`
  (`_AuthRefreshNotifier`) re-runs `redirect` without recreating the whole
  `GoRouter` (recreating it would reset the Navigator to `/splash` mid-onboarding
  and skip the bike step entirely — a real regression risk that was caught and
  avoided). The redirect logic itself is now the pure, unit-tested
  `computeAuthRedirect()` function in `app_router.dart`
  (test: `test/core/router/app_router_test.dart`).
- **Phase 1 — Rider Stats Hub**: the old placeholder "AI" chat tab
  (`lib/features/chatbot/`, canned replies only, no real functionality) is
  **deleted**. It's replaced by `lib/features/stats/` — a real all-time stats
  screen (avg speed, top speed, avg riding score, most-used bike, total
  distance/rides, recent ride history), computed from existing local ride/bike
  data via `lib/core/utils/rider_stats.dart` (`computeRiderStats`) and
  `lib/core/utils/riding_score.dart` (`computeRidingScore`, also now used by
  `ride_summary_screen.dart` — single source of truth for the score formula).
  Route is `/home/stats`; bottom-nav tab relabeled "Insights"
  (`lib/shared/widgets/app_shell.dart`). Tests:
  `test/core/utils/riding_score_test.dart`, `rider_stats_test.dart`.
- `future2.md` (repo root) — the follow-request + "share ride publicly to
  followers" idea is written up there as a **deferred** idea. Don't build it as
  part of Phases 2-4; Phase 2's feed intentionally uses the *public* feed only
  because no follow-graph exists yet (see Phase 2 below).

**Environment note:** `flutter test` cannot run in this dev environment — the
Windows profile path (`Abraar at Inovace`, contains a space) breaks the
native-asset build hook for the `objective_c` transitive dependency, for every
test file (confirmed against an untouched pre-existing test, not caused by any
change in this repo). `flutter analyze` works fine. Write tests as usual
(matching `test/features/social/*_test.dart`'s pattern for entities, and the
new `test/core/utils/*_test.dart` files for pure logic) — they just can't be
executed here; run them on a machine/CI without that path issue.

---

## ⚠ Firestore rules gap — required for Phases 2 AND 4, not just 3

The deployed rules file (`firestore.rules`, repo root) ends with a catch-all
deny:

```
match /{document=**} {
  allow read, write: if false;
}
```

Only `users/{uid}/...`, `liveSessions/{token}`, and `crashNotifications/{id}`
are currently allowed. This means:

- **Phase 2 breaks silently in production without new rules**: `RideShareRepository`
  (`lib/features/social/data/repositories/ride_share_repository.dart`) reads/writes
  a **top-level** `rides` collection (`_firestore.collection('rides')`) — NOT the
  same as the existing `users/{uid}/rides` subcollection (that one is the private
  ride-sync collection from `cloud_repository.dart`, unrelated). There is currently
  no rule allowing this top-level `rides` collection at all.
- **Phase 4 breaks silently too**: a rules draft already exists at
  `app/firestore_rules_poi_directory.txt` for `places` (+ nested `reviews`) and a
  standalone `reviews` collection, but **it was never merged into the real
  `firestore.rules`** — confirmed by reading both files. The actual
  `ReviewRepository` (`lib/features/poi_directory/data/repositories/review_repository.dart`)
  uses the **standalone top-level `reviews`** collection (queries by a `placeId`
  field), not a subcollection — so only that standalone-`reviews` block from the
  draft is actually load-bearing; the nested `places/{placeId}/reviews` block in
  the draft is dead weight (harmless to include, but not what the code uses).
- Phase 3 (forums) is new, so it needs new rules from scratch — there's no draft.

**Action:** before/alongside Phases 2-4, add these to `firestore.rules` (inside
the existing `match /databases/{database}/documents {` block, before the
catch-all deny):

```
// Shared/public ride posts (Phase 2 — social feed)
match /rides/{rideId} {
  allow read: if request.auth != null &&
    (resource.data.isPrivate == false || request.auth.uid == resource.data.userId);
  allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
  allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;

  match /likes/{userId} {
    allow read: if request.auth != null;
    allow write: if request.auth != null && request.auth.uid == userId;
  }
  match /comments/{commentId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
  }
}

// Places + reviews (Phase 4 — copy the standalone blocks from
// app/firestore_rules_poi_directory.txt: the top-level `places` match and the
// top-level `reviews` match. Skip the nested places/{id}/reviews block — the
// actual ReviewRepository never writes there.)

// Forums (Phase 3 — new)
match /forums/{forumId} {
  allow read: if request.auth != null;
  allow create, update: if request.auth != null; // getOrCreateForum merges; no fixed owner
  match /posts/{postId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    allow update: if request.auth != null && resource.data.userId == request.auth.uid;
    match /replies/{replyId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
  }
}
match /forum_follows/{followId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && followId == (request.auth.uid + '_' + request.resource.data.forumId);
}
```

Adjust exact field/collection names to match whatever you actually implement
below — the point is: **don't ship Phase 2 or 4 assuming the existing rules
file covers them; it doesn't, verify by reading `firestore.rules` yourself
before calling either phase done.**

---

## Phase 2 — Real social feed + "share this ride"

**STATUS: DONE** (branch `feature/social-forums-places-phase2-4`, uncommitted).
Built per the plan below, then a code-review + security-review pass (great_cto
plugin wasn't installable in this environment — no `marketplace.json` in that
repo — so `/code-review` and `/security-review` were used instead) found and
fixed 9 real bugs before this was called done:

- Firestore rules originally let non-owners' like/comment counter `update()`
  calls get rejected outright (broke likes/comments for everyone but the ride
  owner) — fixed, then a security pass found the fix was itself too loose (no
  value-delta/privacy check, allowing arbitrary counter tampering) and an
  unrelated `userId`-reassignment spoofing hole in the owner-update rule. The
  **actual deployed `firestore.rules` `/rides/{rideId}` block is now more
  complex than the draft originally sketched in this doc** — read the real
  file, it now constrains counter updates to a ±1 delta gated on read access,
  and pins `userId` immutable on update. Treat the live file as ground truth,
  not the snippet below (kept for historical context only).
- `RideShareRepository`/`RideShareModel` (`data/repositories/ride_share_repository.dart`,
  `data/models/ride_share_model.dart`) — spec said reuse as-is, but 3 real bugs
  required touching them anyway: `toggleLike` is now a transaction (was
  double-incrementing), `getPublicRides` now resolves `isLikedByCurrentUser`
  per-ride against the `likes` subcollection (was always `false`), `shareRide`
  now merges instead of overwriting on re-share (was zeroing existing
  likes/comments).
- `social_screen.dart`: fixed a `setState`-after-dispose crash in
  `_loadComments`, and a stale comment-count-in-header bug (added
  `RideLikeNotifier.incrementCommentCount`).
- `ride_summary_screen.dart`: share button was tappable before the polyline
  finished loading (spurious "Polyline too short" error on valid rides) —
  now also gated on `_polylineLoaded`.

Original plan (as built, no other deviations):

**Reuse `RideShareRepository` as-is** (`lib/features/social/data/repositories/ride_share_repository.dart`)
— it's fully built: `shareRide`, `getPublicRides`, `getFriendsFeed` (don't use
this one — no follow graph exists, see Already Done above), `toggleLike`,
`addComment`, `getComments`, `updateRideVisibility`.

1. `lib/features/social/presentation/providers/ride_feed_provider.dart`:
   - `publicRideFeedProvider` — `FutureProvider<List<SharedRideEntity>>` calling
     `RideShareRepository().getPublicRides()`.
   - A small like-toggle notifier: optimistic UI update +
     `RideShareRepository().toggleLike(rideId, userId, like)`, using
     `ref.read(currentUserProvider)` for the uid (see
     `lib/features/auth/presentation/providers/auth_provider.dart`).
2. Rewrite `lib/features/social/presentation/screens/social_screen.dart`: replace
   the placeholder body with a real list. Card per `SharedRideEntity`: bike
   name/type, distance (`distanceKm`), duration (`durationMinutes`), max speed
   (`maxSpeedKmh`), like count + like button, comment count. Tapping a card
   expands/opens comments (`RideShareRepository().getComments(rideId)` +
   `addComment(...)`). Style consistent with `shared/widgets/app_card.dart` /
   `stat_card.dart` and the card patterns already used in `garage_screen.dart`'s
   `_BikeCard` and `stats_screen.dart`'s `_RecentRideRow` (both in this repo,
   read them for the established visual style before inventing a new one).
3. **"Share this ride" action** in
   `lib/features/ride/presentation/screens/ride_summary_screen.dart`: add a
   share toggle/button (near the existing Export JSON/GPX buttons) that calls
   `RideShareRepository().shareRide(...)` with `isPrivate: false`. Needs:
   `rideId` (`widget.rideId`), the current user's uid/name/photo
   (`currentUserProvider` / Firebase `User`), the ride's `bikeId`/`bikeName`/
   `bikeType` (join against `garageProvider`'s bikes by `ride.bikeId`),
   `rideDate` (`ride.startTime`), `distanceKm`, `durationSeconds`,
   `maxSpeedKmh`, and the **polyline** — this screen already loads it via
   `RidePointDao().getForRide(widget.rideId)` into `_polyline` (see the
   existing `_loadPolyline()` method) — reuse that, don't refetch. Show a
   success/error snackbar; this is a fire-and-forget action off the ride
   summary, not a blocking flow.
4. Delete these confirmed-orphaned files (not reachable from
   `lib/core/router/app_router.dart` — verified by reading the router; grep
   `feed_screen\|route_list_screen\|group_ride_map_screen\|ride_detail_screen`
   across `lib/` to double check before deleting, in case something changed):
   - `lib/features/social/presentation/screens/feed_screen.dart`
   - `lib/features/social/presentation/screens/route_list_screen.dart`
   - `lib/features/social/presentation/screens/group_ride_map_screen.dart`
   - `lib/features/social/presentation/screens/ride_detail_screen.dart`
5. Turn `SocialScreen` into a 3-tab host using a `TabBar`/`TabBarView`:
   **Feed** (this phase's real feed) / **Forums** (Phase 3) / **Places**
   (Phase 4). Build the Feed tab now; the other two tabs can show a lightweight
   loading/placeholder until Phases 3-4 land, but wire the `TabBar` itself now
   so the shape doesn't change again per phase.
6. Add Firestore rules for the top-level `rides` collection — see the rules
   section above. Verify by actually reading `firestore.rules` after editing it.

**Tests:** none of this is pure logic (it's Firestore + widgets), so no new
`*_test.dart` is required for Phase 2 itself beyond what the repo already has
for `SharedRideEntity` (`test/features/social/shared_ride_entity_test.dart`,
already exists and passes today — don't break it).

---

## Phase 3 — Bike/brand forums (follow + ask/help)

**STATUS: DONE** (same branch, uncommitted). Built per the plan below, then
review found and fixed 6 real bugs — see `update.md` at repo root for the
full run summary and all assumptions made (this phase ran unattended, no user
available to confirm judgment calls):

- **Slug collision (critical)**: `bikeForumSlug` originally let different
  (brand, model) pairs produce the identical slug (e.g. brand='Royal
  Enfield'/model='Classic 350' collided with brand='Royal'/model='Enfield
  Classic 350'), silently merging distinct bike forums. Fixed by using a `__`
  separator between brand/model that can't appear within a single segment.
  **This changes the slug format from the original spec's example** —
  `bikeForumSlug('Yamaha', model: 'MT-15')` is now `'yamaha__mt-15'`, not
  `'yamaha_mt-15'` as originally sketched above.
- `getOrCreateForum` had a race condition on first-ever creation of a forum
  (two concurrent creators → the second got `PERMISSION_DENIED` even though
  the forum now legitimately existed) — fixed via a Firestore transaction.
- `postCount`/`replyCount`/`followerCount` went stale in the UI after
  mutations (same bug class as Phase 2's comment-count issue) — fixed with
  additional cache invalidation at each mutation call site.
- A `TextEditingController` leak in the new-post bottom sheet, and a
  `ref.invalidate`-after-dispose crash in two follow-toggle handlers — both
  fixed.
- Security review found `forum_follows`'s read rule exposed any user's
  full list of followed forums to any other authenticated user (no ownership
  check) — fixed to scope reads to the owning user, matching the `rides`
  collection's `likes` subcollection pattern.

Goal: a forum per bike brand (e.g. "Yamaha") and per specific bike model (e.g.
"Yamaha MT-15"), so riders can post issues/questions and others can reply and
follow forums for bikes they own.

New feature folder `lib/features/forums/`, mirroring the shape already used by
`lib/features/poi_directory/` and `lib/features/social/`
(`data/models`, `data/repositories`, `domain/entities`,
`presentation/{screens,providers}`).

1. **Pure util** `lib/core/utils/slugify.dart`:
   `String bikeForumSlug(String brand, {String? model})` — lowercase, spaces
   → `-` or `_` (pick one, be consistent), e.g. `bikeForumSlug('Yamaha')` →
   `'yamaha'`, `bikeForumSlug('Yamaha', model: 'MT-15')` → `'yamaha_mt-15'`.
   This is the Firestore doc id for a forum, so **it must be deterministic** —
   same brand/model always produces the same slug, so every rider with the
   same bike lands on the same forum doc (no duplicate forums). Unit test:
   `test/core/utils/slugify_test.dart`.
2. **Entities** (`domain/entities/`):
   - `ForumEntity`: `id` (the slug), `type` (`brand` | `bikeModel`), `brand`,
     `model` (nullable), `displayName` (e.g. `"Yamaha"` or `"Yamaha MT-15"`),
     `followerCount`, `postCount`, `createdAt`.
   - `ForumPostEntity`: `id`, `forumId`, `userId`, `userName`, `userPhotoUrl`,
     `title`, `body`, `createdAt`, `replyCount`, `likes`.
   - `ForumReplyEntity`: `id`, `postId`, `forumId`, `userId`, `userName`,
     `body`, `createdAt`.
   Follow the existing `Equatable`-based entity style (see
   `lib/features/poi_directory/domain/entities/place_entity.dart` for the
   pattern: plain immutable class, `props` getter, no Firestore imports in
   `domain/`).
3. **Models** (`data/models/`) — `fromFirestore`/`toFirestore` mappers per
   entity, mirroring `lib/features/poi_directory/data/models/place_model.dart`.
4. **Repository** (`data/repositories/forum_repository.dart`), Firestore layout:
   `forums/{slug}`, `forums/{slug}/posts/{postId}`, `posts/{postId}/replies/{replyId}`,
   `forum_follows/{uid}_{slug}` (idempotent membership doc, same pattern as
   `ride_share_repository.dart`'s `likes` subcollection keyed by `doc(userId)`):
   - `getOrCreateForum({required String brand, String? model})` — resolve slug
     via `bikeForumSlug`, then `.doc(slug).set({...}, SetOptions(merge: true))`
     so repeated calls never duplicate.
   - `followForum(forumId, userId)` / `unfollowForum(forumId, userId)` /
     `isFollowing(forumId, userId)` / `getFollowedForums(userId)`.
   - `createPost(...)`, `getPosts(forumId)`, `addReply(...)`, `getReplies(postId)`.
   - Keep `postCount`/`followerCount` updated via `FieldValue.increment(...)`
     on create/follow, same pattern `ride_share_repository.dart` uses for
     `likes`/`comments` counts.
5. **Providers** (`presentation/providers/`): `forumsForGarageProvider`
   (derives brand/model list from `ref.watch(garageProvider)`'s bikes, calls
   `getOrCreateForum` per unique bike, so "Your bikes" forums always exist),
   `forumPostsProvider` (family by forumId), `forumFollowingProvider`.
6. **Screens** (`presentation/screens/`):
   - `ForumsHomeScreen` — the "Forums" tab inside `SocialScreen` (see Phase 2
     step 5). Shows "Your bikes" forums first (from `forumsForGarageProvider`),
     then a simple brand search/discover list to find and follow other forums.
   - `ForumThreadScreen(forumId)` — post list + "New post" FAB → a simple
     title+body form.
   - `ForumPostDetailScreen(postId)` — post body + replies list + reply
     composer.
   - Entry point from `lib/features/garage/presentation/screens/bike_detail_screen.dart`:
     add a "Discuss this bike" button/action that resolves
     `getOrCreateForum(brand: bike.brand, model: bike.model)` and navigates
     straight to `ForumThreadScreen` for that forum.
7. Add router entries in `lib/core/router/app_router.dart` for the forum
   screens (nested under wherever `SocialScreen`'s tabs live, or as top-level
   routes like `/forums/:forumId` and `/forums/:forumId/post/:postId` if
   simpler — match whatever pattern you use for the `TabBar` in Phase 2).
8. Add Firestore rules — see the rules section above.

**Tests:** `test/features/forums/forum_entity_test.dart` (and similar for
`ForumPostEntity`/`ForumReplyEntity`) following
`test/features/social/shared_ride_entity_test.dart`'s pattern; plus
`test/core/utils/slugify_test.dart` for the pure slug function (exact-value
assertions, including a case-sensitivity/whitespace case).

---

## Phase 4 — Garages & fuel pumps directory ("Places")

**STATUS: DONE** (same branch, uncommitted). Full run summary and all
assumptions are in `update.md` at repo root. Note: **"backend already exists
and needs no changes" (below) turned out to be not quite true** — the
existing `PlaceRepository`/`ReviewRepository` write pattern (a plain
`WriteBatch` with client-computed absolute rating totals) had a real race
condition that review found and required changing:

- Two concurrent reviewers both read the same cached place rating, computed
  their own "new total," and the second one's entire submission (review +
  rating update) got rejected by Firestore rules — fixed by rewriting the
  rating update as a transaction that reads the current server value fresh.
- No check against submitting a second review for the same place — fixed
  client-side, then a security pass found the client-side check alone wasn't
  enough (bypassable via direct Firestore calls) — fixed by making review
  document ids deterministic (`{uid}_{placeId}`), same pattern as Phase 3's
  `forum_follows`.
- Security review also found the place-rating-update rule let any
  authenticated user fabricate a rating with zero real reviews backing it —
  fixed by tying the rule to require a real review document via `exists()`/
  `get()`. **This fix has one genuinely untested piece** — see update.md's
  "needs human verification" section — worth confirming against a live
  Firestore project before shipping.
- The place detail screen's rating header was a one-shot fetch that never
  updated for other viewers even as the review list below it updated live —
  fixed by converting it to a Firestore stream.

Goal: nearby garages/fuel pumps/parts shops, add-new, star ratings + reviews,
average rating shown. **Backend already exists and needs no changes** —
`PlaceEntity`, `ReviewEntity`, `PlaceRepository`, `ReviewRepository`, and
`geohash_utils.dart` are all complete under `lib/features/poi_directory/`
(read them before starting — `domain/entities/place_entity.dart`,
`domain/entities/review_entity.dart`,
`data/repositories/place_repository.dart`,
`data/repositories/review_repository.dart`,
`data/utils/geohash_utils.dart`). Only the presentation layer is missing (no
`presentation/` folder exists yet under `poi_directory` at all).

1. New `lib/features/poi_directory/presentation/providers/places_provider.dart`:
   `nearbyPlacesProvider` — `FutureProvider.family` keyed by an optional
   category filter, using `geolocator` (already a dependency, used elsewhere
   e.g. `ride_recording_provider.dart`) for current position →
   `PlaceRepository().getNearbyPlaces(latitude: ..., longitude: ..., radiusKm: ..., category: ...)`.
2. `lib/features/poi_directory/presentation/screens/places_list_screen.dart` —
   the "Places" tab inside `SocialScreen` (Phase 2 step 5). Category filter
   chips using `PlaceCategory.icon`/`displayName` (Fuel/Garage/Parts, already
   defined on the enum in `place_entity.dart`). Each row: name, category icon,
   distance from current position, star rating (`PlaceEntity.averageRating`)
   + `ratingCount`.
3. `lib/features/poi_directory/presentation/screens/add_place_screen.dart` —
   form: name, category picker, address, optional phone/hours. Captures
   current lat/lng via `geolocator`, computes `geohash` via the existing
   `geohash_utils.dart`, calls `PlaceRepository().addPlace(...)`.
4. `lib/features/poi_directory/presentation/screens/place_detail_screen.dart` —
   place info header + `ReviewRepository().getReviewsForPlace(placeId)` (or
   `streamReviewsForPlace` for live updates) rendered as a list + "Add your
   review" (star picker 1-5 + text) → on submit:
   - `ReviewRepository().addReview(...)`
   - **then, in the same transaction/batch** (not two separate awaited calls —
     the two repos currently aren't atomic together, this is a real gap to
     close, not an existing pattern to copy): recompute
     `ratingSum`/`ratingCount` and call
     `PlaceRepository().updatePlaceRating(placeId, ratingSum: ..., ratingCount: ...)`.
     Use a Firestore `WriteBatch` or `runTransaction` wrapping both writes so a
     review can never be added without the place's aggregate updating to
     match (currently possible to get these out of sync if the second call
     fails after the first succeeds).
5. Router entries for these 3 screens in `lib/core/router/app_router.dart`
   (e.g. `/places`, `/places/add`, `/places/:placeId`).
6. Add Firestore rules — see the rules section above (copy the standalone
   `places` + standalone `reviews` blocks from
   `app/firestore_rules_poi_directory.txt`, skip the unused nested-reviews
   block as noted there).

**Tests:** this repo already has
`test/features/poi_directory/data/repositories/place_repository_test.dart`
and `review_repository_test.dart` and `data/utils/geohash_utils_test.dart` —
don't break them. No new pure logic here beyond what's already tested, unless
you add a distance-formatting helper, in which case test it the same way.

---

## Verification checklist (for whoever validates after the coder agent)

For each phase, before considering it done:

1. `flutter analyze` from `app/` — must show **0 errors** (the current
   pre-existing baseline is ~106 `info`/`warning`-level lints across the repo;
   don't add new errors, and don't feel obligated to fix the pre-existing
   lints either — just don't add to the error count).
2. Read `firestore.rules` and confirm the collections that phase's repository
   code actually touches are covered — don't trust that "a rules draft exists
   somewhere" means it's deployed; check the real file.
3. Confirm no dead/orphaned screens were left un-deleted after being replaced
   (grep the router for the old file names).
4. Pure-logic additions (`slugify.dart`, any new formatter) have a
   `*_test.dart` with exact-value assertions, following this repo's existing
   pattern in `test/features/social/*_test.dart` and
   `test/core/utils/riding_score_test.dart` / `rider_stats_test.dart`.
5. Manual on-device/emulator check of the actual tap-path per phase (feed
   scroll + like + share-a-ride; forum follow + post + reply; places nearby +
   add + review) — this can't be done from this chat session, note in the
   handoff what was and wasn't manually verified.
