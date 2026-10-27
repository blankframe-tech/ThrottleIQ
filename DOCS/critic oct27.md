# ThrottleIQ critique, 2026-10-27

Read-only audit of `main` at `5bbb53f1`. No code was changed. Every finding below was read in the code, and the top ones were checked a second time against the source. Nothing was run: no tests, no emulator, no device.

**What this repo does:** ThrottleIQ is an offline-first Flutter app for motorcycle riders in Bangladesh. It records rides (GPS plus motion sensors), tracks bikes and their maintenance, and adds a social layer: a ride feed, forums, chat, group rides and a places directory. Data lives in a local SQLite database and syncs to Firebase (Firestore with security rules; Cloud Functions are written but have never been deployed, because the project is on the free Spark plan).

**Load assumed:** a pre-launch beta with tens to low hundreds of riders, often on bad mobile data and on phones (Xiaomi, realme) that kill background apps. The real limit is Spark's free quota of 50,000 Firestore reads a day, so "one read per item" matters more than CPU.

Known issues already listed in `DOCS/Handoff for agents and Todos/issues_open.md` are left out unless this audit found something new about them.

---

## Must fix

1. **Anyone can push any like, comment, reply or follower count as high as they want** (`firestore.rules:1083-1087`, plus the delete rules at `:1100`, `:1309`, `:1340`, `:1361`)
   - **What this is:** Each counter (ride upvotes, post upvotes, `replyCount`, ride `comments`, forum `followerCount`/`postCount`) sits next to the docs it counts. The rules (§24.7, §90.D11) say the counter can only move by 1, and only when its child doc (a vote, comment, reply or follow) is written in the same commit.
   - **Problem:** That check only works one way. Deleting the child doc is allowed on its own, without lowering the counter. So a rider can repeat "create vote and add 1" then "delete vote alone" in a loop, and add 1 each time. No rules test checks a delete on its own.
   - **Fix:** Make the child's delete need the matching counter drop in the same commit: `getAfter(parent).data.X == get(parent).data.X - 1`. For votes, call the existing `voteBumpValid(...)` from the vote rule too. Add one rules test per counter that does a bare delete and expects a deny.
   - **If we skip it:** One script can put any post or ride at the top of the feed and of Pulse. Every ranking and badge built on these counters stops meaning anything.

2. **A rider can claim moderator rights over any bike forum nobody has opened yet** (`firestore.rules:1174-1178`)
   - **What this is:** Bike and topic forums have fixed ids such as `yamaha_r15_v4`. The app creates one the first time someone opens it. `canModerateForum` (`:468`) gives delete rights to whoever is in `createdBy` / `maintainerIds`.
   - **Problem:** The comment above the rule says pre-creating a forum to take it over is closed. It isn't: the rule still accepts `createdBy == me` and `maintainerIds == [me]` on any forum id, not only on rider-made `c-` forums. There is no `keys().hasOnly(...)` either, so the attacker also picks `displayName` and `type`.
   - **Fix:** Allow `createdBy` and `maintainerIds` only when `forumId.matches('c-.+') && request.resource.data.type == 'custom'`, and add a `hasOnly` list of keys. Add a rules test that creates `forums/<bike slug>` with `createdBy` and expects a deny.
   - **If we skip it:** A troll creates the forums for popular bikes before launch, then deletes every post in them, and nobody can remove them as moderator.

3. **A blocked rider can still comment on and vote on the blocker's public rides** (`firestore.rules:1083` vote create, `:1102` comment create; client: `shared_ride_detail_screen.dart:126`, `shared_ride_feed_card.dart:71`, `forum_post_detail_screen.dart:69`)
   - **What this is:** Blocking is meant to stop someone from reaching you. §83.18 covers *reading* public content. This finding is about *writing* to it.
   - **Problem:** Both create rules only check `rideVisibleTo()`, and its public branch never looks at `users/{owner}/blocks/`. The app shows comments and forum replies without filtering blocked users either.
   - **Fix:** Add `!exists(/databases/$(database)/documents/users/$(<ride owner>)/blocks/$(request.auth.uid))` to both creates. In the app, filter the comment and reply lists with `blockedUsersProvider`: `.where((c) => !blocked.contains(c.userId))`.
   - **If we skip it:** A rider who blocked a harasser still gets a comment from them under every ride they share.

