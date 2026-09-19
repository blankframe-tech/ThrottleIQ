# -*- coding: utf-8 -*-
"""Social ad creatives — Meta/Instagram feed format (1080x1350, 4:5), built
to drive installs. Distinct from the street-poster series (posters.py/_v2/_v3,
which are OOH/print): these put a real, cropped app screenshot front and
center instead of an illustrated scene, matching 2026 ASO practice of
showing actual current UI rather than mockups.

Distribution reality (checked against DOCS/Handoff for agents and
Todos/HANDOFF_Document.md): neither the Play Store nor the App Store listing
is live yet. Today's real install path is a signed APK from GitHub Releases
(Android) or an email/WhatsApp waitlist (iOS). So the footer CTA here says
"APK free download" / "Android now, iOS soon" — never a Play Store or App
Store badge, which would claim availability that doesn't exist.

Each creative also picks one of ThrottleIQ's own theme skins (lib.py
SKINS), reusing the same skin-per-segment mapping the v1 street posters
already established (Genesis for maintenance, Editorial for
telemetry/cost, Nocturne for crew/journey, Calming for family) so this
series reads as part of the same brand system.
"""
import sys, os, base64
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from lib import SKINS, SANS, COND, MONO, txt, rect, qr_svg, fit, tw
import bn as _bn

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1080, 1350
BASE = "https://blankframe.tech/ThrottleIQ/install"

INK = "#12161C"
YELLOW = "#FFE100"
FOOTER_BG = "#0E1116"

BADGE_TEXT = {
    "genesis": INK, "editorialLight": "#FFFFFF", "editorialDark": INK,
    "nocturne": INK, "calmingDark": INK, "calmingLight": "#FFFFFF",
    "carbonMono": INK, "trailSocial": INK, "analystBlue": INK, "retro": "#FFFFFF",
}
ACCENT_KEY = {
    "genesis": "pri", "editorialLight": "att", "editorialDark": "att",
    "nocturne": "pri", "calmingDark": "pri", "calmingLight": "sec",
    "carbonMono": "pri", "trailSocial": "pri", "analystBlue": "pri", "retro": "pri",
}


def _b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def svg_doc(body, bg):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="{bg}"/>'
            f'{body}</svg>')


def stroke_headline(x, y, lines, size, fill, stroke, max_w=940, sw=None):
    o = []
    for i, ln in enumerate(lines):
        fs = _bn.bfit(ln, max_w, size, _bn.COND_B, 0, min_size=42)
        w = sw if sw is not None else max(6, fs * 0.09)
        o.append(_bn.btext(x, y + i * (fs * 1.08), ln, fs, fill, _bn.COND_B,
                            anchor="middle", stroke=stroke, stroke_width=w))
    return "".join(o), size * 1.08 * len(lines)


def wrap_lines(text, max_w, size, font=SANS):
    words = text.split(" ")
    lines, cur = [], ""
    for word in words:
        trial = f"{cur} {word}".strip()
        if not cur or tw(trial, size, font, True, 0) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def badge(x, y, w, h, lines, fill, text_color):
    o = [rect(x, y, w, h, fill=fill, rx=18)]
    fs = 28
    cx = x + w / 2
    n = len(lines)
    top = y + h / 2 - (n - 1) * fs * 0.62
    for i, ln in enumerate(lines):
        size = fit(ln, w - 22, fs, SANS, True, 0)
        o.append(txt(cx, top + i * fs * 1.18, ln, size, text_color, SANS, anchor="middle"))
    return "".join(o)


