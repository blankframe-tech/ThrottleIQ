# Batch four: password link (/r/@handle). DRAFT

Written 2026-10-25. **Do not print or post.** The feature (Settings → Privacy &
Safety → "Password link (/r/@handle)") is being built. The app that ships today
has a no-password "Public link" switch instead. Campaign brief, honest claims
and video script: `../../marketing/lost_phone_password_link.DRAFT.md`.

Same rules and layout as batch three (`../batch_three/CRITIQUE.md`): 1080x1350,
Carbon Mono, a 2-line headline, a 2-line subline, three points, a drawn hero card
that follows the real UI, and a 168 px QR code in the footer.

| # | File | Segment | Headline | Hero | QR campaign |
|---|---|---|---|---|---|
| 1 | `1_lost-phone-password-link` | Rider (commuter first) | ওস্তাদ, ফোন কই? লিংক খুলে দেখুন। | drawn `/r/@rafi` viewer: password field, map pin, "শেষ দেখা: ৩২ মিনিট আগে · পলাশী মোড়" | `lostphone_b4` |

Copy on the poster:
- Subline: রাইডের সময় ফোনের লোকেশন আপনার পাসওয়ার্ড দেওয়া লিংকে থাকে। ফোন বন্ধ হলেও শেষ জায়গাটা দেখা যায়।
- Points: অন্য কারো ফোনেও খোলে · পাসওয়ার্ড ছাড়া দেখা যায় না · শুধু রাইডের সময় শেয়ার হয়

Overclaim check: pass. It does not say anti-theft, always-on tracking, "find
anywhere" or "follow the thief". The pin is a steady magenta "last seen" dot,
not the lime pulsing "live" dot, and the chip reads "রাইড শেষ".

## Before posting

- Rebuild the hero card from the real `/r/` viewer once it exists, and match its
  wording ("last seen", the password button label).
- `@rafi`, "৩২ মিনিট" and "পলাশী মোড়" are UI examples, not data.
- The `?c=lostphone_b4` campaign id is new. Check that the install page keeps it.
- QR not decode-tested this batch (same `qr_svg` helper as batch three, which passed).
- The Bangla still needs a native reviewer.

Regenerate: `cd ../generator_helper_files && python3 batch_four.py` (needs pillow,
qrcode, uharfbuzz, fonttools). Render: `rsvg-convert -w 1080 -o out.png
1_lost-phone-password-link.svg`. Keep PNGs out of git.