4. **One unfinished ride stops every later auto-detected trip from counting** (`app/lib/core/database/daos/ride_dao.dart:372-388`, used by `auto_detection_policy.dart:78`)
   - **What this is:** Auto-tracking (trips the app detects without a manual Start) adds its km to the bike's odometer, unless the trip overlaps a recorded ride. `rideWindows` gives the list of recorded rides to check against.
   - **Problem:** It returns every ride, whatever its status. A ride with no end time counts as "still going, forever". The comment at `sync_manager.dart:467` says six empty `active` rides already sit in Firestore, and `downloadRides` (`cloud_repository.dart:780-800`) pulls them back without checking status. After that, every detected trip counts as "inside a ride": it adds 0 km, is still marked done, and is left out of the daily summary. A test (`ride_integrity_migration_v19_test.dart:154`) currently locks this behaviour in.
   - **Fix:** In `rideWindows`, add `AND (end_time IS NOT NULL OR id = ?)`, passing the saved active ride id (`RidePrefsKeys.activeRideId`). In `downloadRides`, skip docs whose `status` is not `completed` or `crash`. Change the v19 test to match.
   - **If we skip it:** For affected riders, auto-tracked km are lost for good, so service reminders come late and the daily digest stays empty.

5. **Deleting a ride or bike can leave the GPS trail in the cloud** (`app/lib/core/cloud/cloud_repository.dart:845`, `:66`, `:75`)
   - **What this is:** When a rider deletes a ride, the app first lists the ride's track chunks (its GPS trail) in Firestore, then deletes them in a batch.
   - **Problem:** The list uses a plain `.get()`. On a phone that shows a connection but has no real internet (an expired data pack, captive Wi-Fi), Firestore quietly answers from its offline cache, which may hold none or only part of the chunks. The batch then deletes only what it saw, and the delete is marked done. For a bike, the uncached rides survive and come back on a new phone as rides of a bike that no longer exists.
   - **Fix:** Use `.get(const GetOptions(source: Source.server))` in those three places. Offline it then throws, and the existing retry handles it.
   - **If we skip it:** A rider deletes a ride for privacy, and the location trail of that ride stays on our server.

6. **Ending a ride doesn't start a sync, and neither does reopening the app** (`app/lib/features/ride/presentation/providers/ride_recording_provider.dart:1294-1390`, `app/lib/app.dart:142`)
   - **What this is:** The README says rides sync "on resume and every 5 min". Only the crash path calls `sync()` (`:1572`).
   - **Problem:** `stopRide` never calls `sync()`, and the resume handler only reconciles detected trips. If MIUI freezes the app before the 5-minute timer fires, the ride exists only on the phone until the next time the app is opened, which can be days.
   - **Fix:** Add `unawaited(_ref.read(syncManagerProvider).sync());` after the stop sequence, and the same line in `didChangeAppLifecycleState` on `resumed`. The existing 30 s throttle and `_isSyncing` guard stop pile-ups.
   - **If we skip it:** A lost phone, a reinstall or "clear data" loses rides the rider thinks are backed up.

7. **Saving the Edit Bike screen undoes km added while it was open** (`app/lib/features/garage/presentation/providers/garage_provider.dart:89-92`, `add_edit_bike_screen.dart:67`, `:236`)
   - **What this is:** Edit Bike loads the bike once when it opens. On Save, `BikeDao.update(BikeModel.toMap(bike))` writes every column back.
   - **Problem:** If auto-tracking credits km in the meantime (the rider leaves the screen open and switches apps), Save writes back the old `odometer_km`, `total_distance_m`, `ride_count`, `is_active` and `last_ride_at`.
   - **Fix:** `updateBike` writes only the columns the screen edits (brand, model, year, cc, image_path, color_value, is_ebike, odometer_km, synced), with the odometer baseline taken from a fresh `getById`.
   - **If we skip it:** Odometer and ride totals silently go backwards, and maintenance due dates go with them.

