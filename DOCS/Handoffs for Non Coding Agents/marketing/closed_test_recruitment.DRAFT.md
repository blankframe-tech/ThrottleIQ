# Closed-test recruitment kit — DRAFT (2026-11-01)

Texts the owner sends to get **20 testers opted in** to the Play closed test, so a
few drop-outs don't take the count under 12. Nothing here has been posted or sent.

**Google's rule** (personal developer accounts created after 13 Nov 2023): a closed
test with at least 12 testers "opted in continuously for at least 14 days" before you
can apply for production. Source: https://support.google.com/googleplay/android-developer/answer/14151465
(fetched 2026-11-01). A tester who leaves the test and rejoins starts their 14 days again.

**The T1 flow.** Every link below is the public install page with a campaign code:
`https://www.blankframe.tech/throttle-iq/install/?c=<code>`. Once the Google Group
exists (owner item, `throttleiq-testers`) that page becomes: join the group → accept
the test on Play → install from Play. Until then it falls back to WhatsApp/email.
Never paste the raw Play listing link: it 404s for anyone not on the test.

| Code | Where it goes |
|---|---|
| `beta_group` | The existing beta WhatsApp/Messenger group |
| `fcb` | Rider Facebook group 1 (e.g. Freewheelers Club BD) |
| `bikebd` | Rider Facebook group 2 (e.g. BikeBD community) |
| `existing_users` | Email to the ~53 accounts that already signed up |
| `friends` | One-to-one DMs to friends and riders you know |
| `github` | GitHub Discussions post for the outside contributors |

