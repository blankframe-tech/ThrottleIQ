# Assumptions Made

_Created 2026-08-01 · during the "do everything in the handoff + TODO docs" pass_

Every judgement call made without asking, and why. Where a choice was
genuinely open, the **recommended / lowest-risk** option was taken and
recorded here rather than blocking on a question.

If you disagree with any of these, they're all cheap to reverse — each
entry names the file to change.

---

## Scope: what was built vs. what was left

The two source docs (`HANDOFF_Document.md`'s "To do" and `TODO next.md`)
together list roughly 30 items. They split cleanly into three groups:

| Group | Handling |
|---|---|
| **Codeable now** | Built. Everything in `TODO next.md` except the data wipe; the codeable half of the handoff to-do list. |
| **Needs credentials / a console / money** | Tooling + exact commands written, execution left to the owner. Cloud Functions deploy, Firestore TTL, the beta data wipe, the Play Console upload, the $25 developer account. |
| **Needs a human on a bike** | Left open, unchanged. On-device smoke tests, Google sign-in tap-through, real-ride sensor tuning. |

Nothing in group 2 or 3 was faked as done. `HANDOFF_Document.md` still
lists them, with the new tooling referenced.

---

## Assumption 1 — `pitch.md` was not touched

The project's own Stop hook says `docs/pitch.md` is off-limits unless
explicitly asked for. The instruction to "do everything in the handoff
doc" doesn't override a standing constraint about a *different* doc, so
it was left alone.

## Assumption 2 — the admin account is hardcoded for beta

`TODO next.md` item 7 says the admin is `the.abraar.rar@gmail.com` and
that the account will be created later. Firestore custom claims would be
the right long-term answer, but setting a claim needs the Admin SDK and a
service-account key that isn't available here.

**Taken:** a single `kAdminEmail` constant in
`app/lib/features/forums/domain/forum_permissions.dart`, compared
case-insensitively against the signed-in user's email.

**Consequence:** the client decides who's admin, so the *Firestore rules*
must independently enforce it too — a client-side check alone is
cosmetic. The rules were written to check
`request.auth.token.email == 'the.abraar.rar@gmail.com'` rather than
trusting the app. Move both to a custom claim before public launch.

## Assumption 3 — forum maintainers are managed by UID, not by search

Item 7 wants maintainers addable/removable. A rider-search-and-pick UI
means a user-directory query and a whole search surface. For a 12-dev
closed beta, the smaller thing is enough.

**Taken:** maintainers are added by pasting a UID. It's ugly and it's
labelled as a beta shortcut in the code.

**To upgrade later:** the rider-search sheet already exists in
`social_screen.dart` (`_RiderSearchSheet`) — reuse it.

## Assumption 4 — turn-by-turn navigation is derived geometrically, offline

Item 4 asks for turn-by-turn navigation on a saved route, "make the UI
yourself". A real routing engine (Valhalla, GraphHopper, Mapbox) means
either a server to run or an API key to pay for — neither exists, and the
handoff doc already flags routing as an XL/T3 item that shouldn't be
attempted before the tracker is solid.

**Taken:** turns are computed from the saved polyline's own geometry —
segment bearings, signed bearing deltas, classified into
slight/normal/sharp left/right and U-turn. Fully offline, no key, no
recurring cost, and it works on exactly the data the app already has.

**What this can't do:** it can't name streets ("turn right onto Mirpur
Road"), can't reroute when the rider goes off-route (it only *tells* them
they're off-route), and can't know about one-way streets or turn
restrictions. It's a breadcrumb follower for a route you already rode,
which is precisely the stated use case ("if I pick a route"). Street
names need map matching — already scoped as Phase 3 in the handoff doc.

## Assumption 5 — iOS widgets ship as sources + instructions, not a wired target

Item 9 asks for home-screen widgets on both platforms. Android App
Widgets are pure file additions (Kotlin + XML + a manifest receiver) and
were built and verified end to end.

iOS WidgetKit needs a second **Xcode target**, which means editing
`Runner.xcodeproj/project.pbxproj`. That file was deliberately not
touched: the iOS release build currently works and was run on a physical
iPhone for Beta v1, and a hand-edited pbxproj is the most likely way to
silently break it — with no way to verify the fix here beyond a full
rebuild.

**Taken:** the complete Swift/SwiftUI widget sources, the extension
`Info.plist`, and the App Group entitlement were written to
`app/ios/ThrottleIQWidget/`, with numbered Xcode steps in that folder's
`README.md`. Adding the target is a one-time ~5-minute GUI step.

**Android is fully done and needs no manual step.**

## Assumption 6 — the beta data wipe is scripted, not executed

Item 8 ("delete all past forum posting and all other user data") is
irreversible and requires Admin SDK credentials that aren't present.
Running it blind would also have destroyed the project owner's own test
data mid-session.

**Taken:** `scripts/reset_beta_data.js`, which **defaults to a dry run**,
refuses to run without both an explicit `--yes-i-really-mean-it` flag and
a `FIREBASE_PROJECT_ID` that matches, and prints per-collection counts
first. See `scripts/README.md`.

## Assumption 7 — schema and shared-file ownership were partitioned up front

Six work packages ran in parallel. To keep them from clobbering each
other, `app_router.dart` and `firestore.rules` were declared off-limits to
all of them; each reported the routes and rules it needed, and those were
merged centrally afterwards. Same for `pubspec.yaml`.

**Consequence worth knowing:** if a future session parallelises work
again, keep that partition — those three files are where concurrent edits
actually collide.

## Assumption 8 — `docs/TODO next.md` is now tracked in git

It was an untracked file in the working tree at the start of this
session. Since it's the source of half this work, it's now committed so
the next session can see what was asked for.

---

## Assumption 9 — parallel agents died mid-flight; the work was finished by hand

Six work packages were dispatched in parallel and **all six were killed by
a session rate limit partway through**. Roughly a third of the intended
work was already on disk, in a half-finished state.

**Taken:** rather than re-dispatching (and risking the same), the partial
state was audited (`flutter analyze` found exactly one broken file — a
misplaced `library;` directive), repaired, and the remainder was completed
sequentially, committing at every green checkpoint so no further
interruption could lose work. Two packages were re-dispatched once the
limit reset.

**Why it matters to you:** the commit history is deliberately
fine-grained for this reason. Each commit is independently green
(0 analyzer errors, full suite passing), so any one of them can be
reverted on its own.

## Assumption 10 — one corner should be one instruction

Writing the turn-by-turn tests surfaced a real defect: a single physical
corner, sampled across several GPS points, produced two instructions
("Turn right", then "Slight right" 50 m later). That both under-states the
first turn and is noisy to ride to.

**Taken:** consecutive same-direction bends are accumulated into one
manoeuvre; a direction reversal or a genuinely straight segment ends the
run, so an S-bend still reads as two turns. The grouping threshold
(8°/segment) is deliberately below the 20° floor at which something counts
as a turn at all, so a long sweeping bend groups rather than vanishing.

**Untested against reality:** these constants are guesses until someone
rides a route with the screen on. Same honest framing as the
crash-detection thresholds.

## Assumption 11 — moving time ignores long GPS gaps

Average speed is now distance ÷ moving time. If tracking is suspended
(tunnel, phone asleep, app killed) the next fix can arrive minutes later.

**Taken:** gaps longer than 60 s are not counted as moving time at all,
rather than being attributed to riding. Under-counting moving time
slightly inflates average speed; counting a 10-minute tunnel as "moving"
would deflate it enormously. The smaller, bounded error was chosen.

## Assumption 12 — GPS trails are chunked, not one doc per point

A ride holds thousands of points. One Firestore document per point would
be thousands of reads/writes per ride.

**Taken:** 500 points per `track` document, each point a fixed-order list
`[lat, lng, tsMillis, speed, accel]` rather than a map — Firestore stores
map keys verbatim in *every* element, so a map encoding repeats the field
names thousands of times against the 1 MiB document limit.

**The cost:** the encoding is positional, so the doc comment in
`ride_track_codec.dart` *is* the schema. New fields append to the end and
must read as nullable. Never reorder them.

## Assumption 13 — discovered routes are shown but not openable

Route documents live at `users/{uid}/routes/{id}`. Opening one needs the
*owner's* uid, and the Discover tab lists routes from every rider.

**Taken:** Discover cards are deliberately **non-tappable** rather than
tappable-and-broken. Threading the owner uid through the route params is a
small change, logged in the handoff doc's to-do list.

## Assumption 14 — Firestore rules were deployed, not just written

The new features are inert without matching rules, and the client-side
permission checks are cosmetic on their own.

**Taken:** rules were deployed to the live `throttleiqfb` project after
confirming they are **strictly more permissive** than what was there
before — new OR-branches and delete rules where deletes were previously
denied outright. Nothing that previously worked can start failing. Rolling
back is `git checkout <old> firestore.rules && firebase deploy`.

**Not verified:** no live account has exercised them. Confirming a
maintainer really can delete a post — and that a non-maintainer really
cannot — is on the handoff doc's device-test list.

## Assumption 15 — bike visibility defaults to `public`, which widens read access

⚠️ **The one decision in this pass with a real privacy consequence — read
this one properly.**

The ask was "option to show or hide my bikes from my followers or the
public or only me". Implementing it means the `users/{uid}/bikes` rule
changes from **owner-only** to "readable per the owner's tier". Existing
accounts have no `bikesVisibility` field, so a default had to be chosen:

- **`private` default** — nothing changes for anyone, but the feature is
  inert until every rider opts in, and other riders' profiles show no
  garage, which reads as broken.
- **`public` default (taken)** — matches the documented product intent
  (`Features.md` has always described `/profile/:uid` as "public profile
  view, **showing a rider's bikes**"), and matches the owner's own framing:
  asking for a way to *hide* implies visible is the baseline.

**Taken:** default `public`.

**Be clear-eyed about what that means:** before this change, no rider
could read another rider's bikes at all — the rule forbade it, so the
"show a rider's bikes" feature was aspirational and silently broken. After
it, every existing account's garage becomes readable by any signed-in
rider who can already see their profile. That is a widening, not a
no-op, and it happens without those riders opting in.

Mitigations actually in place: it's still gated behind
`profileVisibleTo`, so a private/mutual profile keeps its garage hidden;
writes stay strictly owner-only; and the tier is one tap to change in
Edit profile.

**To reverse:** change the `'public'` fallback to `'private'` in BOTH
`bikesVisibleTo()` in `firestore.rules` and `canSeeBikes()` in
`app/lib/features/profile/domain/bike_visibility.dart`, then redeploy.
They must always agree.

## Assumption 16 — DAOs are now tested against real SQLite

The bike-delete deadlock (`Issues.md` §7) shipped because the DAO "tests"
never opened a database — they asserted on plain maps, so a bug that only
exists in real transaction semantics was invisible to them.

**Taken:** added `sqflite_common_ffi` as a **dev** dependency (no effect
on the shipped app) and two `@visibleForTesting` hooks on
`DatabaseHelper`, so DAOs can run against a real in-memory SQLite.

**Worth knowing:** the regression test for that deadlock does not fail
cleanly if the bug returns — it *hangs*, because the deadlock sits below
the level Dart's `@Timeout` can interrupt. Verified by deliberately
reintroducing the old code. A stuck `test/database/` run is the signature.

## Assumption 17 — group-ride invites are in-app, not push

The ask says invitees "will be sent a notification". `firebase_messaging`
is wired, but the Cloud Function that would actually *send* a push is an
explicit stub (`functions/src/crash-notifications.ts` is mocked, and no
group-ride function exists).

**Taken:** write the in-app notification, which is what
`notifications_screen.dart` reads and which works today. A real push
needs the Cloud Function deployed — which needs the Blaze plan already
tracked in the handoff doc's "Soon" section.

**Consequence:** an invitee sees the invite when they next open the app,
not on their lock screen. Called out so nobody assumes push works.

---

_Per-work-package assumptions are appended below as each landed._
