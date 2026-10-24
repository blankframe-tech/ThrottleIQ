# -*- coding: utf-8 -*-
"""Batch three: 18 posters, 1080x1350, one true feature each.

Why it exists and what it fixes in batch two: ../batch_three/CRITIQUE.md.
Run: python3 batch_three.py   (needs pillow, qrcode, uharfbuzz, fonttools)
"""
import base64, io, os
from PIL import Image
import bn
from lib import qr_svg, rect

W, H = 1080, 1350
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(f"{HERE}/../../../..")
SHOTS = f"{ROOT}/DOCS/General/new ui screenshot/dark"
ICON = f"{ROOT}/app/assets/images/app_icon.png"
OUT = os.path.abspath(f"{HERE}/../batch_three")
BASE = "https://blankframe.tech/ThrottleIQ/install"

# app/lib/core/theme/app_theme_style.dart: Carbon Mono (dark) and Calming (light)
DARK = dict(bg="#0D0D0D", surf="#161616", var="#262626", line="#393939",
            t1="#F4F4F4", t2="#A8A8A8", acc="#C8FF3D", on_acc="#0D0D0D", sec="#D633FF")
LIGHT = dict(bg="#F8F5EF", surf="#FEFBF8", var="#EEEBE5", line="#E1DDD8",
             t1="#2B2823", t2="#66635D", acc="#537D5C", on_acc="#FFFFFF", sec="#BD8D65")

M = 72                      # outer margin
HERO = (540, 520, 1008, 1084)  # right column: x0, y0, x1, y1


def b64_jpeg(im, width):
    im = im.convert("RGB")
    im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=86)
    return base64.b64encode(buf.getvalue()).decode("ascii"), im.size


def wrap(text, max_w, size, face):
    lines, cur = [], ""
    for word in text.split(" "):
        trial = f"{cur} {word}".strip()
        if not cur or bn.width(trial, size, face) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur] if cur else lines


def brand(c):
    data, _ = b64_jpeg(Image.open(ICON), 112)
    return (f'<clipPath id="ic"><rect x="{M}" y="56" width="56" height="56" rx="14"/></clipPath>'
            f'<image x="{M}" y="56" width="56" height="56" clip-path="url(#ic)" '
            f'href="data:image/jpeg;base64,{data}"/>'
            + bn.btext(M + 72, 96, "ThrottleIQ", 34, c["t1"], bn.SANS_B, tracking=-0.5)
            + rect(W - M - 168, 62, 168, 46, fill=c["acc"], rx=23)
            + bn.btext(W - M - 84, 94, "ফ্রি অ্যাপ", 24, c["on_acc"], bn.SANS_B, anchor="middle"))


def headline(c, l1, l2, sub):
    o, y = [], 228
    for text, fill in ((l1, c["t1"]), (l2, c["acc"])):
        o.append(bn.btext(M, y, text, bn.bfit(text, W - 2 * M, 96, bn.COND_B), fill, bn.COND_B))
        y += 104
    y += 4
    full = bn.width(sub, 31, bn.SANS_R)  # balance two lines so no word is left alone
    lines = wrap(sub, min(W - 2 * M, full / 2 + 60) if full > W - 2 * M else W, 31, bn.SANS_R)
    lines = lines if len(lines) <= 2 else wrap(sub, W - 2 * M, 31, bn.SANS_R)
    assert len(lines) <= 2, f"subline too long: {sub}"
    for ln in lines:
        o.append(bn.btext(M, y, ln, 31, c["t2"], bn.SANS_R))
        y += 44
    return "".join(o)


def bullets(c, items):
    o, y = [], 610
    for it in items:
        o.append(f'<circle cx="{M + 16}" cy="{y - 11}" r="16" fill="{c["acc"]}"/>'
                 f'<path d="M {M+8} {y-11} l 6 6 l 11 -12" fill="none" stroke="{c["on_acc"]}" '
                 f'stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')
        for i, ln in enumerate(wrap(it, HERO[0] - M - 90, 32, bn.SANS_B)[:2]):
            o.append(bn.btext(M + 50, y + i * 44, ln, 32, c["t1"], bn.SANS_B))
        y += 150
    return "".join(o)