8. **Shared rides, places and reviews accept any image URL and unlimited text** (`firestore.rules:971-998` rides, `:1407` places, `:1489` reviews)
   - **What this is:** §90.D10 added an allow-list of image hosts for profiles, comments and forums, so a rider can't make other phones load an image from their own server.
   - **Problem:** Shared rides (`photoUrls`, `userPhotoUrl`, `mapSnapshotUrl`), places (`photoUrl`) and reviews (`imageUrls`) never got it. A share with `https://evil.example/x.png` makes every feed viewer's phone fetch it, which gives the attacker their IP addresses (`shared_ride_feed_card.dart:369`). `caption`, `polyline` and review `text` have no size cap. A new place can also carry a fake `googleRating: 5, googleRatingCount: 9999`, which the app shows (`place_rating_badges.dart:71`).
   - **Fix:** Reuse `photoUrlAllowed` on the single URL fields and the `forumImagesValid` check on the lists. Add `hasOnly` key lists and size caps, and require `googleRating == 0 && googleRatingCount == 0` on client creates.
   - **If we skip it:** Anyone can track who views the feed, fill docs up to 1 MB, and fake Google ratings on places.

9. **A rider can show someone else's @handle** (`firestore.rules:450-461`, `:528-536`)
   - **What this is:** Handles are unique: `usernames/{handle}` reserves one per rider, tied to the `usernameLower` field.
   - **Problem:** The app shows the `username` field (profile, chat list, People tab, QR, `bestName` in `rider-name.ts`), and that field is free text. A rider keeps their own `usernameLower` and sets `username: 'the_abraar'`.
   - **Fix:** In `profileFieldsValid` add `keeps(before, after, 'username') || after.username.lower() == after.get('usernameLower', '')`. Cap `bio` in the same place; it has no limit today and shows up in 20-doc list reads.
   - **If we skip it:** Easy impersonation of the founder or any known rider.

## Should fix

10. **The release signing key and a Google Cloud service-account key are synced to Google Drive** (`throttleiq-release.keystore`, `secret/throttle-iq-gcc1-b9771877b5d4.json`, `secret/creds.txt`, `secret/tiles.env`)
    - **What this is:** These files are correctly kept out of git (`.gitignore:96`, `:102`). But the whole `~/Everything/dev` tree syncs to Google Drive.
    - **Problem:** So the Android signing key and a key with admin access to the Firebase project sit in Drive. Anyone who gets into that Google account, or any device it syncs to, has both.
    - **Fix:** Move them to a folder Drive doesn't sync (for example `~/.config/throttleiq/`) and point the build and scripts at it. Rotate the service-account key after the move, since the old one has already been uploaded.
    - **If we skip it:** One stolen Google login lets someone sign fake app updates and read or wipe production data.

11. **`deploy.sh` can tag the wrong commit and commit half-done work** (`scripts/deploy.sh:111`, `:202`)
    - **What this is:** The script bumps the version, runs the quality gate, pushes and creates the GitHub release.
    - **Problem:** `gh release create` has no `--target`. When the tag doesn't exist yet, gh creates it on the default branch's head, not on the commit just pushed. That breaks releases from any other branch, such as `mayabi`. Also, `git add -u` commits every changed tracked file under "chore(release)", including unfinished edits.
    - **Fix:** Add `--target "$(git rev-parse HEAD)"`. Stage only `app/pubspec.yaml`, and stop if any other tracked file is dirty.
    - **If we skip it:** A branch release points at main's code, and stray edits get shipped and pushed under a version-bump commit.

