## V2 — one visual, one line, a QR code

`illus.py` + `posters_v2.py` generate a second, louder pass on the same 24
concepts: one big flat-icon illustration per poster (a line-art rider figure,
or a prop icon — traffic light, fuel pump, black box, shield, etc., all
defined in `illus.py`), 1-2 huge headline words, and a QR in the bottom-right
corner. No instrument panels, no stat rows — clickbait-y on purpose, meant to
read from across the street. Same skin-per-poster and campaign IDs as v1
(QR links get a `_v2` campaign suffix for separate attribution).

```bash
.venv/bin/python3 posters_v2.py          # writes svg/v2/*.svg
.venv/bin/python3 -c "
import cairosvg, glob, os
for f in glob.glob('svg/v2/*.svg'):
    n = os.path.basename(f)[:-4]
    cairosvg.svg2png(url=f, write_to=f'print/v2/{n}@2x.png', output_width=2000, output_height=3000)
    cairosvg.svg2png(url=f, write_to=f'web/v2/{n}.png', output_width=800, output_height=1200)
"
```

Output lives in `print/v2/`, `web/v2/`, `svg/v2/` — the v1 files above are
untouched.

---

# ThrottleIQ Street Posters — Dhaka

Twelve placement-specific posters. Each one borrows a different skin from the app's
own theme system (`app/lib/core/theme/app_theme_style.dart`), so the poster a rider
scans looks like the app they land in.

Headlines and rider-facing copy are in **Bangla**; instrument-panel labels, service-log
rows and technical terms stay English, matching how the app itself reads.

