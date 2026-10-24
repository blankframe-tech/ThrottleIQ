# DRAFT: "Ustad, where's my phone?" (password link, /r/@handle)

**Status: DRAFT. Do not post.** The feature is being built (2026-10-25). The
shipped app today has a different switch, "Public link (/r/@handle)": no
password, and the link works only while the rider is live-sharing
(`app/lib/core/services/public_live_link_setting.dart`). Everything below
describes the password version. Before posting, check every line marked
**[VERIFY]** against the built feature and `features.md`.

Poster: `../posters/batch_four/1_lost-phone-password-link.svg` (notes in
`../posters/batch_four/README.md`).

---

## 1. What the feature does (the only facts this campaign may use)

- Settings → Privacy & Safety → "Password link (/r/@handle)". The rider turns
  it on and sets a password of at least 8 characters.
- While it is on, **every ride** (started by hand or auto-detected) shares the
  phone's live location to `https://throttleiqfb.web.app/r/<handle>`.
- Whoever opens the link must type the password first. Without it they see
  nothing.
- When the ride ends, or the phone dies or is switched off during the ride,
  the link keeps showing the **last known location** with "last seen X ago".
- It does **not** track the phone outside rides.
- Separate, and unchanged: the Share button on a ride makes a one-off link
  that anyone can open, for that ride only.

## 2. Positioning

**Lead segment: riders (commuters first).** The owner's story is a rider's
own panic. It needs no persuasion of a third person, and a rider sets the
feature up himself in 30 seconds. Every BD rider has felt for his pocket at a
signal. Enthusiasts get the same message through the same asset; the story
is not about the bike, so it does not blend the commuter and enthusiast
pitches.

**Second asset: anxious family** (section 6). This is a separate post with a
separate tone. Family is a distribution channel. The rider sets up the link
and gives the password to them.

Positioning line:
- EN: *If your phone falls off during a ride, open your link from any phone,
  type your password, and see where it is.*
- BN: *রাইডে ফোন পড়ে গেলে যেকোনো ফোন থেকে নিজের লিংক খুলুন, পাসওয়ার্ড দিন,
  দেখুন ফোনটা কোথায়।*

Growth-loop class: **retention plus light acquisition.** The rider has to be
installed and set it up, so this is a reason to keep the app on and
auto-detect enabled. It is a "tell a friend" story, not a loop. The link page
gets a small acquisition effect only if the `/r/` viewer carries the same
install call to action as `public/live-viewer.html` **[VERIFY]**.

## 3. Key messages (in priority order)

1. **Phone gone? Open your link from any phone.** You need a borrowed phone,
   your @handle and your password. Nothing else.
2. **Switched off? You still see the last place.** "Last seen 32 min ago,
   Palashi mor."
3. **Only during rides, and only with the password.** It is not tracking you
   all day. Nobody without the password sees anything.
4. **Turn it on once.** Every ride after that is covered, auto-detected rides
   too.

Proof point (once built): the setting screen, the password gate on
`/r/<handle>`, and the "last seen" label. Screenshots or screen recordings
only. Don't use mockups once the real UI exists.

## 4. Honest claims vs. claims to avoid

| OK to say | Never say |
|---|---|
| "See where your phone was last seen during a ride" | "Find your phone anywhere" / "anti-theft" / "track a stolen phone" |
| "Works from any phone's browser, with your password" | "Always-on tracking", "24/7", "even when you're not riding" |
| "Phone switched off? The link shows the last location" | "Tracks the phone after it's switched off" |
| "Only during rides" | "Replaces Find My Device / Find My" (tell people to keep those on too) |
| "Nobody sees it without the password" | "100% secure", "unhackable" |
| "If the ride is still recording, the dot moves" **[VERIFY]** | "Follow the thief", "catch whoever took it" |
| "Free, Android" | "iPhone", "SMS alert", "we'll notify you" |

Things to check before any of this goes public:
- **[VERIFY] How fresh "last known" is.** It is the last location that
  *reached the server*. With no signal where the phone fell, the app records
  offline, and the link may show an earlier spot than where it actually lies.
  Copy says "last seen", never "exactly where it is".
- **[VERIFY] What happens after the phone falls and lies still.** Does
  auto-detect end the ride? Then the link shows the last spot, which is good.
  If someone picks it up and carries it, does a new ride start? If not, the
  "follow it" part of the owner's story is not true, and the video must cut
  beat 6 (see section 7).
- **[VERIFY] How long the last location stays** on the link after the ride
  ends (hours, days, until the next ride?).
- Requires location permission set to "Allow all the time", auto-detect
  turned on for automatic rides, mobile data, and a battery saver that does
  not kill the app. Say "turn on auto-detect" in setup copy.
