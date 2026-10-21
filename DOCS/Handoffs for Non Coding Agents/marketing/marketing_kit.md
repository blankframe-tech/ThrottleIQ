# Marketing kit

Ready-to-use copy for the channel plan in [`marketing.md`](marketing.md). Copy,
fill the brackets, adapt the opening line per group. Written 2026-09-05;
corrected 2026-10-22 against the current app.

**The no-overclaim rule.** Crash detection is built but switched off in every
build (shadow mode only, nothing is sent to anyone). No SMS, email or call
goes out. Do not write or imply any of these in any asset: crash alerts,
"we notify your family", SOS, emergency contacts being alerted, "live on Google
Play", an iPhone build, challenges, badge rarity, a premium tier or a price.
What is true today: offline ride recording, distance-based maintenance, a
rider-started live-location link (browser, no login, stops after 24 h), group
ride live map, places, forums, Bangla UI (partly machine-written, review
pending). Check each claim against
`DOCS/Handoff for agents and Todos/features.md` before you post it.

Bangla below that was written or changed on 2026-10-22 is marked
`[draft, unreviewed]`. The owner item "Bangla review by a native speaker"
covers it.

Contents: 1 outreach templates, 2 social captions, 3 FAQ for comment replies,
4 press fact sheet, 5 tester onboarding message, 6 Play screenshot shot list,
7 Phase 0 and 1 calendar.

---

## 1. Outreach templates

Fill the brackets. These communities are close-knit and ad-skeptical, so a
templated mass post reads as one. Do not send any of these until a build is
installable by the people who answer (APK from GitHub releases, or the Play
internal track with them on the tester list).

### Template 1: Closed-tester recruitment post, BD motorcycle Facebook groups (Phase 0)

**Audience:** general BD motorcycle groups and brand owners' groups (Yamaha R15,
Pulsar, RE-type communities). **Goal:** 20-30 closed testers.

**EN:**
> Been building a ride-tracking app for motorcycles for a while now: solo
> project, not a company thing. It records your rides fully offline (no
> signal needed), tracks bike maintenance by actual distance instead of
> guesswork, and lets you share a live-location link with family.
>
> Looking for 20-30 riders in [city/group] to test it before it goes public
> on Play Store. Specifically want to know: does it keep recording through
> the usual dead zones, and how does it do on your phone's battery? Free,
> always will be for core features. Drop a comment or DM if you're in, and
> I'll add you to the tester list directly.

**BN** `[draft, unreviewed]`:
> অনেকদিন ধরে বাইকের জন্য একটা রাইড-ট্র্যাকিং অ্যাপ বানাচ্ছি — একা, কোনো কোম্পানির
> কাজ না। সিগন্যাল ছাড়াই পুরো রাইড রেকর্ড হয়, বাইকের মেইনটেন্যান্স আসল দূরত্ব দেখে
> ট্র্যাক করে (অনুমানে না), আর পরিবারের সাথে লাইভ লোকেশন লিংক শেয়ার করা যায়।
>
> [শহর/গ্রুপ]-এর ২০-৩০ জন রাইডার খুঁজছি যারা Play Store-এ পাবলিক হওয়ার আগে টেস্ট
> করে দেখবেন — বিশেষভাবে জানতে চাই: সিগন্যাল না থাকলেও রেকর্ডিং চলতে থাকে কিনা, আর
> আপনার ফোনের ব্যাটারি কেমন যায়। মূল ফিচারগুলো ফ্রি, সবসময়ই থাকবে। আগ্রহী হলে কমেন্ট
> বা DM করুন — সরাসরি টেস্টার লিস্টে যোগ করে দেব।

---

### Template 2: Launch announcement — same groups, Phase 1

**EN:**
> Update on the ride-tracking app I posted about a while back — it's now
> live on Play Store [internal testing / public, adjust once true]. Been
> testing it with [N] riders here for [X] weeks, fixed the issues that
> came up (mostly around [fill in real fixes from tester feedback]).
> Still solo-built, still free. Link: [Play Store / GitHub release link].
> Would genuinely appreciate anyone giving it a real ride and telling me
> what's broken — that's more useful to me than a good review.

