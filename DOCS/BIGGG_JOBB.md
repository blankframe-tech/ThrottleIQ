# BIGGG JOBB — handoff for the next agent

_Written 2026-09-21 by Claude Opus 5, at the founder's request, for whoever
picks this up next. Baseline: `main` @ `4b4e0da`, version
`1.0.0-beta.3.0.2+19`._

> **Path note.** The founder asked for `docs/BIGGG_JOBB.md`. This disk is
> case-insensitive and `core.ignorecase=true`, and `DOCS/` already exists — so
> `docs/` and `DOCS/` are the *same directory*, and creating one under the
> lower-case name is exactly how issues §69.O16 happened (330 files silently
> staged under the wrong case). It is therefore written as `DOCS/BIGGG_JOBB.md`.
> Do not "fix" this by adding a lower-case `docs/`.

---

## 0. How to use this document

Read §1 (state), §2 (gates) and **§3 (traps) before touching anything**. §3 is
the highest-value section here — most of it is failures I actually hit, not
hypotheticals. Then work §5 in order.

The founder's decisions in §4 are **settled**. Do not re-litigate them; if you
think one is wrong, say so once, in a sentence, and then do it.

---

## 1. Where the project is right now

| | |
|---|---|
| Branch | `main` @ `4b4e0da`, clean, in sync with origin |
| Version | `1.0.0-beta.3.0.2+19` (GitHub release `beta-v3.0.2`) |
| Tests | **1195** passing |
| Analyzer | clean (zero issues) |
| Rules suite | **113** passing |
| Functions | build clean, **NOT deployed** (Spark plan) |
| Firestore rules + indexes | **deployed and verified** 2026-09-21 |

Recent history worth knowing: a full critique pass ran 2026-09-20/21 and is
recorded as **§83** (fixed parts in `issues_fixed.md`, remainder in
`issues_open.md`). The original writeup is
`ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`. Roughly 20 sub-items were fixed,
including every false crash-detection claim, the crash Cloud Function's
`'contacted'` lie, account-deletion gaps, the privacy-zone seed, feed
pagination, and 15 screens that dumped raw exceptions at users.

### What is live vs. what is merely written

This distinction matters more than usual here:

- **Deployed:** Firestore rules, Firestore indexes, hosting.
- **Written, merged, NOT running:** every Cloud Function. The
  account-deletion trigger **has never been deployed in the project's
  history**. So today, deleting an account leaves Cloudinary media and all
  authored content in place. The code to fix that is merged and tested; it
  simply isn't live.
- **Built, deliberately switched off:** crash detection
  (`SensorConstants.impactDetectorLiveEnabled = false`).

---

## 2. The four verification gates

Run **all four** before declaring anything done. CI runs the first three.

```bash
cd app       && flutter analyze          # must be ZERO issues
cd app       && flutter test             # 1195 passing
cd functions && npm run build            # tsc, must be silent
cd scripts   && npm run test:rules       # 113 passing (needs JDK 21+)
```

**`flutter analyze` must be literally zero**, not "no errors". CI is
configured so that info-level lints fail the job. A `curly_braces_in_flow_
control_structures` info will break the build.

---

## 3. TRAPS — read this before touching anything

These are ordered by how much time they will cost you.

### 3.1 NEVER run `dart format` across `lib/`

**This repo is not dart-format-clean.** Running `dart format lib/` reformats
**178 files**, burying your actual changes in thousands of lines of whitespace
churn and making the diff unreviewable.

I did this. Recovering it took: computing a whitespace-insensitive hash per
file to separate "formatting only" from "real change", reverting 98 files
wholesale, then reverting and re-applying the edits on 46 more. Do not repeat
it. Format individual files you have already edited, or nothing at all.

### 3.2 Section numbering is a minefield — check BOTH files

- Next free number is **§85**. It is stated in `issues_open.md`'s header.
- **§79 and §81 are each used twice.** §82 was taken before §83.
- A number can live in `issues_open.md`, `issues_fixed.md`, or **both**
  (open parts vs fixed parts of the same section). The header's "next free
  number" pointer historically tracked only one file, which is how the §81
  collision happened. **Grep both files** before claiming a number.

### 3.3 Renumbering a section? The regex will miss things

When §81 was renumbered to §83, a regex over `§81\.(\d+)` moved every
reference — and silently missed **16** of them, because:

- Sub-headings are written `### 83.9 — …` with **no `§` sigil**.
- Some references are bare in prose: `"same root cause as 81.28"`, `"81.13."`.

