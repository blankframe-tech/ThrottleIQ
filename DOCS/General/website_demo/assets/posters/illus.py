# -*- coding: utf-8 -*-
"""Big, bold, flat-icon illustration primitives for the v2 poster series.

Style: thick colored outline, dark silhouette fill, radial glow behind the
hero art. Everything is built from circles / ellipses / rounded rects / simple
paths so it renders reliably at any size and stays legible from a moving bike.
"""
import math

def glow(cx, cy, r, color, opacity=0.55, uid="glow"):
    return (f'<radialGradient id="{uid}" cx="50%" cy="50%" r="50%">'
            f'<stop offset="0%" stop-color="{color}" stop-opacity="{opacity}"/>'
            f'<stop offset="100%" stop-color="{color}" stop-opacity="0"/></radialGradient>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{uid})"/>')

def _pt(cx, cy, r, deg):
    t = math.radians(deg)
    return cx + r * math.cos(t), cy + r * math.sin(t)

def speed_lines(x, y, n=3, length=90, gap=26, sw=10, color="#fff", opacity=0.85, angle=180):
    """Short parallel motion strokes trailing behind a subject."""
    t = math.radians(angle)
    dx, dy = math.cos(t), math.sin(t)
    px, py = -dy, dx
    out = []
    for i in range(n):
        off = (i - (n - 1) / 2) * gap
        x0, y0 = x + px * off, y + py * off
        x1, y1 = x0 + dx * length * (1 - i * 0.12), y0 + dy * length * (1 - i * 0.12)
        out.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" '
                    f'stroke="{color}" stroke-width="{sw}" stroke-linecap="round" opacity="{opacity}"/>')
    return "".join(out)

# ---- faces -----------------------------------------------------------------

def _face(cx, cy, r, expr, ink, paper):
    """Facial features for a round head. `expr` picks a preset."""
    o = []
    if expr == "shock":
        for dx in (-r*0.42, r*0.42):
            o.append(f'<circle cx="{cx+dx:.0f}" cy="{cy-r*0.06:.0f}" r="{r*0.24:.0f}" fill="{paper}" stroke="{ink}" stroke-width="4"/>')
            o.append(f'<circle cx="{cx+dx:.0f}" cy="{cy-r*0.06:.0f}" r="{r*0.11:.0f}" fill="{ink}"/>')
        for dx, rot in ((-r*0.42, -14), (r*0.42, 14)):
            o.append(f'<line x1="{cx+dx-r*0.22:.0f}" y1="{cy-r*0.42:.0f}" x2="{cx+dx+r*0.22:.0f}" y2="{cy-r*0.5:.0f}" stroke="{ink}" stroke-width="7" stroke-linecap="round"/>')
        o.append(f'<ellipse cx="{cx:.0f}" cy="{cy+r*0.44:.0f}" rx="{r*0.2:.0f}" ry="{r*0.28:.0f}" fill="{ink}"/>')
    elif expr == "sleepy":
        for dx in (-r*0.36, r*0.36):
            o.append(f'<line x1="{cx+dx-r*0.2:.0f}" y1="{cy:.0f}" x2="{cx+dx+r*0.2:.0f}" y2="{cy:.0f}" stroke="{ink}" stroke-width="7" stroke-linecap="round"/>')
        o.append(f'<path d="M {cx-r*0.16:.0f} {cy+r*0.4:.0f} Q {cx:.0f} {cy+r*0.28:.0f} {cx+r*0.16:.0f} {cy+r*0.4:.0f}" fill="none" stroke="{ink}" stroke-width="6" stroke-linecap="round"/>')
    elif expr == "sing":
        for dx in (-r*0.36, r*0.36):
            o.append(f'<path d="M {cx+dx-r*0.16:.0f} {cy+r*0.04:.0f} Q {cx+dx:.0f} {cy-r*0.16:.0f} {cx+dx+r*0.16:.0f} {cy+r*0.04:.0f}" fill="none" stroke="{ink}" stroke-width="6" stroke-linecap="round"/>')
        o.append(f'<ellipse cx="{cx:.0f}" cy="{cy+r*0.42:.0f}" rx="{r*0.24:.0f}" ry="{r*0.3:.0f}" fill="{ink}"/>')
    elif expr == "grin":
        for dx in (-r*0.36, r*0.36):
            o.append(f'<circle cx="{cx+dx:.0f}" cy="{cy:.0f}" r="{r*0.09:.0f}" fill="{ink}"/>')
        o.append(f'<path d="M {cx-r*0.3:.0f} {cy+r*0.28:.0f} Q {cx:.0f} {cy+r*0.58:.0f} {cx+r*0.3:.0f} {cy+r*0.28:.0f}" fill="none" stroke="{ink}" stroke-width="7" stroke-linecap="round"/>')
    elif expr == "calm":
        for dx in (-r*0.36, r*0.36):
            o.append(f'<circle cx="{cx+dx:.0f}" cy="{cy:.0f}" r="{r*0.08:.0f}" fill="{ink}"/>')
        o.append(f'<path d="M {cx-r*0.22:.0f} {cy+r*0.3:.0f} Q {cx:.0f} {cy+r*0.42:.0f} {cx+r*0.22:.0f} {cy+r*0.3:.0f}" fill="none" stroke="{ink}" stroke-width="6" stroke-linecap="round"/>')
    else:  # neutral
        for dx in (-r*0.36, r*0.36):
            o.append(f'<circle cx="{cx+dx:.0f}" cy="{cy:.0f}" r="{r*0.09:.0f}" fill="{ink}"/>')
        o.append(f'<line x1="{cx-r*0.2:.0f}" y1="{cy+r*0.34:.0f}" x2="{cx+r*0.2:.0f}" y2="{cy+r*0.34:.0f}" stroke="{ink}" stroke-width="6" stroke-linecap="round"/>')
    return "".join(o)

