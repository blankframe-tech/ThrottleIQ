#!/usr/bin/env python3
"""Turns raw UI-tour screenshots into the docs set: optimized JPEGs per
appearance combo plus one walkthrough PDF per combo.

usage: build_docs.py <raw-dir> <docs-dir> [combo-dir-name ...]
       build_docs.py --readme <docs-dir>

<raw-dir>   output of run_tour.sh: <NN_color_vibe_brightness>/NNN__section__name.png
<docs-dir>  e.g. DOCS/General/screenshots_ui — gets <combo>/*.jpg, pdfs/*.pdf, README.md

Needs Pillow and reportlab (pip install pillow reportlab).
"""
import datetime
import glob
import io
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

AVENIR = '/System/Library/Fonts/Avenir Next.ttc'
for name, idx in [('AvenirBold', 0), ('AvenirDemi', 2), ('AvenirMedium', 5), ('AvenirRegular', 7)]:
    try:
        pdfmetrics.registerFont(TTFont(name, AVENIR, subfontIndex=idx))
    except Exception:  # not on macOS — fall back to the core fonts
        pass
F_BOLD = 'AvenirBold' if 'AvenirBold' in pdfmetrics.getRegisteredFontNames() else 'Helvetica-Bold'
F_DEMI = 'AvenirDemi' if 'AvenirDemi' in pdfmetrics.getRegisteredFontNames() else 'Helvetica-Bold'
F_MED = 'AvenirMedium' if 'AvenirMedium' in pdfmetrics.getRegisteredFontNames() else 'Helvetica'
F_REG = 'AvenirRegular' if 'AvenirRegular' in pdfmetrics.getRegisteredFontNames() else 'Helvetica'

COLOR_NAMES = {
    'carbonMono': 'Carbon Mono', 'editorial': 'Editorial', 'nocturne': 'Nocturne',
    'trailSocial': 'Trail Social', 'calming': 'Calming', 'retro': 'Retro', 'analystBlue': 'Analyst Blue',
}

# The story the walkthrough tells, in order: tour section slug -> chapter.
CHAPTERS = [
    ('Welcome & sign in', 'Create an account or sign back in.', ['welcome']),
    ('Feature tour', 'The seven-slide guided tour every new rider sees.', ['feature-tour']),
    ('Record & live ride', 'The ride dashboard, bike switcher and the live cockpit while recording.',
     ['record', 'live-ride']),
    ('Social', 'Ride feed, forums, rider profiles, direct messages and notifications.',
     ['social', 'shared-ride', 'rider-profile', 'chats', 'forums', 'notifications']),
    ('Places & routes', 'Rider points of interest around you, place details, adding a place and routes.',
     ['places', 'place-detail', 'add-place', 'routes']),
    ('Rides & stats', 'Your riding history, badges, a full ride breakdown and sharing a ride.',
     ['rides-stats', 'ride-summary']),
    ('Garage & maintenance', 'Your bikes, bike details and the maintenance tracker.',
     ['profile-garage', 'bike', 'maintenance']),
    ('Profile & settings', 'Your public profile, editing it, appearance and safety settings.',
     ['profile', 'settings']),
]

PAGE_W, PAGE_H = 1280, 720  # 16:9, points
MARGIN = 48
PER_PAGE = 4


def lum(rgb):
    r, g, b = [c / 255 for c in rgb[:3]]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hexc(rgb):
    return '#%02x%02x%02x' % tuple(rgb[:3])


def caption_of(fname):
    """'012__record__record-dashboard-cont-2.png' -> ('Record dashboard', 2)."""
    base = os.path.splitext(fname)[0].split('__')[-1]
    cont = None
    m = re.search(r'-cont-(\d+)$', base)
    if m:
        cont = int(m.group(1))
        base = base[:m.start()]
    text = base.replace('-', ' ').strip()
    text = text[:1].upper() + text[1:]
    text = re.sub(r'\bqr\b', 'QR', text, flags=re.I)
    return text, cont


def section_of(fname):
    parts = os.path.splitext(fname)[0].split('__')
    return parts[1] if len(parts) >= 3 else ''