If you renumber, grep for the bare number too, and verify with
`grep -c "8N\." issues_open.md` afterwards.

### 3.4 Ticket references in code: `issues §N`, never a file path

Three earlier conventions rotted and were swept in §83.29: `docs/Issues.md §N`
(renamed), `claude_sol.md §N` (deleted in `fc11e99`), and a 78-character
`DOCS/Handoff for agents and Todos/issues_open.md or issues_fixed.md §N` that
appeared in 28 files and could not decide which file it meant.

The convention is defined once in `DOCS/README.md`:

- `issues §N` — section N of `issues_fixed.md` if resolved, else `issues_open.md`
- `grill §N` — the 2026-09-20 external-critique pass (`claude_sol.md`, deleted;
  recover with `git show fc11e99^:"ANTIGRAVRITY_GRILL/claude_sol.md"`)

**Never write a file path into a new code comment.**

### 3.5 Never `firebase deploy --force`

It would delete the 4 indexes tracked in **§84** that exist in the project but
not in `firestore.indexes.json`. Dropping a live index breaks its query
**immediately, in production**. See §84 for the evidence each is orphaned —
evidence, not proof.

### 3.6 Comparing Firestore indexes? Strip `__name__` first

Firestore appends an implicit `__name__` field to every composite index. A
naive diff of `firebase firestore:indexes` output against
`firestore.indexes.json` reports false mismatches — it told me a
just-deployed index was missing and inflated the drift count from 4 to 16.

### 3.7 Ship the app BEFORE the rules (§78.27)

Already bit us. The chat-create rule requiring deterministic DM ids sat
undeployed on `main`; deploying rules on 2026-09-21 made it live. Builds
`beta_v3.0.1`+ contain the matching client fix, **but the Play Console
internal track still holds `1.0.0-beta.1+3`**, which predates it — anyone on
that build can no longer *start* new chats (existing chats still work).

Any future rule that tightens a write contract needs the client shipped first.

### 3.8 Bash: a heredoc failure does not stop the next line

```bash
python3 - <<'PY'
... assert fails here ...
PY
git commit -m "claims the script worked"     # ← THIS STILL RUNS
```

I shipped a commit whose message overstated its contents this way. Chain with
`&&`, or verify the file actually changed before committing.

### 3.9 Tests must never touch the network

`flutter test` used to emit a wall of
`ClientException … tile.openstreetmap.org`. `AppTileLayer` now swaps in a
`_BlankTileProvider` (1×1 transparent PNG, zero requests) under `FLUTTER_TEST`.
Keep it that way — OSM's usage policy asks apps not to bulk-fetch, and it made
the suite flaky.

### 3.10 Test seams that already exist — use them

- `RideFeedNotifier.seeded(ref, rides)` — a feed that never reaches Firestore.
  Needed because the provider auto-refreshes on construction.
- `AppearanceNotifier` registers a `WidgetsBindingObserver`, so its unit tests
  need `TestWidgetsFlutterBinding.ensureInitialized()`.
- DAOs run against real in-memory SQLite (`sqflite_common_ffi`), not mocks —
  a deadlock bug once shipped because map-based fakes couldn't see real
  transaction semantics (issues §7). Keep it that way.

### 3.11 Spark plan: functions cannot deploy at all

Not "should not" — **cannot**. `artifactregistry.googleapis.com` requires
Blaze. Writing Cloud Function code that can't be deployed "fixes" nothing
while looking fixed (this is exactly what §33.5 warns about). Check the plan
before promising anything server-side.

---

## 4. Founder decisions — settled 2026-09-21

| Area | Decision |
|---|---|
| **Blaze plan** | **Not upgrading.** Stay on Spark. |
| **Crash detection** | **Leave as-is.** Flag stays off. No further work. Stop raising it. |
| **Map tiles** | Founder signing up for a free provider. Recommendation: **Thunderforest** (raster-native, drops into `TILE_URL_TEMPLATE`/`{apiKey}` with no code change; free key, no card; Atlas style is built for navigation legibility). Verify the quota on their live pricing page — the 150k/month figure traces to 2019 docs. |
| **Live `throttleiqfb` data** | **Direct execution authorized** for cleanup/migration scripts. |
| **`AppColors` migration** | **Do it, all at once**, on a branch named **`appcolors`**. |
| **Localization** | **Everything** — all 260 files. |
| **Bangla review** | Reviewer available. Keep translating; hand off each batch marked pending. |
| **Keystore (§78.18)** | ✅ Backed up. That half closed. |
| **CI/branch protection, Play Console, device checks** | Founder, next week. Keep tracked, stop surfacing. |
| **§32 UI/UX** | **Concrete defects only.** Taste calls explicitly NOT being done. |
| **Design calls** | **All four approved** (§78.21, §74, §78.30, §78.24). |
| **App Check** | **Enable** (§83.19). |
| **Analytics** | **Add**, privacy-respecting (§83.27). |
| **Work order** | `appcolors` → full i18n → §32 + design calls → small items. |

