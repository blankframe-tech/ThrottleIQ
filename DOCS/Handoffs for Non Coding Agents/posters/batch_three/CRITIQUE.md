# Batch three: why batch two could not be posted, and what replaced it

Written 2026-10-22. Batch two is 49 posters. Every one was rendered and read
against `DOCS/Handoff for agents and Todos/features.md` and
`../../marketing/marketing.md`.

## What was wrong with batch two

**1. It claims features the app does not have.** One false claim in public is
expensive, and batch two has many:
- 12, 13: "+40% reaction delay", "Noorjahan Dhaba 4 km ahead". There is no
  fatigue model and no pit-stop suggestion. The app has a 90-minute break alert.
- 21, 22: "verified octane", "1,240+ pumps audited". There is no fuel-quality
  data. A rider can only tag a pump "octane 95".
- 28-31: Gixxer, FZ-S, R15 and Pulsar benchmarks across riders. These are not
  built. The "2,150 bikes synced" counts, the named workshops and the review
  counts are made up.
- 19, 20: a "certified gentle rider" certificate. 24: a "biker reunion radar".
  17, 23: brake-force "physics audits". None of these exist.
- 36, 49, 50: "If the ride stops suddenly, the app asks 'Everything okay?'"
  This is the crash flow. It is off in every build, and marketing.md says never
  to advertise it.
- 60: a return ETA for the family. 52: "free forever". Neither is built or
  promised.

**2. Fake social proof.** "2,140 riders online", "128 riders", "8 bikes
connected", star ratings with review counts. The app is a closed beta, and
anyone who installs it sees these numbers are false.

**3. It promotes speed.** 9 (118 km/h on 300 Feet), 23 (150 km/h), 30 (R15 top
speed, 46° lean), 47 ("real speed data"). The Expressway limit is 80 km/h. A
safety-adjacent brand cannot sell bragging rights about speed.

**4. You cannot read it from a street or a feed.** Posters 2-31 carry four
layers of copy and dashboard labels set at 8-10 px. From two metres, only the
headline reads. The social ads (32-56) put a 450 px screenshot behind chips
that cover it, so the screen proves nothing.

**5. Layout bugs.**
- Header labels collide in 21, 23, 24, 26 and 28-31.
- 9: "PEAK GPS VELOCITY" sits on top of the 118.
- 10: "[AUTO-STRIPPED]" sits on "HOME PIN".
- 31: the body copy runs off the right edge.
- 6: the stars spill out of their box.
- In about 15 social ads, the ThrottleIQ logo runs into the headline.
- 57-61: the "LIVE SHARE" watermark is clipped.

**6. Many posters repeat the same idea.** 49 files hold about 15 ideas:
- family: 16, 36, 57, 60
- crew: 7, 8, 14, 15, 58
- maintenance: 32, 42, 54, 55
- speed: 9, 34, 40, 47, 53

The same four screenshots appear in 15 posters, and 57-61 use one identical map
card.

**7. The details are weak.**
- The footer tagline "MACHINE MEMORY FOR MOTORCYCLES" means nothing to a rider.
- "iOS soon": there is no iPhone build.
- Social ads carry a 104 px QR code, which nobody can scan from their own feed,
  and give no URL to type.

## The rules batch three follows

1. **Every claim is checked against features.md.** Nothing is in shadow mode,
   beta-only or unbuilt. The family poster says only what Live Share does: the
   rider turns it on and sends a link, the family opens it in a browser with no
   login, and it shows location, speed and battery.
2. **No invented numbers.** The one number used, "1,100+ places", is real:
   1,238 Dhaka places are seeded, and the screenshot shows 1,114 within 25 km.
   The crew join code, rider name and speed in the drawn cards are labelled UI
   examples, not stats.
3. **One poster, one segment, one feature, one message** (marketing.md §2):
   - commuters: 1-5 and 11-15, 18
   - enthusiasts and touring riders: 6-9, 16, 17
   - families, reached through the rider: 10
4. **The hero image is a real app screen where one exists**
   (`DOCS/General/new ui screenshot/dark`). It is cropped to the part that
   proves the claim and large enough to read. Where no populated screenshot exists (Live Share, group map, break alert,
   running cost, jam time, papers, mileage, quick check, widgets, modules), the
   screen is drawn as a simple card that follows the real UI.
5. **Each poster has three readable layers:** a 2-line headline of 96 px or
   more, a 2-line subline, and three short points. Nothing is smaller than
   19 px at 1080 wide.
6. **The brand comes from `app_theme_style.dart`.** Carbon Mono (lime on black)
   for 7 posters; Calming (sage on cream) for 3: resale, running cost, family.
   The real app icon is used.