**BN:**
> কিছুদিন আগে যে রাইড-ট্র্যাকিং অ্যাপের কথা বলেছিলাম, তার আপডেট — এখন Play
> Store-এ লাইভ [ইন্টারনাল টেস্টিং / পাবলিক, প্রকৃত অবস্থা অনুযায়ী ঠিক করুন]। এখানকার
> [N] জন রাইডারের সাথে [X] সপ্তাহ টেস্ট করেছি, যা সমস্যা এসেছিল ঠিক করেছি (বেশিরভাগ
> [প্রকৃত ফিক্স লিখুন])। এখনও একা তৈরি, এখনও ফ্রি। লিংক: [Play Store / GitHub
> লিংক]। কেউ সত্যিকারের রাইডে ব্যবহার করে কী ভাঙা আছে বলে দিলে সেটা আমার জন্য একটা
> ভালো রিভিউয়ের চেয়েও বেশি কাজে লাগবে।

---

### Template 3: BD moto YouTube / Facebook-reel reviewer outreach (Phase 1)

**Goal:** honest, unpaid review — not a paid placement (`marketing.md` §5:
one credible review reaches more real riders than ad spend at this stage).

> Hi [name], been following your [channel/page] — the [specific recent
> video/reel, name it] review was genuinely useful.
>
> I've built a motorcycle ride-tracking app (ThrottleIQ) solo — offline-first
> ride recording, a live-location link for family, maintenance
> tracking by real distance, and a rider community/forum. It's in beta
> right now (APK on GitHub, Play internal testing by invite).
>
> No ask attached to a paid placement — I'd just like you to try it on a
> real ride and give an honest take, good or bad, on your channel if you
> think it's worth covering. Happy to send you early access and answer any
> questions about how it works under the hood. Let me know if you're
> interested and I'll get you set up.

---

### Template 4: Touring/riding club outreach — live club-ride demo (Phase 1)

**Goal:** support one organized club ride using "Ride with friends" + saved
routes live (`marketing.md` §5) — targets the enthusiast segment directly.

> Hi [club name] — I run ThrottleIQ, a motorcycle ride-tracking app I built
> solo. It's got a live group-map feature (see everyone's position during
> a ride) and saved routes your club could reuse for regular runs.
>
> Would love to be there (in person or just on standby via a club member)
> for one of your upcoming rides to [route/destination, if known] and let
> a few riders try the group-map feature live — no cost, no obligation, just
> want real feedback from people who actually do this kind of riding
> regularly. If a few people want to keep using it after, even better, but
> that's not the ask here. Let me know if there's an upcoming ride this
> could work for.

---

### Template 5: Garage / parts-shop free POI listing outreach (ongoing, Phase 1+)

**Goal:** solve cold-start empty Places directory + build local goodwill
(`marketing.md` §5). Best delivered in person or by phone in Bangla; text
version below for a first contact / WhatsApp message.

**BN:**
> আসসালামু আলাইকুম, আমি থ্রোটল আইকিউ নামের একটা বাইক অ্যাপ বানাই — রাইডাররা
> কাছাকাছি ফুয়েল পাম্প, গ্যারেজ, আর পার্টসের দোকান খুঁজে পান এমন একটা ফিচার আছে।
> আপনার [গ্যারেজ/দোকানের নাম] সেখানে ফ্রিতে লিস্ট করতে চাই — এতে যারা এই এলাকায়
> সমস্যায় পড়বেন তারা সহজে আপনার দোকান খুঁজে পাবেন। কোনো খরচ নেই, শুধু ঠিকানা আর
> কী কী সার্ভিস দেন সেটা জানালেই হবে।

**EN (for reference/translation check):**
> Hi, I run a motorcycle app called ThrottleIQ — riders can find nearby
> fuel stops, garages, and parts shops through it. I'd like to list your
> [garage/shop name] for free — riders who run into trouble in this area
> would be able to find you easily. No cost, just need your address and
> what services you offer.

---

---

### Spec: "How did you hear about us" (spec, not copy; not built)

One optional single-select shown once after first sign-in, never blocking:
Facebook group, friend or rider referral, YouTube or reel review, touring
club, garage or shop sign, other (free text), prefer not to say. Store it as
a plain `referralSource` field on the user profile doc, no analytics
pipeline. As of 2026-10-22 nothing in `app/lib` implements it. Until it does,
read attribution from Play Console cohorts by hand.

---

## 2. Social captions

Short captions for Facebook and Instagram once the tester community exists.
One segment per post; never mix segments in a single post.

#### Commuter segment

**EN — offline hook:**
> No signal, no problem. ThrottleIQ keeps recording through every dead zone
> on your daily ride — because that's most of the ride, in this city.

**BN — offline hook:**
> সিগন্যাল নেই, সমস্যা নেই। রোজকার রাইডের প্রতিটা ডেড জোনেও থ্রোটল আইকিউ রেকর্ড
> করতে থাকে — কারণ শহরের রাস্তায় সেটাই বেশিরভাগ সময়।