### The one dated consequence

Staying on Spark is fine for cost, but **§69.O6 is a deadline**: Cloud
Functions **Node 20 is decommissioned late October 2026**. After that,
`firebase deploy --only functions` fails *regardless of plan*. The Node 22
bump is already written and sitting undeployed. If the Blaze decision is ever
revisited, it should be before then.

---

## 5. The work queue

### JOB 1 — `appcolors`: kill the static token facades

**Branch name: `appcolors`** (founder specified).

#### Scope is bigger than "AppColors" — verify this first

There are **three** mutable static token facades, not one, and
`AppearanceNotifier._applyTokens()` applies all three together:

| Facade | Reads | Mechanism |
|---|---|---|
| `AppColors` | **1,579** | `static void apply(AppColorPalette)` |
| `AppDimensions` | **346** | `static void apply(AppShapeProfile)` |
| `AppTypography` | **17** | `static void applyStyle(AppColorMode)` |
| `Theme.of(context)` | 10 | (the correct pattern, barely used) |

**≈1,942 call sites total.** Migrating only `AppColors` will *not* let you
delete the remount — shape radii and typography would still be stale after a
theme change. Do all three or the job isn't done.

#### The acceptance test

Delete this, from `app/lib/app.dart`:

```dart
return MaterialApp.router(
  key: ValueKey(appearance),   // ← this line is the whole point
```

That key forces the **entire app to unmount and remount** on every theme
change, destroying every `State`: scroll offsets, map camera, half-typed
forms, open sheets, `AnimationController`s. It exists only because static
reads sit outside Flutter's element dependency graph and nothing else can
propagate the change. **If you can delete that line and theme switching still
works everywhere, you're done.** If you can't, you aren't.

#### What it also buys

- `const` becomes usable again at ~1,942 sites (they were all de-`const`ed
  when the fields became getters).
- Static palette state stops leaking between widget tests.
- Golden tests become possible (there are **0** today, across 28 appearance
  combinations: 7 colours × 2 brightnesses × 2 shapes).

#### Suggested approach

1. Define `ThemeExtension`s: `AppPalette` (from `AppColorPalette`),
   `AppShape` (from `AppShapeProfile`), and fold typography into
   `ThemeData.textTheme` where it fits.
2. Register them in `AppTheme.build(appearance)` — that function already
   receives the resolved appearance, so it is the natural seam.
3. Add terse accessors so call sites stay readable, e.g.
   `context.palette.primary` / `context.shape.radiusMd` via a `BuildContext`
   extension. A 1,942-site migration wants the shortest possible replacement.
4. Migrate feature directory by feature directory, running `flutter analyze`
   after each. Expect to thread `BuildContext` into helper methods that
   currently take none — that is the genuinely manual part.
5. Delete the `ValueKey`, delete the `apply()` methods, run all four gates.
6. **Then** fix §74 (Retro/Light near-black cards) — it is a palette-token
   bug and this pass touches every token anyway. Doing it first means doing
   it twice.

#### Watch out for

- Places that read tokens with no `BuildContext` in scope (`initState`,
  static helpers, `Paint` builders in `CustomPainter`). These need the context
  passed in or the value resolved at build time.