def screen(c, shot, crop):
    """A real app screen, cropped to the part that proves the claim."""
    im = Image.open(f"{SHOTS}/{shot}").crop((0, crop[0], 1206, crop[1]))
    x0, y0, x1, y1 = HERO
    w = min(x1 - x0, (y1 - y0) * im.width / im.height)
    h = w * im.height / im.width
    x, y = x0 + (x1 - x0 - w) / 2, y0 + (y1 - y0 - h) / 2
    data, _ = b64_jpeg(im, 900)
    return (rect(x - 10, y - 10, w + 20, h + 20, fill="#1A1A1A", rx=44)
            + f'<clipPath id="sc"><rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="34"/></clipPath>'
            f'<image x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" clip-path="url(#sc)" '
            f'preserveAspectRatio="none" href="data:image/jpeg;base64,{data}"/>'
            + rect(x - 10, y - 10, w + 20, h + 20, stroke=c["line"], sw=2, rx=44))


def card(c, h=550):
    x0, y0, x1, _ = HERO
    return x0, y0, x1 - x0, h, rect(x0, y0, x1 - x0, h, fill=c["surf"], stroke=c["line"], sw=2, rx=36)


def hero_cost(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + 36, y + 72, "প্রতি কিলোমিটারে", 30, c["t2"], bn.SANS_B)
    for i, (k, v) in enumerate((("তেল", "ফুয়েল লগ"), ("সার্ভিস", "সার্ভিস লগ"), ("পার্টস", "বিল"))):
        yy = y + 150 + i * 90
        o += bn.btext(x + 36, yy, k, 38, c["t1"], bn.SANS_B)
        o += bn.btext(x + w - 36, yy, v, 24, c["t2"], bn.SANS_R, anchor="end")
        o += f'<line x1="{x+36}" y1="{yy+30}" x2="{x+w-36}" y2="{yy+30}" stroke="{c["line"]}" stroke-width="2"/>'
    o += rect(x + 24, y + h - 170, w - 48, 140, fill=c["acc"], rx=24)
    o += bn.btext(x + 52, y + h - 112, "আসল খরচ", 30, c["on_acc"], bn.SANS_B)
    o += bn.btext(x + 52, y + h - 56, "৳ ? / কিমি", 52, c["on_acc"], bn.COND_B)
    return o


def mini_map(c, x, y, w, h, uid):
    o = [f'<clipPath id="{uid}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24"/></clipPath>',
         f'<g clip-path="url(#{uid})">', rect(x, y, w, h, fill=c["var"])]
    for i in range(1, 6):  # streets
        o.append(f'<line x1="{x}" y1="{y + i*h/6 + 14*(i%2)}" x2="{x+w}" y2="{y + i*h/6 - 10}" stroke="{c["line"]}" stroke-width="{6 if i==3 else 3}"/>')
        o.append(f'<line x1="{x + i*w/6}" y1="{y}" x2="{x + i*w/6 - 30}" y2="{y+h}" stroke="{c["line"]}" stroke-width="3"/>')
    o.append("</g>")
    return "".join(o)


def hero_crew(c):
    x, y, w, h, o = card(c)
    o += mini_map(c, x + 20, y + 20, w - 40, 380, "cm")
    path = f"M {x+70} {y+360} C {x+150} {y+250}, {x+230} {y+300}, {x+280} {y+200} S {x+380} {y+80}, {x+400} {y+60}"
    o += f'<path d="{path}" fill="none" stroke="{c["acc"]}" stroke-width="7" stroke-linecap="round" opacity="0.9"/>'
    for (px, py, col, ini) in ((x+130, y+300, "#4A9DFF", "র"), (x+235, y+272, c["sec"], "স"),
                               (x+300, y+178, "#FF7A45", "ত"), (x+385, y+82, c["acc"], "আ")):
        o += f'<circle cx="{px}" cy="{py}" r="28" fill="{col}" stroke="{c["bg"]}" stroke-width="5"/>'
        o += bn.btext(px, py + 9, ini, 26, "#0D0D0D", bn.SANS_B, anchor="middle")
    o += bn.btext(x + 36, y + 456, "জয়েন কোড", 26, c["t2"], bn.SANS_B)
    o += bn.btext(x + 36, y + 520, "K7QX9P", 54, c["t1"], bn.MONO_B, tracking=6)
    o += rect(x + w - 150, y + 470, 120, 56, fill=c["acc"], rx=28)
    o += bn.btext(x + w - 90, y + 507, "৪ জন", 26, c["on_acc"], bn.SANS_B, anchor="middle")
    return o


