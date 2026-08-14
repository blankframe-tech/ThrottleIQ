# -*- coding: utf-8 -*-
"""Shared drawing helpers for ThrottleIQ street posters."""
import qrcode
import bn as _bn

W, H = 1000, 1500

# ---- Skins (from app/lib/core/theme/app_theme_style.dart) ----
SKINS = {
 "carbonMono": dict(bg="#0D0D0D", surf="#161616", line="#393939", var="#262626",
    pri="#C8FF3D", priD="#9FCC1F", sec="#D633FF", att="#FF7A45",
    t1="#F4F4F4", t2="#A8A8A8", t3="#6F6F6F", danger="#FA4D56", dark=True),
 "genesis": dict(bg="#080811", surf="#14121E", line="#313142", var="#1D1E29",
    pri="#EAB532", priD="#B68611", sec="#9260DA", att="#F68F5F",
    t1="#F0F1F9", t2="#ACADB8", t3="#787986", danger="#ED5350", dark=True),
 "trailSocial": dict(bg="#101418", surf="#1C2024", line="#2F3338", var="#25292E",
    pri="#F5642B", priD="#BF4213", sec="#53A3F2", att="#EB881F",
    t1="#F3F5F8", t2="#A0A5AB", t3="#6D7277", danger="#E64343", dark=True),
 "analystBlue": dict(bg="#0B1C2C", surf="#172534", line="#2F3C4A", var="#222F3C",
    pri="#25C0E6", priD="#008FBA", sec="#F3906D", att="#F3906D",
    t1="#F3F5F8", t2="#9BA6B1", t3="#69737D", danger="#F14D4C", dark=True),
 "nocturne": dict(bg="#0B0C16", surf="#14151F", line="#2C2D38", var="#1C1E2D",
    pri="#A0A6F3", priD="#7377C6", sec="#56B6BB", att="#E6857E",
    t1="#EDEEF5", t2="#A2A4AE", t3="#6F717D", danger="#E85854", dark=True),
 "retro": dict(bg="#FAFAF7", surf="#FFFFFF", line="#0A0A0A", var="#EAEAE5",
    pri="#0A0A0A", priD="#000000", sec="#4A4A45", att="#1F1F1C",
    t1="#0A0A0A", t2="#56564F", t3="#86867E", danger="#0A0A0A", dark=False),
}

SANS  = "DejaVu Sans"
COND  = "DejaVu Sans Condensed"
MONO  = "DejaVu Sans Mono"

# per-em average advance widths (measured for DejaVu family)
_AW = {SANS: 0.640, COND: 0.560, MONO: 0.602}

_FACE = {
    (SANS, "bold", ""): _bn.SANS_B, (SANS, "normal", ""): _bn.SANS_R,
    (SANS, "bold", "italic"): _bn.SANS_I, (SANS, "normal", "italic"): _bn.SANS_I,
    (COND, "bold", ""): _bn.COND_B, (COND, "normal", ""): _bn.COND_R,
    (MONO, "bold", ""): _bn.MONO_B, (MONO, "normal", ""): _bn.MONO_R,
}

def _face(font, weight="bold", style=""):
    return _FACE.get((font, weight, style), _bn.SANS_B)

def tw(text, size, font=SANS, bold=True, tracking=0.0):
    """Estimate rendered text width in px."""
    return _bn.width(text, size, _face(font, "bold" if bold else "normal"), tracking)

def fit(text, max_w, start, font=SANS, bold=True, tracking=0.0, min_size=10):
    """Largest font size <= start that keeps `text` inside max_w."""
    s = start
    while s > min_size and tw(text, s, font, bold, tracking) > max_w:
        s -= 1
    return s

def esc(t):
    return (t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))

def txt(x, y, s, size=40, fill="#fff", font=SANS, weight="bold", anchor="start",
        tracking=0, opacity=None, style=""):
    return _bn.btext(x, y, s, size, fill, _face(font, weight, style),
                     anchor=anchor, tracking=tracking, opacity=opacity)

def rect(x, y, w, h, fill="none", stroke=None, sw=1, opacity=None, rx=0):
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    o = f' opacity="{opacity}"' if opacity is not None else ""
    r = f' rx="{rx}"' if rx else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}"{s}{o}{r}/>'

def line(x1, y1, x2, y2, stroke, sw=1, opacity=None, dash=None):
    o = f' opacity="{opacity}"' if opacity is not None else ""
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" '
            f'stroke-width="{sw}"{o}{d}/>')

def hazard(x, y, w, h, c1, c2, band=26, angle=45, opacity=1.0, uid="hz"):
    """Diagonal hazard stripe block."""
    return f'''<pattern id="{uid}" width="{band*2}" height="{band*2}"
      patternUnits="userSpaceOnUse" patternTransform="rotate({angle})">
      <rect width="{band*2}" height="{band*2}" fill="{c1}"/>
      <rect width="{band}" height="{band*2}" fill="{c2}"/>
    </pattern>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#{uid})" opacity="{opacity}"/>'''

def dotgrid(x, y, w, h, c, step=25, r=1.2, opacity=0.5, uid="dg"):
    return f'''<pattern id="{uid}" width="{step}" height="{step}" patternUnits="userSpaceOnUse">
      <circle cx="{r}" cy="{r}" r="{r}" fill="{c}"/></pattern>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#{uid})" opacity="{opacity}"/>'''

def tick_ruler(x, y, w, c, n=40, big=14, small=7, sw=2):
    """Instrument-panel tick strip."""
    out = []
    for i in range(n + 1):
        px = x + w * i / n
        hgt = big if i % 5 == 0 else small
        out.append(line(px, y, px, y + hgt, c, sw, opacity=1 if i % 5 == 0 else .45))
    return "".join(out)

def qr_svg(data, x, y, size, dark="#000000", light="#FFFFFF", quiet=2, uid="q"):
    """Real, scannable QR rendered as SVG rects."""
    q = qrcode.QRCode(version=None, error_correction=qrcode.constants.ERROR_CORRECT_H,
                      box_size=10, border=quiet)
    q.add_data(data); q.make(fit=True)
    m = q.get_matrix()
    n = len(m)
    cell = size / n
    out = [rect(x, y, size, size, fill=light)]
    # merge horizontal runs -> fewer rects, crisper render
    for r in range(n):
        c = 0
        while c < n:
            if m[r][c]:
                c2 = c
                while c2 + 1 < n and m[r][c2 + 1]:
                    c2 += 1
                out.append(f'<rect x="{x + c*cell:.2f}" y="{y + r*cell:.2f}" '
                           f'width="{(c2-c+1)*cell:.2f}" height="{cell:.2f}" fill="{dark}"/>')
                c = c2 + 1
            else:
                c += 1
    return "".join(out)

def svg(body, bg):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="{bg}"/>'
            f'{body}</svg>')
