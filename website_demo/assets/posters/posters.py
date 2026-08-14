# -*- coding: utf-8 -*-
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

BASE = "https://throttleiq.app/get"

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


POSTERS = [("01-jam-counter-signal", p01), ("02-pump-maintenance", p02),
           ("03-garage-proof", p03), ("04-rate-it-review", p04),
           ("05-black-box-safety", p05), ("06-crew-community", p06)]

if __name__ == "__main__":
    out = "/sessions/happy-sleepy-goodall/mnt/outputs/gen/out"
    os.makedirs(out, exist_ok=True)
    for name, fn in POSTERS:
        with open(f"{out}/{name}.svg", "w") as f:
            f.write(fn())
        print("wrote", name)