- Does nothing if the phone is lost while **not** riding (in a rickshaw, at a
  tea stall after the ride ended and the location moved since).
- **Personal safety line, always included where "it's moving" appears:**
  "If it's moving, don't chase it alone. Go with someone, or call 999."

## 5. Captions / post copy

### 5a. Rider post (Facebook groups, lead asset)

**BN**

> ওস্তাদ, রাইড শেষে পকেটে হাত দিয়ে দেখি ফোন নাই।
>
> ThrottleIQ-তে এখন একটা পাসওয়ার্ড লিংক আছে: throttleiqfb.web.app/r/@আপনার-ইউজারনেম।
> রাইড চলার সময় ফোনের লোকেশন ওখানে থাকে। অন্য কারো ফোন থেকে লিংকটা খুলুন,
> পাসওয়ার্ড দিন, দেখুন ফোনটা শেষ কোথায় ছিল। ফোন বন্ধ করে দিলেও শেষ জায়গাটা দেখায়,
> "শেষ দেখা ৩২ মিনিট আগে" লেখা থাকে।
>
> ✔ শুধু রাইডের সময় শেয়ার হয়, সারাদিন না
> ✔ পাসওয়ার্ড ছাড়া কেউ কিছু দেখে না
> ✔ Settings → Privacy & Safety → Password link, একবার চালু করলেই হয়
>
> Find My Device বন্ধ করবেন না, এটা তার বদলি না। এটা রাইডের জন্য বাড়তি সেফটি নেট।
> ফ্রি, Android। blankframe.tech/ThrottleIQ

**EN**

> Felt for your pocket after a ride and the phone wasn't there?
>
> ThrottleIQ now has a password link: throttleiqfb.web.app/r/@yourhandle.
> During a ride, your phone's location goes there. Open it from any phone, type
> your password, and see where your phone was last. If it gets switched off,
> the link still shows the last spot, marked "last seen 32 min ago".
>
> ✔ Shares only during rides, not all day
> ✔ Nobody sees anything without your password
> ✔ Settings → Privacy & Safety → Password link, turn it on once
>
> Keep Find My Device on too. This doesn't replace it; it's an extra safety
> net for rides. Free, Android. blankframe.tech/ThrottleIQ

### 5b. Short captions (reels, story stickers)

- BN: "ওস্তাদ, ফোন কই? লিংক খুলে দেখুন।" / EN: "Lost your phone on a ride? Open your link."
- BN: "ফোন বন্ধ? শেষ জায়গাটা তো দেখা যায়।" / EN: "Switched off? You still see the last place."
- BN: "পাসওয়ার্ড ছাড়া কেউ না। রাইড ছাড়া কিছু না।" / EN: "No password, no view. No ride, no sharing."

### 5c. Setup reminder (comment reply or follow-up post)

- BN: "লিংক আর পাসওয়ার্ড একটা কাগজে লিখে মানিব্যাগে রাখুন। ফোন হারালে নিজের ফোনে তো দেখতে পারবেন না।"
- EN: "Write your link and password on a slip in your wallet. If the phone's gone, it can't remind you."

## 6. Family-safety variant (separate asset; never merge with 5a)

Segment: anxious family, reached through the rider. Frame: "set it up and
give your family the password", the way you'd give them a spare key.

**BN**

> রাইডে বের হলে বাসায় সবাই চিন্তা করে? একবার সেট করে দিন।
>
> ThrottleIQ-র পাসওয়ার্ড লিংক চালু করুন, আর লিংক আর পাসওয়ার্ডটা আম্মু বা
> জীবনসঙ্গীকে দিয়ে রাখুন। আপনি যখনই রাইডে থাকবেন, উনি যেকোনো ব্রাউজারে আপনার
> লোকেশন দেখতে পাবেন, প্রতিবার লিংক পাঠাতে হবে না। রাইড শেষ হলে বা ফোনের চার্জ
> শেষ হলে শেষ লোকেশন আর কতক্ষণ আগে দেখা গেছে, সেটা দেখায়।
>
> শুধু রাইডের সময়। পাসওয়ার্ড ছাড়া কেউ দেখে না।

**EN**

> Family worries every time you ride out? Set it up once.
>
> Turn on ThrottleIQ's password link and give the link and password to your
> mother or spouse. Whenever you're on a ride, they can see your location in
> any browser, without you sending a link every time. When the ride ends or
> your battery dies, it shows the last location and how long ago it was seen.
>
> Only during rides. Nobody sees it without the password.

