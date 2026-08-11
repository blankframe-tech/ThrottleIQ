# What to do now

_Written 2026-08-11 · Branch: `main` · Snapshot, not a living doc_

This is a short-lived checklist for the state the project is in **right
now**, at the end of the 2026-08-11 session (ride survival + discard, Retro
as a terminal skin, the Record redesign, model-only bike forums, bike-photo
cropping). It is
deliberately *not* a second backlog — the durable to-do list, the
known-limitations list and the release checklist all stay in
`HANDOFF_Document.md`, and defects stay in `Issues.md`. When the boxes below
are ticked, this file has done its job and should be deleted rather than
maintained.

---

## Where things actually stand

| | |
|---|---|
| Tests | **717/717 green** |
| `flutter analyze` | clean — 0 errors, 0 new warnings |
| iOS build | simulator (debug) + **release, installed and running on Abraar's iPhone** |
| Committed | **nothing** — the entire session is uncommitted working tree |
| Seen rendered by a human | **nothing from this session** |

**The release build is already on your phone**, and it is the current one —
rebuilt and reinstalled after the cropper landed, confirmed running. The
device pass below needs no build step from you; just open the app.

(Two ThrottleIQ builds are installed on that phone now. Same bundle id, so
you get one icon and the newest wins — but if anything looks stale, delete
the app and reinstall.)

Note `flutter run --release` reported "Could not run … Try launching Xcode"
at the install step, and `xcrun devicectl device install app` then installed
the *same* bundle on the first try. The bundle was fine; `flutter run`'s
install was not. See the ⚠️ in `HANDOFF_Document.md`'s iOS-install section
— it is a second, distinct cause of that message.

The "seen rendered" row is the important one. Every change from this session is
verified by the type checker and the test suite and by nothing else. The
app boots clean, but it stops at sign-in, and no sign-in or tap automation
exists in the agent environment (`Issues.md` §15) — so the redesigned Record
screen, the Retro skin, the forums changes and the whole kill-and-resume
flow have never been looked at.

---

## 0. Commit first

Nothing from this session is committed, and it spans ~20 files including a
rewrite of the ride-recording provider. A stray `git checkout` loses all of
it.

```
git add -A && git commit
```

Worth splitting into at least: the ride-survival/discard work, the Retro
skin + typography, the Record redesign, and the forums scoping — they're
independent and each is separately revertable.

---

## 1. The device pass (~15 minutes, needs you signed in)

This is the only thing that can't be delegated back to the agent, and it's
the gate on everything else. Ordered by risk — highest first.

### 1a. Kill-and-resume — the headline change

The behaviour you asked for. Test it exactly like this:

1. Start a ride. Let it run **2–3 minutes and actually move** — the restore
   path needs at least 2 stored GPS fixes, and it deliberately discards
   anything shorter (a single fix has no derivable distance).
2. Note the distance and the elapsed clock.
3. **Swipe the app out of the recents switcher.** Not background — kill it.
4. Reopen.

Expected: you land on the paused ride screen with a **"Ride kept from last
time"** banner, and the distance/clock match step 2 (elapsed may be up to
**10 seconds short** — that's the snapshot throttle, and it is intentional).
Then check all three exits work: **Resume** carries on counting, **End
Ride** saves it to history, **Discard ride** deletes it.

**The one to watch:** after resuming, ride a bit further and confirm the
distance climbs *smoothly* rather than jumping. A jump means
`_skipNextDistanceDelta` didn't take, and the gap between the kill and the
resume got measured as riding.

### 1b. Record screen

Look for layout breakage, since nobody has seen this render:

- The bike-photo hero — greeting legible over **your actual photo** (the
  scrim is tuned blind; a bright photo is the risk case).
- Slide-to-start sits at the bottom and **doesn't move** when you switch
  between a bike with and without an error.
- The rides / km / **day streak** strip — sanity-check the streak against
  what you actually rode this week.
- Tap the hero: with 2+ bikes a picker sheet opens; with 1 bike **nothing
  should happen**.
- Then turn text size up in iOS accessibility settings and reload — the old
  layout was checked at `textScaler: 1.1176`; this one hasn't been.

### 1c. Retro skin

Settings → Appearance → **Retro**, then page through Record → Active ride →
Ride summary → Forums.

It is the first skin that changes shape and type, not just color, so it is
the most likely of the nine to look wrong applied app-wide. Specifically:
everything should be **square-cornered, black-on-paper, monospace**, with no
color anywhere. Any surviving accent colour is a token reading through a
hard-coded value rather than the palette.

Then switch to another skin and confirm the **monospace type goes away** —
if it sticks, `AppTypography` and `AppColors` have drifted out of sync.

### 1d. Forums

- "Your bikes" shows **only your exact models**, no bare brand rows.
- The first visit re-resolves from Firestore (the cache signature changed),
  so it may take a moment **once**; the second visit should be instant.
- **Topics** now lives under "Find a forum", below Brands.

### 1e. Bike photo cropping

Garage → Add/Edit a bike → add a photo. The cropper should open straight
after the picker. Check: dragging the **corners and edges** resizes, dragging
the **middle** moves, the frame can't escape the photo, **1:1** stays square
while you drag, and **Rotate** turns the photo without leaving the frame in a
silly place. Then Done, and confirm the saved bike shows the crop you chose —
in the garage list *and* in the new Record hero.

Also confirm **Cancel** in the cropper keeps the photo you picked rather than
throwing the selection away.

### 1f. Discard

Start a ride, discard it, and confirm it does **not** appear in Rides. Then
confirm it never reached Firestore either — that's the claim being made, and
the console is the only place to check it.

---

## 2. Once the device pass is clean

- **Cut beta-v3.** `beta-v2` is still the tagged release and it **crashes**
  (nested-array trail upload, fixed 2026-08-03) — nobody should be handed it.
  See the ⚠️ block at the top of `HANDOFF_Document.md`.
- **Back up the signing keystore.** Still open, still the one mistake with
  no recovery: `throttleiq-release.keystore` + `app/android/key.properties`
  exist only on this machine. Lose them and the app can never be updated
  under the same identity.
- Update `HANDOFF_Document.md`'s "Not verified on a device" paragraph to say
  what you actually saw, and delete this file.

---

## Not this project

The `life-manager-upload.jks` keystore instructions from earlier are for
`repos/life-manager`, which has its own Claude session. Nothing about them
applies here: ThrottleIQ already has a release keystore and a filled-in
`key.properties`, and its release SHA-1 is already registered with the
Android OAuth client (verified 2026-08-11 — see `HANDOFF_Document.md`).

If you do run it there, note `keytool` needs Android Studio's bundled JDK on
this Mac; `/usr/bin/keytool` is a stub that fails silently.
