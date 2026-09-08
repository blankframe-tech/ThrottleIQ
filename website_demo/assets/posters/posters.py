# -*- coding: utf-8 -*-
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

BASE = "https://blankframe.tech/ThrottleIQ/install"

def qr_block(x, y, s, skin, campaign, cta_top, cta_bot, frame_c=None, qr_dark=None):
    """QR + framing + scan instruction. High-contrast, scannable at 1-2m."""
    c = frame_c or skin["pri"]
    qd = qr_dark or "#000000"
    o = [rect(x - 10, y - 10, s + 20, s + 20, fill=c)]
    o.append(qr_svg(f"{BASE}?c={campaign}", x, y, s, dark=qd, light="#FFFFFF", uid=campaign))
    # corner crops for a targeting-reticle feel
    L = 30
    for (cx, cy, dx, dy) in ((x-10,y-10,1,1),(x+s+10,y-10,-1,1),(x-10,y+s+10,1,-1),(x+s+10,y+s+10,-1,-1)):
        o.append(line(cx, cy, cx+L*dx, cy, skin["bg"], 6))
        o.append(line(cx, cy, cx, cy+L*dy, skin["bg"], 6))
    tx = x + s + 40
    o.append(txt(tx, y + 34, "SCAN", 54, c, COND, tracking=2))
    o.append(line(tx, y + 52, tx + 210, y + 52, c, 4))
    o.append(txt(tx, y + 92, cta_top, 25, skin["t1"], MONO))
    o.append(txt(tx, y + 124, cta_bot, 25, skin["t1"], MONO))
    o.append(txt(tx, y + 176, "FREE · OFFLINE-FIRST", 17, skin["t3"], MONO))
    o.append(txt(tx, y + 200, "iOS + ANDROID", 17, skin["t3"], MONO))
    return "".join(o)

def dline(x, y, s, size, fill, font=COND, max_w=880, tracking=0, anchor="start", weight="bold"):
    """Display line that auto-shrinks to stay inside max_w."""
    fs = fit(s, max_w, size, font, weight == "bold", tracking)
    return txt(x, y, s, fs, fill, font, weight=weight, anchor=anchor, tracking=tracking)

def eyebrow(y, left, right, skin, c=None):
    c = c or skin["pri"]
    o = [line(60, y, 940, y, skin["line"], 2)]
    o.append(txt(60, y - 16, left, 20, c, MONO, tracking=3))
    o.append(txt(940, y - 16, right, 20, skin["t3"], MONO, anchor="end", tracking=3))
    return "".join(o)

def footer(skin, mark_c=None):
    c = mark_c or skin["pri"]
    o = [line(60, 1400, 940, 1400, skin["line"], 2)]
    o.append(txt(60, 1445, "ThrottleIQ", 40, c, SANS, tracking=-1))
    o.append(txt(60, 1472, "MACHINE MEMORY FOR MOTORCYCLES", 16, skin["t3"], MONO, tracking=2))
    o.append(txt(940, 1450, "ঢাকায় তৈরি", 22, skin["t2"], SANS, anchor="end"))
    o.append(txt(940, 1478, "ঢাকার রাস্তার জন্য", 22, skin["t2"], SANS, anchor="end"))
    return "".join(o)


