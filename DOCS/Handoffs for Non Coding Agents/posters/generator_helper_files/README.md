> **2026-10-22: every poster is now one SVG in `batch_one/`** (`v1/`, `v2/`,
> `v3/`, `social/`). The PNG exports in `print/`, `web/` and `social/png/` were
> deleted as duplicates; render a PNG from the SVG when you need one (commands
> below). Only exception: `batch_one/v1/25-ai-camera-flash-caricature@2x.png`
> has no SVG, so the PNG is the only copy.

> **2026-10-14: v1 and v2 are frozen.** `posters.py`, `posters_v2.py` and
> `illus.py` were deleted (critique `CrtiQue_Oct14.md` §14); the last copy is on
> branch `oct14-int`. Their rendered files stay as they are and can no longer be
> regenerated. Posters that advertised crash detection, SOS or emergency
> dispatch were removed too, because the detector is off in every build: v1 #05
> (black box), #09 (resale passport, "crash spikes" row), #13 (family safety)
> and v2 #05. `posters_v3.py` is the only live generator. The v1/v2 sections
> below are kept as a record.

## V3 — street-ad ("Lalamove style"), 1080×1350

`posters_v3.py` builds a third pass in the flat-icon Dhaka-billboard grammar
seen on delivery-app OOH ads (Lalamove, Pathao): a street scene with two
riders checking phones, a live-map card floating between them, a huge
yellow-fill/black-outline headline, two orange callout badges, and a QR
footer. Vector, not photo — same HarfBuzz-shaped Bangla outlines as v1/v2,
so it needs no photoshoot and no fonts installed to open. One poster per
segment (never blends commuter/enthusiast/family copy in one asset, per
`docs/marketing/marketing.md`); campaign IDs get a `_v3` suffix.