- Tests that assert on `AppColors.x` directly — `test/core/theme/` has several.
- `AppColors.hasHardShadow` (Retro's offset-shadow flag) is read by `AppCard`
  and `StatCard` and is easy to miss.

---

### JOB 2 — localize everything

**21 of 260 files** use `AppLocalizations` today. The founder chose *all* of
them.

#### Workflow

```
app/lib/l10n/app_en.arb   ← template (edit this, plus @description metadata)
app/lib/l10n/app_bn.arb   ← Bangla
flutter gen-l10n          ← regenerates; output IS checked in, so commit it
```

`l10n.yaml` sets `nullable-getter: false` and English as fallback, so a
missing Bangla key degrades to English rather than crashing. There is an **ARB
parity test in `test/core/i18n/`** that stops a missing translation shipping —
it will fail you if the two files drift.

#### Priority within the job

Do onboarding first even though the founder said "everything": it is 7 slides
and 21 callouts and it is where a Bangla-first rider decides whether this app
is for them. Then the ride flow, then the rest.

#### Bangla quality

A reviewer is available. Mark each batch as pending review in the docs so
there is a clear list — §78.28 and the §83 cockpit alerts are both already
waiting. **Do not let unreviewed machine Bangla ship silently to Bangla-first
riders**; that is a real quality risk in the app's primary market.

---

### JOB 3 — §32 defects and the four approved design calls

#### §32 — fix these five, and only these five

1. **Paused-ride scrim dims the stat card**, not just the map — the one screen
   meant to be glanced at mid-ride fades its own numbers. Dim the map only.
2. **Places FAB overlaps the last list row** — no reserved bottom padding.
3. **`★ —` on zero-review places** → "No ratings yet".
4. **Ride summary shows the riding score twice** in adjacent cards.
5. **Maintenance pill never escalates** — 13% remaining shows the same green
   "OK" as 99%, which defeats an early-warning indicator.

**Explicitly NOT doing** (founder decision — do not re-raise as bugs):
slide-to-start friction, the "In jam" label, chart axis styling, theme-picker
live previews, the low-contrast secondary-text pass.

#### The four approved design calls

- **§78.21 — route navigation should record the ride.** Today nav and
  recording are separate flows that don't compose: follow a saved route and
  you end up with no ride logged. Merge nav into the active-ride cockpit.
- **§74 — Retro/Light near-black cards.** Forum cards, Places rows and My
  Places rows render as near-black blocks on Retro's cream background with
  low-contrast text; no other Light mode does this. It's one palette token
  used as a card fill. **Do this inside JOB 1.**
- **§78.30 — crash badge in ride history.** A suspected-crash ride looks
  identical to a commute. It is the only surface where crash data is visible
  at all, given the detector stays off.
- **§78.24 — SafeQR "Print sticker."** Needs the `printing` package; new
  dependency approved.

---

### JOB 4 — infrastructure, instrumentation, data

#### App Check (§83.19)

Enable it. Free, works on Spark. It is the actual control for request-volume
abuse — Firestore rules **cannot** bound volume, which is why the
crash-notification "fix" is idempotency only and says so.

#### Analytics (§83.27) — NOT a code-only change

Screen views and funnel events only. No ad SDK, no behavioural profiling.

**Three documents currently state the app has no behavioural analytics and
must move in the same pass:**

- `public/privacy.html` (deployed at `throttleiqfb.web.app/privacy.html`)
- `DOCS/General/store_listing/data_safety_and_permissions.md`
- the Play Console Data Safety form (Console UI — founder action)

§69.O1 is the last time exactly this mismatch bit (the privacy policy claimed
no microphone while push-to-talk recorded audio). Do not repeat it.

#### Live data cleanup — execution authorized

- **§79** — 14 likes and 3 comments were hand-seeded onto a real rider's
  public post from `qaSeed` accounts. `cleanup_qa_test_riders.js` does **not**
  remove likes/comments left on someone else's post, so they survive cleanup
  and their counter bumps stay on a real post. Extend the script with a
  `collectionGroup` sweep for `qaSeed == true`, decrementing each parent tally.
- **§80** — 97 `qashare_*` rides still carry a dead `likes` integer. Nothing
  reads it. Clear with `FieldValue.delete()`, and drop the now-dead `likes`
  clauses from `firestore.rules` on the next rules pass.
- **§84** — the 4 undeclared indexes. Confirm nothing uses them (check
  `scripts/`, hand-run console queries, and the undeployed `functions/` — the
  code grep already came back clean), then **either** delete them **or** add
  them to `firestore.indexes.json` with a note. Do not use `--force`.

#### Small §78 items

- **§78.26** `HoldToStartButton` completes a hold if press and release land in
  the same frame. `HoldToEndButton` already guards against this — copy it.
- **§78.29** the "Sync issues" screen isn't localized (folds into JOB 2), and
  the immediate outbox attempt `_attemptOne` isn't scoped to the signed-in
  rider.
- **§78.16** wire the tile provider once the founder supplies a key: three
  `--dart-define`s (`TILE_URL_TEMPLATE`, `TILE_API_KEY`, `TILE_ATTRIBUTION`)
  into the release build scripts. `AppTileLayer` already reads them.

---

## 6. Known debt NOT in the queue

Recorded so you don't rediscover it and think it's new. All are in
`issues_open.md` §83.

- **§83.12** — the 877-line active-ride screen rebuilds **in full, once per
  second**, plus every GPS fix. Only **4** `.select(` uses exist app-wide
  against a 21-field state object. Battery/thermal cost in exactly the state
  where battery matters most.
- **§83.13** — DI: DAOs, calculators and coordinators are constructed inline;
  `FirebaseFirestore.instance` appears directly in 20 places. **This is the
  same root cause as §83.28** — nothing touching I/O is injectable, so nothing
  touching I/O is tested.
- **§83.28** — **43 screens, 1 screen test, 0 goldens.** 1,195 tests cover the
  pure calculators exhaustively and the presentation layer essentially not at
  all, which is where every UX defect in §83 lived.
- **§83.14** — **55** bare `catch (_)` blocks, 11 with empty bodies: 55 failure
  modes that will never reach Crashlytics.
- **§83.16** — the Cloudinary *upload* preset is still an open endpoint (cloud
  name + unsigned preset are in the APK). Needs a signed-upload proxy → needs
  Blaze. Group-ride voice notes therefore live at permanent public URLs.
- **§83.18** — blocking is a client-side `.where()`; blocked users' content is
  still downloaded, and blocking doesn't stop them reading the blocker's
  public content.
- **§83.22** — accessibility is a stopgap: 27 tooltips and a 1.0–1.3× text
  clamp. The clamp exists *because* layouts overflow above ~1.3× rather than
  reflowing. Making them scale-tolerant is the real work.
- **§83.26** — `onboarding_ui_mockups.dart` is a 1,162-line hand-drawn copy of
  real screens, shipping in the binary, with nothing to catch drift. It
  already fabricated a lean-angle gauge, a "SHIELD: ARMED" badge and "10Hz
  GPS" — all removed. `integration_test/ui_tour_test.dart` could supply real
  screenshots instead.

---

## 7. Founder-owned — do not attempt, do not keep surfacing

Scheduled by the founder for the week of 2026-09-22:

- **CI + branch protection (§78.18).** `.github/workflows/ci.yml` exists but
  has **never run on GitHub**, and `main` has no required checks — so the
  gates in §2 are enforced on one laptop and nowhere else.
- **Play Console (§69.O1, §69.O8).** Data Safety needs "Audio → Voice or sound
  recordings: collected, shared" (push-to-talk records and uploads audio).
  Android 14 restricts full-screen intents, which the crash alert uses.
- **Device verification (§78.12, §78.26).** Gyro heading sign/axis needs a
  phone mounted on a bike.
- **Keystore — ✅ DONE**, backed up 2026-09-21.

One thing still outstanding and **off-limits to agents unless the founder asks
directly**: the pitch deck (`iDEA_PITCH_SUBMISSION.md`, §78.25) still claims
working crash detection and a team the repo history doesn't show. Every
in-app and in-repo claim has been corrected; that file has not.

---

## 8. Where everything is documented

| File | What |
|---|---|
| `DOCS/Handoff for agents and Todos/HANDOFF_Document.md` | Status, decisions table, deploy state, Known Limitations |
| `DOCS/Handoff for agents and Todos/issues_open.md` | Every unresolved issue. **Next free number: §85** |
| `DOCS/Handoff for agents and Todos/issues_fixed.md` | Resolved, same numbers |
| `DOCS/Handoff for agents and Todos/features.md` | What a user can actually do, by tab |
| `DOCS/README.md` | Doc map + the `issues §N` / `grill §N` legend |
| `ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md` | The full 2026-09-20 critique |
| `arch.md` | Architecture (carries the crash-detection warning) |

**Update the handoff docs as you go.** A stop hook enforces it, and this
session found repeated cases where the docs described an app nobody had
looked at: `features.md` had the bottom-nav order wrong, a test count stale
since 363, and the single most consequential fact about the app (crash
detection doesn't run) was missing from "Known Limitations" entirely.

---

## 9. The meta-point, which is the actual lesson

From §83.31, and worth repeating because it is the reason this document
exists:

> §32's safety finding was written 2026-08-17 and sat open for a month while
> smaller items shipped. `issues_open.md` is append-only and unprioritised, so
> "the FAB overlaps a list row" and "the crash detector is off while
> onboarding promises it works" sit at equal weight — and the one that gets
> fixed is the one that takes twenty minutes.

This repository is far better at *producing* critique than at *ordering* it.
There are 9,000+ lines of handoff docs and a 5,600-line resolved-issues log.
**It does not need another review pass.** Work the queue in §5, and when
something new turns up, file it by *what happens to a rider if it's wrong* —
not by how quickly it could be closed.
