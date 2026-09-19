# Needs Attention

_Added 2026-09-20. These items came out of the Antigravity grill verification (`Handoff for agents and Todos/ANTIGRAVRITY_GRILL/claude_sol.md`, issues_open.md §78). They need the founder: account access, a real device, a decision, or the Blaze plan. A coding agent can't close them._

## Your accounts

- [ ] **Back up the keystore and confirm Play App Signing. Do this today.** Put `throttleiq-release.keystore`, the passwords in `app/android/key.properties`, `secrets/*.json`, and `secret/creds.txt` in a password manager. Then move the keystore out of the repo folder (claude_sol §2.6.2).
- [ ] **Add testers to the Play internal track.** It has zero testers today (claude_sol §4.4).
- [ ] **Fill in the Play Data Safety form and the full-screen alert declaration.** Data Safety needs: audio (voice notes), precise location, and crash logs. The full-screen intent declaration is required for the crash countdown (69.O1, 69.O8).
- [ ] **Lock down the Cloudinary upload preset in its dashboard.** On `throttleiq_unsigned`, set allowed formats, a max file size, a locked folder, and a usage alert (claude_sol §1.4.4).

## Decisions

- [ ] **a. Deleting a bike:** archive it by default? (recommended)
- [ ] **b. Crash alerts:** Path B, where the phone opens a pre-filled text to your contacts, can be built now without Blaze. Or wait for real server-side SMS?
- [ ] **c. Pitch Slide 9:** does the team on the slide exist? If not, rewrite it as a solo founder hiring those roles.
- [ ] **d. Profile tab:** rename it to "Garage"?
- [ ] **e. §74:** are the dark cards on Retro Light intentional?

## New from the fix pass (branch `fix/grill-78`)

- [ ] **Merge `fix/grill-78`** into `master`/`main` once you've looked it over. Then test it on a device (list in `issues_fixed.md` §78, "Not verified on a device").
- [ ] **Pick a map tile provider** (MapTiler, Stadia, Thunderforest, or self-hosted Protomaps). Pass its URL, key and attribution as `--dart-define TILE_URL_TEMPLATE / TILE_API_KEY / TILE_ATTRIBUTION` in release builds, and restrict the key to `com.bft.throttleiq`. Without them, release builds still hit OSM's servers.
- [ ] **Turn on branch protection** for `main`, and make the `flutter`, `rules` and `functions` CI checks required after the first run.
- [ ] **Have a native speaker review the new Bangla strings** (emergency banner and acknowledgement, SafeQR share, moving/stopped).
- [ ] **Deploy order:** ship the app build before deploying `firestore.rules`. The new chat rule rejects chat creation from older builds.
- [ ] **Turning on crash detection** (`SensorConstants.impactDetectorLiveEnabled`) waits on decision b plus field and drop tests.

## Needs Blaze

- [ ] Real SMS and escalation
- [ ] Signed Cloudinary uploads
- [ ] Full account deletion
- [ ] Adding new followers to old posts

## Deploys

- [ ] `firestore.rules` and `firestore.indexes.json` (the new places index), after the fixes are merged. These go public, so confirm before each deploy.
- [ ] `functions` (now on Node 22) once Blaze is on. Delete any 1st-gen copies of `reconcileRideIdentity`, `onCrashNotification` and `escalateCrashAlert` first.
