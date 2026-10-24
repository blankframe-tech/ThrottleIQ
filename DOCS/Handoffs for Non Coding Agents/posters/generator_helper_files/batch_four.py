# -*- coding: utf-8 -*-
"""Batch four: the password link (/r/@handle) poster. DRAFT, feature not shipped.

Same layout, brand and footer as batch three (it reuses batch_three.py). Notes and
the overclaim check: ../batch_four/README.md.
Run: python3 batch_four.py   (needs pillow, qrcode, uharfbuzz, fonttools)
"""
import os
import bn
from lib import rect
from batch_three import DARK, build, card, chip, mini_map

OUT = os.path.abspath(f"{os.path.dirname(os.path.abspath(__file__))}/../batch_four")


def hero_password(c):
    """The /r/@handle viewer after the password: map, last-seen pin, 'last seen' chip."""
    x, y, w, h, o = card(c)
    o += rect(x + 20, y + 20, w - 40, 56, fill=c["var"], rx=28)
    o += (f'<rect x="{x+42}" y="{y+46}" width="18" height="14" rx="3" fill="{c["acc"]}"/>'  # padlock
          f'<path d="M {x+45} {y+46} v -5 a 6 6 0 0 1 12 0 v 5" fill="none" stroke="{c["acc"]}" stroke-width="3"/>')
    o += bn.btext(x + 72, y + 57, "throttleiqfb.web.app/r/@rafi", 19, c["t2"], bn.MONO_R)
    o += rect(x + 20, y + 92, w - 40, 64, fill=c["surf"], stroke=c["acc"], sw=2, rx=18)
    o += bn.btext(x + 44, y + 134, "পাসওয়ার্ড  ••••••••", 26, c["t1"], bn.SANS_B)
    o += chip(x + w - 36, y + 134, "খুলুন", c["acc"], c["on_acc"])
    o += mini_map(c, x + 20, y + 172, w - 40, 236, "pm")
    px, py = x + 240, y + 290  # last known spot: steady, grey-ringed pin, not a live pulse
    o += f'<circle cx="{px}" cy="{py}" r="34" fill="{c["sec"]}" opacity="0.22"/>'
    o += f'<circle cx="{px}" cy="{py}" r="15" fill="{c["sec"]}" stroke="#FFFFFF" stroke-width="5"/>'
    o += bn.btext(x + 36, y + 462, "পলাশী মোড়", 34, c["t1"], bn.SANS_B)
    o += chip(x + w - 36, y + 462, "রাইড শেষ", c["var"], c["t2"])
    o += bn.btext(x + 36, y + 516, "শেষ দেখা: ৩২ মিনিট আগে", 28, c["sec"], bn.SANS_B)
    return o


POSTERS = [
    # (file, theme, campaign, headline 1, headline 2, sub, bullets, hero) as in batch_three
    ("1_lost-phone-password-link", DARK, "lostphone_b4", "ওস্তাদ, ফোন কই?", "লিংক খুলে দেখুন।",
     "রাইডের সময় ফোনের লোকেশন আপনার পাসওয়ার্ড দেওয়া লিংকে থাকে। ফোন বন্ধ হলেও শেষ জায়গাটা দেখা যায়।",
     ["অন্য কারো ফোনেও খোলে", "পাসওয়ার্ড ছাড়া দেখা যায় না", "শুধু রাইডের সময় শেয়ার হয়"],
     hero_password),
]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for p in POSTERS:
        with open(f"{OUT}/{p[0]}.svg", "w") as f:
            f.write(build(p))
        print(p[0])