Rules for every text: say plainly you built it; no crash-alert, SOS or "someone will
know if you fall" claims (crash detection is in shadow mode and sends nothing); no
"live on Google Play"; the link goes in the first comment on Facebook. Bangla blocks
are **machine-drafted and need a native read (#23)** before posting.

---

## 1. Beta group post (`?c=beta_group`)

**EN**
> ThrottleIQ is moving to the Google Play closed test, and I need your help one more
> time. Google lets me publish only after 12 people have stayed on the test for 14 days
> in a row. If you join today and stay on until I say it's live, you are one of those 12.
>
> 1. Open https://www.blankframe.tech/throttle-iq/install/?c=beta_group
> 2. Join the tester group with the Google account on your phone
> 3. Accept the test, then install ThrottleIQ from Play (it replaces the APK; your
>    rides stay in your account once you sign in)
>
> Please don't leave the test (the "Leave" option on the Play testing page) until launch. That's all.

**BN** `[machine-drafted, needs native review #23]`
> থ্রোটল আইকিউ এখন Google Play-এর ক্লোজড টেস্টে যাচ্ছে, আর আপনাদের সাহায্য আরেকবার
> লাগবে। Google তখনই পাবলিক করতে দেয় যখন ১২ জন টেস্টার টানা ১৪ দিন টেস্টে থাকেন।
> আজ যোগ দিয়ে লঞ্চ পর্যন্ত থাকলে আপনি সেই ১২ জনের একজন।
>
> ১. খুলুন https://www.blankframe.tech/throttle-iq/install/?c=beta_group
> ২. ফোনের Google অ্যাকাউন্ট দিয়ে টেস্টার গ্রুপে যোগ দিন
> ৩. টেস্ট accept করে Play থেকে ThrottleIQ ইনস্টল করুন (সাইন ইন করলে আগের রাইড থাকবে)
>
> লঞ্চের আগ পর্যন্ত টেস্ট ছাড়বেন না। এটুকুই।

## 2. Rider group posts (Facebook)

Post text in the group, the link in the first comment. ≤ 120 words.

### 2a. Rider group 1 (`?c=fcb`)

**BN** `[machine-drafted, needs native review #23]`
> নিজে বাইক চালাই, তাই নিজের জন্য একটা অ্যাপ বানিয়েছি — থ্রোটল আইকিউ। যেকোনো বাইকের
> জন্য একটা সার্ভিস বই, যেকোনো গ্যারেজে চলে, বাংলায়। আর রাইড রেকর্ড হয় সিগন্যাল
> ছাড়াই। পাবলিক করার আগে ২০ জন রাইডার খুঁজছি যারা দুই সপ্তাহ টেস্ট করবেন: দুটো
> রাইড, একটা সার্ভিস লগ — এটুকুই। ফ্রি। লিংক প্রথম কমেন্টে।

**First comment:** `https://www.blankframe.tech/throttle-iq/install/?c=fcb`

**EN (for reference)**
> I ride, so I built the app I wanted: ThrottleIQ. One service book for any bike, at
> any garage, in Bangla, and a ride recorder that works with no signal. Before it goes
> public I'm looking for 20 riders to test it for two weeks: two rides and one service
> log, that's it. Free. Link in the first comment.

### 2b. Rider group 2 (`?c=bikebd`)

Same text as 2a with a different opening, so the two groups don't see a copy-paste:

**BN** `[machine-drafted, needs native review #23]`
> চেইন কবে লুব করেছিলেন, অয়েল কবে বদলেছেন — মনে রাখা কঠিন, আর বাইক বিক্রির সময়
> সার্ভিসের হিসাবও হারিয়ে যায়। এজন্যই থ্রোটল আইকিউ বানিয়েছি: আসল দূরত্ব দেখে
> মেইনটেন্যান্স মনে করায়, আর সিগন্যাল না থাকলেও রাইড রেকর্ড করে। Play-তে পাবলিক
> করার আগে ২০ জন টেস্টার দরকার, দুই সপ্তাহের জন্য। ফ্রি। লিংক প্রথম কমেন্টে।

**First comment:** `https://www.blankframe.tech/throttle-iq/install/?c=bikebd`

## 3. Email to existing accounts (`?c=existing_users`)

Owner sends from his own address with **every recipient in BCC** (never To/CC). The
address list stays in Firebase; it is not in this repo.

**Subject:** ThrottleIQ needs 12 riders for 14 days

> Hi,
>
> You signed up for ThrottleIQ during the beta, thank you. The app is moving to Google
> Play, and Google only lets me publish after 12 testers stay on a closed test for 14
> days in a row. Would you be one of them?
>
> 1. Open https://www.blankframe.tech/throttle-iq/install/?c=existing_users
> 2. Join the tester group with the Google account on your Android phone
> 3. Accept the test and install ThrottleIQ from Play. Sign in and your bikes and
>    rides are still there.
>
> Over the two weeks I'll ask for three small things: record two rides, check your
> bike is in the Garage, and log one service. Please stay on the test until I write
> that it's public.
>
> Thanks for riding with it,
> [your name]
>
> (You're getting this because you created a ThrottleIQ account. Reply "stop" and I
> won't email again.)

## 4. DM template (`?c=friends`)

**BN** `[machine-drafted, needs native review #23]`
> ভাই, একটা ছোট উপকার লাগবে। আমার বাইকের অ্যাপ থ্রোটল আইকিউ Play-তে তুলতে ১২ জন
> টেস্টার টানা ১৪ দিন লাগবে। এই লিংকে গ্রুপে জয়েন করে Play থেকে ইনস্টল করবেন?
> https://www.blankframe.tech/throttle-iq/install/?c=friends
> দুই সপ্তাহে দুটো রাইড রেকর্ড করলেই হবে। লঞ্চ পর্যন্ত টেস্ট ছাড়বেন না, প্লিজ।

**EN**
> Small favour: Google needs 12 testers on ThrottleIQ for 14 days straight before I can
> publish it. Could you join from this link and install from Play?
> https://www.blankframe.tech/throttle-iq/install/?c=friends
> Two recorded rides over two weeks is plenty. Please don't leave the test before launch.

## 5. GitHub Discussions post for the outside contributors (`?c=github`)

Category: Announcements. Thank them as a group; don't @-mention anyone.

> **Help ThrottleIQ reach Google Play: 14 days as a tester**
>
> Thanks to everyone who has sent a PR or a Bangla correction. ThrottleIQ is on a Google
> Play closed test now, and Google requires 12 testers opted in for 14 days in a row
> before production. If you have an Android phone, you can be one of them:
> https://www.blankframe.tech/throttle-iq/install/?c=github
>
> Bugs you hit go in the bug form (it asks for your phone and version):
> https://github.com/blankframe-tech/ThrottleIQ/issues/new/choose
> Bangla corrections still go to #23.

---

## 6. Days 1–14 engagement script

Send in the same channel the tester came from (beta group post, or a reply to the email
or DM). The aim is that each tester records **2 rides, has a bike in the Garage and logs
1 service**, and nobody leaves the test.

| Day | Message (EN; BN version to be written from it and reviewed) |
|---|---|
| 1 | "You're in, thank you. First thing: open **Garage** and add your bike (or check it's there). It takes a minute and makes the service reminders work." |
| 2–3 | "When you next ride, tap the round **Record** button before you start and **Stop** when you park. Lock the screen and ride normally. Tell me if anything went missing in a dead zone." |
| 4–5 | "Had an oil change or chain lube recently? Open your bike in Garage → **Maintenance** and log it with the odometer reading. That's the service book." |
| 7 | Day-7 check-in, below. |
| 8–10 | "Second ride, please, any length. Then open **Rides**: does the distance look right against your bike's odometer?" |
| 11–12 | Optional: "Garage → Maintenance → **Papers**: add your tax token or insurance date and it reminds you 30 days ahead." |
| 14 | "Two weeks done, thank you. Please stay on the test until I post that it's public; leaving now could reset Google's count." |

### Day-7 check-in

**EN**
> One week in, thanks for sticking with it. Three quick questions, one line each is fine:
> 1. Did a ride ever stop recording or lose part of the route?
> 2. Roughly how much battery did a 30-minute ride use?
> 3. One thing that annoyed you?
> And please stay on the test: we're halfway to Google's 14 days.

**BN** `[machine-drafted, needs native review #23]`
> এক সপ্তাহ হলো, সাথে থাকার জন্য ধন্যবাদ। তিনটা ছোট প্রশ্ন, এক লাইনে উত্তর দিলেই হবে:
> ১. কোনো রাইডে রেকর্ডিং থেমে গেছে বা রুটের কিছু অংশ হারিয়েছে?
> ২. ৩০ মিনিটের রাইডে মোটামুটি কত ব্যাটারি গেছে?
> ৩. একটা জিনিস যেটা বিরক্ত করেছে?
> আর টেস্ট ছাড়বেন না প্লিজ — Google-এর ১৪ দিনের অর্ধেক পার হলো।

## 7. Tracking

- Install page campaign codes show which channel brought the join request.
- Play Console → Dashboard / Testing shows opted-in testers. Record the count on day 1,
  7 and 14. If it drops under 15 before day 14, post the DM template to more friends.