class Theme:
    """Page colors sampled from the combo's own sign-in screen, so each PDF
    is dressed in the palette it documents."""

    def __init__(self, shots):
        first = Image.open(shots[0]).convert('RGB')
        w, h = first.size
        self.bg = first.getpixel((int(w * 0.03), int(h * 0.30)))
        # The primary "Sign In" button sits mid-screen on the sign-in shot.
        self.accent = first.getpixel((w // 2, int(h * 0.463)))
        if abs(lum(self.accent) - lum(self.bg)) < 0.08:
            self.accent = (90, 110, 255) if lum(self.bg) < 0.5 else (40, 60, 200)
        self.dark = lum(self.bg) < 0.5
        self.ink = (242, 242, 245) if self.dark else (24, 24, 28)
        self.muted = mix(self.bg, self.ink, 0.55)
        self.rule = mix(self.bg, self.ink, 0.14)
        self.card = mix(self.bg, self.ink, 0.05)


def load_shot(path):
    """Opens a screenshot and paints out the Dynamic Island.

    The simulator only draws the island in some captures (whenever a system
    activity such as location use is live), so left alone it flickers in and
    out between otherwise identical screens. Each covered row is refilled
    with that row's own status-bar color from just left of the pill.
    """
    im = Image.open(path).convert('RGB')
    w, h = im.size
    px = im.load()
    cy = int(h * 0.0275)
    cx = w // 2

    def black(p):
        return sum(p) < 24

    if not black(px[cx, cy]):
        return im
    x0 = cx
    while x0 > 0 and black(px[x0 - 1, cy]):
        x0 -= 1
    x1 = cx
    while x1 < w - 1 and black(px[x1 + 1, cy]):
        x1 += 1
    y0 = cy
    while y0 > 0 and black(px[cx, y0 - 1]):
        y0 -= 1
    y1 = cy
    while y1 < h - 1 and black(px[cx, y1 + 1]):
        y1 += 1
    pill_w, pill_h = x1 - x0, y1 - y0
    if not (0.25 * w < pill_w < 0.45 * w and 0.02 * h < pill_h < 0.05 * h):
        return im  # not the island (e.g. a black app background)
    if black(px[max(0, x0 - 20), cy]):
        return im  # island is invisible on this background anyway
    for y in range(max(0, y0 - 6), min(h, y1 + 7)):
        fill = px[max(0, x0 - 20), y]
        for x in range(max(0, x0 - 12), min(w, x1 + 13)):
            px[x, y] = fill
    return im


def phone_image(path, theme, target_h):
    """Screenshot with device-like rounded corners and a soft shadow,
    flattened onto the page color (so the PDF can use compact JPEGs)."""
    im = load_shot(path)
    scale = target_h / im.height
    im = im.resize((int(im.width * scale), target_h), Image.LANCZOS)
    w, h = im.size
    radius = int(w * 0.105)
    pad = int(w * 0.06)
    canvas_im = Image.new('RGB', (w + pad * 2, h + pad * 2), theme.bg)
    shadow = Image.new('L', canvas_im.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad + int(pad * 0.35), pad + w, pad + h + int(pad * 0.35)], radius, fill=110 if theme.dark else 70)
    shadow = shadow.filter(ImageFilter.GaussianBlur(pad * 0.45))
    shade = Image.new('RGB', canvas_im.size, (0, 0, 0))
    canvas_im = Image.composite(shade, canvas_im, shadow)
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius, fill=255)
    canvas_im.paste(im, (pad, pad), mask)
    # Hairline bezel so light screens don't dissolve into a light page.
    ImageDraw.Draw(canvas_im).rounded_rectangle(
        [pad - 1, pad - 1, pad + w, pad + h], radius + 1, outline=theme.rule, width=2)
    buf = io.BytesIO()
    canvas_im.save(buf, 'JPEG', quality=86, optimize=True)
    buf.seek(0)
    return ImageReader(buf), canvas_im.size, pad


