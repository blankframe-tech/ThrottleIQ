# -*- coding: utf-8 -*-
"""ThrottleIQ street posters — V2: one visual, one gut-punch line, a QR code.

No instrument panels, no service logs. One big illustration that reads from
across the street, 1-2 lines of Bangla big enough to catch a red light, and a
QR in the bottom-right corner. Clickbait is allowed here on purpose.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from illus import *

BASE = "https://blankframe.tech/ThrottleIQ/install"


def dline(x, y, s, size, fill, font=COND, max_w=880, tracking=0, anchor="start", weight="bold"):
    fs = fit(s, max_w, size, font, weight == "bold", tracking)
    return txt(x, y, s, fs, fill, font, weight=weight, anchor=anchor, tracking=tracking)


def headline(lines, skin, y0=224, gap=132, size=116, max_w=880, x=60, anchor="start"):
    o = []
    y = y0
    for i, ln in enumerate(lines):
        c = skin["t1"] if i < len(lines) - 1 else skin["pri"]
        o.append(dline(x, y, ln, size, c, max_w=max_w, anchor=anchor))
        y += gap
    return "".join(o)


def qr_corner(skin, campaign, size=176, margin=54, qr_dark=None):
    x, y = W - margin - size, H - margin - size
    c = skin["pri"]
    qd = qr_dark or "#000000"
    o = [rect(x - 10, y - 10, size + 20, size + 20, fill=c)]
    o.append(qr_svg(f"{BASE}?c={campaign}_v2", x, y, size, dark=qd, light="#FFFFFF", uid=campaign + "v2"))
    o.append(txt(x + size / 2, y - 24, "SCAN · GET THE APP", 19, c, MONO, anchor="middle", tracking=1))
    return "".join(o)


def wordmark(skin, tag):
    c = skin["pri"]
    o = [txt(60, H - 88, "ThrottleIQ", 40, c, SANS, tracking=-1)]
    o.append(txt(60, H - 56, tag, 16, skin["t3"], MONO, tracking=2))
    return "".join(o)


def base_bg(skin, gx=520, gy=860, gr=680, opacity=0.45, uid="g"):
    return glow(gx, gy, gr, skin["pri"], opacity, uid)


def frame(skin, num, lines, campaign, tag, art, glow_xy=(520, 860), glow_r=680, glow_op=0.45):
    s = skin
    o = [base_bg(s, glow_xy[0], glow_xy[1], glow_r, glow_op, f"g{num}")]
    o.append(art)
    o.append(headline(lines, s))
    o.append(qr_corner(s, campaign))
    o.append(wordmark(s, tag))
    return svg("".join(o), s["bg"])


# ══════════════════════════════════════════════════════════════════
# 01 — signal jam · Carbon Mono
def p01():
    s = SKINS["carbonMono"]
    art = (traffic_light(560, 760, 1.8, s["pri"], s["bg"], 12, red_on=True) +
           rider(300, 1160, 1.55, s["pri"], s["bg"], 12, expr="sleepy", arm="down"))
    return frame(s, 1, ["৪৭ মিনিট", "আজকে জ্যামে গেল।"], "signal_jam",
                 "RIDE-LOGGING THAT COUNTS YOUR TIME", art, glow_xy=(560, 740))


# 02 — pump maintenance · Genesis
def p02():
    s = SKINS["genesis"]
    art = fuel_pump(500, 800, 2.0, s["pri"], s["bg"], 13, drip=True)
    return frame(s, 2, ["ট্যাংক ফুল।", "চেইন শুকনা।"], "pump_maint",
                 "TK 400 NOW OR TK 12,000 LATER", art, glow_xy=(500, 760))


# 03 — garage proof · Trail Social
def p03():
    s = SKINS["trailSocial"]
    art = wrench_check(500, 800, 2.15, s["pri"], s["bg"], 12)
    return frame(s, 3, ["সব চেঞ্জ করেছি,", "প্রমাণ দিন।"], "garage_proof",
                 "EVERY SERVICE, LOGGED AND TIMESTAMPED", art, glow_xy=(500, 780))


# 04 — rate it review · Retro
def p04():
    s = SKINS["retro"]
    art = (rect(70, 620, 860, 480, fill="none", stroke=s["pri"], sw=6) +
           stars_burst(500, 860, 2.1, s["pri"], s["bg"], 10, count=5, filled=4))
    return frame(s, 4, ["এই গ্যারেজ কেমন?", "৩০ সেকেন্ডে রেট করুন।"], "review_garage",
                 "RATE IT BEFORE THE NEXT RIDER GETS ROBBED", art, glow_xy=(500, 860), glow_op=0.18)


# 05 — black box safety · Analyst Blue
def p05():
    s = SKINS["analystBlue"]
    art = (black_box(560, 740, 1.8, s["pri"], s["bg"], 12) +
           rider(360, 1160, 1.5, s["danger"], s["bg"], 12, expr="shock", arm="up", lean=-18))
    return frame(s, 5, ["আপনি পড়ে গেছেন।", "৩২ সেকেন্ড পর কী হলো?"], "street_blackbox",
                 "AUTO CRASH DETECTION, OFFLINE", art, glow_xy=(500, 720))


# 06 — crew community · Nocturne
def p06():
    s = SKINS["nocturne"]
    art = (rider(180, 1180, 0.9, s["t3"], s["bg"], 11, expr="neutral") +
           rider(430, 1215, 1.5, s["pri"], s["bg"], 13, expr="grin", arm="point") +
           rider(600, 1170, 0.9, s["sec"], s["bg"], 11, expr="neutral"))
    return frame(s, 6, ["একলা চালান?", "ক্রুতে চালান।"], "community_crew",
                 "FIND YOUR RIDING CREW NEARBY", art, glow_xy=(500, 820))


# 07 — highway telemetry · Editorial Dark
def p07():
    s = SKINS["editorialDark"]
    art = (speedo_dial(560, 720, 2.0, s["pri"], s["bg"], 12, frac=0.94, label="KM/H") +
           rider(280, 1180, 1.3, s["t1"], s["bg"], 12, expr="grin", lean=-8) +
           speed_lines(120, 1160, 3, 130, 26, 12, s["pri"], 0.7, 180))
    return frame(s, 7, ["চা স্টলে বললেন ১৩০।", "আসল স্পিড কত ছিল?"], "highway_telemetry",
                 "REAL TOP SPEED, LOGGED EVERY RIDE", art, glow_xy=(520, 760))


# 08 — privacy shield · Calming Dark
def p08():
    s = SKINS["calmingDark"]
    art = shield_pin(500, 800, 2.0, s["pri"], s["bg"], 12, eye_off=True)
    return frame(s, 8, ["রাইড ফেসবুকে দিলেন।", "বাসার গলিও চিনে ফেলল?"], "privacy_shield",
                 "AUTO-BLURRED START AND END POINTS", art, glow_xy=(500, 800))


# 09 — resale passport · Editorial Light
def p09():
    s = SKINS["editorialLight"]
    art = passport(500, 800, 2.25, s["pri"], s["surf"], 12)
    return frame(s, 9, ["মিটার ঘুরানো যায়।", "হিস্ট্রি ঘুরাবেন কীভাবে?"], "resale_passport",
                 "A BIKE'S FULL SERVICE HISTORY, PORTABLE", art, glow_xy=(500, 800), glow_op=0.16)


# 10 — offline deadzone · Carbon Mono
def p10():
    s = SKINS["carbonMono"]
    art = (mountain(500, 920, 2.05, s["pri"], s["bg"], 10) +
           phone_nosignal(790, 580, 1.25, s["danger"], s["bg"], 11))
    return frame(s, 10, ["টাওয়ার নাই?", "নেট ছাড়াই চলে।"], "offline_deadzone",
                 "ZERO SIGNAL. ZERO DATA LOSS.", art, glow_xy=(500, 820))


# 11 — fatigue alert · Trail Social
def p11():
    s = SKINS["trailSocial"]
    art = (rider(420, 1160, 1.5, s["pri"], s["bg"], 13, expr="sleepy", arm="down") +
           alarm_bell(790, 560, 1.05, s["danger"], s["bg"], 11))
    return frame(s, 11, ["দেড় ঘণ্টা টানা রাইড।", "চোখ কি ভারী হচ্ছে?"], "fatigue_alert",
                 "SMART FATIGUE ALERTS ON LONG HAULS", art, glow_xy=(500, 780))


# 12 — group beacon · Nocturne
def p12():
    s = SKINS["nocturne"]
    art = (radar_rings(500, 760, 1.9, s["pri"], s["bg"]) +
           rider(500, 760, 0.55, s["t1"], s["bg"], 16, expr="neutral"))
    return frame(s, 12, ["“দোস্ত তুই কই?”", "আর কত ফোন দেবেন?"], "group_beacon",
                 "LIVE BEACON FOR THE WHOLE GROUP", art, glow_xy=(500, 760))


# 13 — family safety · Calming Dark
def p13():
    s = SKINS["calmingDark"]
    art = heart_pin(500, 800, 2.35, s["pri"], s["bg"], 12)
    return frame(s, 13, ["বাসার মানুষ চিন্তিত?", "লাইভ লোকেশনে নিশ্চিন্ত।"], "family_safety",
                 "SHARE A LIVE, SAFE LOCATION LINK", art, glow_xy=(500, 800))


# 14 — lost biker singing · Carbon Mono
def p14():
    s = SKINS["carbonMono"]
    art = (rider(420, 1180, 1.6, s["pri"], s["bg"], 13, expr="sing", arm="up") +
           music_notes(680, 600, 1.1, s["pri"], s["bg"]))
    return frame(s, 14, ["বন্ধু তুমি কই, কই, কই?", "গান না গেয়ে ড্যাশবোর্ড দেখুন।"], "bondhu_koi",
                 "SHARE YOUR LIVE ROUTE, NOT GUESSES", art, glow_xy=(500, 800))


# 15 — gentle biker proof · Editorial Dark
def p15():
    s = SKINS["editorialDark"]
    art = (rider(420, 1160, 1.75, s["pri"], s["bg"], 13, expr="calm", arm="up") +
           speedo_dial(800, 620, 1.1, s["sec"], s["bg"], 10, frac=0.28, label="KM/H"))
    return frame(s, 15, ["বাসায় ভাবে উড়েন?", "আপনি তো ভদ্র রাইডার!"], "gentle_biker",
                 "PROOF OF YOUR ACTUAL RIDING STYLE", art, glow_xy=(480, 780))


# 16 — touring fuel purity · Genesis
def p16():
    s = SKINS["genesis"]
    art = fuel_drop(500, 800, 2.1, s["pri"], s["bg"], 12, good=True)
    return frame(s, 16, ["হাইওয়েতে কোন পাম্পের", "তেল খাঁটি?"], "tour_fuel",
                 "VERIFIED FUEL STOPS ON EVERY ROUTE", art, glow_xy=(500, 800))


# 17 — chapabaj telemetry · Trail Social
def p17():
    s = SKINS["trailSocial"]
    art = (speech_bubble(460, 660, 1.85, s["pri"], s["bg"], 12, tail="left", dots=False) +
           txt(460, 690, "১৫০ → ০?", 70, s["t1"], COND, anchor="middle") +
           rider(500, 1180, 1.05, s["t1"], s["bg"], 12, expr="grin", arm="point"))
    return frame(s, 17, ["“২ হাতে ব্রেক, ১৫০ থেকে ০!”", "চাপাবাজরে প্রমাণ দেখান।"], "chapabaj_proof",
                 "REAL BRAKING DATA, NO CHAPABAZI", art, glow_xy=(500, 760))


# 18 — old biker reunion · Nocturne
def p18():
    s = SKINS["nocturne"]
    art = handshake(500, 800, 1.85, s["pri"], s["bg"], 12)
    return frame(s, 18, ["পুরনো রাইডার বন্ধুর", "খোঁজ নাই?"], "biker_reunion",
                 "FIND YOUR OLD RIDING CREW AGAIN", art, glow_xy=(500, 800))


# 19 — AI camera radar · Carbon Mono
def p19():
    s = SKINS["carbonMono"]
    art = (camera_flash(600, 660, 1.7, s["pri"], s["bg"], 12) +
           rider(300, 1180, 1.5, s["pri"], s["bg"], 13, expr="shock", arm="up"))
    return frame(s, 19, ["স্মাইল, আপনি ক্যামেরায়!", "AI ক্যামেরা নিয়ে ভয় নেই।"], "ai_camera",
                 "LIVE SPEED-CAMERA ALERTS", art, glow_xy=(560, 720))


# 20 — per km cost · Editorial Light
def p20():
    s = SKINS["editorialLight"]
    art = coins(500, 800, 2.2, s["pri"], s["surf"], 10)
    return frame(s, 20, ["“৭০ টাকা লাভ?”", "ভুল হিসাব।"], "cost_per_km",
                 "REAL PER-KM COST, EVERY RIDE", art, glow_xy=(500, 800), glow_op=0.16)


# 21 — Gixxer benchmark · Analyst Blue
def p21():
    s = SKINS["analystBlue"]
    art = (bike_silhouette(480, 990, 1.1, s["pri"], s["bg"], 13, sport=True) +
           txt(480, 480, "KM/L", 30, s["t3"], MONO, anchor="middle", tracking=4) +
           txt(480, 660, "?", 160, s["pri"], COND, anchor="middle"))
    return frame(s, 21, ["Gixxer মালিক?", "বাকিরা কত মাইলেজ পায়, জানেন?"], "gixxer_benchmark",
                 "REAL OWNER MILEAGE DATA", art, glow_xy=(480, 860))


# 22 — FZ-S benchmark · Trail Social
def p22():
    s = SKINS["trailSocial"]
    art = (bike_silhouette(480, 990, 1.1, s["pri"], s["bg"], 13, sport=False) +
           txt(480, 480, "KM/L", 30, s["t3"], MONO, anchor="middle", tracking=4) +
           txt(480, 660, "?", 160, s["pri"], COND, anchor="middle"))
    return frame(s, 22, ["FZ-S ভাইয়েরা,", "জ্যামে আসল মাইলেজ কত?"], "fzs_benchmark",
                 "REAL OWNER MILEAGE DATA", art, glow_xy=(480, 860))


# 23 — R15 benchmark · Editorial Dark
def p23():
    s = SKINS["editorialDark"]
    art = (bike_silhouette(480, 990, 1.1, s["pri"], s["bg"], 13, sport=True) +
           txt(480, 480, "TOP SPEED", 26, s["t3"], MONO, anchor="middle", tracking=4) +
           txt(480, 660, "?", 160, s["pri"], COND, anchor="middle"))
    return frame(s, 23, ["R15 নিয়ে ছুটছেন?", "আসল টপ-স্পিড জানেন?"], "r15_benchmark",
                 "REAL TELEMETRY, NOT GUESSWORK", art, glow_xy=(480, 860))


# 24 — Pulsar benchmark · Genesis
def p24():
    s = SKINS["genesis"]
    art = (bike_silhouette(480, 990, 1.1, s["pri"], s["bg"], 13, sport=False) +
           txt(480, 480, "KM/L", 30, s["t3"], MONO, anchor="middle", tracking=4) +
           txt(480, 660, "?", 160, s["pri"], COND, anchor="middle"))
    return frame(s, 24, ["১৫ বছর পালসার চালাচ্ছেন?", "মাইলেজ ঠিক আছে তো?"], "pulsar_benchmark",
                 "REAL OWNER MILEAGE DATA", art, glow_xy=(480, 860))


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
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "svg", "v2")
    os.makedirs(out, exist_ok=True)
    names = sys.argv[1:]
    for name, fn in POSTERS:
        if names and name not in names:
            continue
        with open(f"{out}/{name}.svg", "w") as f:
            f.write(fn())
        print("wrote", name)
