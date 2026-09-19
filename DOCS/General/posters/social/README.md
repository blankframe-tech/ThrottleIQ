# ThrottleIQ Social Ad Creatives

Twenty-six install-driving creatives for Meta/Instagram feed ads and
organic social posts — distinct from the street-poster series
(`../posters.py`, `_v2`, `_v3`, which are OOH/print). Format:
**1080×1350 (4:5)**, Meta's recommended feed-ad ratio.

The first six (`social-01`..`social-06`) are the original pass. Twenty
more (`social-07`..`social-26`, added 2026-09-19) follow the same
recipe: a real cropped app screenshot, a two-line stroke headline, one
sentence of subhead, two flanking stat badges, the same footer. See
"The 20 new creatives" below for what's different about them.

Each creative puts a real, cropped app screenshot front and center (2026
ASO best practice: show actual current UI, not mockups) rather than the
posters' illustrated street scene. Screenshots are cropped from
`../../website_demo/assets/ui/carbon-mono.png` and `editorial-bw.png`
(the app's own theme-system demo sheets) via `crop_screenshots.py` and
live in `screenshots/`.

Every creative uses one of ThrottleIQ's own skins (`../lib.py` `SKINS`),
reusing the same skin-per-segment mapping the v1 street posters already
established (Genesis for maintenance, Editorial for telemetry/cost,
Nocturne for crew/journey, Calming for family), so this series reads as
part of the same brand system rather than a one-off.

## Distribution reality — why the CTA says APK, not a store badge

Neither the Play Store nor the App Store listing is live yet (see
`DOCS/Handoff for agents and Todos/HANDOFF_Document.md`, "Play Store &
App Store — step by step", and the "Latest release" row: distribution
today is a signed APK/AAB on GitHub Releases; the Play Console internal
track is stale; no iOS build has gone to TestFlight). Putting a "Get it
on Google Play" or "Download on the App Store" badge on these creatives
would claim availability that doesn't exist, so every footer here reads
**"ThrottleIQ APK ফ্রি ডাউনলোড"** / **"ANDROID NOW · iOS শীঘ্রই"** instead,
pointing at the same OS-sniffing `/install` page the poster QR codes use.
Update the footer copy in `social.py` the day a real store listing ships.

## No-overclaim notes specific to this set

- **Family creatives (05, 06) do not claim automatic crash-alert
  delivery to contacts.** `functions/src/crash-notifications.ts` is a
  mock end-to-end — no SMS/email ever actually sends (blocked on the
  Blaze billing plan, per `issues_open.md`). The on-screen "Everything
  okay?" copy in the real screenshot mentions checking in with emergency
  contacts, but the ad copy around it deliberately only claims what's
  true: the app self-checks with the **rider**, and a **Live Share**
  viewer (opt-in, real, working since 2026-08-14) would notice the dot
  stop moving. Neither creative implies contacts get an automatic
  message.
- **Enthusiast copy** ("ক্রু নিয়ে রাইড করুন") is retention framing, not an
  acquisition claim — group rides still require the invitee to already
  have the app installed.
- **"২০+ ডেটা পয়েন্ট/সেকেন্ড"** (03) reuses the already-verified enthusiast
  positioning number from `../../marketing/marketing.md`, not a new claim.
- **None of the 20 new creatives (07-26) claim a shareable-outside-the-app
  ride link.** `marketing.md` §3 flags the public ride-summary page as
  *not built* — the in-app Save Ride/Share buttons are real UI, but the
  ad copy around any ride-complete screenshot (02, 14, 25) only ever
  claims what the screenshot itself shows (stats, splits, a badge), never
  "share your ride with a friend."
- **Reused screenshots keep whatever redaction the original crop has.**
  `family-parent.png`/`family-spouse.png` had two bands blanked at crop
  time (see `crop_screenshots.py`'s `REDACT`) to remove on-screen copy
  that implied automatic crash-contact delivery. Creatives 18 and 19
  reuse those same crop files under new segments/copy and inherit the
  same redaction — checked visually after rendering (no leftover
  "notify contacts" text in either final PNG).

## The first six creatives

| id | Segment | Skin | Hook | Screenshot |
|---|---|---|---|---|
| `social-01-commuter-maintenance` | Commuter | Genesis | Service reminders driven by real distance, free | Maintenance checklist |
| `social-02-commuter-ridelog` | Commuter | Editorial Light | Every ride logged offline, no towers needed | Ride Complete (splits/stats) |
| `social-03-enthusiast-telemetry` | Enthusiast | Editorial Dark | Real telemetry, not tea-stall bragging | On The Road (live speed) |
| `social-04-enthusiast-journey` | Enthusiast | Nocturne | Levels/badges/distance, ride with your crew | Your Journey |
| `social-05-family-parent` | Family | Calming Dark | Hard-stop self check-in + opt-in Live Share | Safety Check-In |
| `social-06-family-spouse` | Family | Calming Light | Opt-in Live Share for peace of mind, rider-controlled | Safety Check-In |

Each footer QR points to a distinct campaign so installs can be
attributed by creative:

```
01 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_maint
02 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_ridelog
03 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_telemetry
04 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_journey
05 https://blankframe.tech/ThrottleIQ/install?c=social_family_hardstop
06 https://blankframe.tech/ThrottleIQ/install?c=social_family_liveshare2
```

## The 20 new creatives

Same recipe as the first six, deliberately extended two ways:

1. **8 new screenshot crops** (`start-ride-{carbon,editorial}`,
   `on-the-road-editorial`, `garage-{carbon,editorial}`,
   `journey-carbon`, `maintenance-carbon`, `ridecomplete-hero-editorial`)
   pull the remaining screen cards off the same two UI sheets that were
   only partly cropped for the first six. See `crop_screenshots.py`'s
   docstring for exactly how each box was measured, including two crops
   (`start-ride-editorial`, `on-the-road-editorial`) that needed a
   tighter bottom edge than the naive measurement gave, to avoid
   bleeding in the next screen's section label. (A ninth and tenth crop —
   the Save Ride/Share buttons below the Splits table, in both skins —
   were tried and dropped: mostly empty card, not worth a creative on
   its own.)
2. **12 of the 20 reuse one of the original six screenshots** (or one of
   the 8 new ones a second time) under a genuinely different segment and
   headline — the same "test another angle on the same creative asset"
   practice any performance-marketing account runs, not a cosmetic
   duplicate. Every poster still carries exactly one segment's copy
   (never blended, per `../../marketing/marketing.md`'s segment rule) and
   its own campaign id, so installs from the reused-image versions
   attribute separately from the originals.

Four skins new to this series were added (`carbonMono`, `trailSocial`,
`analystBlue`, `retro`) to keep 20 more posters visually distinct rather
than cycling the same six backgrounds; `BADGE_TEXT`/`ACCENT_KEY` in
`social.py` map each to a badge fill/text pair the same way the
original six skins already were.

| id | Segment | Skin | Hook | Screenshot |
|---|---|---|---|---|
| `social-07-commuter-startride` | Commuter | Carbon Mono | One-tap ride start, daily streak habit | Start Ride (new) |
| `social-08-family-giftinstall` | Family | Calming Light | Install it for a rider you love, they'll figure out the rest | Start Ride (new) |
| `social-09-enthusiast-liveguard` | Enthusiast | Trail Social | Live speed + in-ride caution nudge | On The Road, editorial (new) |
| `social-10-commuter-garagefleet` | Commuter | Genesis | Every bike, one dashboard | Your Garage (new) |
| `social-11-family-garagepeace` | Family | Calming Dark | App remembers the service date so you don't have to | Your Garage, editorial (new) |
| `social-12-enthusiast-totalstats` | Enthusiast | Nocturne | 642 km / 31 rides — real milestones, not vibes | Your Journey (new) |
| `social-13-enthusiast-upkeep` | Enthusiast | Carbon Mono | Overdue chain lube flagged before it costs you performance | Maintenance (new) |
| `social-14-commuter-fullreport` | Commuter | Editorial Light | Full ride report — splits + elevation + badge | Ride Complete, editorial (new) |
| `social-15-commuter-offlinesignal` | Commuter | Carbon Mono | Recording never stops just because signal does | On The Road (reuse of 03's shot) |
| `social-16-enthusiast-speedproof` | Enthusiast | Nocturne | Avg/max speed as bragging rights, with receipts | Ride Complete (reuse of 02's shot) |
| `social-17-family-habitproof` | Family | Calming Light | Every ride logged = a rider who owns their habits | Your Journey (reuse of 04's shot) |
| `social-18-enthusiast-solocheckin` | Enthusiast | Trail Social | Riding solo doesn't mean riding unchecked | Safety Check-In (reuse of 05's shot) |
| `social-19-commuter-selfcheck` | Commuter | Editorial Dark | The same self check-in, for every daily commute | Safety Check-In (reuse of 06's shot) |
| `social-20-family-roadworthy` | Family | Calming Dark | Less money at the garage, less risk on the road | Maintenance (reuse of 01's shot) |
| `social-21-commuter-freeforever` | Commuter | Retro | No subscription, no hidden charge | Start Ride (reuse of 07's shot) |
| `social-22-family-safehabit` | Family | Calming Dark | Not just location — the app coaches safer riding habits | On The Road (reuse of 09's shot) |
| `social-23-enthusiast-multigarage` | Enthusiast | Analyst Blue | The parked bike doesn't get forgotten either | Your Garage (reuse of 10's shot) |
| `social-24-family-autoreminder` | Family | Genesis | Forget it yourself — the app won't | Maintenance (reuse of 13's shot) |
| `social-25-enthusiast-badgeproof` | Enthusiast | Editorial Dark | Badges unlocked, with proof, every ride | Ride Complete, editorial (reuse of 14's shot) |
| `social-26-family-milestonepride` | Family | Calming Light | Every level up is a more experienced, more careful rider | Your Journey (reuse of 12's shot) |

```
07 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_startride
08 https://blankframe.tech/ThrottleIQ/install?c=social_family_giftinstall
09 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_liveguard
10 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_garagefleet
11 https://blankframe.tech/ThrottleIQ/install?c=social_family_garagepeace
12 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_totalstats
13 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_upkeep
14 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_fullreport
15 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_offlinesignal
16 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_speedproof
17 https://blankframe.tech/ThrottleIQ/install?c=social_family_habitproof
18 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_solocheckin
19 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_selfcheck
20 https://blankframe.tech/ThrottleIQ/install?c=social_family_roadworthy
21 https://blankframe.tech/ThrottleIQ/install?c=social_commuter_freeforever
22 https://blankframe.tech/ThrottleIQ/install?c=social_family_safehabit
23 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_multigarage
24 https://blankframe.tech/ThrottleIQ/install?c=social_family_autoreminder
25 https://blankframe.tech/ThrottleIQ/install?c=social_enthusiast_badgeproof
26 https://blankframe.tech/ThrottleIQ/install?c=social_family_milestonepride
```

## Files

- `crop_screenshots.py` — crops 14 UI-sheet regions into
  `screenshots/*.png` (rounded-corner alpha mask applied; several are
  trimmed to drop dead trailing space or a bleeding section label — see
  the script's docstring for the exact crop boxes and why each trim is
  where it is).
- `screenshots/*.png` — the 14 cropped, alpha-masked app-card images
  backing the 26 creatives (12 are reused a second time under different
  copy, per "The 20 new creatives" above).
- `social.py` — the generator, now with 26 entries in `POSTERS`. Reuses
  `../lib.py` / `../bn.py` (HarfBuzz-shaped Bangla text, QR, skins) so
  headlines render with correct conjuncts. Run with the existing venv:
  ```bash
  ../.venv/bin/python3 social.py            # writes svg/*.svg
  ../.venv/bin/python3 -c "
  import cairosvg, glob, os
  for f in glob.glob('svg/*.svg'):
      n = os.path.basename(f)[:-4]
      cairosvg.svg2png(url=f, write_to=f'png/{n}.png', output_width=1080, output_height=1350)
  "
  ```
- `svg/*.svg` — vector source (screenshot embedded as a base64 `<image>`,
  so each SVG is self-contained).
- `png/*.png` — final 1080×1350 creatives, ready to upload as Meta/IG ad
  images or organic posts.

## Regenerating after a UI change

If `carbon-mono.png` / `editorial-bw.png` are re-exported (e.g. after a
real design refresh), the crop boxes in `crop_screenshots.py` are
pixel coordinates tied to the current sheets and will need
re-measuring — the script's column/row detection comments explain the
approach (background-diff row/column projection, thresholded per skin
since Carbon Mono's dark-on-dark contrast needs a lower threshold than
Editorial's light-on-light).