def draw_phone(c, path, theme, x, y_top, box_h, cache):
    key = (path, box_h)
    if key not in cache:
        cache[key] = phone_image(path, theme, int(box_h * 2.2))
    reader, (pw, ph), pad = cache[key]
    s = box_h / (ph - 2 * pad)
    dw, dh = pw * s, ph * s
    c.drawImage(reader, x - pad * s, y_top - dh + pad * s, dw, dh)
    return (pw - 2 * pad) * s


def build_pdf(combo_dir, shots, out_pdf, meta):
    color, vibe, bright = meta
    theme = Theme(shots)
    title = f'{COLOR_NAMES.get(color, color)} · {vibe.capitalize()} · {bright.capitalize()}'
    c = canvas.Canvas(out_pdf, pagesize=(PAGE_W, PAGE_H))
    c.setTitle(f'ThrottleIQ UI walkthrough — {title}')
    c.setAuthor('ThrottleIQ')
    c.setSubject('Every screen of the app in one appearance combination')
    cache = {}
    page_no = [0]

    def bg():
        c.setFillColor(hexc(theme.bg))
        c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)

    def footer():
        page_no[0] += 1
        c.setFont(F_REG, 10)
        c.setFillColor(hexc(theme.muted))
        c.drawString(MARGIN, 26, f'ThrottleIQ — UI walkthrough  ·  {title}')
        c.drawRightString(PAGE_W - MARGIN, 26, str(page_no[0]))

    # Group shots into chapters, keeping capture order inside each.
    by_section = {}
    for p in shots:
        by_section.setdefault(section_of(os.path.basename(p)), []).append(p)
    chapters = []
    used = set()
    for name, blurb, sections in CHAPTERS:
        items = [p for s in sections for p in by_section.get(s, [])]
        items.sort(key=lambda p: os.path.basename(p))
        used.update(sections)
        if items:
            chapters.append((name, blurb, items))
    leftover = sorted(p for s, ps in by_section.items() if s not in used for p in ps)
    if leftover:
        chapters.append(('More screens', 'Other screens captured during the tour.', leftover))

    # ── Cover ──
    bg()
    c.setFillColor(hexc(theme.accent))
    c.rect(MARGIN, PAGE_H - MARGIN - 6, 56, 6, fill=1, stroke=0)
    c.setFillColor(hexc(theme.ink))
    c.setFont(F_BOLD, 64)
    c.drawString(MARGIN, PAGE_H - 150, 'ThrottleIQ')
    c.setFont(F_MED, 26)
    c.setFillColor(hexc(theme.muted))
    c.drawString(MARGIN, PAGE_H - 192, 'UI walkthrough')
    chips = [('Color', COLOR_NAMES.get(color, color)), ('Shape', vibe.capitalize()), ('Mode', bright.capitalize())]
    y = PAGE_H - 290
    for label, value in chips:
        c.setFont(F_REG, 13)
        c.setFillColor(hexc(theme.muted))
        c.drawString(MARGIN, y + 30, label.upper())
        c.setFont(F_DEMI, 30)
        c.setFillColor(hexc(theme.ink))
        c.drawString(MARGIN, y, value)
        y -= 78
    c.setFont(F_REG, 13)
    c.setFillColor(hexc(theme.muted))
    for i, line in enumerate([
        f'{len(shots)} screenshots in {len(chapters)} chapters',
        'Captured on an iPhone 17 Pro simulator',
        f'Generated {datetime.date.today():%d %B %Y} by the automated UI tour',
    ]):
        c.drawString(MARGIN, 112 - i * 20, line)
    heroes = []
    for want in ('record-dashboard', 'social-feed', 'stats', 'maintenance'):
        for p in shots:
            if os.path.basename(p).endswith(f'__{want}.png'):
                heroes.append(p)
                break
    heroes = (heroes + shots)[:3]
    ph = 520
    x = PAGE_W - MARGIN
    for p in reversed(heroes):
        pw = ph * 1206 / 2622
        x -= pw
        draw_phone(c, p, theme, x, PAGE_H / 2 + ph / 2 - 10, ph, cache)
        x -= 26
    footer()
    c.showPage()

    # ── Pages ── (contents page first, drawn after we know page numbers)
    plan = []  # (chapter_index, items)
    for ci, (_, _, items) in enumerate(chapters):
        for i in range(0, len(items), PER_PAGE):
            plan.append((ci, items[i:i + PER_PAGE], i == 0))
    first_page_of = {}
    for pi, (ci, _, first) in enumerate(plan):
        if first:
            first_page_of[ci] = pi + 3  # cover=1, contents=2

    bg()
    c.setFont(F_BOLD, 40)
    c.setFillColor(hexc(theme.ink))
    c.drawString(MARGIN, PAGE_H - 110, 'Contents')
    y = PAGE_H - 175
    for ci, (name, blurb, items) in enumerate(chapters):
        c.setFont(F_DEMI, 20)
        c.setFillColor(hexc(theme.accent))
        c.drawString(MARGIN, y, f'{ci + 1:02d}')
        c.setFillColor(hexc(theme.ink))
        c.drawString(MARGIN + 50, y, name)
        c.setFont(F_REG, 12.5)
        c.setFillColor(hexc(theme.muted))
        c.drawString(MARGIN + 50, y - 19, f'{blurb}  ({len(items)} screens)')
        c.setFont(F_MED, 16)
        c.setFillColor(hexc(theme.ink))
        c.drawRightString(PAGE_W - MARGIN, y, str(first_page_of[ci]))
        c.setStrokeColor(hexc(theme.rule))
        c.setLineWidth(1)
        c.line(MARGIN + 50, y - 32, PAGE_W - MARGIN, y - 32)
        y -= 58
    footer()
    c.showPage()

    for ci, items, first in plan:
        name, blurb, all_items = chapters[ci]
        bg()
        c.setFont(F_DEMI, 13)
        c.setFillColor(hexc(theme.accent))
        c.drawString(MARGIN, PAGE_H - 52, f'{ci + 1:02d}')
        c.setFont(F_BOLD, 26)
        c.setFillColor(hexc(theme.ink))
        c.drawString(MARGIN + 34, PAGE_H - 56, name + ('' if first else '  (continued)'))
        if first:
            c.setFont(F_REG, 13)
            c.setFillColor(hexc(theme.muted))
            c.drawString(MARGIN + 34, PAGE_H - 78, blurb)
        c.setFont(F_REG, 11)
        c.setFillColor(hexc(theme.muted))
        c.drawRightString(PAGE_W - MARGIN, PAGE_H - 52, title)

        box_h = 492
        box_w = box_h * 1206 / 2622
        gap = (PAGE_W - 2 * MARGIN - PER_PAGE * box_w) / (PER_PAGE - 1)
        top = PAGE_H - 108
        for i, p in enumerate(items):
            x = MARGIN + i * (box_w + gap)
            draw_phone(c, p, theme, x, top, box_h, cache)
            cap, cont = caption_of(os.path.basename(p))
            c.setFont(F_DEMI, 13)
            c.setFillColor(hexc(theme.ink))
            c.drawCentredString(x + box_w / 2, top - box_h - 30, cap)
            if cont:
                c.setFont(F_REG, 11)
                c.setFillColor(hexc(theme.muted))
                c.drawCentredString(x + box_w / 2, top - box_h - 46, f'scrolled further ({cont})')
        footer()
        c.showPage()
    c.save()
    return len(chapters), page_no[0]


