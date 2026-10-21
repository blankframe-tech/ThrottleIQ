# Play Store listing — Bangla addendum (draft, needs native-speaker review)

Companion to `store_listing.md` (English, source of truth for what's
actually built). Updated 2026-10-22: crash detection and leaderboards removed
(neither is live), a Live Share section added to match the English listing.
The new Bangla lines in the Live Share section are not yet reviewed by a
native speaker. This draft adds the Bangla translation Play Console
supports natively (Store presence → Translations → add Bengali) — it does
**not** replace the English listing, both should be live together per
`marketing.md` §3 ("ship with a Bangla short description and Bangla
keywords alongside the English one").

Tone matches the existing Bangla sample copy in
`marketing.md` §2 (`DOCS/Handoffs for Non Coding Agents/marketing/`) — direct, plain, no marketing-speak
superlatives, checked against the no-overclaim rule (no automatic SMS/email
alert claim, no precise data-point-per-second number).

**Before pasting into Play Console:** have a Bangla-speaking rider (or the
20-30 closed testers once recruited) skim this for tone/idiom — a
literal-but-correct translation can still read as stiff or slightly off to
a native speaker in a way I can't fully self-check.

---

## App name
থ্রোটল আইকিউ (keep the Latin "ThrottleIQ" as a subtitle/parenthetical if
Play allows a secondary name field — brand recognition matters more than a
full Bangla name for a product name)

## Short description (target ≤80 characters — verify in Play Console;
Bangla conjuncts can count differently than the English budget)

**Option A (commuter-first, matches segment-priority order in
`marketing.md` in `DOCS/Handoffs for Non Coding Agents/marketing/`):**
> সিগন্যাল না থাকলেও রাইড রেকর্ড হয়। বাইকের মেইনটেন্যান্স, লাইভ শেয়ার, সব একসাথে।

*(Rides record even without signal. Bike maintenance, live share, all in
one place.)*

**Option B (feature-parity with the English short description):**
> প্রতিটি রাইড ট্র্যাক করুন: গতি, রুট, মেইনটেন্যান্স, লাইভ শেয়ার ও রাইডার কমিউনিটি।

*(Track every ride: speed, route, maintenance, live share, and rider
community.)*

Recommend **Option A** — it leads with the offline-first hook that
`marketing.md` §3 identifies as the strongest, most locally-resonant
commuter message, rather than a straight feature list.

## Long description (Bangla)

> থ্রোটল আইকিউ একটি রাইড ট্র্যাকিং ও বাইক-বুদ্ধিমত্তা অ্যাপ — তৈরি তাদের জন্য যারা
> পারফরম্যান্স, নিরাপত্তা, আর বাইক ঠিকঠাক চলা নিয়ে সত্যিই ভাবেন।
>
> **রাইড রেকর্ডিং**
> • স্ক্রিন লক থাকলেও ব্যাকগ্রাউন্ডে নিজে থেকে রেকর্ড হয়
> • রাইডের সময় লাইভ গতি, অ্যাক্সিলারেশন, উচ্চতা ও দূরত্ব দেখা যায়
> • ওভারস্পিড, হার্ড ব্রেকিং, হঠাৎ অ্যাক্সিলারেশন আর দীর্ঘ রাইডে ক্লান্তির জন্য স্মার্ট
>   অ্যালার্ট
> • সম্পূর্ণ অফলাইনে কাজ করে — রাইড প্রথমে আপনার ফোনেই সেভ হয়, প্রতিবার
>
> **রাইড হিস্ট্রি ও স্ট্যাটস**
> • প্রতিটি রাইডের সামারি: সর্বোচ্চ গতি, দূরত্ব, সময়, হার্ড-ব্রেকিং ও অ্যাক্সিলারেশনের
>   সংখ্যা
> • চলমান সময় আর থেমে থাকা সময় আলাদা করে দেখায়
> • যেকোনো রাইড JSON বা GPX ফরম্যাটে এক্সপোর্ট করে অন্য অ্যাপে ব্যবহার করা যায়
>
> **লাইভ শেয়ার**
> • লাইভ লিংক শেয়ার করুন — পরিবার বা বন্ধুরা রাইডের সময় রিয়েল-টাইমে আপনার অবস্থান, গতি
>   ও ব্যাটারি দেখতে পাবেন
> • কখন শুরু হবে সেটা আপনি ঠিক করেন, যেকোনো সময় বন্ধ করা যায়, আর ২৪ ঘণ্টা পরে লিংক নিজে
>   থেকে কাজ করা বন্ধ করে দেয়
>
> **গ্যারেজ ও মেইনটেন্যান্স**
> • একাধিক বাইক, তাদের ওডোমিটার আর সার্ভিস হিস্ট্রি ট্র্যাক করুন
> • কী মেইনটেন্যান্স কবে দরকার, তার হিসাব রাখুন — অনুমানের উপর নির্ভর না করে
>
> **রাইডার প্লেসেস**
> • কাছাকাছি ফুয়েল পাম্প, গ্যারেজ আর পার্টসের দোকান খুঁজে পান — অন্য রাইডারদের দেওয়া
>   তথ্য ও রেটিং থেকে
> • রাইডের মধ্যেই এক ট্যাপে সবচেয়ে কাছের ফুয়েল পাম্প খুঁজে নিন
>
> **রাইডার কমিউনিটি**
> • অন্য রাইডারদের ফলো করুন, ছবি আর রুট সহ রাইড শেয়ার করুন
> • ফিড আর ফোরামে আপভোট ও কমেন্ট করুন
> • প্রতিটি রাইডের জন্য আলাদা করে ঠিক করুন কে দেখবে
> • আপনার বাড়ির লোকেশন কখনোই প্রকাশ পায় না — শেয়ার করা প্রতিটি রুটের শুরু ও শেষ
>   স্বয়ংক্রিয়ভাবে ছেঁটে দেওয়া হয়
>
> **ক্লাউড ব্যাকআপ**
> • অনলাইনে থাকলে প্রোফাইল, বাইক আর মেইনটেন্যান্স লগ নিজে থেকেই ব্যাকআপ হয়
> • গুগল বা ইমেইল দিয়ে সাইন ইন করুন
>
> থ্রোটল আইকিউ এখনও সক্রিয়ভাবে তৈরি হচ্ছে — সামনে আরও ফিচার আসছে, যেমন বাঁকা রাস্তার
> জন্য বিশেষ নেভিগেশন আর ক্লাব ইভেন্ট।

## Keywords (Bangla — for your own reference; Play derives search terms
from description + category, same as the English listing notes)

মোটরসাইকেল, বাইক ট্র্যাকার, জিপিএস ট্র্যাকার, লাইভ লোকেশন শেয়ার, বাইক মেইনটেন্যান্স,
রাইডার কমিউনিটি, বাইক লগ, রাইড লগ, বাইক সার্ভিস রিমাইন্ডার

## What was deliberately kept out (mirrors the English listing's accuracy notes)

- No crash detection or emergency-alert claim — same as the English
  listing: the detector is off in every build and nothing is sent to anyone.
- No specific data-point-per-second number.
- "থ্রোটল আইকিউ" is used as the product name throughout rather than a fully
  localized invented Bangla name — the product is known by its English name
  in every channel (GitHub, existing Facebook assets, the landing page), and
  inventing a different Bangla name here would fragment brand recognition
  rather than help ASO.