12. **A ride restored after the app was killed loses its earlier safety counts** (`app/lib/features/ride/presentation/providers/ride_recording_provider.dart:1493`)
    - **What this is:** If the OS kills the app mid-ride, `restoreInterruptedRide` rebuilds distance, speed and moving time from the saved points.
    - **Problem:** It calls `_detector.reset()`. The hard-brake, rapid-acceleration, jerk and overspeed counts were never saved, so they restart at zero. A ride killed at minute 40 of 60 scores only the last 20 minutes.
    - **Fix:** Save the four counters next to `elapsedSeconds` in `persistElapsed`, and seed the detector with them on restore.
    - **If we skip it:** Ride scores and badges are wrong on exactly the phones that kill apps most, which is most phones in the target market.

13. **Forum vote lookups cost one read per post on every page** (`app/lib/features/forums/data/forum_repository.dart:735`)
    - **What this is:** To show whether you voted, the app reads your vote doc for each post.
    - **Problem:** It does this even when the post has 0 upvotes and 0 downvotes, which is most beta posts. That's 25 reads per thread page, plus Pulse. The ride feed already skips them (§104.3, `ride_share_repository.dart:367`); forums never got that fix.
    - **Fix:** Return `null` without reading when `upvotes == 0 && downvotes == 0`. The counter rules (once finding 1 is fixed) keep this safe.
    - **If we skip it:** Forum browsing eats the free quota much faster than it needs to.

14. **The People tab re-reads every followed rider's profile on each visit** (`app/lib/features/social/presentation/screens/social_screen.dart:85`)
    - **What this is:** `_followingProfilesProvider` loads one profile per followed rider.
    - **Problem:** It is `autoDispose` inside a tab view, so it runs again on every tab switch, and again for everyone after any follow or unfollow. A rider who follows 60 people spends 60 reads per switch.
    - **Fix:** `ref.keepAlive()` plus a timer, the same three lines as `suggestedProfilesProvider` (`follow_providers.dart:87-89`).
    - **If we skip it:** Active social users burn through the daily quota.

15. **A bike whose photo file is missing is uploaded again every 5 minutes, forever** (`app/lib/core/database/daos/bike_dao.dart:345`, `app/lib/core/cloud/sync_manager.dart:494`, `cloud_repository.dart:374-378`)
    - **What this is:** Sync uploads bikes that have a local photo path.
    - **Problem:** `getBikesWithLocalImages` ignores `synced`. When the file is gone, the upload sends `image_path: null` but leaves the local row as it was, so the next cycle does it again: one read and one write per cycle, and a new `syncedAt` that makes the rider's other phones read the doc too.
    - **Fix:** When the file can't be found, clear the local path with the existing `updateImagePath(id, null)`.
    - **If we skip it:** A steady quota drain that grows with the number of riders, and nobody can see it.

16. **Account erasure leaves the rider's name and photo in other riders' data** (`functions/src/account-erasure.ts:206-219`, `:281-358`)
    - **What this is:** The Cloud Function that runs when an account is deleted. It is not deployed yet (Spark), so this applies once you move to Blaze.
    - **Problem:** It misses: follow notifications in other riders' inboxes (`fromName`, `fromPhotoUrl`), `senderName`/`senderPhotoUrl` on group-ride voice notes, vote docs keyed by uid, the uid inside review doc ids (`{uid}_{placeId}`), and `members/{uid}` plus `creatorName` on group rides the rider created. The test (`account-deletion.test.js`) covers only the rider's own notifications.
    - **Fix:** Delete notifications with a collection-group query on `fromUid` (this needs an index), blank the voice-note sender fields, delete the votes, and delete `members/{uid}` and clear `creatorName` in the creator branch. Add one test per item.
    - **If we skip it:** The privacy policy promises deletion that doesn't fully happen.

## Nice to have