def readme_only(docs):
    """Rebuilds README.md from what is already in <docs-dir> (used after
    building combos in parallel, one process per combo)."""
    rows = []
    for combo_path in sorted(glob.glob(os.path.join(docs, '[0-9][0-9]_*'))):
        combo = os.path.basename(combo_path)
        _, color, vibe, bright = combo.split('_')
        pdfs = glob.glob(os.path.join(docs, 'pdfs', f'{combo[:2]}_*.pdf'))
        if not pdfs:
            continue
        with open(pdfs[0], 'rb') as f:
            pages = len(re.findall(rb'/Type\s*/Page[^s]', f.read()))
        n = len(glob.glob(os.path.join(combo_path, '*.jpg')))
        rows.append((combo, color, vibe, bright, n, os.path.basename(pdfs[0]), pages))
    write_readme(docs, rows)


def main():
    if sys.argv[1] == '--readme':
        return readme_only(sys.argv[2])
    raw, docs = sys.argv[1], sys.argv[2]
    only = set(sys.argv[3:])
    os.makedirs(os.path.join(docs, 'pdfs'), exist_ok=True)
    rows = []
    for combo_path in sorted(glob.glob(os.path.join(raw, '[0-9][0-9]_*'))):
        combo = os.path.basename(combo_path)
        if only and combo not in only:
            continue
        shots = sorted(glob.glob(os.path.join(combo_path, '*.png')))
        if not shots:
            continue
        _, color, vibe, bright = combo.split('_')
        # Optimized full-resolution JPEGs for the docs folder.
        out_dir = os.path.join(docs, combo)
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, '*.jpg')):
            os.remove(old)
        for p in shots:
            load_shot(p).save(
                os.path.join(out_dir, os.path.basename(p)[:-4] + '.jpg'), 'JPEG', quality=88, optimize=True)
        pretty = f'{COLOR_NAMES.get(color, color).replace(" ", "")}_{vibe.capitalize()}_{bright.capitalize()}'
        pdf = os.path.join(docs, 'pdfs', f'{combo[:2]}_ThrottleIQ_UI_{pretty}.pdf')
        n_ch, n_pages = build_pdf(combo, shots, pdf, (color, vibe, bright))
        size = os.path.getsize(pdf) / 1e6
        print(f'{combo}: {len(shots)} shots -> {os.path.basename(pdf)} ({n_pages} pages, {size:.1f} MB)', flush=True)
        rows.append((combo, color, vibe, bright, len(shots), os.path.basename(pdf), n_pages))
    if not only:
        write_readme(docs, rows)
    return rows