# ══════════════════════════════════════════════════════════════════
# 01 — JAM COUNTER · at traffic signals · Carbon Mono
# ══════════════════════════════════════════════════════════════════
def p01():
    s = SKINS["carbonMono"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 26, 1.3, .55, "dg1"))
    o.append(hazard(0, 0, W, 26, s["pri"], s["bg"], 18, 45, 1, "hz1"))
    o.append(eyebrow(120, "// SIGNAL 04 · GULSHAN 1", "LIVE", s))
    o.append(f'<circle cx="866" cy="91" r="7" fill="{s["danger"]}"/>')

    o.append(dline(60, 202, "আবার দাঁড়িয়ে আছেন।", 54, s["t1"]))
    o.append(dline(60, 264, "প্রতিদিনের মতোই।", 54, s["t3"]))

    # hero number
    o.append(txt(500, 700, "47", 520, s["pri"], COND, anchor="middle", tracking=-12))
    o.append(txt(500, 754, "MINUTES LOST TODAY", 38, s["t1"], MONO, anchor="middle", tracking=6))
    o.append(line(60, 786, 940, 786, s["pri"], 3))

    # instrument strip
    o.append(tick_ruler(60, 796, 880, s["line"], 40, 16, 8, 2))
    stats = [("TODAY", "47m"), ("THIS WEEK", "5h 12m"), ("THIS MONTH", "23h"), ("PER YEAR", "11 DAYS")]
    for i, (k, v) in enumerate(stats):
        x = 60 + i * 220
        o.append(rect(x, 832, 200, 118, fill=s["surf"], stroke=s["line"], sw=2))
        o.append(txt(x + 16, 864, k, 17, s["t3"], MONO, tracking=1))
        col = s["pri"] if i == 3 else s["t1"]
        o.append(txt(x + 16, 922, v, fit(v, 168, 46, COND), col, COND))
    o.append(txt(940, 984, "^ 11 DAYS A YEAR. GONE.", 22, s["att"], MONO, anchor="end"))

    o.append(dline(60, 1052, "জ্যামে কত সময় নষ্ট হয়,", 58, s["t1"]))
    o.append(dline(60, 1112, "ThrottleIQ সেটা গুনে রাখে।", 58, s["pri"]))
    o.append(dline(60, 1152, "অটো রাইড-লগিং। বাটন নেই। ইন্টারনেট লাগে না।", 26, s["t2"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1190, 180, s, "signal_jam", "দেখুন আপনার সময়", "কোথায় যাচ্ছে"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 02 — PUMP · maintenance · Genesis gold
# ══════════════════════════════════════════════════════════════════
def p02():
    s = SKINS["genesis"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 30, 1.2, .5, "dg2"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// FUEL STOP · CHECKLIST", "0 SEC READ", s))

    o.append(dline(60, 232, "ট্যাংক ফুল।", 108, s["t1"]))
    o.append(dline(60, 344, "চেইন শুকনা।", 108, s["pri"]))

    # gauge cluster — three dials
    dials = [("CHAIN LUBE", 0.92, s["danger"], "480 km OVER"),
             ("ENGINE OIL", 0.68, s["pri"],   "1,100 km LEFT"),
             ("BRAKE PADS", 0.31, s["sec"],   "4,200 km LEFT")]
    import math
    for i, (name, frac, col, sub) in enumerate(dials):
        cx, cy, r = 190 + i * 310, 520, 112
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{s["surf"]}" stroke="{s["line"]}" stroke-width="2"/>')
        # arc track 240deg
        a0, span = 150, 240
        def pt(a, rr):
            t = math.radians(a); return cx + rr*math.cos(t), cy + rr*math.sin(t)
        x0,y0 = pt(a0, r-16); x1,y1 = pt(a0+span, r-16)
        o.append(f'<path d="M {x0:.1f},{y0:.1f} A {r-16},{r-16} 0 1 1 {x1:.1f},{y1:.1f}" fill="none" stroke="{s["line"]}" stroke-width="16"/>')
        xe,ye = pt(a0 + span*frac, r-16)
        large = 1 if span*frac > 180 else 0
        o.append(f'<path d="M {x0:.1f},{y0:.1f} A {r-16},{r-16} 0 {large} 1 {xe:.1f},{ye:.1f}" fill="none" stroke="{col}" stroke-width="16" stroke-linecap="butt"/>')
        o.append(txt(cx, cy + 6, f"{int(frac*100)}%", 60, col, COND, anchor="middle"))
        o.append(txt(cx, cy + 42, "WEAR", 18, s["t3"], MONO, anchor="middle", tracking=2))
        o.append(txt(cx, cy + 148, name, 24, s["t1"], MONO, anchor="middle", tracking=1))
        o.append(txt(cx, cy + 176, sub, 20, col, MONO, anchor="middle"))

    o.append(line(60, 762, 940, 762, s["line"], 2))
    o.append(dline(60, 840, "পেট্রল ভরছেন। বাইকের", 58, s["t1"]))
    o.append(dline(60, 900, "বাকি জিনিস কবে দেখবেন?", 58, s["pri"]))

    # cost box
    o.append(rect(60, 936, 880, 196, fill=s["surf"], stroke=s["pri"], sw=3))
    o.append(txt(88, 1002, "Tk 400", 62, s["pri"], COND))
    o.append(txt(430, 1000, "এখন চেইন সার্ভিস", 32, s["t1"], SANS))
    o.append(line(88, 1024, 912, 1024, s["line"], 2))
    o.append(txt(88, 1086, "Tk 12,000", 54, s["danger"], COND))
    o.append(txt(430, 1068, "পরে স্প্রকেট + চেইন", 32, s["danger"], SANS))
    o.append(txt(430, 1104, "ThrottleIQ আগেই জানায়।", 25, s["t2"], SANS, weight="normal"))

    o.append(qr_block(60, 1172, 172, s, "pump_maint", "ফ্রি মেইনটেন্যান্স", "ট্র্যাকার"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 03 — GARAGE · service proof · Trail Social orange
# ══════════════════════════════════════════════════════════════════
def p03():
    s = SKINS["trailSocial"]; o = []
    o.append(hazard(0, 0, W, H, s["bg"], s["surf"], 60, 45, 1, "hz3"))
    o.append(rect(0, 0, W, H, fill=s["bg"], opacity=.55))
    o.append(rect(0, 0, 22, H, fill=s["pri"]))
    o.append(eyebrow(120, "// GARAGE COUNTER", "RECEIPT #4417", s))

    o.append(dline(60, 214, "“সব", 92, s["t1"], max_w=550))
    o.append(dline(60, 332, "চেঞ্জ", 92, s["pri"], max_w=550))
    o.append(dline(60, 450, "করেছি”", 92, s["t1"], max_w=550))
    o.append(txt(640, 300, "— every", 30, s["t2"], SANS, weight="normal", style="italic"))
    o.append(txt(640, 340, "mechanic,", 30, s["t2"], SANS, weight="normal", style="italic"))
    o.append(txt(640, 380, "ever.", 30, s["t2"], SANS, weight="normal", style="italic"))

    o.append(dline(60, 528, "প্রমাণ দিন।", 78, s["pri"]))

    # service log receipt
    o.append(rect(60, 560, 880, 400, fill=s["surf"], stroke=s["line"], sw=2))
    o.append(txt(88, 606, "SERVICE LOG · RONIN 350 · 42,180 km", 22, s["t2"], MONO, tracking=1))
    o.append(line(88, 622, 912, 622, s["line"], 2))
    rows = [("14 MAR", "Engine oil + filter", "5,000 km ago", s["danger"], "OVERDUE"),
            ("02 MAY", "Chain lube", "620 km ago", s["pri"], "OK"),
            ("28 APR", "Front brake pads", "1,400 km ago", s["pri"], "OK"),
            ("11 FEB", "Tyre pressure", "NOT LOGGED", s["att"], "UNKNOWN")]
    for i, (d, item, ago, col, tag) in enumerate(rows):
        y = 672 + i * 68
        o.append(txt(88, y, d, 24, s["t3"], MONO))
        o.append(txt(220, y, item, 30, s["t1"], SANS))
        o.append(txt(640, y, ago, 22, s["t2"], MONO))
        o.append(rect(806, y - 26, 106, 36, fill=col))
        o.append(txt(859, y - 1, tag, 18, s["bg"], MONO, anchor="middle", tracking=1))
        o.append(line(88, y + 22, 912, y + 22, s["line"], 1, opacity=.6))
    o.append(txt(88, 940, "Every service, timestamped. Nobody can rewrite it.", 24, s["pri"], MONO))

    o.append(dline(60, 1046, "যা করানো হয়েছে, তার রেকর্ড থাকুক।", 50, s["t1"]))
    o.append(dline(60, 1102, "পরেরবার প্রমাণ নিয়ে কথা বলবেন।", 50, s["t2"]))

    o.append(qr_block(60, 1160, 180, s, "garage_proof", "প্রতিটা সার্ভিস লগ হোক।", "চিরকাল ফ্রি।"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 04 — RATE IT · reviews at garages & pumps · Retro brutalist B/W
# ══════════════════════════════════════════════════════════════════
def p04():
    s = SKINS["retro"]; o = []
    ink, paper = s["pri"], s["bg"]
    o.append(rect(0, 0, W, 150, fill=ink))
    o.append(txt(60, 108, "এই গ্যারেজ", 88, paper, COND))
    o.append(txt(940, 108, "কেমন?", 88, paper, COND, anchor="end"))

    o.append(line(60, 196, 940, 196, ink, 8))
    o.append(txt(60, 250, "// RATE IT BEFORE THE NEXT RIDER GETS ROBBED", 24, ink, MONO, tracking=1))

    # giant stars
    def star(cx, cy, r, fill, stroke_w=6):
        import math
        pts = []
        for i in range(10):
            rr = r if i % 2 == 0 else r * 0.42
            a = math.radians(-90 + i * 36)
            pts.append(f"{cx + rr*math.cos(a):.1f},{cy + rr*math.sin(a):.1f}")
        return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="{ink}" stroke-width="{stroke_w}"/>'
    for i in range(5):
        o.append(star(140 + i * 180, 400, 78, ink if i < 4 else paper))

    o.append(txt(500, 532, "৪.০ / ৫  ·  ১২৮ জন রাইডার", 36, ink, SANS, anchor="middle"))

    # brutalist comparison blocks
    o.append(rect(74, 604, 425, 300, fill=ink, opacity=.22))
    o.append(rect(60, 590, 425, 300, fill=paper, stroke=ink, sw=6))
    o.append(dline(88, 652, "ThrottleIQ ছাড়া", 40, ink, max_w=380))
    for i, t in enumerate(["শুনে শুনে গ্যারেজ খোঁজা", "দাম কেউ জানে না", "কাজ খারাপ হলেও চুপ",
                           "একই ভুল, পরের রাইডার"]):
        o.append(dline(88, 708 + i * 44, "— " + t, 25, s["t2"], font=SANS, weight="normal", max_w=370))

    o.append(rect(515, 590, 425, 300, fill=ink))
    o.append(dline(543, 652, "ThrottleIQ দিয়ে", 40, paper, max_w=380))
    for i, t in enumerate(["কাছের রেটেড গ্যারেজ", "আসল দাম, আসল রিভিউ", "ছবি + বিলের প্রমাণ",
                           "খারাপ কাজ ফ্ল্যাগ হয়"]):
        o.append(dline(543, 708 + i * 44, "— " + t, 25, paper, font=SANS, weight="normal", max_w=370))

    o.append(line(60, 934, 940, 934, ink, 8))
    o.append(txt(60, 1004, "GARAGE. PUMP. PARTS SHOP.", 58, ink, COND, tracking=1))
    o.append(dline(60, 1066, "রেট করুন। ৩০ সেকেন্ড।", 60, ink))
    o.append(dline(60, 1112, "ঢাকার রাইডাররা ম্যাপ বানাচ্ছে। আপনারটা যোগ করুন।", 26, s["t2"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1160, 180, s, "review_garage", "এই জায়গা রেট করুন।", "পরের রাইডার বাঁচুক।",
                      frame_c=ink, qr_dark=ink))
    o.append(line(60, 1400, 940, 1400, ink, 4))
    o.append(txt(60, 1445, "ThrottleIQ", 40, ink, SANS, tracking=-1))
    o.append(txt(60, 1472, "MACHINE MEMORY FOR MOTORCYCLES", 16, s["t2"], MONO, tracking=2))
    o.append(txt(940, 1450, "ঢাকায় তৈরি", 22, s["t2"], SANS, anchor="end"))
    o.append(txt(940, 1478, "ঢাকার রাস্তার জন্য", 22, s["t2"], SANS, anchor="end"))
    return svg("".join(o), paper)


# ══════════════════════════════════════════════════════════════════
# 05 — BLACK BOX · crash detection · Analyst Blue
# ══════════════════════════════════════════════════════════════════
def p05():
    s = SKINS["analystBlue"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 28, 1.2, .5, "dg5"))
    o.append(rect(0, 0, W, 16, fill=s["danger"]))
    o.append(eyebrow(120, "// IMPACT DETECTED", "T + 00:08", s, s["danger"]))

    o.append(dline(60, 220, "আপনি পড়ে", 96, s["t1"]))
    o.append(dline(60, 344, "গেছেন।", 96, s["danger"]))
    o.append(dline(60, 400, "ফোনে কেউ কল করতে পারবেন না।", 30, s["t2"], font=SANS, weight="normal"))

    # timeline of automatic response
    o.append(line(96, 420, 96, 900, s["line"], 3))
    steps = [("00:00", "IMPACT", "Sensor spike detected", s["danger"]),
             ("00:10", "COUNTDOWN", "“Are you okay?” — no reply", s["att"]),
             ("00:30", "SOS SENT", "3 emergency contacts alerted", s["pri"]),
             ("00:31", "LOCATION", "Live GPS pin shared", s["pri"]),
             ("00:32", "RIDE DATA", "Speed, route, impact — saved", s["pri"])]
    for i, (t, head, sub, col) in enumerate(steps):
        y = 460 + i * 92
        o.append(f'<circle cx="96" cy="{y}" r="14" fill="{s["bg"]}" stroke="{col}" stroke-width="5"/>')
        o.append(f'<circle cx="96" cy="{y}" r="5" fill="{col}"/>')
        o.append(txt(140, y - 6, t, 26, col, MONO, tracking=1))
        o.append(txt(268, y - 4, head, 40, s["t1"], COND, tracking=1))
        o.append(txt(268, y + 30, sub, 24, s["t2"], SANS, weight="normal"))
    o.append(dline(60, 952, "ফোন না ছুঁয়েই সব হয়ে যায়।", 30, s["pri"], font=SANS))

    o.append(line(60, 990, 940, 990, s["line"], 2))
    o.append(dline(60, 1060, "ঢাকায় অ্যাক্সিডেন্ট হলে,", 58, s["t1"]))
    o.append(dline(60, 1120, "সাক্ষী থাকে না। ডেটা থাকবে।", 58, s["pri"]))
    o.append(dline(60, 1158, "ক্র্যাশ ডিটেকশন · অটো SOS · রাইড রেকর্ডিং — অফলাইনে।", 25, s["t2"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1180, 172, s, "street_blackbox", "ফোনটাই হোক", "ব্ল্যাক বক্স। ফ্রি।"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 06 — CREW · community · Nocturne
# ══════════════════════════════════════════════════════════════════
def p06():
    s = SKINS["nocturne"]; o = []
    o.append(f'''<defs><radialGradient id="glow6" cx="50%" cy="34%" r="62%">
      <stop offset="0%" stop-color="{s["pri"]}" stop-opacity="0.20"/>
      <stop offset="100%" stop-color="{s["bg"]}" stop-opacity="0"/></radialGradient></defs>
      <rect width="{W}" height="{H}" fill="url(#glow6)"/>''')
    o.append(dotgrid(0, 0, W, H, s["line"], 32, 1.2, .45, "dg6"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// 2,140 RIDERS ONLINE · DHAKA", "TEA BREAK", s))

    o.append(txt(60, 250, "একলা", 140, s["t1"], COND))
    o.append(dline(60, 392, "চালেন না।", 140, s["pri"]))
    o.append(dline(60, 452, "ঢাকায় ২,১৪০ জন রাইডার একসাথে।", 32, s["t2"], font=SANS, weight="normal"))

    # network constellation
    import math, random
    random.seed(7)
    cx, cy = 500, 640
    nodes = [(cx, cy, 34)]
    for i in range(9):
        a = math.radians(i * 40 + 12); r = 148 + (i % 3) * 58
        nodes.append((cx + r*math.cos(a), cy + r*math.sin(a)*0.52, 15 + (i % 3) * 5))
    for (nx, ny, nr) in nodes[1:]:
        o.append(line(cx, cy, f"{nx:.1f}", f"{ny:.1f}", s["pri"], 2, opacity=.35))
    for i, (nx, ny, nr) in enumerate(nodes):
        col = s["pri"] if i == 0 else s["sec"]
        o.append(f'<circle cx="{nx:.1f}" cy="{ny:.1f}" r="{nr}" fill="{col}" opacity="{1 if i==0 else .85}"/>')
        if i == 0:
            o.append(f'<circle cx="{nx}" cy="{ny}" r="{nr+16}" fill="none" stroke="{s["pri"]}" stroke-width="3" opacity=".5"/>')
    o.append(txt(500, 852, "YOUR CREW · ROUTES · WORKSHOP TIPS", 25, s["t2"], MONO, anchor="middle", tracking=3))

    # feature strip
    feats = [("RIDE GROUPS", "শুক্রবারের রাইড প্ল্যান"), ("FORUMS", "পার্টস, দাম, ফিক্স"),
             ("LIVE SPOTS", "জ্যাম, পুলিশ, গর্ত")]
    for i, (k, v) in enumerate(feats):
        x = 60 + i * 297
        o.append(rect(x, 880, 277, 128, fill=s["surf"], stroke=s["line"], sw=2))
        o.append(rect(x, 880, 277, 6, fill=s["pri"]))
        o.append(txt(x + 20, 936, k, 30, s["t1"], COND, tracking=1))
        o.append(dline(x + 20, 974, v, 23, s["t2"], font=SANS, weight="normal", max_w=240))

    o.append(dline(60, 1084, "ঢাকার রাস্তা একজনে বোঝা যায় না।", 52, s["t1"]))
    o.append(dline(60, 1142, "আপনার ক্রু এখানেই আছে।", 52, s["pri"]))

    o.append(qr_block(60, 1176, 172, s, "community_crew", "ক্রু খুঁজুন।", "একসাথে চালান।"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 07 — HIGHWAY TELEMETRY · 300 Feet & expressways · Editorial Dark
# ══════════════════════════════════════════════════════════════════
def p07():
    s = SKINS["editorialDark"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 28, 1.2, .5, "dg7"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// PURBACHAL EXPRESSWAY · 300 FEET", "TELEMETRY LOG", s))

    o.append(dline(60, 204, "চা স্টলে ১৩০।", 86, s["t1"]))
    o.append(dline(60, 292, "আসল টান কত ছিল?", 86, s["pri"]))
    o.append(dline(60, 344, "মিটারে বাড়িয়ে দেখায়। কিন্তু জিপিএস আর সেন্সর মিথ্যা বলে না।", 27, s["t2"], font=SANS, weight="normal"))

    # HUD instrument display
    o.append(rect(60, 370, 880, 480, fill=s["surf"], stroke=s["line"], sw=2))
    o.append(txt(88, 412, "REAL GPS VELOCITY · SATELLITE DERIVED", 20, s["t3"], MONO, tracking=2))

    # Speed readout
    o.append(txt(300, 546, "118", 170, s["pri"], COND, anchor="middle", tracking=-4))
    o.append(txt(420, 482, "KM/H", 46, s["t1"], COND))
    o.append(txt(420, 518, "PEAK GPS VELOCITY", 20, s["sec"], MONO, tracking=2))
    o.append(txt(420, 546, "Meter error: +14 km/h", 20, s["t3"], MONO))

    # Speed arc / bar strip
    o.append(tick_ruler(88, 574, 824, s["line"], 35, 14, 7, 2))
    o.append(rect(88, 598, 824, 18, fill=s["var"]))
    o.append(rect(88, 598, 610, 18, fill=s["pri"]))
    o.append(line(698, 588, 698, 626, s["sec"], sw=3))
    o.append(txt(698, 650, "^ 118 km/h peak", 18, s["sec"], MONO, anchor="middle"))

    # 4 Telemetry cards
    cards = [("0-60 KM/H", "3.8s", s["pri"]), ("LEAN ANGLE", "34°", s["sec"]),
             ("HARD BRAKES", "0", s["pri"]), ("LOG RATE", "20 Hz", s["t1"])]
    for i, (k, v, c) in enumerate(cards):
        x = 88 + i * 210
        o.append(rect(x, 680, 194, 140, fill=s["var"], stroke=s["line"], sw=1.5))
        o.append(txt(x + 14, 714, k, 17, s["t3"], MONO, tracking=1))
        o.append(txt(x + 14, 786, v, fit(v, 166, 48, COND), c, COND))

    o.append(line(60, 880, 940, 880, s["line"], 2))
    o.append(dline(60, 952, "টানলে বাইক ওড়ে, হিসাব থাকে না।", 56, s["t1"]))
    o.append(dline(60, 1012, "ThrottleIQ প্রতি সেকেন্ডের সত্য বলে।", 56, s["pri"]))
    o.append(dline(60, 1060, "টপ স্পিড · পিকআপ টাইমিং · রুট — ফোন পকেটে থাকলেই অটো রেকর্ড।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1104, "বন্ধুর সাথে স্ক্রিনশট নয়, সরাসরি লাইভ ডেটা কম্পেয়ার করুন।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1156, 180, s, "highway_telemetry", "আপনার আসল স্পিড", "লগ করে দেখুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 08 — PRIVACY SHIELD · residential gates & parking · Calming Dark
# ══════════════════════════════════════════════════════════════════
def p08():
    s = SKINS["calmingDark"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 30, 1.2, .45, "dg8"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// PRIVACY ZONE · 200M GEOFENCE", "SHIELD ACTIVE", s))

    o.append(dline(60, 204, "রাইড ফেসবুকে দিলেন।", 78, s["t1"]))
    o.append(dline(60, 288, "বাসার গলিটাও সবাই চিনে গেল?", 78, s["pri"]))
    o.append(dline(60, 342, "আপনার শখের বাইক রাতে কোন গেটে পার্ক থাকে—সবাই কেন জানবে?", 28, s["t2"], font=SANS, weight="normal"))

    # Radar geofence visual card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))
    cx, cy = 480, 560
    # radar circles
    o.append(f'<circle cx="{cx}" cy="{cy}" r="170" fill="none" stroke="{s["line"]}" stroke-width="1.5" stroke-dasharray="6 6"/>')
    o.append(f'<circle cx="{cx}" cy="{cy}" r="115" fill="{s["pri"]}" fill-opacity="0.10" stroke="{s["pri"]}" stroke-width="3"/>')
    o.append(f'<circle cx="{cx}" cy="{cy}" r="45" fill="none" stroke="{s["sec"]}" stroke-width="1.5"/>')
    o.append(f'<circle cx="{cx}" cy="{cy}" r="9" fill="{s["sec"]}"/>')
    o.append(txt(cx, cy + 34, "HOME PIN", 16, s["sec"], MONO, anchor="middle", tracking=2))

    # route trajectory
    o.append(line(100, 470, 370, 532, s["pri"], 6))
    o.append(f'<circle cx="370" cy="532" r="7" fill="{s["pri"]}"/>')
    o.append(line(370, 532, cx, cy, s["danger"], 4, dash="8 6"))
    o.append(txt(110, 452, "PUBLIC ROUTE [LIVE]", 18, s["pri"], MONO))
    o.append(txt(290, 574, "[AUTO-STRIPPED]", 18, s["danger"], MONO))

    # badge on right
    o.append(rect(630, 480, 280, 110, fill=s["var"], stroke=s["pri"], sw=2, rx=6))
    o.append(txt(650, 518, "200M RADIUS CUT", 20, s["pri"], MONO, tracking=1))
    o.append(txt(650, 550, "First & last 200 meters", 17, s["t1"], SANS))
    o.append(txt(650, 574, "never broadcasted", 17, s["t3"], SANS))

    # status row
    o.append(line(88, 750, 912, 750, s["line"], 1))
    o.append(txt(88, 794, "GEOFENCE ENGINE", 18, s["t3"], MONO, tracking=1))
    o.append(txt(88, 822, "AUTOMATIC STRIP ACTIVE", 24, s["pri"], MONO))
    o.append(txt(912, 822, "ZERO LEAKS · 100% PRIVATE", 22, s["sec"], MONO, anchor="end"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "সোশ্যালে রাইড শেয়ার করুন নিশ্চিন্তে।", 54, s["t1"]))
    o.append(dline(60, 1004, "আপনার বাসার গেট থাকবে সুরক্ষিত।", 54, s["pri"]))
    o.append(dline(60, 1052, "ThrottleIQ বাসার আগের ২০০ মিটার নিজে থেকেই রুট থেকে মুছে ফেলে।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "অডিয়েন্স কন্ট্রোল · অফলাইন প্রোটেকশন · কোনো ট্র্যাকার আপনার বাসা দেখবে না।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "privacy_shield", "বাসার গেট লুকিয়ে", "রাইড শেয়ার করুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 09 — RESALE PASSPORT · Banglamotor & used bike shops · Editorial Light
# ══════════════════════════════════════════════════════════════════
def p09():
    s = SKINS["editorialLight"]; o = []
    ink = s["t1"]
    o.append(rect(24, 24, W - 48, H - 48, fill="none", stroke=s["line"], sw=2))
    o.append(eyebrow(120, "// DIGITAL BIKE PASSPORT · TSAL VERIFIED", "PASSPORT #8814", s, s["pri"]))

    o.append(dline(60, 204, "মিটার ঘুরানো যায়।", 86, s["t1"]))
    o.append(dline(60, 292, "আসল হিস্ট্রি ঘুরাবেন কেমনে?", 86, s["pri"]))
    o.append(dline(60, 344, "“এক হাত চালানো ভাই”—মুখের কথায় বাইক কেনাবেচা বন্ধ হোক।", 28, s["t2"], font=SANS, weight="normal"))

    # Certificate card
    o.append(rect(60, 370, 880, 480, fill=s["surf"], stroke=ink, sw=3))
    # banner
    o.append(rect(60, 370, 880, 52, fill=ink))
    o.append(txt(88, 404, "MACHINE MEMORY · VERIFIED VEHICLE PASSPORT", 20, s["surf"], MONO, tracking=2))
    o.append(txt(912, 404, "VERIFIED", 20, s["sec"], MONO, anchor="end", tracking=2))

    # mileage hero
    o.append(txt(88, 468, "TOTAL DISTANCE LOGGED (GPS VERIFIED)", 18, s["t3"], MONO, tracking=1))
    o.append(txt(88, 552, "34,210", 96, ink, COND))
    o.append(txt(410, 532, "KM", 40, s["pri"], COND))

    # badge
    o.append(rect(610, 440, 302, 110, fill=s["var"], stroke=s["pri"], sw=2))
    o.append(txt(761, 482, "TAMPER-PROOF", 20, s["pri"], MONO, anchor="middle", tracking=2))
    o.append(txt(761, 520, "IMMUTABLE SQLITE LOG", 16, s["t2"], MONO, anchor="middle"))

    # inspection rows
    o.append(line(88, 584, 912, 584, s["line"], 2))
    rows = [("ON-TIME SERVICE", "96% COMPLIANCE", "14 of 15 service cycles logged", s["pri"]),
            ("CRASH SPIKES", "0 DETECTED", "Chassis & sensor logs clean", s["pri"]),
            ("ENGINE HOURS", "840 HOURS", "Zero prolonged idle heat spikes", ink)]
    for i, (head, val, sub, col) in enumerate(rows):
        y = 632 + i * 56
        o.append(txt(88, y, head, 20, s["t3"], MONO))
        o.append(txt(380, y, val, 22, col, COND))
        o.append(txt(620, y, sub, 19, s["t2"], SANS, weight="normal"))
        if i < 2:
            o.append(line(88, y + 18, 912, y + 18, s["line"], 1, opacity=.6))

    o.append(rect(88, 768, 824, 56, fill=s["var"]))
    o.append(txt(108, 804, "PASSPORT ID: BFT-7719-DHAKA · READY FOR RESALE", 19, s["t2"], MONO))

    o.append(line(60, 880, 940, 880, s["line"], 2))
    o.append(dline(60, 950, "বাইক বেচতে গেলে ক্রেতা দাম কমাবে কেন?", 54, s["t1"]))
    o.append(dline(60, 1010, "কবে কী সার্ভিস হয়েছে—এক ক্লিকে প্রুফ দেখান।", 54, s["pri"]))
    o.append(dline(60, 1058, "ডিজিটাল সার্ভিস বুক · জিপিএস ভেরিফাইড কিমি · রিসেল ভ্যালু প্রটেকশন।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1100, "বাংলা মটরে যাওয়ার আগে নিজের বাইকের ফুল হিস্ট্রি নিজের পকেটে রাখুন।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "resale_passport", "বাইকের আসল ডেটা", "লগ করে রাখুন",
                      frame_c=ink, qr_dark=ink))
    o.append(line(60, 1400, 940, 1400, ink, 3))
    o.append(txt(60, 1445, "ThrottleIQ", 40, ink, SANS, tracking=-1))
    o.append(txt(60, 1472, "MACHINE MEMORY FOR MOTORCYCLES", 16, s["t2"], MONO, tracking=2))
    o.append(txt(940, 1450, "ঢাকায় তৈরি", 22, s["t2"], SANS, anchor="end"))
    o.append(txt(940, 1478, "ঢাকার রাস্তার জন্য", 22, s["t2"], SANS, anchor="end"))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 10 — OFFLINE DEAD ZONE · mountain trails & tours · Carbon Mono
# ══════════════════════════════════════════════════════════════════
def p10():
    s = SKINS["carbonMono"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 26, 1.2, .55, "dg10"))
    o.append(hazard(0, 0, W, 22, s["pri"], s["bg"], 16, 45, 1, "hz10"))
    o.append(eyebrow(120, "// MOUNTAIN TRAIL · 0 CELLULAR BARS", "LOCAL STORAGE ENGAGED", s))

    o.append(dline(60, 204, "টাওয়ার নাই?", 88, s["t1"]))
    o.append(dline(60, 294, "ThrottleIQ-র নেট লাগে না।", 88, s["pri"]))
    o.append(dline(60, 344, "পাহাড়ে নেটওয়ার্ক শেষ হতে পারে। কিন্তু বাইকের রেকর্ড বন্ধ হবে না।", 28, s["t2"], font=SANS, weight="normal"))

    # Card container
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Cell tower vs Satellite
    o.append(rect(88, 396, 380, 166, fill=s["var"], stroke=s["danger"], sw=2))
    o.append(txt(112, 434, "CELLULAR NETWORK", 20, s["danger"], MONO, tracking=1))
    o.append(txt(112, 490, "NO SERVICE", 44, s["danger"], COND))
    o.append(txt(112, 532, "[ X  X  X  X ] 0 BARS · DEAD ZONE", 18, s["t3"], MONO))

    o.append(rect(532, 396, 380, 166, fill=s["var"], stroke=s["pri"], sw=2))
    o.append(txt(556, 434, "GPS SATELLITE ARRAY", 20, s["pri"], MONO, tracking=1))
    o.append(txt(556, 490, "LOCKED", 44, s["pri"], COND))
    o.append(txt(556, 532, "[ |||||||||||| ] 14 BIRDS IN VIEW", 18, s["pri"], MONO))

    # Pipeline visualization
    o.append(rect(88, 590, 824, 130, fill=s["bg"], stroke=s["line"], sw=2))
    o.append(txt(112, 628, "OFFLINE DATA PIPELINE · ZERO DATA CONSUMPTION", 18, s["t3"], MONO, tracking=1))
    o.append(txt(112, 680, "SENSORS", 32, s["t1"], COND))
    o.append(txt(285, 680, "-->", 28, s["pri"], MONO))
    o.append(txt(355, 680, "LOCAL SQLITE", 32, s["pri"], COND))
    o.append(txt(605, 680, "-->", 28, s["pri"], MONO))
    o.append(txt(675, 680, "AUTO SYNC", 32, s["t2"], COND))

    o.append(txt(112, 770, "BUFFERED: 14,820 DATA POINTS", 22, s["pri"], MONO))
    o.append(txt(888, 770, "MOBILE DATA USED: 0.00 KB", 22, s["t1"], MONO, anchor="end"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "অন্যান্য অ্যাপ নেটের আশায় হাঁসফাঁস করে।", 54, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ পুরোপুরি অফলাইনে চলে।", 54, s["pri"]))
    o.append(dline(60, 1052, "মেঘে ঢাকা সাঝেক হোক বা চিম্বুকের জঙ্গল—আপনার পুরো রাইড সুরক্ষিত থাকবে।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "জিরো এমবি খরচ · জিরো ডেটা লস · নেট ফিরলে অটোমেটিক ক্লাউড সিঙ্ক।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "offline_deadzone", "নেট ছাড়াই ফুল রাইড", "ট্র্যাক করুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 11 — FATIGUE ALERT · highway rest stops & dhabas · Trail Social
# ══════════════════════════════════════════════════════════════════
def p11():
    s = SKINS["trailSocial"]; o = []
    o.append(hazard(0, 0, W, H, s["bg"], s["surf"], 50, 45, 1, "hz11"))
    o.append(rect(0, 0, W, H, fill=s["bg"], opacity=.6))
    o.append(rect(0, 0, W, 14, fill=s["pri"]) )
    o.append(eyebrow(120, "// HIGHWAY REST STOP · FATIGUE MONITOR", "ALERT: BREAK DUE", s, s["danger"]))

    o.append(dline(60, 204, "টানা দেড় ঘণ্টা সিটে।", 86, s["t1"]))
    o.append(dline(60, 292, "রিফ্লেক্স কিন্তু স্লো হয়ে গেছে।", 86, s["pri"]))
    o.append(dline(60, 344, "হাইওয়েতে সামান্য চোখের পলক মানেই জীবনের ঝুঁকি। একটু থামুন, চা খান।", 27, s["t2"], font=SANS, weight="normal"))

    # Saddle clock card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Clock box
    o.append(rect(88, 396, 450, 160, fill=s["var"], stroke=s["pri"], sw=2))
    o.append(txt(112, 432, "CONTINUOUS SADDLE TIME", 18, s["t3"], MONO, tracking=2))
    o.append(txt(112, 514, "01:32:45", 72, s["pri"], MONO))
    o.append(txt(112, 542, "NON-STOP HIGHWAY RUN", 18, s["sec"], MONO))

    # Fatigue meter
    o.append(rect(562, 396, 350, 160, fill=s["var"], stroke=s["danger"], sw=2))
    o.append(txt(586, 432, "FATIGUE SEVERITY", 18, s["danger"], MONO, tracking=2))
    o.append(txt(586, 500, "+40%", 64, s["danger"], COND))
    o.append(txt(586, 540, "REACTION DELAY ESTIMATED", 18, s["t2"], MONO))

    # Recommended pitstop
    o.append(rect(88, 580, 824, 130, fill=s["bg"], stroke=s["line"], sw=2))
    o.append(txt(112, 620, "RECOMMENDED PITSTOP", 18, s["pri"], MONO, tracking=2))
    o.append(txt(112, 672, "NOORJAHAN DHABA · 4 KM AHEAD", 34, s["t1"], COND))
    o.append(txt(112, 700, "১৫ মিনিট বিশ্রাম নিন। গরম চা আর এক কাপ পানি খান।", 24, s["t2"], SANS, weight="normal"))

    o.append(txt(112, 764, "FATIGUE ALERT GATED AT 90 MIN", 20, s["t3"], MONO))
    o.append(txt(912, 764, "SAFELY HOME > FAST ARRIVAL", 22, s["pri"], MONO, anchor="end"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "একটানা চালালে মনে হয় ঠিক আছেন,", 54, s["t1"]))
    o.append(dline(60, 1004, "কিন্তু হাত-চোখের টাইমিং ঠিক থাকে না।", 54, s["pri"]))
    o.append(dline(60, 1052, "ThrottleIQ খেয়াল রাখে আপনি কতক্ষণ সিটে আছেন—সময়মতো সতর্ক করে।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "স্মার্ট ফ্যাটিগ অ্যালার্ট · রুট সেফটি · সুস্থভাবে গন্তব্যে পৌঁছান।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "fatigue_alert", "ট্যুরিংয়ের জন্য", "ফ্রি সেফটি টুল"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 12 — GROUP BEACON · weekend rides & morning meetups · Nocturne
# ══════════════════════════════════════════════════════════════════
def p12():
    s = SKINS["nocturne"]; o = []
    o.append(f'''<defs><radialGradient id="glow12" cx="50%" cy="36%" r="65%">
      <stop offset="0%" stop-color="{s["pri"]}" stop-opacity="0.22"/>
      <stop offset="100%" stop-color="{s["bg"]}" stop-opacity="0"/></radialGradient></defs>
      <rect width="{W}" height="{H}" fill="url(#glow12)"/>''')
    o.append(dotgrid(0, 0, W, H, s["line"], 30, 1.2, .45, "dg12"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// FRIDAY MORNING RIDE · 8 BIKES", "SHARED RADAR LIVE", s))

    o.append(dline(60, 204, "“দোস্ত তুই কই?”", 90, s["t1"]))
    o.append(dline(60, 292, "— আর কত ফোন করবেন?", 90, s["pri"]))
    o.append(dline(60, 344, "গ্রুপ রাইডে কে আগে, কে পিছে—হাইওয়েতে দাঁড়িয়ে চিৎকার না করে স্ক্রিনে দেখুন।", 27, s["t2"], font=SANS, weight="normal"))

    # Card container
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Route ribbon
    o.append(f'<path d="M 120,720 Q 300,600 500,530 T 880,430" fill="none" stroke="{s["line"]}" stroke-width="32" stroke-linecap="round"/>')
    o.append(f'<path d="M 120,720 Q 300,600 500,530 T 880,430" fill="none" stroke="{s["var"]}" stroke-width="12" stroke-linecap="round"/>')

    # Leader beacon (Ahead)
    o.append(f'<circle cx="820" cy="445" r="18" fill="{s["sec"]}"/>')
    o.append(f'<circle cx="820" cy="445" r="28" fill="none" stroke="{s["sec"]}" stroke-width="2" opacity=".6"/>')
    o.append(rect(610, 395, 185, 52, fill=s["bg"], stroke=s["sec"], sw=1.5, rx=4))
    o.append(txt(625, 420, "LEADER · TANVIR", 18, s["sec"], MONO))
    o.append(txt(625, 440, "2.8 km ahead", 16, s["t2"], MONO))

    # Rider beacon (You)
    o.append(f'<circle cx="500" cy="530" r="22" fill="{s["pri"]}"/>')
    o.append(f'<circle cx="500" cy="530" r="34" fill="none" stroke="{s["pri"]}" stroke-width="3" opacity=".7"/>')
    o.append(rect(405, 455, 185, 52, fill=s["bg"], stroke=s["pri"], sw=1.5, rx=4))
    o.append(txt(420, 480, "YOU (IN PACK)", 18, s["pri"], MONO))
    o.append(txt(420, 500, "Speed: 72 km/h", 16, s["t2"], MONO))

    # Mid pack rider
    o.append(f'<circle cx="320" cy="600" r="14" fill="{s["pri"]}" opacity=".8"/>')

    # Sweeper beacon (Rear)
    o.append(f'<circle cx="160" cy="705" r="18" fill="{s["att"]}"/>')
    o.append(f'<circle cx="160" cy="705" r="28" fill="none" stroke="{s["att"]}" stroke-width="2" opacity=".6"/>')
    o.append(rect(195, 685, 185, 52, fill=s["bg"], stroke=s["att"], sw=1.5, rx=4))
    o.append(txt(210, 710, "SWEEPER · HASAN", 18, s["att"], MONO))
    o.append(txt(210, 730, "Rear guard intact", 16, s["t2"], MONO))

    # Radar status row
    o.append(line(88, 770, 912, 770, s["line"], 1))
    o.append(txt(88, 810, "GROUP SESSION: MAWA RUN #12", 20, s["t1"], MONO))
    o.append(txt(912, 810, "8 BIKES CONNECTED · 0 LOST", 22, s["pri"], MONO, anchor="end"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "হোয়াটসঅ্যাপ লোকেশন চেয়ে রাইড নষ্ট করবেন না।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ গ্রুপ রাইডে সবাইকে এক ম্যাপে রাখে।", 52, s["pri"]))
    o.append(dline(60, 1052, "সিগন্যালে আটকে যাওয়া বা টায়ার পাংচার—কেউ কখনো হারিয়ে যাবে না।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "রিয়েল-টাইম বিকন · শেয়ার্ড রুট · স্ক্রিনশট ছাড়াই নিখুঁত ট্র্যাকিং।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "group_beacon", "গ্রুপের লাইভ ম্যাপ", "স্ক্রিনে দেখুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])



# ══════════════════════════════════════════════════════════════════
# 13 — FAMILY SAFETY · residential gates & campuses · Calming Dark
# ══════════════════════════════════════════════════════════════════
def p13():
    s = SKINS["calmingDark"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 28, 1.2, .45, "dg13"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// FAMILY SAFETY NETWORK · REALTIME PROTOCOL", "DISPATCH READY", s))

    o.append(dline(60, 204, "প্রিয়জন কি বাইকার বলে চিন্তিত?", 76, s["t1"]))
    o.append(dline(60, 292, "নো টেনশন। ThrottleIQ আছে।", 76, s["pri"]))
    o.append(dline(60, 344, "বাইক রাস্তায় নামলেই বাসায় অস্থিরতা? লাইভ সেফটি স্ট্যাটাস আর বিপদে প্রথম কল যাবে পরিবারের কাছেই।", 26, s["t2"], font=SANS, weight="normal"))

    # Family Safety Dispatch Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Top Status Bar
    o.append(rect(88, 396, 824, 76, fill=s["var"], stroke=s["pri"], sw=1.5, rx=6))
    o.append(f'<circle cx="120" cy="434" r="9" fill="{s["pri"]}"/>')
    o.append(txt(145, 442, "STATUS: SAFE & MONITORED", 22, s["pri"], MONO))
    o.append(txt(620, 442, "SPEED: 42 KM/H · GENTLE", 20, s["t1"], MONO))
    o.append(txt(888, 442, "BATT: 84%", 20, s["sec"], MONO, anchor="end"))

    # Emergency Protocol Box
    o.append(rect(88, 492, 824, 210, fill=s["bg"], stroke=s["line"], sw=2))
    o.append(txt(112, 530, "AUTOMATIC EMERGENCY DISPATCH PROTOCOL", 18, s["t3"], MONO, tracking=2))
    o.append(txt(112, 576, "FALL & CRASH SENSORS: ARMED", 26, s["t1"], COND))
    o.append(txt(112, 614, "If severe impact (>3.2G) detected, system automatically triggers:", 19, s["t2"], SANS, weight="normal"))

    # 3 Dispatch steps
    steps = [("1. VOICE CALL", "Primary Contact: Ammu"),
             ("2. SOS SMS + GPS", "Exact Map Coordinates"),
             ("3. BLOOD GROUP", "Rider Profile Auto-Sent")]
    for i, (k, v) in enumerate(steps):
        x = 112 + i * 265
        o.append(rect(x, 630, 248, 56, fill=s["var"], stroke=s["pri"], sw=1, rx=4))
        o.append(txt(x + 12, 654, k, 15, s["pri"], MONO))
        o.append(txt(x + 12, 674, v, 14, s["t1"], SANS, weight="normal"))

    # Lower reassurance banner
    o.append(rect(88, 722, 824, 94, fill=s["var"], stroke=s["pri"], sw=1.5))
    o.append(txt(112, 758, "BACKGROUND GUARDIAN · ZERO BATTERY DRAIN", 18, s["sec"], MONO, tracking=1))
    o.append(txt(112, 792, "রাইডারকে বারবার কল না দিয়েও পরিবার থাকবে ১০০% নিশ্চিন্ত।", 22, s["t1"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "বারবার ফোনে কল দিয়ে রাইডারকে ডিস্টার্ব করবেন না।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ আপনজনকে রাখে প্রতি মুহূর্তের আপডেটে।", 52, s["pri"]))
    o.append(dline(60, 1052, "রাইড শেষ হলে অটো মেসেজ—আপনার প্রিয় মানুষটি নিরাপদে বাড়ি ফিরেছে।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "অটো ক্র্যাশ অ্যালার্ট · লাইভ সেফটি বিকন · পরিবারের ১০০% নিশ্চিন্ততা।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "family_safety", "প্রিয়জনের সুরক্ষায়", "ThrottleIQ নামান"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 14 — LOST BIKER · highway group ride · Carbon Mono
# ══════════════════════════════════════════════════════════════════
def p14():
    s = SKINS["carbonMono"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 26, 1.2, .55, "dg14"))
    o.append(hazard(0, 0, W, 22, s["pri"], s["bg"], 16, 45, 1, "hz14"))
    o.append(eyebrow(120, "// CONVOY COMMUNICATIONS · AUDIO vs RADAR", "RADAR HUD ACTIVE", s))

    o.append(dline(60, 204, "“বন্ধু তুমি কই, কই, কই??”", 84, s["pri"]))
    o.append(dline(60, 292, "ফোনে গান না গেয়ে, ড্যাশবোর্ডে দেখুন।", 72, s["t1"]))
    o.append(dline(60, 344, "হাইওয়েতে দলছুট হয়ে বারবার ফোন কেটে যাওয়া আর চিল্লামিল্লি নয়—স্ক্রিনেই পুরো কনভয় লাইভ।", 26, s["t2"], font=SANS, weight="normal"))

    # Visual Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Left: Audio Failure Box
    o.append(rect(88, 396, 380, 240, fill=s["var"], stroke=s["danger"], sw=2))
    o.append(txt(112, 434, "THE OLD WAY: PHONE CALL", 18, s["danger"], MONO, tracking=1))
    o.append(txt(112, 480, "INCOMING CALL...", 28, s["danger"], COND))
    o.append(txt(112, 514, "TANVIR (LOST AT FLYOVER)", 18, s["t2"], MONO))
    o.append(txt(112, 560, "“দোস্ত তুই কই রে?! হ্যালো?!”", 24, s["t1"], SANS))
    o.append(txt(112, 600, "[ CALL DROPPED · WIND NOISE ]", 18, s["danger"], MONO))

    # Right: ThrottleIQ Radar Box
    o.append(rect(490, 396, 422, 240, fill=s["var"], stroke=s["pri"], sw=2))
    o.append(txt(514, 434, "THROTTLEIQ LIVE RADAR HUD", 18, s["pri"], MONO, tracking=1))
    o.append(txt(514, 480, "6 BIKES IN CONVOY", 28, s["pri"], COND))
    o.append(txt(514, 524, "• TANVIR: 850m AHEAD (AT PUMP)", 18, s["t1"], MONO))
    o.append(txt(514, 558, "• NABIL: 1.4km BEHIND (65 KM/H)", 18, s["t2"], MONO))
    o.append(txt(514, 592, "• YOU: MID-PACK FORMATION", 18, s["sec"], MONO))

    # Bottom strip: Zero Calls Needed
    o.append(rect(88, 660, 824, 156, fill=s["bg"], stroke=s["line"], sw=2))
    o.append(txt(112, 700, "CONVOY TELEMETRY · ZERO DISTRACTION RIDING", 18, s["pri"], MONO, tracking=1))
    o.append(txt(112, 746, "নো কল · নো ইন্টারনেট লস · স্ক্রিনে তাকালেই সবাই সামনে-পেছনে।", 24, s["t1"], SANS, weight="normal"))
    o.append(txt(112, 786, "এক হাত হ্যান্ডেলে আর এক হাত ফোনে রেখে জীবন ঝুঁকিতে ফেলবেন না।", 22, s["t3"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "এক হাতে হ্যান্ডেল আর আরেক হাতে ফোন ধরা বন্ধ করুন।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ স্ক্রিনে এক নজরেই পুরো গ্রুপ ক্লিয়ার।", 52, s["pri"]))
    o.append(dline(60, 1052, "সিগন্যালে কে পেছনে পড়ল আর কে পেট্রোল পাম্পে থামল—সব লাইভ।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "অফলাইন কনভয় বিকন · লাইভ রাডার · কোনো রাইডার আর হারাবে না।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "bondhu_koi", "কনভয় না হারিয়ে", "ফ্রি অ্যাপ নামান"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 15 — GENTLE BIKER PROOF · campus & family gates · Editorial Dark
# ══════════════════════════════════════════════════════════════════
def p15():
    s = SKINS["editorialDark"]; o = []
    o.append(rect(24, 24, W - 48, H - 48, fill="none", stroke=s["line"], sw=2))
    o.append(eyebrow(120, "// RIDER TELEMETRY VERIFICATION", "CERTIFIED GENTLE RIDER", s, s["pri"]))

    o.append(dline(60, 204, "বাসায় ভাবে আপনি বাইক নিয়ে উড়েন?", 74, s["t1"]))
    o.append(dline(60, 292, "অথচ আপনি তো ভদ্র রাইডার!", 74, s["pri"]))
    o.append(dline(60, 344, "সবার ধারণা আপনি রকেট চালান? বাবা, মা, বউ, ভাই বা দুলাভাই—যাকে খুশি লাইভ লিংক পাঠান।", 27, s["t2"], font=SANS, weight="normal"))

    # Certificate Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["pri"], sw=2))

    # Certificate Title Bar
    o.append(rect(60, 370, 880, 50, fill=s["var"]))
    o.append(txt(88, 404, "OFFICIAL GENTLE RIDER TELEMETRY CERTIFICATE", 20, s["pri"], MONO, tracking=2))
    o.append(txt(912, 404, "100% VERIFIED", 20, s["sec"], MONO, anchor="end", tracking=2))

    # Left Stats Column
    stats = [("LEGAL SPEED ADHERENCE", "98.8%", s["pri"]),
             ("TOP SPEED TODAY", "48 KM/H", s["t1"]),
             ("HARSH BRAKING EVENTS", "0 TIMES", s["sec"]),
             ("LEAN ANGLE STABILITY", "< 18° UPRIGHT", s["pri"])]
    for i, (k, v, col) in enumerate(stats):
        x = 88 + (i % 2) * 250
        y = 440 + (i // 2) * 90
        o.append(rect(x, y, 235, 76, fill=s["bg"], stroke=s["line"], sw=1.5))
        o.append(txt(x + 12, y + 26, k, 13, s["t3"], MONO, tracking=1))
        o.append(txt(x + 12, y + 60, v, 24, col, COND))

    # Right Audience Box
    o.append(rect(600, 440, 312, 166, fill=s["bg"], stroke=s["line"], sw=1.5))
    o.append(txt(618, 470, "SHARED REASSURANCE LINK", 16, s["t3"], MONO, tracking=1))
    o.append(txt(618, 504, "[✓] বাবা  [✓] মা  [✓] বউ", 20, s["t1"], SANS))
    o.append(txt(618, 540, "[✓] ভাই  [✓] দুলাভাই  [✓] বোন", 20, s["t1"], SANS))
    o.append(txt(618, 580, "Phone Battery: 88% · Safe at 40 km/h", 15, s["pri"], MONO))

    # Bottom Quote Strip
    o.append(rect(88, 626, 824, 190, fill=s["var"], stroke=s["line"], sw=1.5))
    o.append(txt(112, 664, "REAL-TIME TELEMETRY SHARING FOR WORRIED FAMILIES", 18, s["sec"], MONO, tracking=1))
    o.append(txt(112, 712, "“বাসার মানুষ নিজেই দেখুক আপনি কত সাবধানে আর ভদ্রভাবে বাইক চালান।”", 24, s["t1"], SANS, weight="normal"))
    o.append(txt(112, 756, "স্পিড, লোকেশন, ব্যাটারি ও রুট—সব রিয়েলটাইম লিংকে দেখা যায়, অ্যাপ ছাড়াই।", 22, s["t2"], SANS, weight="normal"))
    o.append(txt(112, 792, "অযথা ফোনে বকাঝকা খাওয়া বন্ধ। এবার প্রমাণ দিন ডেটা দিয়ে।", 20, s["t3"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "অযথা বাসার সন্দেহ আর বকাঝকা কেন সহ্য করবেন?", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ দিয়ে পরিবারকে দেখান আপনার শান্ত রাইড।", 52, s["pri"]))
    o.append(dline(60, 1052, "লাইভ লোকেশন, স্পিড আর সেফটি লগ শেয়ার করুন এক ট্যাপে।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "ভদ্র রাইডারের খাঁটি প্রমাণ · ফ্যামিলি শেয়ারিং · ১০০% নিশ্চিন্ত পরিবার।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "gentle_biker", "বাসার সবাইকে নিশ্চিন্ত", "রাখতে স্ক্যান করুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 16 — TOURING FUEL PURITY · highway toll & pump exits · Genesis
# ══════════════════════════════════════════════════════════════════
def p16():
    s = SKINS["genesis"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 30, 1.2, .5, "dg16"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// HIGHWAY FUEL DIRECTORY · OCTANE PURITY AUDIT", "CROWD-VERIFIED", s))

    o.append(dline(60, 204, "ট্যুরে হাইওয়েতে তেলের টেনশন?", 78, s["t1"]))
    o.append(dline(60, 292, "কোন পাম্পের তেল খাঁটি?", 78, s["pri"]))
    o.append(dline(60, 344, "অচেনা রাস্তায় পানি মেশানো তেল ভরে ইঞ্জিন নকিং? ThrottleIQ-তে খাঁটি পাম্প চিনে নিন।", 27, s["t2"], font=SANS, weight="normal"))

    # Station comparison card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Station 1: Verified Good
    o.append(rect(88, 396, 824, 180, fill=s["var"], stroke=s["pri"], sw=2))
    o.append(txt(112, 434, "PADMA EXPRESSWAY REST PLAZA · KM 32", 18, s["t3"], MONO, tracking=1))
    o.append(txt(112, 480, "4.9 ★★★★★ (VERIFIED OCTANE)", 32, s["pri"], COND))
    o.append(txt(112, 518, "• Density: 742 kg/m³ · 0 Water Detected · Engine Runs Smooth", 19, s["t1"], SANS, weight="normal"))
    o.append(txt(112, 552, "• 24/7 bKash & Card Accepted · Clean Washroom · Free Air", 19, s["t2"], SANS, weight="normal"))

    # Station 2: Warning Bad
    o.append(rect(88, 592, 824, 150, fill=s["bg"], stroke=s["danger"], sw=2))
    o.append(txt(112, 628, "UNBRANDED HIGHWAY PUMP · KM 84", 18, s["danger"], MONO, tracking=1))
    o.append(txt(112, 672, "2.1 ★☆☆☆☆ (POOR FUEL WARNING)", 30, s["danger"], COND))
    o.append(txt(112, 712, "• 38 Tourers reported engine knocking & severe mileage drop (-14%)", 19, s["t2"], SANS, weight="normal"))

    # Bottom status badge
    o.append(rect(88, 756, 824, 60, fill=s["var"]))
    o.append(txt(112, 794, "DATABASE: 1,240+ BANGLADESH HIGHWAY PUMPS AUDITED BY RIDERS", 18, s["sec"], MONO))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "ভেজাল তেল একবার ঢুকলে পুরো ইঞ্জিন ডাউন।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ-তে দেখুন কোন পাম্পে খাঁটি তেল।", 52, s["pri"]))
    o.append(dline(60, 1052, "হাজারো বাইকারদের দেওয়া লাইভ রেটিং, মাইলেজ ইমপ্যাক্ট আর আসল রিভিউ।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "ভেরিফায়েড হাইওয়ে পাম্প · ভেজালমুক্ত ফুয়েল ডিরেক্টরি · নিরাপদ ট্যুর।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "tour_fuel", "খাঁটি তেলের পাম্প", "খুঁজে নিন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 17 — CHAPABAJ PROOF · 300ft roadside & tea stalls · Trail Social
# ══════════════════════════════════════════════════════════════════
def p17():
    s = SKINS["trailSocial"]; o = []
    o.append(hazard(0, 0, W, H, s["bg"], s["surf"], 50, 45, 1, "hz17"))
    o.append(rect(0, 0, W, H, fill=s["bg"], opacity=.6))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// TELEMETRY VS CHAPABAJI · BRAKE DECELERATION LOG", "PHYSICS AUDIT", s))

    o.append(dline(60, 198, "“তারপর মামা, ১৫০ স্পিড থেকে", 76, s["t1"]))
    o.append(dline(60, 276, "২ হাতে ব্রেক মাইরা ০ নামাইসি!”", 76, s["pri"]))
    o.append(dline(60, 334, "এমন চাপাবাজ বন্ধুর কাছে প্রমাণ চান? পারলে ThrottleIQ-র ডাটা লগ দেখাইতে বলেন!", 27, s["t2"], font=SANS, weight="normal"))

    # Comparison card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # The Braggart's Tale
    o.append(rect(88, 396, 824, 160, fill=s["var"], stroke=s["danger"], sw=2))
    o.append(txt(112, 432, "THE TEA STALL CLAIM (চাপাবাজির গল্প)", 18, s["danger"], MONO, tracking=1))
    o.append(txt(112, 480, "150 KM/H -> 0 KM/H IN 1 METER (২ হাত)", 32, s["danger"], COND))
    o.append(txt(112, 520, "PHYSICS AUDIT: -88.6G DECELERATION REQUIRED · RIDER LAUNCHED INTO ORBIT", 18, s["t1"], MONO))

    # The ThrottleIQ Reality
    o.append(rect(88, 574, 824, 244, fill=s["bg"], stroke=s["pri"], sw=2))
    o.append(txt(112, 612, "THROTTLEIQ 6-AXIS IMU TELEMETRY (আসল ডাটা)", 18, s["pri"], MONO, tracking=1))
    o.append(txt(112, 664, "ACTUAL INITIAL SPEED: 68 KM/H (NOT 150)", 28, s["t1"], COND))
    o.append(txt(112, 706, "STOPPING DISTANCE: 21.8 METERS · TIME: 2.1s", 22, s["sec"], MONO))
    o.append(txt(112, 746, "PEAK BRAKING FORCE: -0.74G (CONTROLLED HARD BRAKE)", 20, s["pri"], MONO))
    o.append(txt(112, 790, "VERDICT: ভালো ড্রাইভ, কিন্তু ১০০% খাঁটি চাপাবাজি ধরা খেয়ে গেছে।", 22, s["t2"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "চা স্টলের ফাঁকা আওয়াজ অনেক হয়েছে।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ থাকলে ব্রেক আর স্পিডের খাঁটি প্রমাণ থাকে।", 52, s["pri"]))
    o.append(dline(60, 1052, "অ্যাক্সিলারেশন, ব্রেকিং জি-ফোর্স আর রিয়েল স্পিড মিটার—কোনো ফাঁকিবাজি নাই।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "আইএমইউ সেন্সর লগিং · নিখুঁত ব্রেক অ্যানালাইসিস · প্রমাণের সাথে আড্ডা।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "chapabaj_proof", "চাপাবাজি বন্ধ,", "প্রমাণ লগ দেখুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 18 — BIKER REUNION · cafes & weekend hubs · Nocturne
# ══════════════════════════════════════════════════════════════════
def p18():
    s = SKINS["nocturne"]; o = []
    o.append(f'''<defs><radialGradient id="glow18" cx="50%" cy="36%" r="65%">
      <stop offset="0%" stop-color="{s["pri"]}" stop-opacity="0.22"/>
      <stop offset="100%" stop-color="{s["bg"]}" stop-opacity="0"/></radialGradient></defs>
      <rect width="{W}" height="{H}" fill="url(#glow18)"/>''')
    o.append(dotgrid(0, 0, W, H, s["line"], 30, 1.2, .45, "dg18"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// BIKER REUNION RADAR · COMMUNITY DISCOVERY", "FIND OLD CREWS", s))

    o.append(dline(60, 204, "বহুদিন পুরনো রাইডার বন্ধুর খোঁজ নাই?", 74, s["t1"]))
    o.append(dline(60, 292, "ThrottleIQ-তে আসেন, একসাথে চিল করি!", 74, s["pri"]))
    o.append(dline(60, 344, "আগের সেই রাইডিং পার্টনার এখন কোথায় ঘুরে? দেখুন সে কোন ক্যাফে রেটিং দিয়েছে আর কবে বের হচ্ছে।", 26, s["t2"], font=SANS, weight="normal"))

    # Discovery Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Old Crew Profile
    o.append(rect(88, 396, 824, 180, fill=s["var"], stroke=s["pri"], sw=1.5))
    o.append(txt(112, 432, "OLD RIDING BUDDY FOUND: TANVIR (PULSAR NS 160)", 18, s["sec"], MONO, tracking=1))
    o.append(txt(112, 480, "RECOMMENDED CAFÉ: “300FT ROASTERS” · 4.9 ★", 30, s["pri"], COND))
    o.append(txt(112, 518, "• Note: “বাইক পার্কিং সুপার সেফ, ফ্রেশ কফি আর মাঝরাতের পরোটা বেস্ট”", 20, s["t1"], SANS, weight="normal"))
    o.append(txt(112, 552, "• Last ride logged: 82 km to Mawa Ghat · Average pace: 58 km/h", 18, s["t2"], MONO))

    # Upcoming group plan
    o.append(rect(88, 592, 824, 140, fill=s["bg"], stroke=s["line"], sw=1.5))
    o.append(txt(112, 628, "POPULAR WEEKEND ROUTES FROM YOUR NETWORK", 18, s["t3"], MONO, tracking=1))
    o.append(txt(112, 672, "1. DHAKA -> MAWA SUNRISE RUN (42 RIDERS ACTIVE THIS FRIDAY)", 22, s["t1"], COND))
    o.append(txt(112, 706, "2. PURBACHAL EXPRESSWAY NIGHT CHILL (28 RIDERS CHECKED IN)", 22, s["pri"], COND))

    # Connect strip
    o.append(rect(88, 746, 824, 70, fill=s["var"]))
    o.append(txt(112, 788, "TAP TO RECONNECT · DISCOVER CAFES · RIDE TOGETHER AGAIN", 18, s["sec"], MONO))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "রাইডের পুরোনো স্মৃতিগুলো আবার তাজা হোক।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ দিয়ে পুরনো রাইডারদের খুঁজে নিন।", 52, s["pri"]))
    o.append(dline(60, 1052, "বুকের ভেতর আবার ইঞ্জিনের গর্জন তুলুন—নতুন ক্যাফে আর রুটে একসাথে ঘুরুন।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "কমিউনিটি ডিসকভারি · ক্যাফে রিভিউ · ফ্রাইডে মর্নিং রাইড রিইউনিয়ন।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "biker_reunion", "পুরোনো ক্রুর সাথে", "রিইউনিয়ন করুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 19 — AI CAMERA RADAR · flyovers & expressways · Carbon Mono
# ══════════════════════════════════════════════════════════════════
def p19():
    s = SKINS["carbonMono"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 26, 1.2, .55, "dg19"))
    o.append(hazard(0, 0, W, 22, s["pri"], s["bg"], 16, 45, 1, "hz19"))
    o.append(eyebrow(120, "// SPEED TRAP RADAR · SMART ROAD INTELLIGENCE", "AUTOMATED HUD", s))

    o.append(dline(60, 204, "AI ক্যামেরা নিয়ে ভয়?", 88, s["t1"]))
    o.append(dline(60, 292, "আর নয়! ThrottleIQ আছে সাথে।", 86, s["pri"]))
    o.append(dline(60, 344, "ফ্লাইওভার আর এক্সপ্রেসওয়েতে কোথায় এআই ক্যামেরা বসে আছে—স্ক্রিনেই আগাম সতর্কবার্তা।", 27, s["t2"], font=SANS, weight="normal"))

    # HUD Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Camera Alert Box
    o.append(rect(88, 396, 824, 220, fill=s["var"], stroke=s["pri"], sw=2))
    o.append(txt(112, 434, "RADAR DETECTION: AUTOMATED ANPR SPEED TRAP", 18, s["danger"], MONO, tracking=1))
    o.append(txt(112, 486, "MAYOR HANIF FLYOVER · PILLAR 18 (350M AHEAD)", 32, s["t1"], COND))
    o.append(line(112, 508, 888, 508, s["line"], 1))

    o.append(txt(112, 550, "ZONE SPEED LIMIT", 16, s["t3"], MONO))
    o.append(txt(112, 592, "60 KM/H", 38, s["danger"], COND))

    o.append(txt(380, 550, "YOUR CURRENT SPEED", 16, s["t3"], MONO))
    o.append(txt(380, 592, "54 KM/H", 38, s["pri"], COND))

    o.append(txt(660, 550, "RADAR STATUS", 16, s["t3"], MONO))
    o.append(txt(660, 592, "[ SAFE PASS ]", 34, s["pri"], COND))

    # Lower Stats
    o.append(rect(88, 634, 824, 182, fill=s["bg"], stroke=s["line"], sw=2))
    o.append(txt(112, 672, "AUTOMATED FINE PREVENTION ENGINE", 18, s["sec"], MONO, tracking=1))
    o.append(txt(112, 718, "• অফলাইন ক্যামেরা ডাটাবেস—নেট না থাকলেও ৫০০ মিটার আগে অডিও বিপ।", 22, s["t1"], SANS, weight="normal"))
    o.append(txt(112, 756, "• অযথা ৩,০০০ টাকার ট্রাফিক কেস খাওয়ার আগে স্পিড নিয়ন্ত্রণে আনুন।", 22, s["t2"], SANS, weight="normal"))
    o.append(txt(112, 792, "SAVED RIDERS OVER TK 14,00,000 IN UNNECESSARY FINES", 18, s["pri"], MONO))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "অজান্তে স্পিড উঠে মামলা খাওয়ার দিন শেষ।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ আপনাকে আগেই সাবধান করে দেয়।", 52, s["pri"]))
    o.append(dline(60, 1052, "কমিউনিটি ড্রাইভেন ক্যামেরা পয়েন্ট—আইন মেনে চলুন, নিরাপদে বাড়ি ফিরুন।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "স্পিড ট্র্যাপ অ্যালার্ট · লাইভ ক্যামেরা পয়েন্ট · অনাকাঙ্ক্ষিত কেস থেকে বাঁচুন।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "ai_camera", "ক্যামেরা অ্যালার্ট পেতে", "ThrottleIQ নামান"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 20 — PER-KM RUNNING COST · ride share & delivery hubs · Editorial Light
# ══════════════════════════════════════════════════════════════════
def p20():
    s = SKINS["editorialLight"]; o = []
    ink = s["t1"]
    o.append(rect(24, 24, W - 48, H - 48, fill="none", stroke=s["line"], sw=2))
    o.append(eyebrow(120, "// RIDE ECONOMICS AUDIT · PER-KM EXPENSE BREAKDOWN", "REAL PROFIT CHECK", s, s["pri"]))

    o.append(dline(60, 198, "“১০০ টাকা ভাড়া, ৩০ টাকার তেল—", 72, s["t1"]))
    o.append(dline(60, 276, "৭০ টাকা লাভ?” ভুল হিসাব!", 76, s["danger"]))
    o.append(dline(60, 334, "মোবিল, চেইন লুব, টায়ার আর সার্ভিস খরচ হিসাব করবেন কে? ThrottleIQ রাখে আসল হিসাব।", 27, s["t2"], font=SANS, weight="normal"))

    # Expense Receipt Card
    o.append(rect(60, 370, 880, 480, fill=s["surf"], stroke=ink, sw=3))
    o.append(rect(60, 370, 880, 48, fill=ink))
    o.append(txt(88, 402, "ITEMIZED TRIP RUNNING COST AUDIT (8.0 KM RUN)", 18, s["surf"], MONO, tracking=2))
    o.append(txt(912, 402, "COMMUTER RECEIPT", 18, s["sec"], MONO, anchor="end"))

    # Rows of expenses
    items = [
        ("PASSENGER FARE COLLECTED (8.0 KM TRIP)", "+ Tk 100.00", s["pri"]),
        ("OCTANE CONSUMED (0.24L @ TK 125/L)", "- Tk  30.00", ink),
        ("ENGINE OIL DEPRECIATION (8 KM / 1200 KM LIFE)", "- Tk   4.20", ink),
        ("DRIVE CHAIN LUBE & WEAR RESERVE", "- Tk   0.80", ink),
        ("TYRE WEAR & BRAKE PAD CONSUMPTION", "- Tk   3.50", ink),
        ("PERIODIC TUNING & AIR FILTER RESERVE", "- Tk   2.50", ink),
    ]
    for i, (name, val, col) in enumerate(items):
        y = 444 + i * 44
        o.append(txt(88, y, name, 19, s["t2"], MONO))
        o.append(txt(912, y, val, 22, col, COND, anchor="end"))
        o.append(line(88, y + 12, 912, y + 12, s["line"], 1, opacity=.5))

    # Total Box
    o.append(rect(88, 710, 824, 120, fill=s["var"], stroke=ink, sw=2))
    o.append(txt(112, 750, "ACTUAL NET PROFIT: Tk 59.00 (NOT Tk 70!)", 32, s["danger"], COND))
    o.append(txt(112, 792, "TRUE RUNNING COST: Tk 5.12 / KM · EARNING: Tk 12.50 / KM", 19, ink, MONO))

    o.append(line(60, 880, 940, 880, ink, 2))
    o.append(dline(60, 950, "শুধু তেলের হিসাব করলে দিনশেষে লসে থাকবেন।", 52, s["t1"]))
    o.append(dline(60, 1010, "ThrottleIQ প্রতি কিলোমিটারের পাই টু পাই খরচ রাখে।", 52, s["pri"]))
    o.append(dline(60, 1058, "রাইড শেয়ারিং বা ডেলিভারি—কবে মোবিল বদলাবেন আর আসল লাভ কত, সব ক্লিয়ার।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1100, "প্রতি কিমি খাঁটি কস্টিং · মেইনটেন্যান্স ট্র্যাকার · স্মার্ট বাইকারদের আসল হিসাব।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "cost_per_km", "আসল খরচ ও লাভ", "হিসাব করুন",
                      frame_c=ink, qr_dark=ink))
    o.append(footer(s, ink))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 21 — SUZUKI GIXXER BENCHMARK · service hubs & Bangshal · Analyst Blue
# ══════════════════════════════════════════════════════════════════
def p21():
    s = SKINS["analystBlue"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 28, 1.2, .5, "dg21"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// SUZUKI GIXXER COMMUNITY METRICS", "REAL-WORLD BENCHMARK", s))

    o.append(dline(60, 204, "এই যে ভাই, বাকি Gixxer মালিকরা", 76, s["t1"]))
    o.append(dline(60, 292, "কত মাইলেজ পায় জানেন?", 76, s["pri"]))
    o.append(dline(60, 344, "ঢাকায় অন্য গিক্সার কত কিলোমিটার চলে? সেরা টিউনিং মিস্ত্রি কোথায়? জানুন ThrottleIQ-তে।", 27, s["t2"], font=SANS, weight="normal"))

    # Diagnostic Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Gixxer Header
    o.append(rect(88, 396, 824, 52, fill=s["var"]))
    o.append(txt(112, 430, "SUZUKI GIXXER 155 (CARB & FI) · DHAKA FLEET BENCHMARK", 18, s["pri"], MONO, tracking=1))
    o.append(txt(888, 430, "1,420 BIKES SYNCED", 18, s["t3"], MONO, anchor="end"))

    # Two big stat boxes
    o.append(rect(88, 466, 395, 160, fill=s["bg"], stroke=s["pri"], sw=1.5))
    o.append(txt(112, 502, "CITY TRAFFIC MILEAGE", 16, s["t3"], MONO))
    o.append(txt(112, 560, "38.4", 62, s["pri"], COND))
    o.append(txt(255, 542, "KM/L (FI)", 22, s["t1"], COND))
    o.append(txt(112, 600, "Carburetor avg: 34.2 km/l", 17, s["t2"], MONO))

    o.append(rect(517, 466, 395, 160, fill=s["bg"], stroke=s["sec"], sw=1.5))
    o.append(txt(541, 502, "HIGHWAY CRUISE MILEAGE", 16, s["t3"], MONO))
    o.append(txt(541, 560, "46.5", 62, s["sec"], COND))
    o.append(txt(685, 542, "KM/L", 22, s["t1"], COND))
    o.append(txt(541, 600, "Purbachal & Mawa runs", 17, s["t2"], MONO))

    # Top Workshop & Pro-tip Box
    o.append(rect(88, 644, 824, 172, fill=s["var"], stroke=s["line"], sw=1.5))
    o.append(txt(112, 680, "COMMUNITY VERIFIED WORKSHOP & PREVENTIVE ALERT", 18, s["sec"], MONO, tracking=1))
    o.append(txt(112, 726, "• TOP WORKSHOP: SUZUKI MASTER, MIRPUR 10 · 4.9 ★ (84 REVIEWS)", 22, s["t1"], COND))
    o.append(txt(112, 764, "• কমন ইস্যু: ৮০০ কিমি পরপর চেইন স্ল্যাক হয়। সময়মতো লুব করার রিমাইন্ডার সেট রাখুন।", 22, s["t2"], SANS, weight="normal"))
    o.append(txt(112, 796, "আপনার গিক্সারের পারফর্মেন্স অন্য সবার চেয়ে ভালো না খারাপ—নিজে দেখুন।", 19, s["pri"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "অন্যদের চেয়ে আপনার গিক্সারে মাইলেজ কম আসছে?", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ-তে দেখুন কোন গ্যারেজে পারফেক্ট টিউনিং।", 52, s["pri"]))
    o.append(dline(60, 1052, "হাজারো গিক্সার রাইডারের আসল ডেটা দেখে বাইকের সর্বোচ্চ পারফর্মেন্স বের করুন।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "গিক্সার কমিউনিটি ডেটা · আসল মাইলেজ · সেরা সার্ভিসের সন্ধান।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "gixxer_benchmark", "গিক্সারের আসল ডাটা", "দেখুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 22 — YAMAHA FZ-S BENCHMARK · Tejgaon & Mirpur hubs · Trail Social
# ══════════════════════════════════════════════════════════════════
def p22():
    s = SKINS["trailSocial"]; o = []
    o.append(hazard(0, 0, W, H, s["bg"], s["surf"], 50, 45, 1, "hz22"))
    o.append(rect(0, 0, W, H, fill=s["bg"], opacity=.6))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// YAMAHA FZ-S FI (V2/V3/V4) FLEET", "OWNER TELEMETRY", s))

    o.append(dline(60, 204, "FZ-S ভাইয়েরা, জ্যামে আপনার বাইক", 74, s["t1"]))
    o.append(dline(60, 292, "আসলে কত মাইলেজ দিচ্ছে?", 76, s["pri"]))
    o.append(dline(60, 344, "মিটারের ডিসপ্লে আর আসল ড্রপের পার্থক্য কত? কোন গ্যারেজে খাঁটি কাজ হয়? জানুন এক ক্লিকে।", 26, s["t2"], font=SANS, weight="normal"))

    # Diagnostic Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Header
    o.append(rect(88, 396, 824, 52, fill=s["var"]))
    o.append(txt(112, 430, "YAMAHA FZ-S FI (V2/V3/V4) · FLEET TELEMETRY AUDIT", 18, s["pri"], MONO, tracking=1))
    o.append(txt(888, 430, "2,150 BIKES SYNCED", 18, s["t3"], MONO, anchor="end"))

    # Meter vs Tank-to-Tank
    o.append(rect(88, 466, 395, 160, fill=s["bg"], stroke=s["sec"], sw=1.5))
    o.append(txt(112, 502, "CONSOLE METER DISPLAY", 16, s["t3"], MONO))
    o.append(txt(112, 560, "44.0", 62, s["sec"], COND))
    o.append(txt(255, 542, "KM/L", 22, s["t1"], COND))
    o.append(txt(112, 600, "Optimistic digital readout", 17, s["t2"], MONO))

    o.append(rect(517, 466, 395, 160, fill=s["bg"], stroke=s["pri"], sw=1.5))
    o.append(txt(541, 502, "REAL TANK-TO-TANK (GPS)", 16, s["t3"], MONO))
    o.append(txt(541, 560, "39.6", 62, s["pri"], COND))
    o.append(txt(685, 542, "KM/L", 22, s["t1"], COND))
    o.append(txt(541, 600, "True traffic consumption", 17, s["t2"], MONO))

    # Workshop & Tip Box
    o.append(rect(88, 644, 824, 172, fill=s["var"], stroke=s["line"], sw=1.5))
    o.append(txt(112, 680, "WORKSHOP VERIFICATION & INJECTOR MAINTENANCE", 18, s["pri"], MONO, tracking=1))
    o.append(txt(112, 726, "• TOP WORKSHOP: YAMAHA POINT, TEJGAON · 4.8 ★ (RATED BY 142 RIDERS)", 22, s["t1"], COND))
    o.append(txt(112, 764, "• সার্ভিস টিপস: প্রতি ৭,৫০০ কিমিতে FI ইনজেক্টর ক্লিনিং করালে ইঞ্জিন মসৃণ থাকে।", 22, s["t2"], SANS, weight="normal"))
    o.append(txt(112, 796, "টায়ার প্রেশার ৩৩ PSI রাখলে জ্যামেও ৪০+ মাইলেজ পাওয়া সম্ভব।", 19, s["sec"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "স্মুথনেস ঠিক রাখতে মিস্ত্রিদের মিষ্টি কথায় ভুলবেন না।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ-তে দেখুন FZ-S স্পেশালিস্ট গ্যারেজ।", 52, s["pri"]))
    o.append(dline(60, 1052, "আসল মাইলেজ, রাইডার রিভিউ আর সার্ভিস রিমাইন্ডারে বাইক থাকবে নতুনের মতো।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "এফজেড-এস ওনার ডাটা · খাঁটি মাইলেজ · সেরা মেকানিক চয়েস।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "fzs_benchmark", "FZ-S এর আসল মাইলেজ", "যাচাই করুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 23 — YAMAHA R15 BENCHMARK · sportbike tracks & 300ft · Editorial Dark
# ══════════════════════════════════════════════════════════════════
def p23():
    s = SKINS["editorialDark"]; o = []
    o.append(rect(24, 24, W - 48, H - 48, fill="none", stroke=s["line"], sw=2))
    o.append(eyebrow(120, "// YAMAHA R15 RACING TELEMETRY", "LEAN & VELOCITY AUDIT", s, s["pri"]))

    o.append(dline(60, 204, "R15 নিয়ে ছুটছেন?", 88, s["t1"]))
    o.append(dline(60, 292, "আসল টপ-স্পিড আর পার্টস চেনেন?", 76, s["pri"]))
    o.append(dline(60, 344, "স্পিডোমিটারের স্পিড আর জিপিএস ট্রু স্পিড এক না! খাঁটি স্পেয়ার পার্টস গ্যারেজ কোথায়?", 27, s["t2"], font=SANS, weight="normal"))

    # R15 Telemetry Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["pri"], sw=2))

    # Header
    o.append(rect(60, 370, 880, 50, fill=s["var"]))
    o.append(txt(88, 404, "YAMAHA R15 (V3 / V4 / M) · TRACK & ROAD TELEMETRY", 18, s["pri"], MONO, tracking=2))
    o.append(txt(912, 404, "890 TRACKERS ACTIVE", 18, s["sec"], MONO, anchor="end"))

    # Speedo vs GPS
    o.append(rect(88, 440, 395, 170, fill=s["bg"], stroke=s["sec"], sw=1.5))
    o.append(txt(112, 476, "SPEEDO CLUSTER DISPLAY", 16, s["t3"], MONO))
    o.append(txt(112, 540, "144", 68, s["sec"], COND))
    o.append(txt(245, 520, "KM/H", 24, s["t1"], COND))
    o.append(txt(112, 584, "Speedo error: +10.4 km/h", 17, s["t2"], MONO))

    o.append(rect(517, 440, 395, 170, fill=s["bg"], stroke=s["pri"], sw=1.5))
    o.append(txt(541, 476, "TRUE GPS SATELLITE VELOCITY", 16, s["t3"], MONO))
    o.append(txt(541, 540, "133.6", 68, s["pri"], COND))
    o.append(txt(735, 520, "KM/H", 24, s["t1"], COND))
    o.append(txt(541, 584, "Actual physical road velocity", 17, s["t2"], MONO))

    # Lean Angle & Genuine Parts
    o.append(rect(88, 630, 824, 186, fill=s["var"], stroke=s["line"], sw=1.5))
    o.append(txt(112, 666, "PEAK LEAN ANGLE & GENUINE PARTS PROTECTION", 18, s["pri"], MONO, tracking=1))
    o.append(txt(112, 712, "• MAX LEAN ANGLE LOGGED: 46.4° (IMU SENSOR VERIFIED · SAFE ZONE)", 22, s["t1"], COND))
    o.append(txt(112, 750, "• সেরা পারফর্মেন্স গ্যারেজ: APEX TUNING LAB, BANGLAMOTOR · 4.9 ★", 22, s["t2"], SANS, weight="normal"))
    o.append(txt(112, 786, "ফেইক স্পেয়ার পার্টস অ্যালার্ট: ৩টি ভুয়া ব্রেক প্যাড বিক্রেতাকে ফ্ল্যাগ করেছে রাইডাররা।", 20, s["danger"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "ট্র্যাকে আর রাস্তায় খাঁটি পারফর্মেন্সের প্রমাণ রাখুন।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ দিয়ে R15-এর আসল ক্ষমতা মাপুন।", 52, s["pri"]))
    o.append(dline(60, 1052, "লিন অ্যাঙ্গেল, ০-১০০ টাইমিং আর ১০০% অথেনটিক পার্টস গ্যারেজের সন্ধান।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "আর১৫ স্পোর্টস টেলমেট্রি · খাঁটি স্পিড · জেনুইন পার্টস ডিরেক্টরি।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "r15_benchmark", "R15 টেলমেট্রি ও গ্যারেজ", "লগ দেখুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 24 — BAJAJ PULSAR BENCHMARK · commuter routes & Banglamotor · Genesis
# ══════════════════════════════════════════════════════════════════
def p24():
    s = SKINS["genesis"]; o = []
    o.append(dotgrid(0, 0, W, H, s["line"], 30, 1.2, .5, "dg24"))
    o.append(rect(0, 0, W, 14, fill=s["pri"]))
    o.append(eyebrow(120, "// BAJAJ PULSAR OWNER FLEET", "15+ YEARS COMMUTER BENCHMARK", s))

    o.append(dline(60, 204, "পালসার ভাইয়েরা, ১৫ বছর ধরে তো চালাচ্ছেন—", 66, s["t1"]))
    o.append(dline(60, 286, "মাইলেজ আর মেইনটেন্যান্স ঠিক আছে তো?", 68, s["pri"]))
    o.append(dline(60, 340, "ঢাকার জ্যামে পালসার কত মাইলেজ দিচ্ছে? ইঞ্জিন না খুলেই আসল রোগ ধরে কোন মিস্ত্রি? জানুন।", 26, s["t2"], font=SANS, weight="normal"))

    # Diagnostic Card
    o.append(rect(60, 370, 880, 470, fill=s["surf"], stroke=s["line"], sw=2))

    # Header
    o.append(rect(88, 396, 824, 52, fill=s["var"]))
    o.append(txt(112, 430, "BAJAJ PULSAR (150 UG / NS 160) · FLEET TELEMETRY AUDIT", 18, s["pri"], MONO, tracking=1))
    o.append(txt(888, 430, "3,800 RIDERS CONNECTED", 18, s["t3"], MONO, anchor="end"))

    # Stats: Pulsar 150 vs NS 160
    o.append(rect(88, 466, 395, 160, fill=s["bg"], stroke=s["pri"], sw=1.5))
    o.append(txt(112, 502, "PULSAR 150 (CITY TRAFFIC)", 16, s["t3"], MONO))
    o.append(txt(112, 560, "41.5", 62, s["pri"], COND))
    o.append(txt(255, 542, "KM/L", 22, s["t1"], COND))
    o.append(txt(112, 600, "Highway cruising: 48.2 km/l", 17, s["t2"], MONO))

    o.append(rect(517, 466, 395, 160, fill=s["bg"], stroke=s["sec"], sw=1.5))
    o.append(txt(541, 502, "PULSAR NS 160 (CITY TRAFFIC)", 16, s["t3"], MONO))
    o.append(txt(541, 560, "36.8", 62, s["sec"], COND))
    o.append(txt(685, 542, "KM/L", 22, s["t1"], COND))
    o.append(txt(541, 600, "Highway cruising: 44.0 km/l", 17, s["t2"], MONO))

    # Top Mechanic & Diagnostic Tip
    o.append(rect(88, 644, 824, 172, fill=s["var"], stroke=s["line"], sw=1.5))
    o.append(txt(112, 680, "LEGENDARY COMMUTER SERVICE & SOUND DIAGNOSTIC", 18, s["pri"], MONO, tracking=1))
    o.append(txt(112, 726, "• সেরা মিস্ত্রি: ওস্তাদ শহিদ, বাংলা মটর · ৪.৮ ★ (১৫ বছরের পালসার এক্সপার্ট)", 22, s["t1"], SANS, weight="normal"))
    o.append(txt(112, 764, "• সাউন্ড ডায়াগনস্টিক: ইঞ্জিনের ট্যাফেট লুজ হলে মাত্র ৩০০ টাকায় ফিক্স—হেড খোলার দরকার নেই।", 22, s["t2"], SANS, weight="normal"))
    o.append(txt(112, 796, "ThrottleIQ-তে দেখুন আপনার পালসারের সার্ভিস আর আসল মাইলেজ হিসাব।", 19, s["sec"], SANS, weight="normal"))

    o.append(line(60, 870, 940, 870, s["line"], 2))
    o.append(dline(60, 944, "সবচেয়ে বিশ্বস্ত বাইকটার জন্য বেস্ট যত্ন নিন।", 52, s["t1"]))
    o.append(dline(60, 1004, "ThrottleIQ-তে দেখুন আসল মাইলেজ আর রেটিং।", 52, s["pri"]))
    o.append(dline(60, 1052, "ঢাকার সেরা পালসার মেকানিক আর পার্টসের খাঁটি ঠিকানা জেনে রাখুন আগেভাগেই।", 27, s["t2"], font=SANS, weight="normal"))
    o.append(dline(60, 1096, "পালসার ওনার বেঞ্চমার্ক · বিশ্বস্ত মেকানিক · সঠিক মাইলেজ লগিং।", 25, s["t3"], font=SANS, weight="normal"))

    o.append(qr_block(60, 1150, 180, s, "pulsar_benchmark", "পালসারের আসল ডাটা", "জানুন"))
    o.append(footer(s))
    return svg("".join(o), s["bg"])


POSTERS = [("01-jam-counter-signal", p01), ("02-pump-maintenance", p02),
           ("03-garage-proof", p03), ("04-rate-it-review", p04),
           ("05-black-box-safety", p05), ("06-crew-community", p06),
           ("07-highway-telemetry", p07), ("08-privacy-shield", p08),
           ("09-resale-passport", p09), ("10-offline-deadzone", p10),
           ("11-fatigue-alert", p11), ("12-group-beacon", p12),
           ("13-family-safety", p13), ("14-lost-biker-singing", p14),
           ("15-gentle-biker-proof", p15), ("16-touring-fuel-purity", p16),
           ("17-chapabaj-telemetry", p17), ("18-old-biker-reunion", p18),
           ("19-ai-camera-radar", p19), ("20-per-km-cost", p20),
           ("21-gixxer-benchmark", p21), ("22-fzs-benchmark", p22),
           ("23-r15-benchmark", p23), ("24-pulsar-benchmark", p24)]

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "svg")
    os.makedirs(out, exist_ok=True)
    for name, fn in POSTERS:
        with open(f"{out}/{name}.svg", "w") as f:
            f.write(fn())
        print("wrote", name)