**EN — maintenance hook:**
> "When did I last change the oil?" isn't a question anymore. ThrottleIQ
> tracks it by real distance, not memory.

**BN — maintenance hook:**
> "তেল শেষ কবে পাল্টেছিলাম?" — এই প্রশ্নটা আর থাকবে না। থ্রোটল আইকিউ আসল দূরত্ব
> দেখে হিসাব রাখে, স্মৃতির উপর ভরসা করে না।

---

#### Enthusiast / touring segment

**EN — telemetry hook:**
> Your bike's dash never showed you this. Speed, braking, route, every
> second of the ride — fully offline, all the way to the hill-tract roads
> your signal doesn't reach.

**EN — group-ride hook:**
> Stop screenshotting the route after the fact. See your whole group's
> position live, on the ride, in ThrottleIQ.

**BN — group-ride hook:**
> রাইডের পর রুটের স্ক্রিনশট নেওয়া বাদ দিন। থ্রোটল আইকিউতে পুরো গ্রুপের লাইভ
> পজিশন দেখুন, রাইডের মধ্যেই।

---

#### Anxious-family segment (verify against the no-overclaim rule every time)

**EN** `[draft]`:
> Before a long ride, they send you a link. Open it in any browser and see
> where they are, how fast they're going and how much battery is left. No
> app, no login. They choose when it starts and it stops on its own after 24
> hours.

**BN** `[draft, unreviewed]`:
> লম্বা রাইডের আগে সে আপনাকে একটা লিংক পাঠায়। যেকোনো ব্রাউজারে খুললেই দেখবেন সে কোথায়,
> কত গতিতে যাচ্ছে, আর ফোনে কতটুকু ব্যাটারি আছে — অ্যাপ লাগবে না, লগইন লাগবে না। কখন
> শুরু হবে সেটা রাইডার ঠিক করে, আর ২৪ ঘণ্টা পরে লিংক নিজে থেকে বন্ধ হয়ে যায়।

Never post for this segment: anything about crash detection, automatic
notification, or SMS or email delivery. None of it exists.

#### Solo-builder credibility (once every few weeks at most)

**EN:**
> Built by one rider, not a company. If something's broken, tell me — I'm
> the one who'll fix it.

**BN:**
> একজন রাইডার বানিয়েছেন, কোনো কোম্পানি না। কিছু ভাঙা থাকলে বলুন — আমিই ঠিক
> করব।

---

## 3. FAQ for comment replies

Adapt to your own voice; a pasted wall of text reads as templated in a skeptical group.

**"Another app asking for my location? No thanks."**
Fair to be skeptical. Location is only used for ride tracking and the
optional nearby-places search — it's never sent anywhere without you
starting a ride or tapping "find nearby." No background selling of
location data; there's no ad network or data broker involved because
there's no monetization at all right now. `public/privacy.html` has the
actual data table if you want specifics, not just my word for it.

**"Is this just another side project that gets abandoned in 3 months?"**
Can't prove the future, only show the present: it has had several security
and privacy passes, over 2,000 automated tests run before every push, and
it ships a new beta every week or two. Check the GitHub history yourself, it's
public. If it stalls, you'll see the commits stop, same as with any project.

**"Does it drain my battery running in the background?"**
It uses adaptive GPS accuracy tiers, not maximum precision the whole
time — tuned specifically because most testers ride on prepaid data and
budget phones where battery matters more than lab-perfect GPS. Genuinely
want to know if it doesn't hold up on your specific phone — that's exactly
the kind of feedback closed testing exists for.

**"Strava already does ride tracking, why do I need another app?"**
Strava is built for cyclists and runners. ThrottleIQ is built around the bike:
service schedules by real distance, a record of every service with the bill,
paperwork expiry reminders, motorcycle events like hard braking, and offline
recording through dead zones. If you only want a route map, Strava is fine.

**"Does it detect crashes or call someone if I go down?"**
No, and it matters too much to overclaim. Crash detection is built but
switched off while it is tested on real roads, because a pothole looks like
an impact to a phone. Nothing is sent to anyone automatically. What exists
today is a live-location link you start yourself before a ride and send to
whoever you choose.

**"Is it actually free, or is there a catch later?"**
Free today. No premium tier is built or priced in the app. If/when that happens, core ride recording
and maintenance tracking are not the kind of thing that would go behind a
paywall retroactively; that's a promise about intent, not a
Play-Store-enforced guarantee, so judge it by whether it holds when the
premium tier actually ships.