def logo_mark(x, y, s=44):
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
    o.append(qr_svg(f"{BASE}?c={campaign}", 44, y0 + 24, 104, dark="#000000",
                     light="#FFFFFF", uid=campaign))
    o.append(txt(168, y0 + 54, "SCAN", 32, "#F5642B", COND, tracking=2))
    o.append(txt(168, y0 + 82, "ThrottleIQ APK ফ্রি ডাউনলোড", 21, "#F4F4F4", SANS))
    o.append(txt(168, y0 + 108, "FREE · OFFLINE-FIRST · ANDROID NOW · iOS শীঘ্রই", 14,
                  "#8A8F98", MONO, tracking=0.5))
    o.append(txt(W - 44, y0 + 58, "ThrottleIQ", 34, "#FFFFFF", SANS, anchor="end", tracking=-1))
    o.append(txt(W - 44, y0 + 84, "MACHINE MEMORY FOR MOTORCYCLES", 13, "#6B7078", MONO,
                  anchor="end", tracking=1.5))
    o.append(txt(W - 44, y0 + 112, "ঢাকায় তৈরি, ঢাকার রাস্তার জন্য", 18, "#8A8F98", SANS, anchor="end"))
    return "".join(o)


def phone_card(cx, top, bottom, screenshot_path, max_w=460):
    """Embed the cropped screenshot, scaled to fit the vertical band
    [top, bottom] and centered at cx, with a soft drop shadow."""
    from PIL import Image
    im = Image.open(screenshot_path)
    nw, nh = im.size
    band_h = bottom - top
    scale = min(max_w / nw, band_h / nh, 1.4)
    w, h = nw * scale, nh * scale
    x = cx - w / 2
    y = top + (band_h - h) / 2
    data = _b64(screenshot_path)
    o = [rect(x - 4, y + 16, w + 8, h + 8, fill="#000000", opacity=0.24, rx=30 * scale)]
    o.append(f'<image x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" '
              f'href="data:image/png;base64,{data}"/>')
    return "".join(o), (x, y, w, h)