| # | Poster | Where it goes | Skin | The hook |
|---|--------|---------------|------|----------|
| 01 | `01-jam-counter-signal` | Traffic signals, foot-over-bridge pillars | Carbon Mono (lime) | আবার দাঁড়িয়ে আছেন। — 47 minutes of jam, counted |
| 02 | `02-pump-maintenance` | Fuel pumps, beside the nozzle | Genesis (gold) | ট্যাংক ফুল। চেইন শুকনা। — Tk 400 now vs Tk 12,000 later |
| 03 | `03-garage-proof` | Garage counters, workshop walls | Trail Social (orange) | "সব চেঞ্জ করেছি" — প্রমাণ দিন। |
| 04 | `04-rate-it-review` | Garages + pumps (review driver) | Retro (brutalist B/W) | এই গ্যারেজ কেমন? — rate it in 30 seconds |
| 05 | `05-black-box-safety` | Street level, signal islands | Analyst Blue (cyan) | আপনি পড়ে গেছেন। — the 32 seconds after |
| 06 | `06-crew-community` | Tea stalls, bike meets, parts markets | Nocturne (lavender) | একলা চালেন না। |
| 07 | `07-highway-telemetry` | Purbachal 300ft, Expressway toll plazas | Editorial Dark (cobalt) | চা স্টলে ১৩০। আসল টান কত ছিল? |
| 08 | `08-privacy-shield` | Corporate parking, apartment basements | Calming Dark (sage) | রাইড ফেসবুকে দিলেন। বাসার গলিটাও সবাই চিনে গেল? |
| 09 | `09-resale-passport` | Banglamotor, Bijoy Sarani used shops | Editorial Light (paper) | মিটার ঘুরানো যায়। আসল হিস্ট্রি ঘুরাবেন কেমনে? |
| 10 | `10-offline-deadzone` | Mountain trails, tour routes, dead zones | Carbon Mono (lime) | টাওয়ার নাই? ThrottleIQ-র নেট লাগে না। |
| 11 | `11-fatigue-alert` | Highway dhabas, Comilla/Mawa rest stops | Trail Social (orange) | টানা দেড় ঘণ্টা সিটে। রিফ্লেক্স কিন্তু স্লো হয়ে গেছে। |
| 12 | `12-group-beacon` | Friday 6 AM meet points, club hangouts | Nocturne (indigo) | “দোস্ত তুই কই?” — আর কত ফোন করবেন? |
| 13 | `13-family-safety` | Residential gates, university parking | Calming Dark (sage) | প্রিয়জন কি বাইকার বলে চিন্তিত? নো টেনশন। |
| 14 | `14-lost-biker-singing` | Highway exits, flyovers, tea stalls | Carbon Mono (lime) | “বন্ধু তুমি কই, কই, কই??” — ফোনে গান না গেয়ে, ড্যাশবোর্ডে দেখুন। |
| 15 | `15-gentle-biker-proof` | University campus, coaching, home stands | Editorial Dark (cobalt) | বাসায় ভাবে আপনি বাইক নিয়ে উড়েন? অথচ আপনি তো ভদ্র রাইডার! |
| 16 | `16-touring-fuel-purity` | Highway toll plazas, pump exits | Genesis (gold) | ট্যুরে হাইওয়েতে তেলের টেনশন? কোন পাম্পের তেল খাঁটি? |
| 17 | `17-chapabaj-telemetry` | 300ft tea stalls, roadside benches | Trail Social (orange) | “তারপর মামা, ১৫০ স্পিড থেকে ২ হাতে ব্রেক মাইরা ০ নামাইসি!” — চাপাবাজ দোস্তরে প্রমাণ দেখাইতে বলেন। |
| 18 | `18-old-biker-reunion` | Biker cafes, vintage meets, lake spots | Nocturne (indigo) | দীর্ঘদিন পুরনো রাইডার বন্ধুর খোঁজ নাই? ThrottleIQ-তে আসেন, একসাথে চিল করি! |
| 19 | `19-ai-camera-radar` | Flyover ramps, expressway speed traps | Carbon Mono (lime) | AI ক্যামেরা নিয়ে ভয়? আর নয়! ThrottleIQ আছে সাথে। |
| 20 | `20-per-km-cost` | Ride-share stands, delivery parking | Editorial Light (paper) | “১০০ টাকা ভাড়া, ৩০ টাকার তেল—৭০ টাকা লাভ?” ভুল হিসাব! মোবিল আর লুবের হিসাব কে করবে? |
| 21 | `21-gixxer-benchmark` | Suzuki service centers, Bangshal | Analyst Blue (cyan) | এই যে ভাই, বাকি Gixxer মালিকরা কত মাইলেজ পায় জানেন? |
| 22 | `22-fzs-benchmark` | Yamaha hubs, Tejgaon, Mirpur 10 | Trail Social (orange) | FZ-S ভাইয়েরা, জ্যামে আপনার বাইক আসলে কত মাইলেজ দিচ্ছে? |
| 23 | `23-r15-benchmark` | 300ft sports cafes, Mawa track runs | Editorial Dark (cobalt) | R15 নিয়ে ছুটছেন? আসল টপ-স্পিড আর পার্টস চেনেন? |
| 24 | `24-pulsar-benchmark` | Banglamotor, commuter stops, bus bays | Genesis (gold) | পালসার ভাইয়েরা, ১৫ বছর ধরে তো চালাচ্ছেন—মাইলেজ আর মেইনটেন্যান্স ঠিক আছে তো? |

## Files

- `print/*@2x.png` — 2000×3000, use for A3/A2 print (≈170 DPI at A3, ≈120 at A2)
- `web/*.png` — 800×1200, for social and the site
- `svg/*.svg` — vector source, scales to any size. All text is **converted to outlines**,
  so these open correctly anywhere with no fonts installed — hand them to a press as-is.
- `posters.py`, `lib.py`, `bn.py` — the generator. Edit copy/numbers and re-run.
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
python3 posters.py                     # writes out/*.svg
python3 -c "import cairosvg,glob,os
for f in glob.glob('out/*.svg'):
    n=os.path.basename(f)[:-4]
    cairosvg.svg2png(url=f,write_to=f'print/{n}@2x.png',output_width=2000,output_height=3000)"
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