def hero_break(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + w / 2, y + 90, "রাইডের সময়", 28, c["t2"], bn.SANS_B, anchor="middle")
    o += bn.btext(x + w / 2, y + 200, "1:30:00", 96, c["t1"], bn.MONO_B, anchor="middle")
    o += rect(x + 24, y + 260, w - 48, 270, fill=c["acc"], rx=28)
    cx, cy = x + w / 2, y + 340  # tea cup
    o += (f'<path d="M {cx-46} {cy-26} h 92 v 34 a 46 40 0 0 1 -92 0 z" fill="{c["on_acc"]}"/>'
          f'<path d="M {cx+46} {cy-14} a 18 18 0 0 1 0 36" fill="none" stroke="{c["on_acc"]}" stroke-width="8"/>'
          f'<path d="M {cx-16} {cy-40} q -10 -14 0 -28 M {cx+12} {cy-40} q -10 -14 0 -28" fill="none" '
          f'stroke="{c["on_acc"]}" stroke-width="5" stroke-linecap="round"/>')
    o += bn.btext(cx, y + 455, "বিরতির সময়", 50, c["on_acc"], bn.COND_B, anchor="middle")
    o += bn.btext(cx, y + 503, "একটু থামুন, চা খান", 28, c["on_acc"], bn.SANS_B, anchor="middle")
    return o


def hero_live(c):
    x, y, w, h, o = card(c)
    o += rect(x + 20, y + 20, w - 40, 56, fill=c["var"], rx=28)
    o += f'<circle cx="{x+52}" cy="{y+48}" r="9" fill="{c["acc"]}"/>'
    o += bn.btext(x + 72, y + 57, "throttleiqfb.web.app/live/…", 19, c["t2"], bn.MONO_R)
    o += mini_map(c, x + 20, y + 92, w - 40, 300, "lm")
    o += (f'<path d="M {x+60} {y+360} C {x+140} {y+300}, {x+200} {y+330}, {x+250} {y+240}" fill="none" '
          f'stroke="{c["acc"]}" stroke-width="7" stroke-linecap="round"/>')
    o += f'<circle cx="{x+250}" cy="{y+240}" r="36" fill="{c["acc"]}" opacity="0.25"/>'
    o += f'<circle cx="{x+250}" cy="{y+240}" r="16" fill="{c["acc"]}" stroke="#FFFFFF" stroke-width="5"/>'
    o += rect(x + 36, y + 418, 108, 40, fill=c["acc"], rx=20)
    o += bn.btext(x + 90, y + 446, "লাইভ", 22, c["on_acc"], bn.SANS_B, anchor="middle")
    o += bn.btext(x + 160, y + 448, "রাফি · এখন রাইড করছে", 26, c["t1"], bn.SANS_B)
    o += bn.btext(x + 36, y + 516, "৩২ km/h", 34, c["t1"], bn.SANS_B)
    o += bn.btext(x + w - 36, y + 516, "ব্যাটারি ৭৬%", 28, c["t2"], bn.SANS_B, anchor="end")
    return o


def chip(x, y, text, fill, color, size=24, anchor="end"):
    w = bn.width(text, size, bn.SANS_B) + 32
    x = x - w if anchor == "end" else x
    return rect(x, y - size - 6, w, size + 20, fill=fill, rx=(size + 20) / 2) + bn.btext(
        x + w / 2, y + 2, text, size, color, bn.SANS_B, anchor="middle")


