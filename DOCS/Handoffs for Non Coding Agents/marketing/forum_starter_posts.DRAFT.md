> DRAFT for owner review, 2026-10-22

# Brand forum starter posts (PM item 5)

Starter posts and discussion prompts for cold-start seeding (`marketing.md` §4: "seed 2-3 starter posts in the biggest brand forums so nothing looks abandoned on day one"). Every Bangla block is machine-drafted and needs native review before posting.

## 1. What the app actually has (checked in code, 2026-10-22)

- **Brand paddocks** (`app/lib/features/forums/domain/forum_directory.dart`, `kBrandPaddocks`): Yamaha, Honda, Royal Enfield, KTM, Bajaj, TVS, Suzuki, Kawasaki, Hero. Opening one creates it if it does not exist yet.
- **Model forums** are created per bike, one per brand + model (`bikeForumSlug` in `app/lib/core/utils/slugify.dart`). A brand paddock also shows its model forums' posts, tagged "from <model>". Model forums do not show brand-level posts.
- **Model names come from the bike catalog** (`app/lib/core/constants/bike_catalog.dart`) or whatever the rider types. Only Yamaha FZ-S generations are merged into one forum (`yamaha__fzs`).
- **Post types:** Troubleshoot, DIY guide, Gear review, General. Up to 4 photos. The author of a Troubleshoot post can mark it solved.
- **Topic boards** that fit cross-brand prompts: Maintenance ("The Wrench Bench"), Engine Oil Review, Mileage Tips, Riding Skills, and others.

### Mismatches with PM item 5

| PM item 5 says | Code says | Suggested handling |
|---|---|---|
| "Yamaha FZ/R15" forum | Two model forums: `yamaha__fzs` and `yamaha__r15` (catalog names `FZS`, `R15`). No combined forum | Post one set in each model forum. Both show up in the Yamaha paddock |
| "Bajaj Pulsar" | Catalog has `Pulsar 150` and `Pulsar NS160`, two separate forums | Seed `Pulsar 150`. Add an NS160 post later if riders show up |
| "Suzuki Gixxer" | Catalog has `Gixxer 155` and `Gixxer SF 155`, two separate forums | Seed `Gixxer 155` |
| "Honda Hornet" | **Hornet is not in the bike catalog.** Riders who type "Hornet 160", "CB Hornet 160R" or "Hornet 2.0" each get a separate forum. (The maintenance schedule template does recognise Hornet: `schedule_templates.dart`, `honda_hornet_160`.) | Post in the **Honda** paddock until the catalog gets one Hornet name (a code change, owner call) |
| "Royal Enfield Bangladesh" | The paddock is named "Royal Enfield". Catalog models: Classic 350, Bullet 350, Meteor 350, Hunter 350, Himalayan 411 | Post in the Royal Enfield paddock (covers every RE model) |

## 2. Posting rules

- Post from the owner's own account and say plainly that you built the app. These groups are ad-skeptical (`marketing_kit.md` §1).
- **No specs from memory.** No service intervals, oil grades, prices, part numbers or dealer claims. Ask riders for theirs.
- Do not mention crash alerts, SOS, prizes, badge rewards, "live on Google Play" or anything on the `marketing_kit.md` no-overclaim list.
- Point to features that exist (fuel log km/L, maintenance setup, Ask owners, Share to forum). Do not promise fixes on a date.
- Pick the post type shown in brackets.

---

## 3. Yamaha FZS (`yamaha__fzs`) and Yamaha R15 (`yamaha__r15`)

### Post Y1 [General]: "FZS owners: what is your real mileage?"

**EN:**
> Hi all, I built ThrottleIQ and I ride too. Let's make one useful thread: what km/L does your FZS actually get in daily riding?
> Please share: generation (V2, V3, Fi...), city or highway, and how you measured it (full tank to full tank, or a guess).
> If you use the app's fuel log, it works km/L out between two full-tank fills, so the number is from your own fill-ups.