**"Why should I trust a solo developer with my ride data?"**
Legitimate question, no scripted answer beats just being direct about it:
it's one person, not a company, and that cuts both ways — faster fixes
when you report something, but also no support team if something goes
wrong. The Firestore security rules and data-handling are public in the
repo if you want to actually check rather than take it on trust.

---

## 4. Press and reviewer fact sheet

Hand this to a reviewer alongside the DM in outreach template 3. Update the
status line whenever it changes.

**What it is:** ThrottleIQ turns a rider's phone into a motorcycle logbook:
offline ride recording, distance-based maintenance tracking, a live-location
link for family, and a rider community. Built solo, not by a company.

**Status (2026-10-22):** Beta `1.0.0-beta.4.7.1` (build 29). Signed Android APK
on [GitHub releases](https://github.com/blankframe-tech/ThrottleIQ/releases/latest);
Google Play internal testing by invite (request through the install page).
No public Play listing yet. No iPhone build: iPhone is in development.

**What works today:**
- Offline-first ride recording (GPS and motion sensors), syncs on reconnect
- Maintenance by real distance and time: per-model schedules, a forecast of
  what is due next, service visits with receipts, reminders, paperwork expiry,
  an exportable service record
- Live Share: the rider starts a link that shows location, speed and battery
  in any browser, no login, stops after 24 hours
- Group rides with a shared live map and a join code
- Places (fuel, garages, parts) with rider ratings; saved routes
- Social: follow, audience-tiered ride sharing, brand and model forums, chat
- Bangla and English UI (the Bangla is partly machine-written, native-speaker
  review pending)
- Two looks: Calming light (default) and Carbon Mono dark

**What does not exist (say so plainly if asked):**
- Crash detection is switched off in every build; it runs in shadow mode only
  and nothing is sent to anyone
- No SMS, email or call alerts to anyone
- No public Play or App Store listing
- No monetization; the app is free

**Why it differs from Strava or Komoot:** those are built for cyclists and
runners. Motorcycle-specific competitors exist abroad (Rever, Calimoto,
Detecht, Tonit, EatSleepRide); the honest differentiator is a Bangla,
Bangladesh-road-context, free option, not inventing the category.

**Who it is for:** daily BD commuters (100-160cc, prepaid data), touring and
enthusiast riders (clubs, bigger bikes), and the families who care about them.

**Built by:** a solo developer in Bangladesh. App id `com.bft.throttleiq`.
**Contact:** hello@blankframe.tech. **Source and releases:**
https://github.com/blankframe-tech/ThrottleIQ

**Assets on request:** app icon (light and dark), the feature graphic
(`DOCS/General/Files for Stores/store_listing/`), real in-app screenshots.
Never send mockups of unbuilt features.

---

## 5. Closed-tester onboarding message

Send the moment someone is added to the Play tester list or handed the APK.
Recruitment gets a yes; this is what stops the silent churn after it.

**EN:**
> You're in, thanks for testing ThrottleIQ.
>
> **To install:** [if Play] check your email for the opt-in link from Google
> Play, tap it, then open the Play Store app and search ThrottleIQ (or use
> the direct link I'll send). [if GitHub APK] download the APK from [link].
> Android will warn about "unknown sources"; that's expected for a beta not
> on Play yet, allow it just for this install.
>
> **What I actually want from you:**
> 1. Record at least one real ride. Does it survive a signal dead zone
>    without losing data?
> 2. Does it keep recording with the screen locked, and how much battery
>    does a ride cost on your phone?
> 3. Anything that felt broken, confusing or just annoying, big or small.
>
> Reply here or DM me, whichever is easier. No bug-report format needed:
> "the maintenance screen did something weird" is a perfectly good report.

**BN** `[draft, unreviewed; lines 1 and 3 unchanged from 2026-09-05, line 2 new]`:
> আপনি এখন টেস্টার — থ্রোটল আইকিউ টেস্ট করার জন্য ধন্যবাদ।
>
> **ইনস্টল করতে:** [Play Console হলে] Google Play থেকে পাঠানো ইমেইলে
> opt-in লিংক চেক করুন, ট্যাপ করুন, তারপর Play Store অ্যাপে গিয়ে ThrottleIQ
> সার্চ করুন (অথবা আমি সরাসরি লিংক পাঠাব)। [GitHub APK হলে] [লিংক] থেকে APK
> ডাউনলোড করুন — অ্যান্ড্রয়েড "unknown sources" নিয়ে সতর্ক করবে, এটা স্বাভাবিক
> কারণ এটা এখনও Play Store-এ নেই, শুধু এই ইনস্টলের জন্য অনুমতি দিন।
>
> **আপনার কাছ থেকে যা জানতে চাই:**
> ১. অন্তত একটা আসল রাইড রেকর্ড করুন — সিগন্যাল না থাকা জায়গায় ডেটা হারায়
>    কিনা দেখুন।
> ২. স্ক্রিন লক থাকলেও রেকর্ডিং চলতে থাকে কিনা, আর একটা রাইডে আপনার ফোনের ব্যাটারি কতটা
>    খরচ হয়?
> ৩. যা কিছু ভাঙা মনে হয়েছে, গোলমেলে লেগেছে, বা বিরক্তিকর লেগেছে — ছোট হোক
>    বা বড়, বলে ফেলুন।
>
> এখানে রিপ্লাই করুন বা সরাসরি DM করুন, যেটা সহজ। কোনো ফরমাল বাগ-রিপোর্ট
> ফরম্যাট লাগবে না — "মেইনটেন্যান্স স্ক্রিনে কিছু একটা অদ্ভুত লাগলো" এটাই
> যথেষ্ট।

---

## 6. Play screenshot shot list

`store_listing/` has an icon and a feature graphic but no screenshots. Real
screenshots are the biggest conversion gap before a public listing. Capture on
a real device with real or seeded data (never an empty forum or a Places map
with no pins), portrait, with a short caption bar. Order is broadest appeal
first.

| # | Screen | Caption (EN) | Caption (BN, 2026-09-05 draft) |
|---|---|---|---|
| 1 | Ride summary (max speed, distance, duration, hard-braking counts) | "Every ride, fully analyzed" | "প্রতিটি রাইডের সম্পূর্ণ বিশ্লেষণ" |
| 2 | Active ride screen mid-ride | "Works even with zero signal" | "সিগন্যাল না থাকলেও কাজ করে" |
| 3 | Garage and maintenance (service intervals by distance) | "Never guess when it's due again" | "আর অনুমানে চলবে না" |
| 4 | Live Share, rider side | "Share your ride, live, with who you choose" | "যাকে চান, তার সাথে লাইভ শেয়ার করুন" |
| 5 | Group ride live map | "See your whole group, live" | "পুরো গ্রুপ একসাথে, লাইভ" |
| 6 | Brand or model forum with real posts | "Find your bike's people" | "আপনার বাইকের কমিউনিটি" |
| 7 (optional) | Places map | "The nearest fuel stop, one tap away" | "সবচেয়ে কাছের ফুয়েল পাম্প, এক ট্যাপে" |

Do not shoot a crash screen (the detector is off) or any mocked screen.
Keep the "under active development" closing line of the store listing: a rider
told to expect rough edges rates more kindly. Category: Auto & Vehicles. Re-check
the listing each time a segment-relevant feature ships.

---

## 7. Calendar, Phase 0 and 1

Relative weeks; start when a build is installable (owner item "Put the app on
Google Play"). Skip any row whose template is not true yet.

| Week | Action | Channel | Template |
|---|---|---|---|
| 1 | Recruit closed testers | 2-3 general BD moto FB groups, 1-2 brand owners' groups | 1 |
| 1 | Check the POI directory for Dhaka, Chattogram, Sylhet | internal | |
| 2 | Add responders to the tester list; send the onboarding message | Play Console | section 5 |
| 2 | First garage and parts-shop outreach for free listings | WhatsApp, in person | 5 |
| 2-3 | Collect feedback on offline survival and battery | DMs, comments | |
| 3 | Ship the Bangla store listing (after native review) | Play Console | `store_listing_bn_addendum.md` |
| 4 | Launch post in the tester groups and 2-3 new groups | FB groups | 2 |
| 4-5 | Reviewer outreach, 2-3 YouTube or reel accounts | DM, email | 3 |
| 5 | Propose a live club-ride demo to 1-2 clubs | direct message | 4 |
| 6 | If a review goes live, share it in the groups (no cold re-post) | FB groups | |
| 7-8 | Support the club ride if a club said yes | in person | |
| 9 | Retro: installs vs Day-7 and Day-30 retention; repeat in the next city or fix retention first | internal | |

Do not: buy installs (paid acquisition waits for Phase 2-3), post identical
text in many groups the same week (stagger by days, change the opening line),
or push iPhone (there is no build).