def rider(cx, cy, scale, stroke, fill, sw=13, expr="neutral", arm="down", lean=0, helmet=False):
    """Round-head figure seated on a simple two-wheel bike. cx,cy = ground
    contact point between the wheels. scale 1.0 ~= 260px wide bike."""
    s = scale
    o = [f'<g transform="translate({cx},{cy}) scale({s}) rotate({lean})">']
    # wheels
    o.append(f'<circle cx="-95" cy="0" r="72" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="95" cy="0" r="72" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="-95" cy="0" r="10" fill="{stroke}"/>')
    o.append(f'<circle cx="95" cy="0" r="10" fill="{stroke}"/>')
    # frame + seat + tank (one rounded silhouette)
    o.append(f'<path d="M -95,-16 L -40,-70 Q 10,-96 60,-78 L 95,-16 '
              f'Q 40,-46 -20,-40 Q -70,-34 -95,-16 Z" '
              f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    # headlight
    o.append(f'<circle cx="118" cy="-30" r="14" fill="{stroke}"/>')
    # torso
    o.append(f'<path d="M -30,-92 Q -46,-160 -14,-206 Q 22,-238 62,-206 '
              f'Q 84,-180 66,-140 Q 100,-150 108,-118 L 40,-88 Q 4,-72 -30,-92 Z" '
              f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    # arm
    if arm == "up":
        o.append(f'<path d="M 48,-150 Q 96,-190 118,-238" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
        o.append(f'<circle cx="122" cy="-244" r="17" fill="{fill}" stroke="{stroke}" stroke-width="{sw*0.8:.1f}"/>')
    elif arm == "point":
        o.append(f'<path d="M 50,-152 Q 110,-160 158,-140" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
        o.append(f'<circle cx="164" cy="-136" r="15" fill="{fill}" stroke="{stroke}" stroke-width="{sw*0.8:.1f}"/>')
    else:
        o.append(f'<path d="M 40,-140 Q 90,-136 112,-104" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
    # head
    hx, hy, hr = 4, -244, 66
    o.append(f'<circle cx="{hx}" cy="{hy}" r="{hr}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(_face(hx, hy, hr, expr, stroke, fill))
    if helmet:
        o.append(f'<path d="M {hx-hr-4},{hy-6} A {hr+8},{hr+8} 0 0 1 {hx+hr+4},{hy-6} '
                  f'L {hx+hr+4},{hy-hr-6} Q {hx},{hy-hr*1.7:.0f} {hx-hr-4},{hy-hr-6} Z" '
                  f'fill="{stroke}" opacity="0.9"/>')
    o.append("</g>")
    return "".join(o)

# ---- prop icons (drawn centered on cx,cy) -----------------------------------

def traffic_light(cx, cy, s, stroke, fill, sw=12, red_on=True):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<rect x="-46" y="-140" width="92" height="230" rx="26" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    cols = ["#FA4D56", "#EAB532", "#3BB273"]
    for i, c in enumerate(cols):
        cy2 = -90 + i * 76
        lit = (i == 0 and red_on) or (i != 0 and not red_on and i == 2)
        o.append(f'<circle cx="0" cy="{cy2}" r="30" fill="{c if lit else stroke}" opacity="{1 if lit else 0.35}"/>')
        if lit:
            o.append(glow(0, cy2, 70, c, 0.6, f"tl{i}{cx}{cy}"))
            o.append(f'<circle cx="0" cy="{cy2}" r="30" fill="{c}"/>')
    o.append(f'<rect x="-14" y="90" width="28" height="70" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def clock_burst(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<circle cx="0" cy="0" r="150" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    for a in range(0, 360, 30):
        x0, y0 = _pt(0, 0, 122, a); x1, y1 = _pt(0, 0, 140, a)
        o.append(f'<line x1="{x0:.0f}" y1="{y0:.0f}" x2="{x1:.0f}" y2="{y1:.0f}" stroke="{stroke}" stroke-width="6"/>')
    o.append(f'<line x1="0" y1="0" x2="0" y2="-95" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
    o.append(f'<line x1="0" y1="0" x2="70" y2="40" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
    o.append(f'<circle cx="0" cy="0" r="12" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def fuel_pump(cx, cy, s, stroke, fill, sw=12, drip=True):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<rect x="-70" y="-190" width="140" height="240" rx="18" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<rect x="-46" y="-160" width="92" height="70" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="7"/>')
    o.append(f'<path d="M 70,-140 Q 130,-140 130,-90 L 130,40 Q 130,64 108,64 L 90,64" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
    o.append(f'<path d="M 90,54 Q 60,70 40,110" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>')
    if drip:
        o.append(f'<circle cx="34" cy="140" r="11" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def wrench_check(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<circle cx="0" cy="0" r="160" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append('<g transform="rotate(-45)">')
    o.append(f'<rect x="-20" y="-86" width="40" height="172" rx="12" fill="{stroke}"/>')
    o.append(f'<path d="M -44,-86 A 44,44 0 1 1 44,-86 L 26,-86 A 26,26 0 1 0 -26,-86 Z" fill="{stroke}"/>')
    o.append(f'<circle cx="0" cy="86" r="44" fill="{stroke}"/>')
    o.append(f'<circle cx="0" cy="86" r="19" fill="{fill}"/>')
    o.append('</g>')
    o.append(f'<circle cx="86" cy="-86" r="48" fill="{fill}" stroke="{stroke}" stroke-width="9"/>')
    o.append(f'<path d="M 64,-84 L 80,-66 L 112,-108" fill="none" stroke="{stroke}" stroke-width="11" '
              f'stroke-linecap="round" stroke-linejoin="round"/>')
    o.append("</g>")
    return "".join(o)

def stars_burst(cx, cy, s, stroke, fill, sw=10, count=5, filled=4):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    def star(x, y, r, c):
        pts = []
        for i in range(10):
            rr = r if i % 2 == 0 else r * 0.42
            a = math.radians(-90 + i * 36)
            pts.append(f"{x+rr*math.cos(a):.1f},{y+rr*math.sin(a):.1f}")
        return f'<polygon points="{" ".join(pts)}" fill="{c}" stroke="{stroke}" stroke-width="5" stroke-linejoin="round"/>'
    span = 300
    for i in range(count):
        x = -span/2 + span * i / (count - 1)
        c = stroke if i < filled else fill
        o.append(star(x, math.sin(i*1.3)*-18, 58, c))
    o.append("</g>")
    return "".join(o)

def black_box(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(glow(0, 0, 190, stroke, 0.5, f"bb{cx}{cy}"))
    # squat armored recorder box with a carry handle + antenna
    o.append(f'<path d="M -60,-150 L 60,-150 L 60,-110 L 40,-110 L 40,-150" fill="none" stroke="{stroke}" stroke-width="10" stroke-linejoin="round"/>')
    o.append(f'<line x1="-40" y1="-150" x2="-40" y2="-180" stroke="{stroke}" stroke-width="10" stroke-linecap="round"/>')
    o.append(f'<circle cx="-40" cy="-186" r="8" fill="{stroke}"/>')
    o.append(f'<rect x="-130" y="-108" width="260" height="220" rx="20" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<rect x="-98" y="-72" width="196" height="110" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="6" opacity="0.9"/>')
    o.append(f'<polyline points="-90,-18 -54,-18 -34,-56 -10,14 14,-30 38,-18 90,-18" '
              f'fill="none" stroke="{stroke}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>')
    o.append(f'<circle cx="-72" cy="66" r="12" fill="{stroke}"/>')
    o.append(f'<text x="-48" y="72" font-family="sans-serif" font-weight="900" font-size="26" fill="{stroke}" opacity="0.9">REC</text>')
    o.append("</g>")
    return "".join(o)

def shield_pin(cx, cy, s, stroke, fill, sw=12, eye_off=True):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<path d="M 0,-170 L 130,-120 Q 130,40 0,170 Q -130,40 -130,-120 Z" '
              f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    o.append(f'<circle cx="0" cy="-30" r="46" fill="none" stroke="{stroke}" stroke-width="10"/>')
    if eye_off:
        o.append(f'<line x1="-46" y1="-76" x2="46" y2="16" stroke="{stroke}" stroke-width="12" stroke-linecap="round"/>')
    o.append(f'<circle cx="0" cy="70" r="10" fill="{stroke}"/>')
    o.append(f'<line x1="0" y1="86" x2="0" y2="130" stroke="{stroke}" stroke-width="10" stroke-linecap="round"/>')
    o.append("</g>")
    return "".join(o)

def passport(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<rect x="-110" y="-150" width="220" height="300" rx="16" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="0" cy="-50" r="46" fill="none" stroke="{stroke}" stroke-width="8"/>')
    for y in (40, 76, 112):
        o.append(f'<line x1="-70" y1="{y}" x2="70" y2="{y}" stroke="{stroke}" stroke-width="8" stroke-linecap="round" opacity="0.6"/>')
    o.append(f'<g transform="translate(78,-96) rotate(18)">'
              f'<circle cx="0" cy="0" r="46" fill="none" stroke="{stroke}" stroke-width="9"/>'
              f'<text x="0" y="8" font-family="sans-serif" font-weight="900" font-size="30" '
              f'fill="{stroke}" text-anchor="middle">?</text></g>')
    o.append("</g>")
    return "".join(o)

def phone_nosignal(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<rect x="-70" y="-140" width="140" height="280" rx="30" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<rect x="-50" y="-110" width="100" height="190" rx="6" fill="none" stroke="{stroke}" stroke-width="5" opacity="0.5"/>')
    for i in range(4):
        h = 20 + i * 20
        o.append(f'<rect x="{-40+i*26}" y="{-40-h}" width="16" height="{h}" fill="{stroke}" opacity="0.9"/>')
    o.append(f'<line x1="-64" y1="-90" x2="64" y2="30" stroke="{stroke}" stroke-width="14" stroke-linecap="round"/>')
    o.append(f'<circle cx="0" cy="110" r="12" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def mountain(cx, cy, s, stroke, fill, sw=10):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<path d="M -220,80 L -90,-120 L -10,-10 L 60,-140 L 220,80 Z" '
              f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    o.append(f'<path d="M -90,-120 L -55,-70 L -110,-55 Z" fill="{stroke}"/>')
    o.append(f'<path d="M 60,-140 L 95,-90 L 30,-78 Z" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def alarm_bell(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(glow(0, -10, 190, stroke, 0.5, f"al{cx}{cy}"))
    o.append(f'<path d="M -110,60 Q -110,-120 0,-140 Q 110,-120 110,60 Z" '
              f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    o.append(f'<circle cx="0" cy="90" r="24" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="0" cy="-152" r="14" fill="{stroke}"/>')
    for a, r0, r1 in ((-40, 130, 170), (40, 130, 170)):
        x0, y0 = _pt(0, -20, r0, a); x1, y1 = _pt(0, -20, r1, a)
        o.append(f'<line x1="{x0:.0f}" y1="{y0:.0f}" x2="{x1:.0f}" y2="{y1:.0f}" stroke="{stroke}" stroke-width="10" stroke-linecap="round"/>')
    o.append("</g>")
    return "".join(o)

def radar_rings(cx, cy, s, stroke, fill, dot=True):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    for i, r in enumerate((60, 120, 180)):
        o.append(f'<circle cx="0" cy="0" r="{r}" fill="none" stroke="{stroke}" stroke-width="{10-i*2}" opacity="{0.85-i*0.22}"/>')
    if dot:
        o.append(f'<circle cx="0" cy="0" r="22" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def heart_pin(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<path d="M 0,150 Q -140,30 -140,-50 Q -140,-140 -55,-140 Q 0,-140 0,-80 '
              f'Q 0,-140 55,-140 Q 140,-140 140,-50 Q 140,30 0,150 Z" '
              f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    o.append(f'<path d="M -40,-20 L -6,-20 L 10,-54 L 30,10 L 46,-20 L 70,-20" '
              f'fill="none" stroke="{stroke}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>')
    o.append("</g>")
    return "".join(o)

def music_notes(cx, cy, s, stroke, fill):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    for dx, dy, r in ((-70, 40, 1.0), (60, -30, 1.25), (150, 60, 0.85)):
        o.append(f'<g transform="translate({dx},{dy}) scale({r})">'
                  f'<ellipse cx="0" cy="0" rx="26" ry="19" fill="{stroke}"/>'
                  f'<line x1="24" y1="-4" x2="24" y2="-100" stroke="{stroke}" stroke-width="8"/>'
                  f'<path d="M 24,-100 Q 60,-96 56,-64" fill="none" stroke="{stroke}" stroke-width="8" stroke-linecap="round"/>'
                  f'</g>')
    o.append("</g>")
    return "".join(o)

def speedo_dial(cx, cy, s, stroke, fill, sw=12, frac=0.9, label="KM/H"):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    r = 170
    o.append(f'<circle cx="0" cy="0" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    a0, span = 150, 240
    def pt(a, rr):
        t = math.radians(a); return rr*math.cos(t), rr*math.sin(t)
    x0, y0 = pt(a0, r-30); x1, y1 = pt(a0+span, r-30)
    o.append(f'<path d="M {x0:.1f},{y0:.1f} A {r-30},{r-30} 0 1 1 {x1:.1f},{y1:.1f}" fill="none" stroke="{stroke}" stroke-width="14" opacity="0.35"/>')
    xe, ye = pt(a0 + span*frac, r-30)
    large = 1 if span*frac > 180 else 0
    o.append(f'<path d="M {x0:.1f},{y0:.1f} A {r-30},{r-30} 0 {large} 1 {xe:.1f},{ye:.1f}" fill="none" stroke="{stroke}" stroke-width="14"/>')
    na = math.radians(a0 + span*frac)
    o.append(f'<line x1="0" y1="0" x2="{(r-56)*math.cos(na):.0f}" y2="{(r-56)*math.sin(na):.0f}" stroke="{stroke}" stroke-width="8" stroke-linecap="round"/>')
    o.append(f'<circle cx="0" cy="0" r="14" fill="{stroke}"/>')
    o.append(f'<text x="0" y="70" font-family="sans-serif" font-weight="900" font-size="26" fill="{stroke}" text-anchor="middle" opacity="0.8">{label}</text>')
    o.append("</g>")
    return "".join(o)

def fuel_drop(cx, cy, s, stroke, fill, sw=12, good=True):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<path d="M 0,-170 Q 120,-20 120,60 Q 120,160 0,160 Q -120,160 -120,60 '
              f'Q -120,-20 0,-170 Z" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    if good:
        o.append(f'<path d="M -46,40 L -12,80 L 56,0" fill="none" stroke="{stroke}" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>')
    else:
        o.append(f'<line x1="-40" y1="0" x2="40" y2="80" stroke="{stroke}" stroke-width="16" stroke-linecap="round"/>')
        o.append(f'<line x1="40" y1="0" x2="-40" y2="80" stroke="{stroke}" stroke-width="16" stroke-linecap="round"/>')
    o.append("</g>")
    return "".join(o)

def speech_bubble(cx, cy, s, stroke, fill, sw=12, tail="left", dots=True):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<rect x="-180" y="-110" width="360" height="200" rx="40" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    if tail == "left":
        o.append(f'<path d="M -110,86 L -150,150 L -60,92 Z" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    else:
        o.append(f'<path d="M 110,86 L 150,150 L 60,92 Z" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    if dots:
        o.append(f'<circle cx="-70" cy="-10" r="12" fill="{stroke}"/>')
        o.append(f'<circle cx="0" cy="-10" r="12" fill="{stroke}"/>')
        o.append(f'<circle cx="70" cy="-10" r="12" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def handshake(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    for dx, fl in ((-140, 1), (140, -1)):
        o.append(f'<g transform="translate({dx},0) scale({fl},1)">'
                  f'<path d="M -140,220 Q -150,60 -80,10 Q -20,-24 40,20 L 40,90 Q -40,60 -110,90 Z" '
                  f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>'
                  f'<circle cx="-60" cy="-70" r="52" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
                  f'<circle cx="-76" cy="-78" r="8" fill="{stroke}"/>'
                  f'<circle cx="-44" cy="-78" r="8" fill="{stroke}"/>'
                  f'<path d="M -78,-56 Q -60,-44 -42,-56" fill="none" stroke="{stroke}" stroke-width="6" stroke-linecap="round"/>'
                  f'<path d="M -100,-10 Q -60,-40 0,-10 L 60,10 Q 80,20 68,42 Q 56,60 30,48 L 0,34" '
                  f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/></g>')
    o.append(f'<path d="M -60,26 Q 0,4 60,26" fill="none" stroke="{stroke}" stroke-width="14" stroke-linecap="round"/>')
    o.append("</g>")
    return "".join(o)

def camera_flash(cx, cy, s, stroke, fill, sw=12):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(glow(0, 0, 230, stroke, 0.6, f"cf{cx}{cy}"))
    for a in range(0, 360, 45):
        x0, y0 = _pt(0, 0, 90, a); x1, y1 = _pt(0, 0, 210, a)
        o.append(f'<polygon points="{x0:.0f},{y0:.0f} {x1:.0f},{y1:.0f} {_pt(0,0,110,a+14)[0]:.0f},{_pt(0,0,110,a+14)[1]:.0f}" fill="{stroke}" opacity="0.75"/>')
    o.append(f'<rect x="-120" y="-70" width="240" height="150" rx="20" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<rect x="-40" y="-110" width="90" height="40" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="0" cy="8" r="58" fill="{stroke}"/>')
    o.append(f'<circle cx="0" cy="8" r="30" fill="{fill}"/>')
    o.append(f'<circle cx="86" cy="-42" r="10" fill="{stroke}"/>')
    o.append("</g>")
    return "".join(o)

def coins(cx, cy, s, stroke, fill, sw=10):
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    for i, (dx, dy, r) in enumerate(((-70, 20, 78), (60, 40, 90), (0, -50, 70))):
        o.append(f'<circle cx="{dx}" cy="{dy}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
        o.append(f'<text x="{dx}" y="{dy+16}" font-family="sans-serif" font-weight="900" font-size="{r*0.62:.0f}" '
                  f'fill="{stroke}" text-anchor="middle">Tk</text>')
    o.append("</g>")
    return "".join(o)

def bike_silhouette(cx, cy, s, stroke, fill, sw=13, sport=True):
    """Standalone motorcycle (no rider), for the model-benchmark posters."""
    o = [f'<g transform="translate({cx},{cy}) scale({s})">']
    o.append(f'<circle cx="-150" cy="10" r="90" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="150" cy="10" r="90" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="-150" cy="10" r="13" fill="{stroke}"/>')
    o.append(f'<circle cx="150" cy="10" r="13" fill="{stroke}"/>')
    if sport:
        body = (f'M -150,-30 L -70,-110 Q -10,-140 70,-100 L 150,-30 '
                f'Q 90,-70 20,-64 Q -60,-56 -150,-30 Z')
    else:
        body = (f'M -150,-20 L -90,-90 Q -20,-110 60,-90 L 150,-20 '
                f'Q 70,-50 0,-46 Q -80,-40 -150,-20 Z')
    o.append(f'<path d="{body}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')
    o.append(f'<circle cx="176" cy="-46" r="16" fill="{stroke}"/>')
    o.append(speed_lines(-230, 10, 4, 110, 24, 12, stroke, 0.7, 180))
    o.append("</g>")
    return "".join(o)