**BN:** (Bangla: machine-drafted, needs native review)
> সবাইকে সালাম, আমি ThrottleIQ বানিয়েছি, নিজেও বাইক চালাই। চলুন একটা কাজের থ্রেড বানাই: প্রতিদিনের চলাচলে আপনার FZS আসলে লিটারে কত কিলোমিটার যায়?
> জানাবেন: কোন জেনারেশন (V2, V3, Fi...), শহরে নাকি হাইওয়েতে, আর কীভাবে মেপেছেন (ফুল ট্যাংক থেকে ফুল ট্যাংক, নাকি আন্দাজে)।
> অ্যাপের ফুয়েল লগ ব্যবহার করলে, দুইবার ফুল ট্যাংক ভরার মাঝের হিসাব থেকে km/L বের করে দেয়, তাই সংখ্যাটা আপনার নিজের তেল ভরার হিসাব থেকেই আসে।

### Post Y2 [Troubleshoot]: "Most common problem you have had with your R15?"

**EN:**
> R15 owners: what is the one problem that came back most often on your bike, and what finally fixed it?
> I'll mark the reply that fixes it as the solution, so the next owner finds it fast.

**BN:** (Bangla: machine-drafted, needs native review)
> R15 মালিকরা: আপনার বাইকে কোন সমস্যাটা সবচেয়ে বেশিবার ফিরে এসেছে, আর শেষ পর্যন্ত কীভাবে ঠিক হয়েছে?
> যে উত্তরে সমস্যার সমাধান হবে, আমি সেটাকে সমাধান হিসেবে মার্ক করব, যাতে পরের মালিক দ্রুত খুঁজে পান।

### Post Y3 [General]: "Does the default service schedule match your dealer's?"

**EN:**
> When you set up maintenance for an FZ or R15 in ThrottleIQ, it picks a schedule for that model, with its free services. Does it match what your dealer or service book told you? If not, tell me what yours says and I will check the template.

**BN:** (Bangla: machine-drafted, needs native review)
> ThrottleIQ-এ FZ বা R15-এর মেইনটেন্যান্স সেটআপ করলে অ্যাপ ওই মডেলের জন্য একটা শিডিউল বেছে নেয়, ফ্রি সার্ভিসসহ। এটা কি আপনার ডিলার বা সার্ভিস বুকের সাথে মেলে? না মিললে আপনারটা জানান, আমি টেমপ্লেটটা দেখে নেব।

**Discussion prompts (Yamaha):**
- Which generation do you ride, and would you buy the same one again?
- Best route out of Dhaka for a weekend ride on an R15? Share it as a saved route if you have one.
- Chain care: how often do you clean and lube, and with what?

---

## 4. Bajaj Pulsar 150 (`bajaj__pulsar_150`)

### Post B1 [General]: "Pulsar 150 owners: what does a km cost you?"

**EN:**
> Pulsar 150 riders: after fuel and servicing, what does your bike cost you per km? The app's Running costs card works this out from your fuel log and service bills, but I would like to hear real numbers from riders, however you count them.

**BN:** (Bangla: machine-drafted, needs native review)
> পালসার ১৫০ রাইডাররা: তেল আর সার্ভিসিং মিলিয়ে কিলোমিটারপ্রতি আপনার খরচ কত পড়ে? অ্যাপের রানিং কস্ট কার্ড আপনার ফুয়েল লগ আর সার্ভিস বিল থেকে এটা হিসাব করে, তবে আমি রাইডারদের আসল হিসাব শুনতে চাই, যেভাবেই গুনুন।

### Post B2 [Troubleshoot]: "First thing you replaced on your Pulsar?"

**EN:**
> What was the first part you had to replace on your Pulsar, at roughly what km, and was it covered by a free service? Your answers help new owners know what to watch for.

**BN:** (Bangla: machine-drafted, needs native review)
> আপনার পালসারে প্রথম কোন পার্টসটা বদলাতে হয়েছিল, মোটামুটি কত কিলোমিটারে, আর সেটা কি ফ্রি সার্ভিসে কভার হয়েছিল? আপনাদের উত্তর নতুন মালিকদের বুঝতে সাহায্য করবে কোন দিকে নজর রাখতে হবে।

### Post B3 [DIY guide prompt]: "Show your DIY jobs"

**EN:**
> If you do your own oil change or chain adjustment, post a DIY guide with photos (up to 4). Short and real beats long and perfect.

