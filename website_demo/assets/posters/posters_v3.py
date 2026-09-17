# -*- coding: utf-8 -*-
"""V3 — 'street-ad' poster series: a Dhaka street scene, two riders checking
phones, a live-map card between them, and a big yellow-on-black headline —
the same visual grammar as the big BD delivery-app billboards (Lalamove,
Pathao), rebuilt flat/vector so it needs no photo shoot and no font-fallback
risk for Bangla. Same QR/campaign/footer conventions as v1 (`posters.py`).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bn as _bn

W, H = 1080, 1350
BASE = "https://blankframe.tech/ThrottleIQ/install"

INK      = "#12161C"
SKY_TOP  = "#2E66C4"
SKY_BOT  = "#8FC6EC"
BUILD_A  = "#1E3A63"
BUILD_B  = "#274873"
TREE     = "#204A34"
ROAD     = "#57626D"
ROAD_D   = "#4A5560"
SIDEWALK = "#A9B1B8"
CARD_BG  = "#FFFFFF"
MAP_BG   = "#E6EEF6"
ACCENT   = "#F5642B"   # ThrottleIQ "Trail Social" orange
YELLOW   = "#FFE100"
FIGURE   = "#F4EFE6"
FOOTER_BG = "#0E1116"

def svg_doc(body, bg):
    """Local canvas wrapper — lib.svg() bakes in lib.py's own 1000x1500, so
    it can't be reused for this series' 1080x1350 frame."""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="{bg}"/>'
            f'{body}</svg>')

def stroke_headline(x, y, lines, size, max_w=980, tracking=0):
    """Two-line yellow-fill / black-outline display headline, centered."""
    o = []
    for i, ln in enumerate(lines):
        fs = _bn.bfit(ln, max_w, size, _bn.COND_B, tracking, min_size=40)
        o.append(_bn.btext(x, y + i * (fs * 1.06), ln, fs, YELLOW, _bn.COND_B,
                            anchor="middle", tracking=tracking,
                            stroke=INK, stroke_width=max(8, fs * 0.11)))
    return "".join(o)

def scene():
    """Flat street backdrop: sky, buildings, trees, road in perspective."""
    vp_x, vp_y = W / 2, 760
    o = [f'''<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="{SKY_TOP}"/>
        <stop offset="100%" stop-color="{SKY_BOT}"/></linearGradient>
        <rect x="0" y="0" width="{W}" height="{vp_y+40}" fill="url(#sky)"/>''']
    # buildings, left block
    o.append(f'<rect x="-20" y="120" width="340" height="{vp_y-100}" fill="{BUILD_A}"/>')
    o.append(f'<rect x="240" y="220" width="220" height="{vp_y-200}" fill="{BUILD_B}"/>')
    for i in range(6):
        for j in range(10):
            wx, wy = 20 + i * 52, 170 + j * 46
            if wx < 300 and wy < vp_y - 30:
                o.append(f'<rect x="{wx}" y="{wy}" width="26" height="30" fill="{SKY_BOT}" opacity="0.35"/>')
    # buildings, right block
    o.append(f'<rect x="760" y="60" width="340" height="{vp_y-40}" fill="{BUILD_B}"/>')
    o.append(f'<rect x="600" y="260" width="220" height="{vp_y-240}" fill="{BUILD_A}"/>')
    for i in range(6):
        for j in range(10):
            wx, wy = 800 + i * 50, 110 + j * 46
            if wx < 1080 and wy < vp_y - 30:
                o.append(f'<rect x="{wx}" y="{wy}" width="24" height="28" fill="{SKY_BOT}" opacity="0.3"/>')
    # tree silhouettes flanking the road mouth
    for cx, r in ((150, 90), (260, 60), (830, 70), (930, 95)):
        o.append(f'<circle cx="{cx}" cy="{vp_y+30}" r="{r}" fill="{TREE}"/>')
        o.append(f'<rect x="{cx-10}" y="{vp_y+20}" width="20" height="70" fill="#3A2A1E"/>')
    # sidewalks
    o.append(f'<polygon points="0,{H} 0,{vp_y+10} {vp_x-70},{vp_y+10} {vp_x-260},{H}" fill="{SIDEWALK}"/>')
    o.append(f'<polygon points="{W},{H} {W},{vp_y+10} {vp_x+70},{vp_y+10} {vp_x+260},{H}" fill="{SIDEWALK}"/>')
    # road
    o.append(f'<polygon points="{vp_x-70},{vp_y+10} {vp_x+70},{vp_y+10} {vp_x+260},{H} {vp_x-260},{H}" fill="{ROAD}"/>')
    # dashed centerline
    n = 9
    for i in range(n):
        t0, t1 = i / n, i / n + 0.5 / n
        yA = vp_y + 10 + (H - vp_y - 10) * t0
        yB = vp_y + 10 + (H - vp_y - 10) * t1
        wA = 2 + 4 * t0
        wB = 2 + 4 * t1
        o.append(f'<polygon points="{vp_x-wA},{yA} {vp_x+wA},{yA} {vp_x+wB},{yB} {vp_x-wB},{yB}" fill="#F4F4F4" opacity="0.85"/>')
    return "".join(o), (vp_x, vp_y)

def standing_phone(cx, cy, s, mirror=False):
    """Flat-icon rider on foot, one hand up checking a phone."""
    m = -1 if mirror else 1
    o = [f'<g transform="translate({cx},{cy}) scale({s*m},{s})">']
    sw = 12
    # legs
    o.append(f'<path d="M -34,-8 L -44,150 Q -44,168 -26,168 L -14,168 L -6,-8 Z" fill="{FIGURE}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"/>')
    o.append(f'<path d="M 34,-8 L 44,150 Q 44,168 26,168 L 14,168 L 6,-8 Z" fill="{FIGURE}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"/>')
    # jacket / torso
    o.append(f'<path d="M -50,-8 Q -60,-140 -28,-190 Q 0,-212 28,-190 Q 60,-140 50,-8 Q 0,12 -50,-8 Z" fill="{FIGURE}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"/>')
    # far arm, relaxed
    o.append(f'<path d="M -30,-148 Q -54,-108 -44,-38" fill="none" stroke="{INK}" stroke-width="{sw}" stroke-linecap="round"/>')
    # near arm, bent sharply up so the forearm holds the phone at chest height
    o.append(f'<path d="M 30,-152 Q 68,-170 70,-198 Q 70,-166 46,-152" fill="none" stroke="{INK}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')
    # head, tipped down toward the phone
    hx, hy, hr = -4, -246, 54
    o.append(f'<circle cx="{hx}" cy="{hy}" r="{hr}" fill="{FIGURE}" stroke="{INK}" stroke-width="{sw}"/>')
    o.append(f'<circle cx="{hx-14}" cy="{hy+12}" r="6.5" fill="{INK}"/>')
    o.append(f'<circle cx="{hx+15}" cy="{hy+14}" r="6.5" fill="{INK}"/>')
    # phone, held up chest-high, right under the chin
    px, py = 54, -180
    o.append(f'<rect x="{px-24}" y="{py-42}" width="48" height="84" rx="9" fill="{INK}"/>')
    o.append(f'<rect x="{px-17}" y="{py-34}" width="34" height="60" rx="4" fill="{ACCENT}" opacity="0.92"/>')
    o.append("</g>")
    return "".join(o)

def ground_pin(cx, cy, r=40):
    """The map's route-end pin, dropped onto the actual street — ties the
    live-map card to the real road below it."""
    o = [f'<ellipse cx="{cx}" cy="{cy+r*0.35}" rx="{r*0.9}" ry="{r*0.28}" fill="#000000" opacity="0.28"/>']
    tip_y = cy - r * 0.1
    o.append(f'<path d="M {cx-r},{cy-r*0.55} a {r},{r} 0 1 1 {2*r},0 Q {cx+r},{cy-r*0.05} {cx},{tip_y+r*0.55} '
              f'Q {cx-r},{cy-r*0.05} {cx-r},{cy-r*0.55} Z" fill="{ACCENT}" stroke="{INK}" stroke-width="5"/>')
    o.append(f'<circle cx="{cx}" cy="{cy-r*0.55}" r="{r*0.42}" fill="#FFFFFF"/>')
    # tiny bike glyph inside the pin head
    bx, by, br = cx, cy - r * 0.55, r * 0.16
    o.append(f'<circle cx="{bx-br*1.7}" cy="{by+br*0.6}" r="{br}" fill="none" stroke="{INK}" stroke-width="3.5"/>')
    o.append(f'<circle cx="{bx+br*1.7}" cy="{by+br*0.6}" r="{br}" fill="none" stroke="{INK}" stroke-width="3.5"/>')
    o.append(f'<path d="M {bx-br*1.7},{by+br*0.6} L {bx-br*0.3},{by-br*0.8} L {bx+br*1.7},{by+br*0.6} M {bx-br*0.3},{by-br*0.8} L {bx},{by+br*0.6}" '
              f'fill="none" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"/>')
    return "".join(o)

def map_card(x, y, w, h, live_label="LIVE"):
    o = [f'<rect x="{x}" y="{y+14}" width="{w}" height="{h}" rx="34" fill="#000000" opacity="0.22"/>']
    o.append(rect(x, y, w, h, fill=CARD_BG, rx=34))
    p = 14
    mx, my, mw, mh = x + p, y + p, w - 2*p, h - 2*p
    o.append(rect(mx, my, mw, mh, fill=MAP_BG, rx=22))
    # faint street grid
    for gx in range(1, 4):
        xx = mx + mw * gx / 4
        o.append(line(xx, my + 10, xx, my + mh - 10, "#C7D4E2", 6, opacity=0.8))
    for gy in range(1, 3):
        yy = my + mh * gy / 3
        o.append(line(mx + 10, yy, mx + mw - 10, yy, "#C7D4E2", 6, opacity=0.8))
    # route: start pin (top-left-ish) to bike marker (bottom-right-ish)
    sx, sy = mx + mw * 0.24, my + mh * 0.30
    ex, ey = mx + mw * 0.72, my + mh * 0.66
    cxp, cyp = mx + mw * 0.42, my + mh * 0.70
    o.append(f'<path d="M {sx},{sy} Q {cxp},{cyp} {ex},{ey}" fill="none" stroke="{ACCENT}" '
              f'stroke-width="9" stroke-linecap="round" stroke-dasharray="2 20"/>')
    o.append(f'<circle cx="{sx}" cy="{sy}" r="11" fill="{CARD_BG}" stroke="{ACCENT}" stroke-width="6"/>')
    o.append(f'<circle cx="{ex}" cy="{ey}" r="17" fill="{ACCENT}"/>')
    o.append(f'<circle cx="{ex}" cy="{ey}" r="17" fill="none" stroke="{ACCENT}" stroke-width="6" opacity="0.4"><animate attributeName="r" values="17;30;17" dur="2s" repeatCount="indefinite"/></circle>')
    # LIVE pill
    o.append(rect(mx + 12, my + 12, 108, 34, fill=INK, rx=17))
    o.append(f'<circle cx="{mx+28}" cy="{my+29}" r="5" fill="#3BB273"/>')
    o.append(txt(mx + 42, my + 36, live_label, 20, "#FFFFFF", MONO, tracking=2))
    # wordmark, bottom-left of map like a map-provider credit
    o.append(txt(mx + 12, my + mh - 12, "ThrottleIQ", 18, "#4A5568", SANS))
    return "".join(o)

def badge(x, y, w, h, lines, align="left"):
    o = [rect(x, y, w, h, fill=ACCENT, rx=18)]
    fs = 30
    cx = x + w / 2
    n = len(lines)
    top = y + h/2 - (n-1) * fs * 0.62
    for i, ln in enumerate(lines):
        size = fit(ln, w - 24, fs, SANS, True, 0)
        o.append(txt(cx, top + i * fs * 1.18, ln, size, "#FFFFFF", SANS, anchor="middle"))
    return "".join(o)

def logo_mark(x, y, s=44):
    """Small gauge mark + wordmark, top-right — echoes icon-light.svg."""
    o = [f'<g transform="translate({x},{y})">']
    o.append(f'<circle cx="{s/2}" cy="{s/2}" r="{s/2}" fill="#0E1116"/>')
    o.append(f'<path d="M {s*0.24},{s*0.66} A {s*0.32},{s*0.32} 0 1 1 {s*0.76},{s*0.66}" '
              f'fill="none" stroke="#3BB273" stroke-width="{s*0.1}" stroke-linecap="round"/>')
    o.append(f'<circle cx="{s*0.5}" cy="{s*0.5}" r="{s*0.08}" fill="#FFFFFF"/>')
    o.append("</g>")
    return "".join(o)

def footer(campaign):
    y0 = H - 150
    o = [rect(0, y0, W, 150, fill=FOOTER_BG)]
    o.append(qr_svg(f"{BASE}?c={campaign}", 44, y0 + 24, 104, dark="#000000", light="#FFFFFF", uid=campaign))
    o.append(txt(168, y0 + 54, "SCAN", 32, ACCENT, COND, tracking=2))
    o.append(txt(168, y0 + 82, "ThrottleIQ নামান", 22, "#F4F4F4", SANS))
    o.append(txt(168, y0 + 108, "FREE · OFFLINE-FIRST · iOS + ANDROID", 15, "#8A8F98", MONO, tracking=1))
    o.append(txt(W - 44, y0 + 58, "ThrottleIQ", 34, "#FFFFFF", SANS, anchor="end", tracking=-1))
    o.append(txt(W - 44, y0 + 84, "MACHINE MEMORY FOR MOTORCYCLES", 13, "#6B7078", MONO, anchor="end", tracking=1.5))
    o.append(txt(W - 44, y0 + 112, "ঢাকায় তৈরি, ঢাকার রাস্তার জন্য", 18, "#8A8F98", SANS, anchor="end"))
    return "".join(o)

def poster(campaign, headline, subhead, badge_l, badge_r, road_tag, live_label="LIVE"):
    body, (vp_x, vp_y) = scene()
    o = [body]
    # the map's route pin, dropped onto the actual road
    o.append(ground_pin(vp_x, 1010, 46))
    # road watermark, between the pin and the footer
    o.append(f'<g transform="translate({vp_x},1195) skewX(-10)">')
    o.append(txt(0, 0, road_tag, 44, "#FFFFFF", COND, anchor="middle", tracking=10, opacity=0.22))
    o.append("</g>")
    # standing figures, foreground
    o.append(standing_phone(140, H - 168, 0.62, mirror=False))
    o.append(standing_phone(W - 140, H - 168, 0.62, mirror=True))
    # headline
    o.append(stroke_headline(W/2, 132, headline, 92, max_w=1000))
    o.append(txt(W/2, 132 + len(headline)*98 + 10, subhead, 24, "#FFFFFF", SANS, anchor="middle", opacity=0.92))
    # badges either side of the map card
    badge_y = 560
    o.append(badge(30, badge_y, 220, 118, badge_l))
    o.append(badge(W - 250, badge_y, 220, 118, badge_r))
    # map card, center
    card_w, card_h = 460, 360
    o.append(map_card(W/2 - card_w/2, 470, card_w, card_h, live_label))
    # logo, top right
    o.append(logo_mark(W - 60, 34, 44))
    o.append(txt(W - 74, 66, "ThrottleIQ", 30, "#FFFFFF", SANS, anchor="end", tracking=-1))
    o.append(footer(campaign))
    return svg_doc("".join(o), SKY_TOP)


POSTERS = [
    dict(
        id="v3-01-family-live-share",
        campaign="family_live_v3",
        headline=["আপনার বাইকার", "কোথায় আছে?"],
        subhead="লাইভ শেয়ার অন করলে, প্রতি মুহূর্তে অবস্থান দেখবে পরিবার।",
        badge_l=["রাইডার", "শেয়ার করলে"],
        badge_r=["পরিবার", "লাইভ দেখে"],
        road_tag="LIVE SHARE",
        live_label="LIVE",
    ),
    dict(
        id="v3-02-crew-beacon",
        campaign="crew_beacon_v3",
        headline=["বন্ধু তুই", "কই এখন?"],
        subhead="গ্রুপ বিকন অন করলে, পুরো ক্রু থাকবে একই লাইভ ম্যাপে।",
        badge_l=["লাইভ ম্যাপে", "সবাই"],
        badge_r=["একসাথে", "রাইড করুন"],
        road_tag="GROUP BEACON",
        live_label="CREW",
    ),
]

if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "svg", "v3")
    os.makedirs(out_dir, exist_ok=True)
    for p in POSTERS:
        doc = poster(p["campaign"], p["headline"], p["subhead"], p["badge_l"],
                     p["badge_r"], p["road_tag"], p["live_label"])
        path = os.path.join(out_dir, f'{p["id"]}.svg')
        with open(path, "w", encoding="utf-8") as f:
            f.write(doc)
        print("wrote", path)