POSTERS = [
    dict(
        id="social-01-commuter-maintenance",
        segment="Commuter",
        skin="genesis",
        screenshot="commuter-maintenance.png",
        headline=["দূরত্ব দেখেই", "সার্ভিসের রিমাইন্ডার"],
        subhead="টায়ার, চেইন, ব্রেক — আসল কিলোমিটার হিসেবে, সম্পূর্ণ ফ্রি।",
        badge_l=["রিয়েল", "কিলোমিটার"],
        badge_r=["সম্পূর্ণ", "ফ্রি"],
        campaign="social_commuter_maint",
    ),
    dict(
        id="social-02-commuter-ridelog",
        segment="Commuter",
        skin="editorialLight",
        screenshot="commuter-ridelog.png",
        headline=["প্রতিটা রাইডের", "আসল হিসাব"],
        subhead="স্পিড, দূরত্ব, সময় — টাওয়ার ছাড়াই রেকর্ড হয়, নেট ফিরলে সিঙ্ক।",
        badge_l=["অফলাইন", "GPS"],
        badge_r=["প্রতি রাইডে", "লগ থাকে"],
        campaign="social_commuter_ridelog",
    ),
    dict(
        id="social-03-enthusiast-telemetry",
        segment="Enthusiast",
        skin="editorialDark",
        screenshot="enthusiast-telemetry.png",
        headline=["চা স্টলে গল্প না,", "আসল স্পিড ডেটা"],
        subhead="প্রতি সেকেন্ডে ২০+ ডেটা পয়েন্ট — একজন বাইকারের বানানো অ্যাপ।",
        badge_l=["রিয়েল", "টেলিমেট্রি"],
        badge_r=["বাইকারের", "বানানো"],
        campaign="social_enthusiast_telemetry",
    ),
    dict(
        id="social-04-enthusiast-journey",
        segment="Enthusiast",
        skin="nocturne",
        screenshot="enthusiast-journey.png",
        headline=["প্রতিটা কিলোমিটার", "গোনা থাকে"],
        subhead="লেভেল, ব্যাজ, মোট দূরত্ব — নিজের ক্রুর সাথে একসাথে রাইড করুন।",
        badge_l=["লেভেল আপ", "প্রতি রাইডে"],
        badge_r=["ক্রু নিয়ে", "রাইড করুন"],
        campaign="social_enthusiast_journey",
    ),
    dict(
        id="social-05-family-parent",
        segment="Family",
        skin="calmingDark",
        screenshot="family-parent.png",
        headline=["রাইড হঠাৎ", "থেমে গেলে?"],
        subhead="লাইভ শেয়ার অন থাকলে, যিনি দেখছেন সাথে সাথে বুঝবেন। আর অ্যাপ নিজেই "
                 "রাইডারকে জিজ্ঞেস করে, 'ঠিক আছেন তো?'",
        badge_l=["লাইভ শেয়ার", "অপ্ট-ইন"],
        badge_r=["রাইডার", "নিজেই অন করে"],
        campaign="social_family_hardstop",
    ),
    dict(
        id="social-06-family-spouse",
        segment="Family",
        skin="calmingLight",
        screenshot="family-spouse.png",
        headline=["উনি ঠিকঠাক", "পৌঁছেছেন তো?"],
        subhead="লাইভ শেয়ার অন করলে, বাসার মানুষ লাইভ ম্যাপে দেখতে পারবেন — "
                 "রাইডার নিজে অন করলে তবেই, অটোমেটিক নয়।",
        badge_l=["লাইভ", "ম্যাপে দেখা"],
        badge_r=["রাইডারের", "সিদ্ধান্তে"],
        campaign="social_family_liveshare2",
    ),
    # --- second pass (2026-09-19), 20 more — see README "The 20 new creatives" ---
    dict(
        id="social-07-commuter-startride",
        segment="Commuter",
        skin="carbonMono",
        screenshot="start-ride-carbon.png",
        headline=["এক ট্যাপে রাইড", "শুরু, প্রতিদিন"],
        subhead="সকালে বাইক স্টার্ট দেওয়ার আগে একবার ট্যাপ — বাকিটা অ্যাপ নিজেই রেকর্ড করে।",
        badge_l=["৭ দিনের", "স্ট্রিক"],
        badge_r=["এক ট্যাপে", "শুরু"],
        campaign="social_commuter_startride",
    ),
    dict(
        id="social-08-family-giftinstall",
        segment="Family",
        skin="calmingLight",
        screenshot="start-ride-editorial.png",
        headline=["যাকে ভালোবাসেন,", "তাকে দিন এই অ্যাপ"],
        subhead="ইনস্টল করে দিন, বাকিটা রাইডার নিজেই বুঝে নেবে — একটা বাটনেই রাইড শুরু।",
        badge_l=["শেখাতে হয় না", "এমনিই সহজ"],
        badge_r=["সম্পূর্ণ", "ফ্রি"],
        campaign="social_family_giftinstall",
    ),
    dict(
        id="social-09-enthusiast-liveguard",
        segment="Enthusiast",
        skin="trailSocial",
        screenshot="on-the-road-editorial.png",
        headline=["গতি বাড়লে,", "অ্যাপও খেয়াল রাখে"],
        subhead="রাইডের মাঝেই লাইভ স্পিড আর সতর্কতা — একজন বাইকারের বানানো, বাইকারের জন্য।",
        badge_l=["লাইভ", "স্পিড"],
        badge_r=["রাইডেই", "সতর্কতা"],
        campaign="social_enthusiast_liveguard",
    ),
    dict(
        id="social-10-commuter-garagefleet",
        segment="Commuter",
        skin="genesis",
        screenshot="garage-carbon.png",
        headline=["একাধিক বাইক?", "একটাই গ্যারেজ"],
        subhead="কোনটার সার্ভিস কবে, কোনটা পার্ক করা — সব বাইক একই ড্যাশবোর্ডে।",
        badge_l=["যত বাইকই", "থাকুক"],
        badge_r=["সম্পূর্ণ", "ফ্রি"],
        campaign="social_commuter_garagefleet",
    ),
    dict(
        id="social-11-family-garagepeace",
        segment="Family",
        skin="calmingDark",
        screenshot="garage-editorial.png",
        headline=["বাইকের যত্ন", "কতদূর, দেখে নিন"],
        subhead="কবে সার্ভিস লাগবে সেটা অ্যাপই মনে রাখে — অযথা টেনশন করতে হয় না।",
        badge_l=["সার্ভিস", "রিমাইন্ডার"],
        badge_r=["রাইডার", "নিশ্চিন্ত"],
        campaign="social_family_garagepeace",
    ),
    dict(
        id="social-12-enthusiast-totalstats",
        segment="Enthusiast",
        skin="nocturne",
        screenshot="journey-carbon.png",
        headline=["৬৪২ কিলোমিটার।", "৩১টা রাইড।"],
        subhead="প্রতিটা কিলোমিটার গোনা থাকে — লেভেল, ব্যাজ, রিয়েল হিসাব।",
        badge_l=["লেভেল ৪", "স্টেডি ক্রুজার"],
        badge_r=["রিয়েল", "মাইলফলক"],
        campaign="social_enthusiast_totalstats",
    ),
    dict(
        id="social-13-enthusiast-upkeep",
        segment="Enthusiast",
        skin="carbonMono",
        screenshot="maintenance-carbon.png",
        headline=["চেইন ওভারডিউ?", "অ্যাপ বলে দেবে"],
        subhead="টায়ার থেকে চেইন লুব — আসল কিলোমিটার হিসেবে, পারফরম্যান্স ধরে রাখুন।",
        badge_l=["রিয়েল-টাইম", "চেকলিস্ট"],
        badge_r=["পারফরম্যান্স", "অক্ষুণ্ণ"],
        campaign="social_enthusiast_upkeep",
    ),
    dict(
        id="social-14-commuter-fullreport",
        segment="Commuter",
        skin="editorialLight",
        screenshot="ridecomplete-hero-editorial.png",
        headline=["রাইড শেষে,", "সম্পূর্ণ রিপোর্ট"],
        subhead="স্পিড, দূরত্ব, প্রতি কিলোমিটারের স্প্লিট আর এলিভেশন — একনজরে।",
        badge_l=["প্রতি KM", "স্প্লিট"],
        badge_r=["ব্যাজ", "আনলক"],
        campaign="social_commuter_fullreport",
    ),
    dict(
        id="social-15-commuter-offlinesignal",
        segment="Commuter",
        skin="carbonMono",
        screenshot="enthusiast-telemetry.png",
        headline=["সিগন্যাল না থাকলেও,", "রেকর্ড হতেই থাকে"],
        subhead="হাইওয়েতে নেট না থাকলেও GPS থামে না — নেট ফিরলেই নিজে থেকে সিঙ্ক।",
        badge_l=["অফলাইন", "GPS"],
        badge_r=["অটো", "সিঙ্ক"],
        campaign="social_commuter_offlinesignal",
    ),
    dict(
        id="social-16-enthusiast-speedproof",
        segment="Enthusiast",
        skin="nocturne",
        screenshot="commuter-ridelog.png",
        headline=["আজকের রাইডে,", "গড় স্পিড কত ছিল?"],
        subhead="অ্যাভারেজ, ম্যাক্স স্পিড, ব্যাজ — প্রমাণসহ বলুন, চা স্টলের আন্দাজ না।",
        badge_l=["অ্যাভারেজ", "৪৬ KM/H"],
        badge_r=["ম্যাক্স", "৮৮ KM/H"],
        campaign="social_enthusiast_speedproof",
    ),
    dict(
        id="social-17-family-habitproof",
        segment="Family",
        skin="calmingLight",
        screenshot="enthusiast-journey.png",
        headline=["কতটা সাবধানে", "চালায়, বোঝা যায়"],
        subhead="প্রতিটা রাইডের হিসাব থেকে যায় — রাইডারও নিজের অভ্যাস বুঝে দায়িত্ব নিয়ে চালান।",
        badge_l=["প্রতিটা রাইড", "হিসাবে"],
        badge_r=["নিজের", "অভ্যাস বোঝা"],
        campaign="social_family_habitproof",
    ),
    dict(
        id="social-18-enthusiast-solocheckin",
        segment="Enthusiast",
        skin="trailSocial",
        screenshot="family-parent.png",
        headline=["একলা ট্যুরে গেলেও,", "একা না"],
        subhead="হুট করে থেমে গেলে অ্যাপ নিজেই জিজ্ঞেস করে — লাইভ শেয়ার অন থাকলে সঙ্গীও বুঝবে।",
        badge_l=["সোলো", "ট্যুরার"],
        badge_r=["লাইভ শেয়ার", "অপ্ট-ইন"],
        campaign="social_enthusiast_solocheckin",
    ),
    dict(
        id="social-19-commuter-selfcheck",
        segment="Commuter",
        skin="editorialDark",
        screenshot="family-spouse.png",
        headline=["রোজ যেভাবেই চালান,", "অ্যাপ খেয়াল রাখে"],
        subhead="হুট করে থেমে গেলে অ্যাপ নিজেই জিজ্ঞেস করে, 'ঠিক আছেন তো?' — রোজকার কমিউটেও।",
        badge_l=["ডেইলি", "কমিউট"],
        badge_r=["নিজের", "সেফটি"],
        campaign="social_commuter_selfcheck",
    ),
    dict(
        id="social-20-family-roadworthy",
        segment="Family",
        skin="calmingDark",
        screenshot="commuter-maintenance.png",
        headline=["গ্যারেজে টাকা কম,", "রাস্তায় ঝুঁকি কম"],
        subhead="চেইন, ব্রেক, টায়ার সময়মতো ঠিক থাকলে রাস্তায় হুট করে সমস্যা হওয়ার আশঙ্কাও কমে।",
        badge_l=["সময়মতো", "সার্ভিস"],
        badge_r=["নিরাপদ", "রাইড"],
        campaign="social_family_roadworthy",
    ),
    dict(
        id="social-21-commuter-freeforever",
        segment="Commuter",
        skin="retro",
        screenshot="start-ride-carbon.png",
        headline=["রাইড শুরু।", "টাকা লাগে না।"],
        subhead="কোনো সাবস্ক্রিপশন না, কোনো লুকানো চার্জ না — ইনস্টল করুন, রাইড শুরু করুন।",
        badge_l=["০", "টাকা"],
        badge_r=["সম্পূর্ণ", "ফ্রি"],
        campaign="social_commuter_freeforever",
    ),
    dict(
        id="social-22-family-safehabit",
        segment="Family",
        skin="calmingDark",
        screenshot="on-the-road-editorial.png",
        headline=["শুধু লোকেশন না,", "রাইডিং অভ্যাসও"],
        subhead="ব্রেক হঠাৎ চাপলে অ্যাপ নিজেই সতর্ক করে — নিরাপদ রাইডিং অভ্যাস গড়ে তোলে।",
        badge_l=["রিয়েল-টাইম", "সতর্কতা"],
        badge_r=["নিরাপদ", "অভ্যাস"],
        campaign="social_family_safehabit",
    ),
    dict(
        id="social-23-enthusiast-multigarage",
        segment="Enthusiast",
        skin="analystBlue",
        screenshot="garage-carbon.png",
        headline=["পার্ক করা বাইকও,", "ভুলে যান না"],
        subhead="যে বাইকটা চলে, আর যেটা পার্কে বিশ্রামে — দুটোরই হিসাব একসাথে।",
        badge_l=["মাল্টি-বাইক", "গ্যারেজ"],
        badge_r=["সব বাইকের", "হিসাব"],
        campaign="social_enthusiast_multigarage",
    ),
    dict(
        id="social-24-family-autoreminder",
        segment="Family",
        skin="genesis",
        screenshot="maintenance-carbon.png",
        headline=["ভুলে গেলেও চলবে,", "অ্যাপ মনে রাখবে"],
        subhead="কোন চেকটা ওভারডিউ, কোনটা ঠিক আছে — বাইকের যত্নের পুরো হিসাব একজায়গায়।",
        badge_l=["অটো", "রিমাইন্ডার"],
        badge_r=["নিশ্চিন্ত", "রাইড"],
        campaign="social_family_autoreminder",
    ),
    dict(
        id="social-25-enthusiast-badgeproof",
        segment="Enthusiast",
        skin="editorialDark",
        screenshot="ridecomplete-hero-editorial.png",
        headline=["ব্যাজ আনলক।", "প্রমাণসহ।"],
        subhead="“আর্লি বার্ড”, “স্মুথ অপারেটর” — চা স্টলের গল্প না, রাইড শেষেই দেখা যায়।",
        badge_l=["রিয়েল", "ব্যাজ"],
        badge_r=["প্রতি রাইডে", "প্রমাণ"],
        campaign="social_enthusiast_badgeproof",
    ),
    dict(
        id="social-26-family-milestonepride",
        segment="Family",
        skin="calmingLight",
        screenshot="journey-carbon.png",
        headline=["৬৪২ কিলোমিটার", "নিরাপদে পার"],
        subhead="প্রতিটা লেভেল মানে আরও অভিজ্ঞ, আরও সতর্ক রাইডার — পরিবারও গর্ব করতে পারে।",
        badge_l=["লেভেল", "আপ"],
        badge_r=["অভিজ্ঞ", "রাইডার"],
        campaign="social_family_milestonepride",
    ),
]