**BN:** (Bangla: machine-drafted, needs native review)
> নিজে অয়েল চেঞ্জ বা চেইন অ্যাডজাস্ট করলে ছবিসহ (৪টা পর্যন্ত) একটা DIY গাইড পোস্ট করুন। ছোট আর আসল, লম্বা আর নিখুঁতের চেয়ে ভালো।

**Discussion prompts (Bajaj):**
- Pulsar 150 or NS160: which would you pick today, and why?
- Which mechanic in your area knows Pulsars best? (Add them in Places if they are missing.)
- What do you check before a long ride?

---

## 5. Suzuki Gixxer 155 (`suzuki__gixxer_155`)

### Post S1 [General]: "Gixxer owners, introduce your bike"

**EN:**
> Gixxer 155 owners: post your bike, the year you bought it, how many km so far, and one thing you love and one thing you would change.

**BN:** (Bangla: machine-drafted, needs native review)
> জিক্সার ১৫৫ মালিকরা: আপনার বাইকের ছবি দিন, কোন বছর কিনেছেন, এখন পর্যন্ত কত কিলোমিটার চালিয়েছেন, আর একটা জিনিস যা ভালো লাগে আর একটা যা বদলাতে চান।

### Post S2 [Troubleshoot]: "Problems that came back after a service"

**EN:**
> Has a problem ever come back right after a service on your Gixxer? What was it and how was it finally sorted? I'll mark the reply that fixes it as the solution, so the next owner finds it fast.

**BN:** (Bangla: machine-drafted, needs native review)
> সার্ভিসের ঠিক পরেই কি আপনার জিক্সারে কোনো সমস্যা আবার ফিরে এসেছে? কী ছিল, আর শেষে কীভাবে ঠিক হলো? যে উত্তরে সমস্যার সমাধান হবে, আমি সেটাকে সমাধান হিসেবে মার্ক করব, যাতে পরের মালিক দ্রুত খুঁজে পান।

### Post S3 [General]: "Free services: did you get all of them?"

**EN:**
> Did you get all your free services done on time, or did you miss some? What made it hard? ThrottleIQ can track the next free service by km and date, but I want to know what actually gets in the way.

**BN:** (Bangla: machine-drafted, needs native review)
> সব ফ্রি সার্ভিস কি সময়মতো করিয়েছেন, নাকি কিছু মিস হয়েছে? কী কারণে কঠিন হয়েছিল? ThrottleIQ কিলোমিটার আর তারিখ দিয়ে পরের ফ্রি সার্ভিস ট্র্যাক করতে পারে, তবে আমি জানতে চাই আসলে কী বাধা হয়।

**Discussion prompts (Suzuki):**
- Gixxer or Gixxer SF: what made you choose?
- Which engine oil do you use, and did you feel a difference? (Cross-post to the Engine Oil Review board.)
- Tyre swaps: what did you change to, and was it worth it?

---

## 6. Honda paddock (`honda`), Hornet riders

Post here, not in a Hornet model forum, until the catalog has one Hornet name (section 1).

### Post H1 [General]: "Hornet riders, check in"

**EN:**
> Hornet owners (160R or 2.0): this is your thread in the Honda paddock for now. Tell us which version you ride, how long you have had it and what you use it for.

**BN:** (Bangla: machine-drafted, needs native review)
> হর্নেট মালিকরা (160R বা 2.0): আপাতত হোন্ডা প্যাডকে এটাই আপনাদের থ্রেড। জানান কোন ভার্সন চালান, কতদিন ধরে আছে আর কী কাজে ব্যবহার করেন।

### Post H2 [Troubleshoot]: "Hornet: what needed fixing first?"

**EN:**
> What was the first thing that needed fixing on your Hornet, and where did you get it done? I'll mark the reply that fixes it as the solution, so the next owner finds it fast.

**BN:** (Bangla: machine-drafted, needs native review)
> আপনার হর্নেটে প্রথম কোন জিনিসটা ঠিক করাতে হয়েছিল, আর কোথায় করিয়েছেন? যে উত্তরে সমস্যার সমাধান হবে, আমি সেটাকে সমাধান হিসেবে মার্ক করব, যাতে পরের মালিক দ্রুত খুঁজে পান।

### Post H3 [General]: "Service schedule check"

**EN:**
> ThrottleIQ recognises the Hornet 160R and 2.0 when you set up maintenance and picks a schedule for it. Does it match your service book? Tell me where it does not.