def toggle(x, y, on, c):
    knob = x + 50 if on else x + 22
    return (rect(x, y - 22, 72, 44, fill=c["acc"] if on else c["line"], rx=22)
            + f'<circle cx="{knob}" cy="{y}" r="16" fill="#FFFFFF"/>')


def rows(c, x, y, w, items, gap=90, size=34):
    """Label left, chip right, a hairline under each row."""
    o = ""
    for i, (label, value, fill, color) in enumerate(items):
        yy = y + i * gap
        o += bn.btext(x + 36, yy, label, size, c["t1"], bn.SANS_B)
        o += chip(x + w - 36, yy, value, fill, color)
        if i < len(items) - 1:
            o += f'<line x1="{x+36}" y1="{yy+34}" x2="{x+w-36}" y2="{yy+34}" stroke="{c["line"]}" stroke-width="2"/>'
    return o


def hero_jam(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + 36, y + 72, "আজকের অফিস যাওয়া", 30, c["t2"], bn.SANS_B)
    for i, (label, mins, bn_mins, col) in enumerate((("চলেছেন", 28, "২৮", c["acc"]), ("জ্যামে", 19, "১৯", "#FF7A45"))):
        yy = y + 160 + i * 130
        o += bn.btext(x + 36, yy, label, 34, c["t1"], bn.SANS_B)
        o += bn.btext(x + w - 36, yy, f"{bn_mins} মিনিট", 34, col, bn.SANS_B, anchor="end")
        o += rect(x + 36, yy + 24, w - 72, 28, fill=c["var"], rx=14)
        o += rect(x + 36, yy + 24, (w - 72) * mins / 28, 28, fill=col, rx=14)
    o += rect(x + 24, y + h - 170, w - 48, 140, fill="#FF7A45", rx=24)
    o += bn.btext(x + 52, y + h - 70, "৪০%", 72, "#0D0D0D", bn.COND_B)
    o += bn.btext(x + 210, y + h - 108, "সময় গেছে", 28, "#0D0D0D", bn.SANS_B)
    o += bn.btext(x + 210, y + h - 66, "জ্যামে বসে", 28, "#0D0D0D", bn.SANS_B)
    return o


def hero_papers(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + 36, y + 72, "বাইকের কাগজ", 30, c["t2"], bn.SANS_B)
    ok, warn = (c["var"], c["acc"]), ("#B88255", "#FFFFFF")
    o += rows(c, x, y + 160, w, [("ট্যাক্স টোকেন", "১২ দিন বাকি", *warn),
                                 ("ইন্স্যুরেন্স", "ঠিক আছে", *ok), ("ফিটনেস", "ঠিক আছে", *ok),
                                 ("রেজিস্ট্রেশন", "ঠিক আছে", *ok), ("লাইসেন্স", "৩ মাস বাকি", *ok)], gap=84, size=32)
    return o


def hero_mileage(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + w / 2, y + 72, "আপনার বাইকের আসল মাইলেজ", 28, c["t2"], bn.SANS_B, anchor="middle")
    o += bn.btext(x + w / 2, y + 200, "৩৮.৬", 120, c["acc"], bn.COND_B, anchor="middle")
    o += bn.btext(x + w / 2, y + 250, "কিমি / লিটার", 30, c["t1"], bn.SANS_B, anchor="middle")
    for i, (l, km) in enumerate((("৭.২ লিটার", "২৭৮ কিমি"), ("৬.৮ লিটার", "২৬১ কিমি"), ("৭.০ লিটার", "২৭০ কিমি"))):
        yy = y + 340 + i * 70
        o += f'<line x1="{x+36}" y1="{yy-46}" x2="{x+w-36}" y2="{yy-46}" stroke="{c["line"]}" stroke-width="2"/>'
        o += bn.btext(x + 36, yy, f"ফুল ট্যাংক · {l}", 26, c["t1"], bn.SANS_B)
        o += bn.btext(x + w - 36, yy, km, 26, c["t1"], bn.SANS_B, anchor="end")
    return o


