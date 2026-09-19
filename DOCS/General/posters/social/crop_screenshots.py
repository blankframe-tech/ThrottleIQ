# -*- coding: utf-8 -*-
"""Crops 6 app-screen cards out of the two UI-sheet demo images
(`../../website_demo/assets/ui/{carbon-mono,editorial-bw}.png`, each a
1000x6000 2-column grid of 7 stacked screen cards) into standalone PNGs
for the social ad creatives.

The crop boxes below were measured once via background-diff row/column
projection: for each column x-range, find rows whose pixel difference
from the corner background color exceeds a threshold (20 for the light
Editorial sheet's paper background; needs to drop to ~20 for Carbon
Mono too once restricted to a single column, since dark-on-dark
contrast is low). Columns landed at x:(64,384) and x:(424,744) in both
sheets. Re-run that projection if the source sheets are ever
re-exported at different card positions — see the README's
"Regenerating after a UI change" section.

Three crops (`commuter-maintenance`, `commuter-ridelog`,
`enthusiast-journey`) have real content ending well before the source
card's full height — the sheet bakes in trailing blank space so every
card in a row matches the row's tallest card. Those three are trimmed
to their real content height (found via the same diff projection,
looking for the single largest contiguous non-content gap) so the ad
creative doesn't carry dead space. The other three (`enthusiast-
telemetry`, `family-parent`, `family-spouse`) keep their full crop —
their internal whitespace is deliberate breathing room before a
bottom-anchored CTA, not dead trailing space.

`family-parent`/`family-spouse` additionally get two bands redacted
after crop (see `REDACT` below, `issues_fixed.md` §72.1): the Safety
Check-In screen's own on-screen copy — "Looked like a hard stop. We'll
gently check in with your emergency contacts if we don't hear from
you" and a "Notify contacts now" link — implies live crash-contact
delivery that doesn't exist (`crash-notifications.ts` is mock
end-to-end, blocked on Blaze billing, same gap as §69.O3/§33). The
surrounding ad copy in `social.py` is already opt-in-only; this keeps
the screenshot itself from contradicting it. Each band is filled with
the locally-sampled background color (not a fixed color) so it blends
into either skin without a visible seam. If the source sheets are ever
re-exported, re-measure these bands the same way (crop a preview slice
around the paragraph/link and inspect it) — do not skip this step when
re-running this script, or the overclaim comes back.

Second pass (2026-09-19, for the wider `social-07..26` set): each sheet
has 7 stacked screen-cards per column and only some were cropped above.
Measured the same way (row-wise background-diff against each sheet's
`bg`, threshold 20) to find every remaining card's exact (y0, y1), then
padded ±10px to match the original six's convention:

- `start-ride-{carbon,editorial}` — card 01 (home/"Start Ride"), both
  skins, previously uncropped. The Editorial sheet's row-1 cards
  (`start-ride-editorial`, `on-the-road-editorial`) both need a tighter
  y1 (1030, not the naive core+10 of 1075) than the same detection
  method gives elsewhere: the background-diff mask stays "non-background"
  past the card's real rounded-bottom border (~1015) because of the
  card's own drop shadow, so a naive core+10 pad reaches far enough to
  pick up the next row's faint gray section label ("04 · RIDE COMPLETE"
  / similar) sitting at ~1048-1060. Checked visually (crop a wide band
  and inspect) rather than trusting the diff numbers alone — every other
  new crop below was spot-checked at its bottom 100px this same way and
  came back clean.
- `on-the-road-editorial` — card 02 in the Editorial skin (Carbon
  Mono's version was already `enthusiast-telemetry`).
- `garage-{carbon,editorial}` — card 06 ("Your Garage": bike list +
  service-due bar), both skins, previously uncropped.
- `journey-carbon` — card 05 in Carbon Mono (Editorial's version was
  already `enthusiast-journey`); kept full height (no trim) since the
  642 km / 31-rides total boxes sit right after the badge row with no
  real gap to cut at.
- `maintenance-carbon` — card 07 in Carbon Mono (Editorial's version
  was already `commuter-maintenance`); trimmed to the same ~73% content
  ratio as the Editorial crop so both stop at the same "Chain lube —
  OVERDUE" row.
- `ridecomplete-hero-editorial` — card 04 in Editorial (stats/badge/
  speed+elevation charts/Splits table — same content depth as Carbon
  Mono's `commuter-ridelog`, just the other skin), trimmed the same way
  to drop the card's own trailing Save Ride/Share buttons. (A separate
  crop of just those two buttons was tried and dropped — mostly empty
  card, not worth a creative on its own.)
"""
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, "..", "..", "website_demo", "assets", "ui")
OUT = os.path.join(HERE, "screenshots")

