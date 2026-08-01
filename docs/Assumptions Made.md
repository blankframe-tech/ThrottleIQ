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

_Per-work-package assumptions are appended below as each landed._
