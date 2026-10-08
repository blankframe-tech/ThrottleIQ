# Needs Attention

_Rewritten 2026-09-21 (evening) against the real state of `main` @ `0222f03`. Earlier versions
listed things that have since been done (keystore, route navigation, print sticker, rules deploy).
What is left needs the founder: an account, a real device, a decision, or the Blaze plan._

## Release — the one thing everything else waits on

_Update 2026-10-07 (later):_ the current release is `beta-v4.2` (`1.0.0-beta.4.2.0+23`, AAB + APK
on GitHub, tag on `ed8fd34`): the Places hub (§96), the Forums Pit Wall, and the two forum fixes
(photos on posts, brand paddock counts; issues_fixed §97). The iOS release build of `ed8fd34` is
installed and launched on the founder's iPhone 15, but photos on posts and the paddock counts have
not been tried on the device yet. `app/pubspec.yaml` is already bumped to `1.0.0-beta.4.3.0+24` for
the next release; that one is not tagged yet.

_Earlier, 2026-10-07:_ `beta-v4.1` (`1.0.0-beta.4.1.0+22`): the maintenance redesign plus the
auto-tracking daily summary. It has **not been tested on a device**. Device checks to do:
`issues_open.md` §95.1. The follow-ups below still apply.

- [x] **Publish the release.** Shipped as `beta-v4` (`1.0.0-beta.4.0.0+21`, 2026-09-27). It carries
      two things nobody has checked on hardware (route navigation, Bangla) and the machine-drafted
      Bangla keys.
- [x] (Deployed 2026-10-08 by the founder, together with the Firestore rules and indexes; the rules compiler warned `[W] 427:46 Invalid type. Received one of [null]`, worth a look. Check the analytics build is out.) After it ships: **deploy hosting** (`firebase deploy --only hosting`) so `privacy.html`
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
- [~] **Cloudinary:** (formats locked and verified 2026-10-08; size cap and usage alert remain) lock the `throttleiq_unsigned` preset — allowed formats, max size, locked
      folder, usage alert.
- [x] **Map tiles (done 2026-10-08):** Thunderforest `atlas` key is in git-ignored `secret/tiles.env`; `scripts/deploy.sh` sources it automatically. Free tier is 150k tiles/month, which is enough for the beta but not for ~100 daily riders; the app already has an on-disk tile cache. Original note: sign up for a provider (Thunderforest recommended), then export
      `TILE_URL_TEMPLATE` / `TILE_API_KEY` / `TILE_ATTRIBUTION` before `scripts/deploy.sh`. Restrict
      the key to `com.bft.throttleiq`. Without them, release builds hit OSM directly.

## Needs a phone, a bike or a person

- [ ] **Device test of everything on `main`.** Never run on real hardware: route navigation
      recording (§78.21), the auto-tracking schedule (§37), the GPS-speed fallback (§49), the
      gyro heading sign/axis (§78.12), SafeQR print scanning off real paper, App Check on a device.
- [ ] **Profile the cockpit** for battery/frame time (§83.12 — fixed structurally, unmeasured).
- [ ] **Bangla review:** a native reviewer for the ~1,100 keys in `app/lib/l10n/bn_pending_review.txt`,
      then Bangla on a real device (simulator tour: 82 screens, 0 overflow, scale 1.0 only).

## Decisions

- [x] **Deleting a bike:** archive by default — built 2026-10-08 (uncommitted), see issues_open §102.
- [x] **Profile tab:** renamed to "Garage" — built, §102.
- [x] **Dates in Bangla:** English-style dates in the Bangla font — built, §102.
- [ ] **Blocking (§83.18) and Cloudinary uploads (§83.16):** how far to go on Spark — see
      `DOCS/DEBT_FIX_PLAN.md` §6 and §7.
- [ ] **Pitch Slide 9:** does the team on the slide exist? The deck still claims working crash
      detection. Off-limits to agents unless you ask.

## Needs Blaze (decision: staying on Spark)

- Firestore TTL on `liveSessions.expiresAt` (tried 2026-10-08: 403 billing disabled), real SMS and escalation, signed Cloudinary uploads, full account deletion (the trigger has
  never been deployed), adding new followers to old posts.
- **Dated:** Cloud Functions Node 20 is decommissioned late October 2026. The `functions/` source
  already targets Node 22 (`package.json` `engines`, `firebase.json` `runtime`; §69.O6), so this
  only bites if a Node 20 build is what gets deployed. Deploying at all still needs Blaze.

## Done — kept here so it isn't re-asked

- ✅ Keystore backed up (2026-09-21). ✅ Route navigation records the ride. ✅ SafeQR print sticker.
- ✅ Firestore rules (incl. the §80 `likes` removal, evening 2026-09-21) and indexes are live.
- ✅ Crash detection stays off — settled, do not raise.