def write_readme(docs, rows):
    lines = [
        '# ThrottleIQ UI screenshots',
        '',
        'Every screen of the app, captured automatically in all **28 appearance combinations**: '
        '7 color modes x 2 shapes (Curvy / Boxy) x 2 brightness modes (Light / Dark).',
        '',
        'Each combination walks through the app in the same order, as one demo flow: sign in, '
        'the feature tour, recording a ride, social, places & routes, rides & stats, the garage '
        '& maintenance, and profile & settings, including the sheets and dialogs those screens open.',
        '',
        '- `pdfs/` has one walkthrough PDF per combination (cover, contents, then the screens chapter by chapter).',
        '- Each `NN_color_shape_brightness/` folder has the full-resolution screenshots, named '
        '`NNN__section__screen.jpg` in capture order.',
        '',
        f'Captured {datetime.date.today():%d %B %Y} on an iPhone 17 Pro simulator (iOS 26.5), signed in as the '
        'test rider `rider@example.com`.',
        '',
        '| # | Color | Shape | Brightness | Screens | PDF | Screenshots |',
        '|---|---|---|---|---|---|---|',
    ]
    for combo, color, vibe, bright, n, pdf, pages in rows:
        lines.append(f'| {combo[:2]} | {COLOR_NAMES.get(color, color)} | {vibe.capitalize()} | {bright.capitalize()} '
                     f'| {n} | [{pdf}](pdfs/{pdf}) ({pages} pages) | [{combo}/]({combo}/) |')
    lines += [
        '',
        '## Regenerating',
        '',
        'The tour is automated. From `app/`:',
        '',
        '```bash',
        '# 1. Capture: builds the tour app, installs it on the simulator and walks every combination.',
        '#    Optional 3rd argument: comma-separated combo ids, e.g. calming_curvy_light,retro_boxy_dark',
        'scripts/ui_tour/run_tour.sh <simulator-udid> /tmp/ui_tour_raw',
        '',
        '# 2. Build this folder (JPEGs, PDFs, this README). Needs: pip install pillow reportlab',
        'python3 scripts/ui_tour/build_docs.py /tmp/ui_tour_raw ../DOCS/General/screenshots_ui',
        '```',
        '',
        '- The tour itself: `app/integration_test/ui_tour_test.dart`',
        '- The runner and the host-side screenshotter: `app/scripts/ui_tour/`',
        '',
    ]
    with open(os.path.join(docs, 'README.md'), 'w') as f:
        f.write('\n'.join(lines))


if __name__ == '__main__':
    main()