CORNER_RADIUS = 30

# (sheet, (x0, y0, x1, y1)) — before trimming
CROPS = {
    "commuter-maintenance": ("editorial-bw.png", (54, 2986, 394, 4231)),
    "commuter-ridelog":     ("carbon-mono.png",  (414, 1002, 754, 2102)),
    "enthusiast-telemetry": ("carbon-mono.png",  (414, 241, 754, 953)),
    "enthusiast-journey":   ("editorial-bw.png", (54, 2223, 394, 2940)),
    "family-parent":        ("carbon-mono.png",  (54, 1002, 394, 1714)),
    "family-spouse":        ("editorial-bw.png", (54, 1072, 394, 1789)),
    # second pass — see module docstring
    "start-ride-carbon":            ("carbon-mono.png",  (54, 241, 394, 953)),
    "start-ride-editorial":         ("editorial-bw.png", (54, 308, 394, 1030)),
    "on-the-road-editorial":        ("editorial-bw.png", (414, 308, 754, 1030)),
    "garage-carbon":                ("carbon-mono.png",  (414, 2151, 754, 2863)),
    "garage-editorial":             ("editorial-bw.png", (414, 2219, 754, 2984)),
    "journey-carbon":               ("carbon-mono.png",  (54, 2151, 394, 2863)),
    "maintenance-carbon":           ("carbon-mono.png",  (54, 2912, 394, 4152)),
    "ridecomplete-hero-editorial":  ("editorial-bw.png", (414, 1068, 754, 2226)),
}

# post-crop trim to the real content height (drops baked-in trailing
# blank space; see module docstring)
TRIM_HEIGHT = {
    "commuter-maintenance": 910,
    "commuter-ridelog": 715,
    "enthusiast-journey": 375,
    "maintenance-carbon": 905,
    "ridecomplete-hero-editorial": 740,
}

# post-crop redaction bands (see module docstring + issues_fixed.md §72.1):
# [(y0, y1), ...] in the *cropped* image's own coordinates, filled with the
# locally-sampled background color.
REDACT = {
    "family-parent": [(196, 256), (647, 666)],
    "family-spouse": [(217, 275), (644, 660)],
}


def rounded_alpha(im, radius):
    im = im.convert("RGBA")
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1],
                                            radius=radius, fill=255)
    im.putalpha(mask)
    return im


def redact_bands(im, bands):
    """Fill each (y0, y1) band with the locally-sampled background color
    (sampled just above the band, center columns) so the patch blends in
    on either a dark or light skin without a visible seam."""
    arr = np.array(im.convert("RGB"))
    im = im.convert("RGBA")
    d = ImageDraw.Draw(im)
    for y0, y1 in bands:
        row = arr[max(0, y0 - 8):y0 - 3, 30:im.width - 30, :]
        bg = tuple(int(v) for v in np.median(row, axis=(0, 1)))
        d.rectangle([14, y0, im.width - 14, y1], fill=bg + (255,))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets = {}
    for name, (sheet_name, box) in CROPS.items():
        if sheet_name not in sheets:
            sheets[sheet_name] = Image.open(os.path.join(UI, sheet_name)).convert("RGB")
        sheet = sheets[sheet_name]
        crop = sheet.crop(box)
        if name in TRIM_HEIGHT:
            crop = crop.crop((0, 0, crop.width, TRIM_HEIGHT[name]))
        if name in REDACT:
            crop = redact_bands(crop, REDACT[name])
        crop = rounded_alpha(crop, CORNER_RADIUS)
        path = os.path.join(OUT, f"{name}.png")
        crop.save(path)
        print("wrote", path, crop.size)


if __name__ == "__main__":
    main()
