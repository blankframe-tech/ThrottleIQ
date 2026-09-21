# Needs Attention

_Rewritten 2026-09-21 (evening) against the real state of `main` @ `0222f03`. Earlier versions
listed things that have since been done (keystore, route navigation, print sticker, rules deploy).
What is left needs the founder: an account, a real device, a decision, or the Blaze plan._

## Release — the one thing everything else waits on

`main` holds a lot that no tester has: App Check, analytics, route navigation that records the
ride, the i18n pass, the SafeQR print sticker, the crash badge, the cockpit perf fix. `pubspec` is
still `1.0.0-beta.3.0.2+19` = `beta-v3.0.2`. The release **APK and AAB both build** (verified this
evening, 84.7 MB / 82.8 MB, not published).

- [ ] **Decide the release** — version bump, notes, and whether it goes out before the device test
      list (below). It carries two things nobody has checked on hardware (route navigation,
      Bangla) and 1,064 machine-drafted Bangla keys.
- [ ] After it ships: **deploy hosting** (`firebase deploy --only hosting`) so `privacy.html`
      describes the analytics the app now does — *not before*, the live policy would then describe
      behaviour the installed app doesn't have.
- [ ] After riders are on it: **turn on App Check enforcement** in the Firebase console (register
      the Play Integrity provider and the debug token first). Enforcing early locks out every
      older build.

## Your accounts (a browser session as you can do most of these)

- [ ] **CI + branch protection.** `.github/workflows/ci.yml` has never run on GitHub and `main`
      has no required checks — the gates run on one laptop only. Make `flutter`, `rules`,
      `functions` required after the first green run.
- [ ] **Play Console:** Data Safety form (audio, precise location, crash logs, **and now app
      interactions / analytics — "collected, optional, not shared"**), the full-screen intent
      declaration (crash countdown), and add testers to the internal track (it has none).
- [ ] **Cloudinary:** lock the `throttleiq_unsigned` preset — allowed formats, max size, locked
      folder, usage alert.
- [ ] **Map tiles:** sign up for a provider (Thunderforest recommended), then export
      `TILE_URL_TEMPLATE` / `TILE_API_KEY` / `TILE_ATTRIBUTION` before `scripts/deploy.sh`. Restrict
      the key to `com.bft.throttleiq`. Without them, release builds hit OSM directly.

## Needs a phone, a bike or a person

- [ ] **Device test of everything on `main`.** Never run on real hardware: route navigation
      recording (§78.21), the auto-tracking schedule (§37), the GPS-speed fallback (§49), the
      gyro heading sign/axis (§78.12), SafeQR print scanning off real paper, App Check on a device.
- [ ] **Profile the cockpit** for battery/frame time (§83.12 — fixed structurally, unmeasured).
- [ ] **Bangla review:** a native reviewer for the 1,064 keys in `app/lib/l10n/bn_pending_review.txt`,
      then Bangla on a real device (simulator tour: 82 screens, 0 overflow, scale 1.0 only).

## Decisions

- [ ] **Deleting a bike:** archive by default? (recommended)
- [ ] **Profile tab:** rename to "Garage"?
- [ ] **Dates in Bangla:** localized month names with Western digits? (§83.23)
- [ ] **Blocking (§83.18) and Cloudinary uploads (§83.16):** how far to go on Spark — see
      `DOCS/DEBT_FIX_PLAN.md` §6 and §7.
- [ ] **Pitch Slide 9:** does the team on the slide exist? The deck still claims working crash
      detection. Off-limits to agents unless you ask.

## Needs Blaze (decision: staying on Spark)

- Real SMS and escalation, signed Cloudinary uploads, full account deletion (the trigger has
  never been deployed), adding new followers to old posts.
- **Dated:** Cloud Functions Node 20 is decommissioned late October 2026; after that
  `firebase deploy --only functions` fails on any plan.

## Done — kept here so it isn't re-asked

- ✅ Keystore backed up (2026-09-21). ✅ Route navigation records the ride. ✅ SafeQR print sticker.
- ✅ Firestore rules (incl. the §80 `likes` removal, evening 2026-09-21) and indexes are live.
- ✅ Crash detection stays off — settled, do not raise.