def hero_check(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + 36, y + 66, "রাইডের আগে · ৩০ সেকেন্ড", 28, c["t2"], bn.SANS_B)
    tw_, th = (w - 72 - 20) / 2, 128
    for i, label in enumerate(("টায়ার", "কন্ট্রোল", "লাইট", "তেল", "চেসিস", "স্ট্যান্ড")):
        tx, ty = x + 36 + (i % 2) * (tw_ + 20), y + 100 + (i // 2) * (th + 18)
        done = i < 4
        o += rect(tx, ty, tw_, th, fill=c["var"], rx=22)
        o += bn.btext(tx + 24, ty + 100, label, 34, c["t1"], bn.SANS_B)
        o += f'<circle cx="{tx+tw_-30}" cy="{ty+30}" r="16" fill="{c["acc"] if done else "none"}" stroke="{c["acc"]}" stroke-width="4"/>'
        if done:
            o += (f'<path d="M {tx+tw_-38} {ty+30} l 6 6 l 10 -11" fill="none" stroke="{c["on_acc"]}" '
                  f'stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')
    return o


def hero_widget(c):
    x, y, w, h, o = card(c)
    o = (f'<linearGradient id="hs" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2A3320"/>'
         f'<stop offset="1" stop-color="#101410"/></linearGradient>'
         + rect(x, y, w, h, fill="url(#hs)", stroke=c["line"], sw=2, rx=36))
    o += bn.btext(x + w / 2, y + 78, "9:41", 48, "#FFFFFF", bn.SANS_B, anchor="middle")
    wx, wy, ww = x + 28, y + 118, w - 56
    o += rect(wx, wy, ww, 200, fill=c["surf"], rx=28)
    o += bn.btext(wx + 28, wy + 50, "পরের সার্ভিস · Ronin 350", 24, c["t2"], bn.SANS_B)
    o += bn.btext(wx + 28, wy + 112, "চেইন লুব", 50, c["t1"], bn.COND_B)
    o += bn.btext(wx + 28, wy + 170, "আর ১২০ কিমি", 34, c["acc"], bn.SANS_B)
    sw_ = (ww - 20) / 2
    for i, (top, big) in enumerate((("এই সপ্তাহে", "৮৪ কিমি"), ("মোট রাইড", "৩১টা"))):
        bx = wx + i * (sw_ + 20)
        o += rect(bx, wy + 222, sw_, 130, fill=c["surf"], rx=28)
        o += bn.btext(bx + 24, wy + 268, top, 22, c["t2"], bn.SANS_B)
        o += bn.btext(bx + 24, wy + 324, big, 38, c["t1"], bn.SANS_B)
    for i in range(4):  # app icon row
        o += rect(wx + 14 + i * (ww - 28) / 4 + 10, y + h - 96, 76, 76, fill="#FFFFFF", opacity=0.12, rx=20)
    return o


def hero_modules(c):
    x, y, w, h, o = card(c)
    o += bn.btext(x + 36, y + 70, "Settings → Your ThrottleIQ", 26, c["t2"], bn.SANS_B)
    for i, (label, sub, on) in enumerate((("মেইনটেন্যান্স", "সবসময় চালু", None),
                                          ("রাইড ট্র্যাকিং", "রেকর্ড আর রাইড ট্যাব", False),
                                          ("প্লেস আর রুট", "ম্যাপ, গ্যারেজ, পাম্প", False),
                                          ("কমিউনিটি", "শুধু ফোরাম", True))):
        yy = y + 160 + i * 98
        o += bn.btext(x + 36, yy, label, 32, c["t1"], bn.SANS_B)
        o += bn.btext(x + 36, yy + 36, sub, 22, c["t2"], bn.SANS_R)
        o += (bn.btext(x + w - 36, yy + 14, "✓", 34, c["acc"], bn.SANS_B, anchor="end") if on is None
              else toggle(x + w - 108, yy + 6, on, c))
        if i < 3:
            o += f'<line x1="{x+36}" y1="{yy+62}" x2="{x+w-36}" y2="{yy+62}" stroke="{c["line"]}" stroke-width="2"/>'
    return o


def footer(c, campaign):
    y = 1112
    return (f'<line x1="{M}" y1="{y}" x2="{W-M}" y2="{y}" stroke="{c["line"]}" stroke-width="2"/>'
            + rect(M, y + 22, 184, 184, fill="#FFFFFF", rx=16)
            + qr_svg(f"{BASE}?c={campaign}", M + 8, y + 30, 168, uid=campaign)
            + bn.btext(M + 216, y + 78, "স্ক্যান করে ফ্রি ডাউনলোড করুন", 36, c["t1"], bn.SANS_B)
            + bn.btext(M + 216, y + 128, "blankframe.tech/ThrottleIQ", 28, c["acc"], bn.MONO_B)
            + bn.btext(M + 216, y + 176, "Android · নেট ছাড়াও চলে · ঢাকায় তৈরি", 26, c["t2"], bn.SANS_R))


def glow(c):
    tint = c["acc"] if c is DARK else c["sec"]
    return (f'<radialGradient id="gl" cx="0.72" cy="0.55" r="0.55"><stop offset="0" stop-color="{tint}" '
            f'stop-opacity="0.13"/><stop offset="1" stop-color="{tint}" stop-opacity="0"/></radialGradient>'
            f'<rect width="{W}" height="{H}" fill="url(#gl)"/>')


POSTERS = [
    # (file, theme, campaign, headline 1, headline 2, sub, bullets, hero)
    ("1_offline-recording", DARK, "offline_b3", "সিগন্যাল না থাকলেও,", "রেকর্ড হতে থাকে।",
     "পুরো রাইড আগে ফোনে সেভ হয়। নেট ফিরলে নিজেই সিঙ্ক হয়।",
     ["পাহাড়ি রাস্তা থেকে হাইওয়ে", "রাইড শেষে পুরো রুট ম্যাপে", "নেট ফিরলে নিজেই ব্যাকআপ"],
     ("062__ride-summary__ride-summary-cont-2.jpg", (830, 2100))),
    ("2_maintenance-due", DARK, "maint_b3", "চেইন কবে লুব করেছিলেন?", "মনে রাখতে হবে না।",
     "আসল কিলোমিটার ধরে হিসাব — কোন কাজ কবে লাগবে, অ্যাপ আগেই জানায়।",
     ["মোবিল, চেইন, ব্রেক, টায়ার", "সময় হওয়ার আগেই নোটিফিকেশন", "জ্যামে বেশি চালালে হিসাব আগে আসে"],
     ("075__maintenance__maintenance.jpg", (330, 1760))),
    ("3_service-record-resale", LIGHT, "resale_b3", "বাইক বেচবেন?", "সার্ভিসের প্রমাণ দিন।",
     "প্রতিটা সার্ভিস, খরচ আর কিলোমিটার লেখা থাকে — এক ট্যাপে PDF বানিয়ে ক্রেতাকে দিন।",
     ["প্রতি গ্যারেজ ভিজিট এক এন্ট্রিতে", "বিলের ছবিও রাখা যায়", "পুরো সার্ভিস রেকর্ড PDF-এ"],
     ("083__maintenance__log-a-service.jpg", (300, 1800))),
    ("4_garages-nearby", DARK, "places_b3", "কাছের ভালো গ্যারেজ কোনটা?", "ম্যাপেই দেখুন।",
     "ঢাকার ১,১০০+ পাম্প, গ্যারেজ আর পার্টসের দোকান — এক ট্যাপে ডিরেকশন আর কল।",
     ["পাম্প · গ্যারেজ · পার্টস", "রাইডারদের রেটিং ও রিভিউ", "নতুন জায়গা নিজেই যোগ করুন"],
     ("040__places__places-map.jpg", (1085, 2250))),
    ("5_real-running-cost", LIGHT, "cost_b3", "তেলের দামই কি", "আসল খরচ?",
     "তেল, সার্ভিস আর পার্টস মিলিয়ে প্রতি কিলোমিটারের আসল খরচ দেখায় ThrottleIQ।",
     ["ফুয়েল লগ থেকে আসল মাইলেজ", "প্রতিটা রাইডের খরচ", "মাসে কত গেল, এক চার্টে"],
     hero_cost),
    ("6_ride-report", DARK, "report_b3", "রাইড শেষে,", "পুরো রিপোর্ট।",
     "দূরত্ব, সময়, জ্যাম, স্পিড চার্ট আর রাইডিং স্কোর — প্রতিটা রাইডের।",
     ["স্মুথ চালালে স্কোর বাড়ে", "হার্ড ব্রেক গুনে রাখে", "GPX আর CSV এক্সপোর্ট"],
     ("061__ride-summary__ride-summary.jpg", (230, 1880))),
    ("7_crew-live-map", DARK, "crew_b3", "দোস্ত তুই কই?", "ম্যাপেই দেখ।",
     "৬ অক্ষরের কোড দিলেই গ্রুপে ঢোকা — পুরো দল এক লাইভ ম্যাপে।",
     ["সবার আলাদা রঙ", "চেপে ধরে ভয়েস নোট পাঠান", "পুরো দল একসাথে ইনস্টল করুন"],
     hero_crew),
    ("8_saved-routes", DARK, "route_b3", "দারুণ রাস্তা পেয়েছেন?", "রুটটা সেভ রাখুন।",
     "রাইড শেষে এক ট্যাপে রুট সেভ — চাইলে পাবলিক করে সবার সাথে শেয়ার করুন।",
     ["রাইড থেকেই রুট", "প্রাইভেট বা পাবলিক", "অন্যদের রুটও খুঁজে নিন"],
     ("066__ride-summary__save-as-route.jpg", (150, 1650))),
    ("9_break-reminder", DARK, "break_b3", "টানা দেড় ঘণ্টা চালালেন?", "এবার একটু চা।",
     "৯০ মিনিট টানা চালালে ThrottleIQ স্ক্রিনে বিরতি নিতে মনে করিয়ে দেয়।",
     ["লম্বা রাইডে বড় করে অ্যালার্ট", "ব্রেক আর থ্রটলেও টিপস", "বাংলা আর ইংরেজিতে"],
     hero_break),
    ("10_family-live-share", LIGHT, "family_live_b3", "সে রাইডে,", "আপনি নিশ্চিন্তে।",
     "রাইডার নিজে লিংক পাঠালে যেকোনো ব্রাউজারে তার লাইভ লোকেশন দেখা যায় — লগইন ছাড়াই।",
     ["রাইডার চালু করলে তবেই শেয়ার", "লোকেশন, স্পিড আর ব্যাটারি", "যেকোনো সময় বন্ধ করা যায়"],
     hero_live),
    ("11_jam-time", DARK, "jam_b3", "আজ কত মিনিট জ্যামে গেল?", "অ্যাপ গুনে রাখে।",
     "প্রতিটা রাইডে চলার সময় আর জ্যামে বসে থাকার সময় আলাদা করে দেখায়।",
     ["চলা আর জ্যাম, আলাদা হিসাব", "সপ্তাহ আর মাসের জ্যাম চার্ট", "কোন সময়ে রাস্তা ফাঁকা, নিজেই দেখুন"],
     hero_jam),
    ("12_papers-reminder", LIGHT, "papers_b3", "ট্যাক্স টোকেনের মেয়াদ কবে?", "অ্যাপ আগেই জানাবে।",
     "ট্যাক্স টোকেন, ইন্স্যুরেন্স, ফিটনেস, রেজিস্ট্রেশন আর লাইসেন্স — মেয়াদ শেষের ৩০ দিন আগে রিমাইন্ডার।",
     ["পাঁচটা কাগজ, এক জায়গায়", "৩০ দিন আগে নোটিফিকেশন", "নেট ছাড়াও রিমাইন্ডার আসে"],
     hero_papers),
    ("13_real-mileage", DARK, "mileage_b3", "শোরুম বলেছিল ৪৫।", "আসলে কত দেয়?",
     "ফুল ট্যাংক করার সময় লগ করুন — ThrottleIQ আসল কিমি/লিটার বের করে দেয়।",
     ["ফুল ট্যাংক থেকে ফুল ট্যাংক হিসাব", "মাসে কত লিটার গেল", "মাইলেজ কমলেই চোখে পড়বে"],
     hero_mileage),
    ("14_pre-ride-check", LIGHT, "precheck_b3", "রাইডের আগে", "৩০ সেকেন্ডের চেক।",
     "টায়ার, কন্ট্রোল, লাইট, তেল, চেসিস, স্ট্যান্ড — ছয়টা জিনিস এক নজরে দেখে নিন।",
     ["আন্তর্জাতিক T-CLOCS চেকলিস্ট", "৭ দিন না করলে মনে করিয়ে দেয়", "সমস্যা পেলে নোট রাখুন"],
     hero_check),
    ("15_home-widget", DARK, "widget_b3", "অ্যাপ না খুলেই", "পরের সার্ভিস দেখুন।",
     "হোম স্ক্রিনের উইজেটে দেখায় কোন সার্ভিস সবার আগে, আর কত কিমি বাকি।",
     ["ওভারডিউ হলে লাল হয়ে যায়", "সপ্তাহের কিমি এক নজরে", "এক ট্যাপে রাইডের স্ক্রিন"],
     hero_widget),
    ("16_ask-owners", DARK, "owners_b3", "একই বাইক, একই সমস্যা?", "মালিকদের জিজ্ঞেস করুন।",
     "প্রতিটা বাইক মডেলের আলাদা ফোরাম — সমস্যা, DIY গাইড আর রিভিউ এক জায়গায়।",
     ["ছবি দিয়ে প্রশ্ন করুন", "সমাধান পেলে Solved মার্ক", "ব্র্যান্ড আর ক্লাবের আলাদা বোর্ড"],
     ("070__bike__bike-detail-cont-2.jpg", (440, 1340))),
    ("17_private-sharing", DARK, "privacy_b3", "রাইড শেয়ার করুন,", "বাসার ঠিকানা না।",
     "শেয়ার করা রাইডের শুরুর জায়গা লুকানো থাকে। কে দেখবে, সেটা আপনি ঠিক করেন।",
     ["শুরুর জায়গা লুকানো", "সবাই, ফলোয়ার বা মিউচুয়াল", "যেকোনো সময় ডিলিট"],
     ("064__ride-summary__share-ride.jpg", (1400, 2330))),
    ("18_maintenance-only", LIGHT, "modules_b3", "শুধু সার্ভিসের হিসাব চান?", "বাকিটা বন্ধ রাখুন।",
     "সোশ্যাল, ম্যাপ, রাইড ট্র্যাকিং — যা লাগে না, Settings থেকে বন্ধ করুন। কিছু মুছে যায় না।",
     ["শুধু মেইনটেন্যান্স অ্যাপ", "ফোরাম রাখুন, বাকি সোশ্যাল বন্ধ", "যেকোনো সময় আবার চালু"],
     hero_modules),
]


def build(p):
    name, c, campaign, h1, h2, sub, items, hero = p
    body = (glow(c) + brand(c) + headline(c, h1, h2, sub) + bullets(c, items)
            + (hero(c) if callable(hero) else screen(c, *hero)) + footer(c, campaign))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<rect width="{W}" height="{H}" fill="{c["bg"]}"/>{body}</svg>')


if __name__ == "__main__":
    assert len({p[2] for p in POSTERS}) == len(POSTERS), "campaign ids must be unique"
    os.makedirs(OUT, exist_ok=True)
    for p in POSTERS:
        with open(f"{OUT}/{p[0]}.svg", "w") as f:
            f.write(build(p))
        print(p[0])