Never in this variant: "they'll know if you crash", "alerts", "automatic
notification", "always know where he is". The crash detector is off in every
build, and SMS/email alerts are not deployed. "Last seen" when the battery
dies is a fact. Don't spin it as "they'll know something happened".

Short copy: BN "একবার সেট করুন, বাসায় নিশ্চিন্ত।" / EN "Set it once. Home stops worrying."

## 7. Short video (30–45 s, vertical 9:16, rider asset)

Tone: real, slightly funny panic, not a thriller. Casual Dhaka Bangla. Shot
on phones, no actors needed beyond two people. Location: a real "mor" (the
owner's story uses Palashi), plus a tea stall.

| # | Time | Shot | Voice-over (BN, casual) | On-screen text |
|---|---|---|---|---|
| 1 | 0–3 s | Close-up: rider at a tea stall, pats chest pocket, then jeans, then jacket. Freezes. | (no VO; ambient street noise, a single "ঢিং" sound) | **ফোন কই???** |
| 2 | 3–7 s | Rider turns to the tea-stall guy, wide-eyed. | "ওস্তাদ, আমার ফোনটা কই গেল? রাইডে পড়ে গেছে মনে হয়…" | "আধা ঘণ্টা পরে টের পেলাম" |
| 3 | 7–12 s | Stranger hands over his phone. Rider types `throttleiqfb.web.app/r/@rafi` in the browser. | "ভাই, আপনার ফোনটা এক মিনিট দেন তো।" | `/r/@rafi` (big, mono) |
| 4 | 12–17 s | Screen recording: password field, 8 dots, tap Open. | "লিংক খুলি, পাসওয়ার্ড দেই…" | **পাসওয়ার্ড ছাড়া কেউ দেখবে না** |
| 5 | 17–23 s | Screen: map, pin, "last seen 31 min ago", Palashi mor. Cut to rider's face, relieved. | "পলাশী মোড়! চলেন ওস্তাদ, এক্ষুনি।" | **শেষ দেখা: ৩১ মিনিট আগে · পলাশী মোড়** |
| 6 | 23–29 s | **[VERIFY: cut if a carried phone doesn't keep recording]** Screen: the dot moves a little along a road. Rider and stranger walk fast together. | "নড়তেছে? কোন দিকে যাচ্ছে দেখা যাচ্ছে। একা দৌড় দিয়েন না, সাথে কাউরে নেন।" | **একা পিছু নেবেন না · দরকারে ৯৯৯** |
| 7 | 29–34 s | Screen: phone goes "offline", the pin stays, label updates. | "কেউ ফোন বন্ধ করে দিলেও শেষ জায়গাটা থাকে।" | **ফোন বন্ধ হলেও শেষ লোকেশন** |
| 8 | 34–38 s | Rider picks the phone up from the roadside near the mor, exhales, laughs. | "পাইছি! ওস্তাদ, চা আমার তরফ থেকে।" | (none) |
| 9 | 38–44 s | End card: Settings screen, Password link toggle turning on, then the logo. | "ThrottleIQ। Settings-এ পাসওয়ার্ড লিংক চালু করেন। শুধু রাইডের সময়, শুধু পাসওয়ার্ড দিয়ে।" | **Settings → Privacy & Safety → Password link** / **ফ্রি · Android · blankframe.tech/ThrottleIQ** |

Without beat 6 the video runs about 38 s. Beat 7 then needs a line of setup:
"পড়ে থাকা ফোনটা কেউ বন্ধ করে দিলেও…"

Small print on the end card (BN, about 2 s): "শুধু রাইড চলার সময় কাজ করে। Find My Device-এর বদলি না।"

Production notes:
- Use a test account with the handle `rafi` (the poster uses `@rafi`). Never
  show a real rider's handle or password.
- Screen recordings must come from the built feature. Until then, the script
  is a storyboard only.
- Don't show the rider riding one-handed or on the phone while riding.

## 8. Where it goes

- Same BD motorcycle Facebook groups as the Phase 0/1 tester posts
  (`marketing.md` §5): the rider post (5a) plus the video.
- The family variant (6) goes out a week later as a "show this to your
  family" post, and as a line in the tester onboarding message in
  `marketing_kit.md`, once the feature ships.
- Poster `batch_four/1` goes on tea stalls and parking spots near busy
  junctions (QR campaign `lostphone_b4`).

## 9. Track

- Installs from `?c=lostphone_b4` (poster) vs. the post links.
- Share of active riders with the password link on, after 2 weeks.
- `/r/` page opens that pass the password (a proxy for "someone used it"),
  if the backend logs it **[VERIFY]**. Don't log passwords or locations for
  analytics.
- One real recovery story (with the rider's consent) is worth more than any
  ad. Ask testers to report one.