**BN:** (Bangla: machine-drafted, needs native review)
> মেইনটেন্যান্স সেটআপের সময় ThrottleIQ হর্নেট 160R আর 2.0 চিনতে পারে আর একটা শিডিউল বেছে নেয়। এটা কি আপনার সার্ভিস বুকের সাথে মেলে? কোথায় মেলে না জানান।

**Discussion prompts (Honda):**
- Hornet 160R or 2.0: what changed for you if you upgraded?
- Best Honda service centre or independent mechanic in your area?
- Riding in the rain: what do you change in how you ride?

---

## 7. Royal Enfield paddock (`royal_enfield`)

There is no model-specific maintenance template for Royal Enfield in the app; it falls into the generic size bracket. Do not claim an RE-specific schedule.

### Post R1 [General]: "Which RE do you ride, and where has it taken you?"

**EN:**
> Royal Enfield riders: Classic, Bullet, Meteor, Hunter or Himalayan? Post your bike and the best trip you have done on it. If you recorded it, share the route.

**BN:** (Bangla: machine-drafted, needs native review)
> রয়্যাল এনফিল্ড রাইডাররা: ক্লাসিক, বুলেট, মিটিওর, হান্টার নাকি হিমালয়ান? আপনার বাইকের ছবি আর এটা নিয়ে করা সেরা ট্রিপটা পোস্ট করুন। রেকর্ড করে থাকলে রুটটা শেয়ার করুন।

### Post R2 [Troubleshoot]: "Finding parts and mechanics for RE in Bangladesh"

**EN:**
> Where do you get parts and service for your Royal Enfield in Bangladesh? Which mechanics actually know these engines? If a good one is missing from Places, add it so other riders find it.

**BN:** (Bangla: machine-drafted, needs native review)
> বাংলাদেশে আপনার রয়্যাল এনফিল্ডের পার্টস আর সার্ভিস কোথা থেকে করান? কোন মেকানিকরা আসলেই এই ইঞ্জিন বোঝেন? ভালো কেউ Places-এ না থাকলে যোগ করে দিন, যাতে অন্য রাইডাররা খুঁজে পান।

### Post R3 [Gear review]: "Touring gear that survived Bangladesh roads"

**EN:**
> What riding gear (helmet, jacket, luggage) has lasted on long trips here, and what fell apart? Post a gear review with photos.

**BN:** (Bangla: machine-drafted, needs native review)
> লম্বা ট্রিপে কোন রাইডিং গিয়ার (হেলমেট, জ্যাকেট, লাগেজ) টিকে গেছে, আর কোনটা নষ্ট হয়ে গেছে? ছবিসহ একটা গিয়ার রিভিউ দিন।

**Discussion prompts (Royal Enfield):**
- Group rides: does your club ride together often? (Group ride with join code exists; do not pitch it as a way to bring in non-users.)
- Service schedule: what does your service book say, and does the app's generic schedule need adjusting for you?
- Which model would you recommend to a first-time RE buyer, and why?

---

## 8. Optional cross-forum prompt: front number plate

PM item 4 (from the scrape of 375 Facebook posts) says the BRTA front number-plate deadline is **15 November 2026**. Confirm the date against the BRTA notice before posting. Post only after the owner picks the format in PM item 4.

**EN:**
> Front number plate: have you got yours done yet? Where, how long did it take, and what did you need to bring? Share your experience to help other riders.

**BN:** (Bangla: machine-drafted, needs native review)
> সামনের নম্বর প্লেট: আপনারটা কি করানো হয়ে গেছে? কোথায় করালেন, কত সময় লাগলো, আর কী কী নিয়ে যেতে হয়েছিল? অন্য রাইডারদের সাহায্য করতে আপনার অভিজ্ঞতা জানান।

## 9. Placeholders

- [PLACEHOLDER: owner decision: post as the owner's personal account or a "ThrottleIQ team" account]
- [PLACEHOLDER: photos for each post, taken by the owner, of real bikes (no stock images)]
- [PLACEHOLDER: owner decision: add one canonical Hornet name to `bike_catalog.dart`, and normalise Hornet variants like FZS]
- [PLACEHOLDER: posting date, only once the build is installable by people who reply (`marketing_kit.md` §1)]