17. **Discover shows 21 routes, not 20** (`app/lib/features/social/data/repositories/route_repository.dart:99`)
    - **What this is:** `getPublicRoutes` fetches public routes for discovery.
    - **Problem:** It asks for `limit + 1` docs (the usual "is there a next page?" trick) but returns all of them. The only caller (`route_providers.dart:18`) never pages, so `startAfter` is unused too.
    - **Fix:** `.limit(limit)` and remove the `startAfter` parameter.
    - **If we skip it:** One extra read and one extra card. Small, but it shows the paging was never finished.

18. **Crash alerts: only one per ride, ever** (`firestore.rules:904-921`, written from `crash_coordinator.dart:95`)
    - **What this is:** The crash alert doc uses the ride id as its own id, and the rules allow `create` only. This is dormant while crash alerts are off.
    - **Problem:** A second real crash in the same ride becomes an update, gets "permission denied", and `_bestEffortWrite` hides the error.
    - **Fix:** Use `{rideId}_{epochMs}` as the id, and match the rule's `rideId` check as a prefix.
    - **If we skip it:** Once crash alerts go live, a rider who falls twice on one ride gets no alert the second time.

19. **About 2,100 lines of code that run in no build** (`app/lib/core/realtime/` 829 lines, `chat_typing_channel.dart` 92, `peerTypingProvider` in `chat_providers.dart:22-60`, the relay in `live_session_coordinator.dart:471`, `public/live-viewer-core.js` 200 plus its 169-line test, `features/indriyo/` 753 plus `active_ride_screen.dart:587-622`)
    - **What this is:** The Realtime Database path (RTDB rules deny everything and no build sets `RTDB_URL`) and Indriyo (compiled out of every build, never run on a device).
    - **Problem:** Each one has to be read, tested and merged around on every change. The viewer page also loads `firebase-database-compat.js` for nothing on every visit (`live-viewer.html:12`).
    - **Fix:** Move both to a branch, the way `park/rtdb-group-ride` was done, and drop the `firebase_database` dependency.
    - **If we skip it:** Slower changes and bigger merge conflicts (the HANDOFF already lists `active_ride_screen.dart` as a conflict hot spot).

20. **Smaller dead code: unused methods, a test that tests nothing, a stale script, two unused packages**
    - **What this is:** `place_repository.dart:107-163` and `:310-332` (four lookup methods, two of them read whole collections), `route_repository.dart:113-132` (`shareRoute`, `makePublic`), all with zero callers. `test/features/poi_directory/data/repositories/place_repository_test.dart` (264 lines) never creates a `PlaceRepository`. `scripts/publish_release.sh` hardcodes `VERSION_CODE="4"` (pubspec is at `+32`), so every run uploads the AAB and then fails. `collection` and `cupertino_icons` in `app/pubspec.yaml` have no uses.
    - **Problem:** The test gives false confidence, and the unbounded place reads are a quota trap for whoever calls them next.
    - **Fix:** Delete all of it (about 440 lines), and remove the script's mentions from `scripts/README.md` and the HANDOFF.
    - **If we skip it:** Clutter, plus a test that passes whatever the code does.

---

**Verdict:** The code is careful and well documented, but the security rules have two real holes (1, 2) and the sync path can lose or misplace rider data (4-7). Fix 1, 2, 3 and 6 before the Play launch, because they are small and visible to riders. Then fix 4, 5 and 7.

**Lean:** -2,540 lines, -3 dependencies possible (`firebase_database`, `collection`, `cupertino_icons`).

**Not checked:** impact-event and crash-event upload, the crash, live-session and sensor coordinators, outbox share handlers, maintenance and fuel DAOs in detail, bike archive, elevation backfill, iOS-only paths, group-ride join/leave transactions, most auth and profile screens, the CI AI-summary workflow (`summary.yml`) for prompt injection, `privacy.html`, and the bodies of most test files. Nothing was run. About 6 smaller findings were left out, mostly items already listed in `issues_open.md` (§62, §83.18, §101.S3, §104, §109, §112).
