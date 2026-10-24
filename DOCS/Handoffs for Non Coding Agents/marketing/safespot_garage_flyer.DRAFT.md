> DRAFT for owner review, 2026-10-22

# SafeSpot verified-garage partner flyer and terms (PM item 6)

PM item 6: "free verified digital listing in exchange for displaying a ThrottleIQ counter sticker and recommending the app for service reminders."

## 1. What exists today (checked in code, 2026-10-22)

**"SafeSpot" does not exist in the app.** The name appears only in the iDEA grant budget (`iDEA_PITCH_SUBMISSION.md`: "Onboarding 500+ local motorcycle mechanics/garages in Dhaka & Chattogram with verified ThrottleIQ SafeSpot badges", a proposed, unfunded line). No screen, field, badge or string is called SafeSpot.

What a garage listing in **Places** actually gets (`features.md` §6, `app/lib/features/poi_directory/`):

- A card in the Places tab under the **Garage** category, on the list and the map, for riders within their chosen radius (5-50 km).
- Name, address, phone, opening hours, photo, rider ratings and reviews.
- One-tap **Directions** (opens the rider's maps app) and **Call**.
- Up to 12 rider tags, from a fixed list: Open 24/7, Octane 95, Digital payment, EFI diagnostics, Puncture repair, Paddock stand, Genuine parts, Bike parking, Restrooms.
- A green **Verified** badge when the place's `verified` flag is true. The tooltip says "Checked by the ThrottleIQ team" (`placesVerifiedOnlyHint`). Riders can filter to "verified only".
- **Rider Approved** appears automatically at 4.5+ stars from 5+ ThrottleIQ riders. ThrottleIQ does not set it.

### Gaps that affect this offer

| The offer implies | Reality in code | Consequence |
|---|---|---|
| "Verified" sets a partner apart | All 1,238 seeded Dhaka places (OSM and Google Maps imports) are already `verified: true` (`features.md` §6, `scripts/README.md`). A rider-added place is always `verified: false` (`firestore.rules`) | Today a partner's Verified badge looks the same as one on any seeded place. The offer is "listed and checked in person", not "a badge others lack" |
| ThrottleIQ can mark a garage verified | No app screen or script verifies a single place. `updateVerification()` exists in `place_repository.dart` but nothing calls it, and the rules allow no client to change `verified` | The owner needs an Admin SDK one-off to set the flag [PLACEHOLDER: script not written] |
| The garage can update its own listing | No owner-edit or claim flow; `updatePlace()` is not wired to any screen and the rules allow only rating updates | Changes go through ThrottleIQ by phone or WhatsApp |
| The app sends riders to the garage for service | Maintenance reminders are local notifications about the rider's own bike. They do not name or suggest any garage | Do not promise referrals, leads or bookings |
| A counter sticker | No sticker artwork exists in the repo. (SafeQR prints medical-info stickers; that is unrelated) | [PLACEHOLDER: sticker design, size, print cost, QR target] |
| Riders can install from the sticker | No public Play listing. Install is the GitHub APK or Play internal testing by invite (`marketing_kit.md` §4) | Hold printing until a public listing exists, or point the QR at the install page (`https://blankframe.tech/ThrottleIQ/install`) [PLACEHOLDER: owner confirms QR target] |

**Owner decisions before printing anything:**
1. What "verified" means for a partner: [PLACEHOLDER: e.g. an in-person visit that confirms name, location, phone, hours and the services claimed].
2. Whether partners need a mark different from the seeded places (a new field and badge are a code change, out of scope for this draft).
3. Whether to use the name "SafeSpot" at all. It suggests safety or emergency help, which the app does not provide at a garage. [PLACEHOLDER: owner decision on the program name]

## 2. Flyer copy

Only claims from section 1. No numbers of riders, no rankings, no leads.

### English

> **Get your garage found by riders. Free.**
>
> ThrottleIQ is a motorcycle app for riders in Bangladesh. Riders use it to log rides, track their bike's servicing, and find fuel, garages and parts shops nearby.
>
> **We list your garage for free:**
> - Your name, address, phone, opening hours and a photo
> - The services you offer (for example EFI diagnostics, puncture repair, genuine parts)
> - One tap for riders to call you or get directions
> - A Verified mark after we visit and check your details
>
> **What we ask in return:**
> - Keep a ThrottleIQ sticker on your counter
> - Tell your customers they can use ThrottleIQ to get reminders for their next service
>
> No fee. No contract length. Leave any time.
>
> Riders rate garages themselves. We do not sell ratings or top spots.
>
> Contact: [PLACEHOLDER: owner name and phone or WhatsApp] · hello@blankframe.tech
> [PLACEHOLDER: QR to install page, once confirmed]

### Bangla

(Bangla: machine-drafted, needs native review)

> **রাইডাররা আপনার গ্যারেজ খুঁজে পাবে। ফ্রিতে।**
>
> ThrottleIQ বাংলাদেশের রাইডারদের জন্য একটা মোটরসাইকেল অ্যাপ। রাইডাররা এটা দিয়ে রাইড রেকর্ড করেন, বাইকের সার্ভিসিংয়ের হিসাব রাখেন, আর কাছাকাছি ফুয়েল পাম্প, গ্যারেজ আর পার্টসের দোকান খুঁজে পান।
>
> **আমরা আপনার গ্যারেজ ফ্রিতে লিস্ট করব:**
> - আপনার দোকানের নাম, ঠিকানা, ফোন নম্বর, খোলার সময় আর একটা ছবি
> - আপনি কী কী সার্ভিস দেন (যেমন EFI ডায়াগনস্টিক, পাংচার সারাই, জেনুইন পার্টস)
> - এক ট্যাপে রাইডাররা আপনাকে কল করতে বা রাস্তা দেখে আসতে পারবেন
> - আমরা এসে আপনার তথ্য যাচাই করার পর একটা "ভেরিফাইড" চিহ্ন
>
> **বিনিময়ে আমাদের অনুরোধ:**
> - আপনার কাউন্টারে একটা ThrottleIQ স্টিকার রাখবেন
> - কাস্টমারদের বলবেন, পরের সার্ভিসের রিমাইন্ডার পেতে তারা ThrottleIQ ব্যবহার করতে পারেন
>
> কোনো খরচ নেই। কোনো মেয়াদের চুক্তি নেই। যেকোনো সময় বাদ দিতে পারবেন।
>
> গ্যারেজের রেটিং রাইডাররা নিজেরাই দেন। আমরা রেটিং বা উপরের জায়গা বিক্রি করি না।
>
> যোগাযোগ: [PLACEHOLDER: মালিকের নাম আর ফোন বা হোয়াটসঅ্যাপ] · hello@blankframe.tech

### Do not put on the flyer

- "SafeSpot" as a safety or emergency claim, crash alerts, SOS, or "riders in trouble will be sent to you".
- Rider counts, install numbers, "thousands of riders", or any growth figure (none is measured).
- Leads, bookings, analytics, "more customers guaranteed", priority placement.
- "Order parts" or any parts-ordering partnership (the order button is a beta-only demo, issues §95.11).
- "Live on Google Play" until it is.

## 3. Partner terms, plain language

Every clause below needs [LAWYER REVIEW] before use. No Terms of Service exist for the app yet (issues §109.14).

1. **Who.** Blankframe Tech ("ThrottleIQ") and the garage named below ("the Garage"). [LAWYER REVIEW: correct legal entity name, trade licence and address for Blankframe Tech]
2. **What ThrottleIQ gives.** A free listing in the ThrottleIQ app's Places section: name, address, location, phone, opening hours, photo and services offered. After an in-person check, ThrottleIQ marks the listing Verified. [PLACEHOLDER: verification criteria, section 1]
3. **What the Garage gives.** The Garage keeps the ThrottleIQ sticker visible at its counter and may tell customers about ThrottleIQ's service reminders. The Garage is not required to sell, install or support the app.
4. **No money changes hands.** Neither side pays the other. [LAWYER REVIEW: whether a no-consideration arrangement needs any stamp or registration in Bangladesh]
5. **Ratings are the riders'.** Riders rate and review garages. ThrottleIQ does not edit, remove or sell ratings, except to remove reviews that break the community rules (`public/community.html`). [LAWYER REVIEW]
6. **No endorsement.** The Verified mark means ThrottleIQ checked the listing details. It is not a guarantee of the Garage's work, prices or parts. ThrottleIQ is not responsible for work the Garage does. [LAWYER REVIEW: liability and disclaimer wording]
7. **Accurate information.** The Garage tells ThrottleIQ when its details change. ThrottleIQ updates the listing within [PLACEHOLDER: number of days]. Listings are edited by ThrottleIQ, not by the Garage (no self-edit feature exists).
8. **Photos and name.** The Garage allows ThrottleIQ to show its name, photo and details in the app. [LAWYER REVIEW: permission to use the photo and any trademark or shop sign]
9. **Personal data.** ThrottleIQ keeps the Garage contact person's name and phone only to manage the listing. [LAWYER REVIEW: the privacy policy, `public/privacy.html`, does not cover partner contact data today; add it, and check against the Personal Data Protection Ordinance 2025]
10. **Not exclusive.** Either side may work with anyone else. Other garages nearby can be listed too.
11. **Ending it.** Either side can end this at any time by phone, WhatsApp or email. ThrottleIQ removes the Verified mark [PLACEHOLDER: and the listing, or keep the listing as a regular place? owner decision] within [PLACEHOLDER: number of days]. The Garage removes the sticker.
12. **ThrottleIQ may remove a listing** that is closed, gives false details, or gets credible rider reports of fraud. [LAWYER REVIEW]
13. **Changes.** ThrottleIQ tells the Garage before changing these terms. [LAWYER REVIEW: notice method and period]
14. **Law.** [LAWYER REVIEW: governing law and dispute forum, presumably Bangladesh]

Signature block: [PLACEHOLDER: Garage name, contact person, phone, address, date, ThrottleIQ representative].

### Bangla summary for the counter conversation

(Bangla: machine-drafted, needs native review. Summary only; the signed version must be lawyer-reviewed.)

> ThrottleIQ আপনার গ্যারেজ অ্যাপে ফ্রিতে লিস্ট করবে, আর যাচাই করার পর "ভেরিফাইড" চিহ্ন দেবে। আপনি কাউন্টারে স্টিকার রাখবেন আর চাইলে কাস্টমারদের সার্ভিস রিমাইন্ডারের কথা বলবেন। কেউ কাউকে টাকা দেবে না। রেটিং রাইডাররা দেন, আমরা বদলাই না। ভেরিফাইড মানে আমরা আপনার তথ্য যাচাই করেছি, আপনার কাজের গ্যারান্টি না। যেকোনো পক্ষ যেকোনো সময় বাদ দিতে পারবে।

## 4. Placeholders, collected

- [PLACEHOLDER: program name ("SafeSpot" or other)]
- [PLACEHOLDER: verification criteria and who visits]
- [PLACEHOLDER: Admin SDK script to set `verified` on one place]
- [PLACEHOLDER: sticker artwork, size, print cost, QR target]
- [PLACEHOLDER: contact name and number on the flyer]
- [PLACEHOLDER: listing update and removal turnaround in days]
- [PLACEHOLDER: what happens to the listing when a partner leaves]
- [PLACEHOLDER: target count and areas; the "500+" figure comes from the iDEA budget line and PM item 6, it is not a measured list]
- [LAWYER REVIEW] items in section 3