def build(p):
    skin = SKINS[p["skin"]]
    dark = skin["dark"]
    accent = skin[ACCENT_KEY[p["skin"]]]
    body_text = skin["t1"]
    badge_fill = accent
    badge_text = BADGE_TEXT[p["skin"]]

    o = []
    # soft glow behind where the card will sit
    o.append(f'<circle cx="{W/2}" cy="700" r="480" fill="{accent}" opacity="{0.10 if dark else 0.14}"/>')

    o.append(logo_mark(W - 78, 34, 44))
    o.append(txt(W - 92, 66, "ThrottleIQ", 28, body_text, SANS, anchor="end", tracking=-1))

    if dark:
        head, used = stroke_headline(W / 2, 118, p["headline"], 82, YELLOW, INK)
    else:
        head, used = stroke_headline(W / 2, 118, p["headline"], 82, INK, accent, sw=7)
    o.append(head)
    sub_size = 24
    sub_lines = wrap_lines(p["subhead"], 900, sub_size)
    sub_y0 = 118 + used + 20
    for i, ln in enumerate(sub_lines):
        o.append(txt(W / 2, sub_y0 + i * sub_size * 1.5, ln, sub_size, body_text, SANS,
                      anchor="middle", opacity=0.92))
    sub_bottom = sub_y0 + (len(sub_lines) - 1) * sub_size * 1.5

    card_top = sub_bottom + 46
    card_bottom = H - 190
    shot_path = os.path.join(HERE, "screenshots", p["screenshot"])
    card_svg, (cx0, cy0, cw, ch) = phone_card(W / 2, card_top, card_bottom, shot_path)
    o.append(card_svg)

    badge_w, badge_h = 210, 112
    badge_y = cy0 + ch / 2 - badge_h / 2
    left_x = max(28, cx0 - badge_w - 26)
    right_x = min(W - 28 - badge_w, cx0 + cw + 26)
    o.append(badge(left_x, badge_y, badge_w, badge_h, p["badge_l"], badge_fill, badge_text))
    o.append(badge(right_x, badge_y, badge_w, badge_h, p["badge_r"], badge_fill, badge_text))

    o.append(footer(p["campaign"]))
    return svg_doc("".join(o), skin["bg"])


if __name__ == "__main__":
    svg_dir = os.path.join(HERE, "svg")
    os.makedirs(svg_dir, exist_ok=True)
    for p in POSTERS:
        doc = build(p)
        path = os.path.join(svg_dir, f'{p["id"]}.svg')
        with open(path, "w", encoding="utf-8") as f:
            f.write(doc)
        print("wrote", path)