7. **The footer works on paper and on a phone.**
   - a 168 px QR code (all 18 decode; checked with OpenCV)
   - the URL written out
   - "Android · নেট ছাড়াও চলে · ঢাকায় তৈরি"
   - a "ফ্রি অ্যাপ" pill at the top
8. **No speed bragging, no crash or SOS, and no "forever".**

## The posters

| # | File | Segment | Headline | Hero | QR campaign |
|---|---|---|---|---|---|
| 1 | `1_offline-recording` | Commuter | সিগন্যাল না থাকলেও, রেকর্ড হতে থাকে। | ride-summary route map | `offline_b3` |
| 2 | `2_maintenance-due` | Commuter | চেইন কবে লুব করেছিলেন? মনে রাখতে হবে না। | Maintenance "Up next" | `maint_b3` |
| 3 | `3_service-record-resale` | Commuter | বাইক বেচবেন? সার্ভিসের প্রমাণ দিন। | Log a visit | `resale_b3` |
| 4 | `4_garages-nearby` | Commuter | কাছের ভালো গ্যারেজ কোনটা? ম্যাপেই দেখুন। | Places map | `places_b3` |
| 5 | `5_real-running-cost` | Commuter | তেলের দামই কি আসল খরচ? | drawn cost card | `cost_b3` |
| 6 | `6_ride-report` | Enthusiast | রাইড শেষে, পুরো রিপোর্ট। | Ride summary | `report_b3` |
| 7 | `7_crew-live-map` | Enthusiast | দোস্ত তুই কই? ম্যাপেই দেখ। | drawn group map + join code | `crew_b3` |
| 8 | `8_saved-routes` | Touring | দারুণ রাস্তা পেয়েছেন? রুটটা সেভ রাখুন। | Save as route | `route_b3` |
| 9 | `9_break-reminder` | Touring | টানা দেড় ঘণ্টা চালালেন? এবার একটু চা। | drawn break alert | `break_b3` |
| 10 | `10_family-live-share` | Family (via rider) | সে রাইডে, আপনি নিশ্চিন্তে। | drawn Live Share viewer | `family_live_b3` |
| 11 | `11_jam-time` | Commuter | আজ কত মিনিট জ্যামে গেল? অ্যাপ গুনে রাখে। | drawn moving-vs-jam card | `jam_b3` |
| 12 | `12_papers-reminder` | Commuter | ট্যাক্স টোকেনের মেয়াদ কবে? অ্যাপ আগেই জানাবে। | drawn papers list | `papers_b3` |
| 13 | `13_real-mileage` | Commuter | শোরুম বলেছিল ৪৫। আসলে কত দেয়? | drawn km/L card | `mileage_b3` |
| 14 | `14_pre-ride-check` | Commuter | রাইডের আগে ৩০ সেকেন্ডের চেক। | drawn T-CLOCS tiles | `precheck_b3` |
| 15 | `15_home-widget` | Commuter | অ্যাপ না খুলেই পরের সার্ভিস দেখুন। | drawn home-screen widgets | `widget_b3` |
| 16 | `16_ask-owners` | Enthusiast | একই বাইক, একই সমস্যা? মালিকদের জিজ্ঞেস করুন। | Bike detail (Ask owners) | `owners_b3` |
| 17 | `17_private-sharing` | Enthusiast | রাইড শেয়ার করুন, বাসার ঠিকানা না। | Share ride (audience) | `privacy_b3` |
| 18 | `18_maintenance-only` | Commuter (minimalist) | শুধু সার্ভিসের হিসাব চান? বাকিটা বন্ধ রাখুন। | drawn module toggles | `modules_b3` |

Format: 1080x1350 (4:5). It posts as-is to Facebook and Instagram. For print,
render at 3240x4050 (`rsvg-convert -w 3240`); that fits A3 with a margin.

Regenerate with `generator_helper_files/batch_three.py` (see its docstring).

## Check before you post

- The Bangla copy is written by hand, not by a machine, but no native reviewer
  has read it yet.
- The screenshots come from a test account: a "Zulfikar", a 2.5 km ride, a
  Honda CBR.
- Some features have passed `scripts/check.sh` but have not been checked on a
  device (see features.md):
  - the maintenance redesign, which includes the PDF service record (posters 2
    and 3)
  - push-to-talk with a headset (poster 7)
  - the T-CLOCS quick check and the papers reminders (posters 12 and 14), which
    are part of the same maintenance redesign

  Before a paid push, try each one once on a phone.
- Poster 16 sends riders to the brand forums. Seed 2-3 starter posts first
  (marketing.md §4), or the forums look abandoned.
- The numbers in the drawn cards (28/19 min, 38.6 km/L, "120 km left") are UI
  examples, not stats. Never quote them as data.
- The `?c=..._b3` campaign ids are new. Check that the install page keeps the
  `c` parameter for attribution.