| id | Segment | Hook |
|---|---|---|
| `57_family-live-location` | Anxious family | আপনার বাইকার কোথায় আছে? — family sees the rider's live position once they turn Live Share on (opt-in, not automatic) |
| `58_crew-live-map` | Enthusiast/crew | বন্ধু তুই কই এখন? — the whole crew on one live map once Group Beacon is on |
| `v3-03-offline-record` | Daily commuter | সিগন্যাল না থাকলেও, রেকর্ড হতে থাকে। — GPS keeps recording with no tower, syncs itself once the net's back. Map card renders dimmed/grey with a steady (non-pulsing) marker and a "NO SIGNAL" pill instead of the live-green "LIVE" one — same `map_card()`, using its new `dim`/`dot_color`/`pulse` params |
| `59_saved-crew-route` | Enthusiast/touring | রাস্তা সেভ থাকলে, কেউ হারায় না। — a route saved from a past ride, so the rest of the crew can navigate the same path turn-by-turn on their own; distinct from `v3-02`'s "where's everyone right now" live-position hook — this one's about a route planned *before* the ride, not live positions during it. Blue, non-pulsing "ROUTE" marker |
| `60_family-return-eta` | Anxious family | আসতে আসতে কতদূর? — a spouse/family member waiting at home, not the "where's my rider right now" framing of `v3-01`; same strict opt-in-only Live Share language |
| `61_jam-time-split` | Daily commuter | আজও ৪৭ মিনিট জ্যামে দাঁড়িয়ে? — the ride summary's real moving-vs-jam split, recast in this series' street-ad grammar (v1's `1_jam-time-counter` concept). Amber, non-pulsing "IN JAM" marker. **The `47` is a placeholder shaped like real app output — swap for an actual aggregate before printing at volume**, same as v1 poster 01 |

Segments deliberately not extended into v3 this pass: garage/resale-proof,
per-km fuel cost, and the AI-camera/benchmark concepts (v1 `#03`, `#09`,
`#19`–`#24`) don't have a live-map-shaped visual hook the way the six above
do — forcing them into this card-and-pin grammar would be the same
"diluting one asset to cover two ideas" mistake the segment-separation rule
warns against, just applied to a visual instead of a message; they stay
v1/v2-only. Also skipped: any push-to-talk/voice-note angle (real feature,
but not a map/location concept, so it doesn't fit this series either) and
anything resembling the shared-ride-summary acquisition loop or a
badge/reward physical-prize promotion — both are proposed-but-not-built per
`marketing.md`, not shipped claims.

```bash
.venv/bin/python3 posters_v3.py          # writes batch_one/v3/*.svg
.venv/bin/python3 -c "
import cairosvg, glob, os
for f in glob.glob('batch_one/v3/*.svg'):
    n = os.path.basename(f)[:-4]
    cairosvg.svg2png(url=f, write_to=f'{n}@2x.png', output_width=2160, output_height=2700)
    cairosvg.svg2png(url=f, write_to=f'{n}.png', output_width=1080, output_height=1350)
"
```

SVGs live in `batch_one/v3/`. The PNGs land in the current folder; don't commit them.

**QR campaigns:**

```
v3-01 https://blankframe.tech/ThrottleIQ/install?c=family_live_v3
v3-02 https://blankframe.tech/ThrottleIQ/install?c=crew_beacon_v3
v3-03 https://blankframe.tech/ThrottleIQ/install?c=offline_record_v3
v3-04 https://blankframe.tech/ThrottleIQ/install?c=saved_route_v3
v3-05 https://blankframe.tech/ThrottleIQ/install?c=family_eta_v3
v3-06 https://blankframe.tech/ThrottleIQ/install?c=jam_proof_v3
```

---

## V2 — one visual, one line, a QR code

`illus.py` + `posters_v2.py` generate a second, louder pass on the same 24
concepts: one big flat-icon illustration per poster (a line-art rider figure,
or a prop icon — traffic light, fuel pump, black box, shield, etc., all
defined in `illus.py`), 1-2 huge headline words, and a QR in the bottom-right
corner. No instrument panels, no stat rows — clickbait-y on purpose, meant to
read from across the street. Same skin-per-poster and campaign IDs as v1
(QR links get a `_v2` campaign suffix for separate attribution).

```bash
# posters_v2.py was deleted 2026-10-14; this is how the files were made
.venv/bin/python3 posters_v2.py          # wrote svg/v2/*.svg, now in batch_one/v2/
.venv/bin/python3 -c "
import cairosvg, glob, os
for f in glob.glob('batch_one/v2/*.svg'):
    n = os.path.basename(f)[:-4]
    cairosvg.svg2png(url=f, write_to=f'{n}@2x.png', output_width=2000, output_height=3000)
    cairosvg.svg2png(url=f, write_to=f'{n}.png', output_width=800, output_height=1200)
"
```

SVGs live in `batch_one/v2/`.

---

# ThrottleIQ Street Posters — Dhaka

Twelve placement-specific posters. Each one borrows a different skin from the app's
own theme system (`app/lib/core/theme/app_theme_style.dart`), so the poster a rider
scans looks like the app they land in.

Headlines and rider-facing copy are in **Bangla**; instrument-panel labels, service-log
rows and technical terms stay English, matching how the app itself reads.

| # | Poster | Where it goes | Skin | The hook |
|---|--------|---------------|------|----------|
| 01 | `1_jam-time-counter` | Traffic signals, foot-over-bridge pillars | Carbon Mono (lime) | আবার দাঁড়িয়ে আছেন। — 47 minutes of jam, counted |
| 02 | `2_chain-lube-at-pump` | Fuel pumps, beside the nozzle | Genesis (gold) | ট্যাংক ফুল। চেইন শুকনা। — Tk 50 chain clean + lube now vs Tk 3,500 sprocket set later |
| 03 | `4_resale-service-history` | Bike resale groups, garage walls | Trail Social (orange) | "বাইক সার্ভিসিং ঠিক ছিল?" — the buyer asks; the seller shows 2 years of logged services |
| 04 | `5_rate-your-garage` | Garages + pumps (review driver) | Retro (brutalist B/W) | এই গ্যারেজ কেমন? — rate it in 30 seconds |
| 05 | `05-black-box-safety` | Street level, signal islands | Analyst Blue (cyan) | আপনি পড়ে গেছেন। — the 32 seconds after |
| 06 | `7_ride-with-crew` | Tea stalls, bike meets, parts markets | Nocturne (lavender) | একলা চালেন না। |
| 07 | `9_real-top-speed` | Purbachal 300ft, Expressway toll plazas | Editorial Dark (cobalt) | চা স্টলে ১৩০। আসল টান কত ছিল? |
| 08 | `10_ride-privacy` | Corporate parking, apartment basements | Calming Dark (sage) | রাইড ফেসবুকে দিলেন। বাসার গলিটাও সবাই চিনে গেল? |
| 09 | `09-resale-passport` | Banglamotor, Bijoy Sarani used shops | Editorial Light (paper) | মিটার ঘুরানো যায়। আসল হিস্ট্রি ঘুরাবেন কেমনে? |
| 10 | `11_offline-recording` | Mountain trails, tour routes, dead zones | Carbon Mono (lime) | টাওয়ার নাই? ThrottleIQ-র নেট লাগে না। |
| 11 | `12_fatigue-alert` | Highway dhabas, Comilla/Mawa rest stops | Trail Social (orange) | টানা দেড় ঘণ্টা সিটে। রিফ্লেক্স কিন্তু স্লো হয়ে গেছে। |
| 12 | `14_group-beacon` | Friday 6 AM meet points, club hangouts | Nocturne (indigo) | “দোস্ত তুই কই?” — আর কত ফোন করবেন? |
| 13 | `16_family-peace-of-mind` | Residential gates, university parking | Calming Dark (sage) | প্রিয়জন কি বাইকার বলে চিন্তিত? নো টেনশন। |
| 14 | `17_find-lost-friend` | Highway exits, flyovers, tea stalls | Carbon Mono (lime) | “বন্ধু তুমি কই, কই, কই??” — ফোনে গান না গেয়ে, ড্যাশবোর্ডে দেখুন। |
| 15 | `19_careful-rider-proof` | University campus, coaching, home stands | Editorial Dark (cobalt) | বাসায় ভাবে আপনি বাইক নিয়ে উড়েন? অথচ আপনি তো ভদ্র রাইডার! |
| 16 | `21_touring-fuel-quality` | Highway toll plazas, pump exits | Genesis (gold) | ট্যুরে হাইওয়েতে তেলের টেনশন? কোন পাম্পের তেল খাঁটি? |
| 17 | `23_speed-brag-proof` | 300ft tea stalls, roadside benches | Trail Social (orange) | “তারপর মামা, ১৫০ স্পিড থেকে ২ হাতে ব্রেক মাইরা ০ নামাইসি!” — চাপাবাজ দোস্তরে প্রমাণ দেখাইতে বলেন। |
| 18 | `24_old-riders-reunion` | Biker cafes, vintage meets, lake spots | Nocturne (indigo) | দীর্ঘদিন পুরনো রাইডার বন্ধুর খোঁজ নাই? ThrottleIQ-তে আসেন, একসাথে চিল করি! |
| 19 | `25_speed-camera-alert` | Flyover ramps, expressway speed traps | Carbon Mono (lime) | AI ক্যামেরা নিয়ে ভয়? আর নয়! ThrottleIQ আছে সাথে। |
| 20 | `26_per-km-cost` | Ride-share stands, delivery parking | Editorial Light (paper) | “১০০ টাকা ভাড়া, ৩০ টাকার তেল—৭০ টাকা লাভ?” ভুল হিসাব! মোবিল আর লুবের হিসাব কে করবে? |
| 21 | `28_gixxer-mileage-benchmark` | Suzuki service centers, Bangshal | Analyst Blue (cyan) | এই যে ভাই, বাকি Gixxer মালিকরা কত মাইলেজ পায় জানেন? |
| 22 | `29_fzs-mileage-benchmark` | Yamaha hubs, Tejgaon, Mirpur 10 | Trail Social (orange) | FZ-S ভাইয়েরা, জ্যামে আপনার বাইক আসলে কত মাইলেজ দিচ্ছে? |
| 23 | `30_r15-speed-benchmark` | 300ft sports cafes, Mawa track runs | Editorial Dark (cobalt) | R15 নিয়ে ছুটছেন? আসল টপ-স্পিড আর পার্টস চেনেন? |
| 24 | `31_pulsar-mileage-benchmark` | Banglamotor, commuter stops, bus bays | Genesis (gold) | পালসার ভাইয়েরা, ১৫ বছর ধরে তো চালাচ্ছেন—মাইলেজ আর মেইনটেন্যান্স ঠিক আছে তো? |

## Files

- `batch_one/v1/*.svg` — vector source (render at 2000×3000 for A3/A2 print, 800×1200 for web), scales to any size. All text is **converted to outlines**,
  so these open correctly anywhere with no fonts installed — hand them to a press as-is.
- `lib.py`, `bn.py` — shared drawing and Bangla shaping, used by `posters_v3.py` and `social/social.py`. The v1 generator `posters.py` was deleted 2026-10-14.
- `fonts/` — Noto Sans Bengali (SIL OFL) and DejaVu Sans fonts.

## QR codes

Every poster carries a real, verified QR (error correction H, decodes at ~180px printed).
Each points to a distinct campaign so you can attribute installs by placement:

```
01 https://blankframe.tech/ThrottleIQ/install?c=signal_jam
02 https://blankframe.tech/ThrottleIQ/install?c=pump_maint
03 https://blankframe.tech/ThrottleIQ/install?c=garage_proof
04 https://blankframe.tech/ThrottleIQ/install?c=review_garage
05 https://blankframe.tech/ThrottleIQ/install?c=street_blackbox
06 https://blankframe.tech/ThrottleIQ/install?c=community_crew
07 https://blankframe.tech/ThrottleIQ/install?c=highway_telemetry
08 https://blankframe.tech/ThrottleIQ/install?c=privacy_shield
09 https://blankframe.tech/ThrottleIQ/install?c=resale_passport
10 https://blankframe.tech/ThrottleIQ/install?c=offline_deadzone
11 https://blankframe.tech/ThrottleIQ/install?c=fatigue_alert
12 https://blankframe.tech/ThrottleIQ/install?c=group_beacon
13 https://blankframe.tech/ThrottleIQ/install?c=family_safety
14 https://blankframe.tech/ThrottleIQ/install?c=bondhu_koi
15 https://blankframe.tech/ThrottleIQ/install?c=gentle_biker
16 https://blankframe.tech/ThrottleIQ/install?c=tour_fuel
17 https://blankframe.tech/ThrottleIQ/install?c=chapabaj_proof
18 https://blankframe.tech/ThrottleIQ/install?c=biker_reunion
19 https://blankframe.tech/ThrottleIQ/install?c=ai_camera
20 https://blankframe.tech/ThrottleIQ/install?c=cost_per_km
21 https://blankframe.tech/ThrottleIQ/install?c=gixxer_benchmark
22 https://blankframe.tech/ThrottleIQ/install?c=fzs_benchmark
23 https://blankframe.tech/ThrottleIQ/install?c=r15_benchmark
24 https://blankframe.tech/ThrottleIQ/install?c=pulsar_benchmark
```

The `/install` page automatically sniffs the device OS and presents:
- **iOS / App Store**: "Coming Soon" notification + early access email signup / TestFlight.
- **Android**: Two options:
  1. Direct APK download (pointed to latest GitHub release tag, with experimental warning).
  2. Google Play Store Beta (during the 14-day closed tester verification period, rider submits Play Store email which directs to WhatsApp with a prefilled invite request message; afterwards takes directly to Play Store).

## Regenerating

```bash
pip install qrcode cairosvg --break-system-packages
python3 posters_v3.py                  # v1's posters.py was deleted 2026-10-14
python3 -c "import cairosvg,glob,os
for f in glob.glob('batch_one/v1/*.svg'):
    n=os.path.basename(f)[:-4]
    cairosvg.svg2png(url=f,write_to=f'{n}@2x.png',output_width=2000,output_height=3000)"
```

The `47` in poster 01, the wear percentages in 02, and the service log in 03 are
placeholders shaped like real app output — swap them for actual aggregate numbers
before printing at volume.

## Note on type

Bangla is shaped with HarfBuzz (`bn.py`) and written out as vector outlines, so
conjuncts (চেঞ্জ, প্রমাণ, স্প্রকেট), matras and reph are all correct and can't be
broken by a viewer with no Bengali font. Bengali numerals are used where the number
is rider-facing (৪.০ / ৫ · ১২৮).

Bangla is **Noto Sans Bengali**; Latin is DejaVu, standing in for IBM Plex. To match
the app exactly, drop IBM Plex TTFs into `fonts/` and repoint the `SANS_*`/`COND_*`/
`MONO_*` paths at the top of `bn.py`, then re-run — the Bangla pairing and all the
auto-fitting still work.
