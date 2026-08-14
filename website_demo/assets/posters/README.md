# ThrottleIQ Street Posters — Dhaka

Six placement-specific posters. Each one borrows a different skin from the app's
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

## Files

- `print/*@2x.png` — 2000×3000, use for A3/A2 print (≈170 DPI at A3, ≈120 at A2)
- `web/*.png` — 800×1200, for social and the site
- `svg/*.svg` — vector source, scales to any size. All text is **converted to outlines**,
  so these open correctly anywhere with no fonts installed — hand them to a press as-is.
- `posters.py`, `lib.py`, `bn.py` — the generator. Edit copy/numbers and re-run.
- `fonts/` — Noto Sans Bengali (SIL OFL), the weights the generator uses.

## QR codes

Every poster carries a real, verified QR (error correction H, decodes at ~180px printed).
Each points to a distinct campaign so you can attribute installs by placement:

```
01 https://throttleiq.app/get?c=signal_jam
02 https://throttleiq.app/get?c=pump_maint
03 https://throttleiq.app/get?c=garage_proof
04 https://throttleiq.app/get?c=review_garage
05 https://throttleiq.app/get?c=street_blackbox
06 https://throttleiq.app/get?c=community_crew
```

Point `/get` at a redirect that sniffs UA and sends iOS → App Store, Android → Play,
preserving `?c=` into the store referrer.

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
