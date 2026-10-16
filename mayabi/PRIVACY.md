# What the Maya Ride app shares with ThrottleIQ, and why

## Stays on the phone

- The GPS track (every position). Only per-road-cell averages leave the phone.
- Raw motion sensor data.
- The rider's name, phone number, emergency contacts, fares and cost profile.

## Sent to ThrottleIQ

| Data | When | Why | Kept |
|---|---|---|---|
| Ride summary: start and end time, km per leg, moving time, average and top speed, hard brake / acceleration / jerk / overspeed counts, weather code | After each trip | The riding score | With the ride record |
| Average speed per ~150 m road cell (a geohash, not an address) | After each trip | Compare her speed with Dhaka's usual speed there. The same averages, with no rider attached, join ThrottleIQ's shared Dhaka road-speed pool | Pool: indefinitely, anonymous. Ride record: with the ride |
| Impact events (strength, speed before) and her "Did you fall?" answer | After each trip with an impact | Teach crash detection Dhaka's potholes from real falls | With the ride record |
| Live position, speed, battery | Only while she shares a live link | Show the link | Until the link ends or expires after 12 h |
| Alert: kind, position, live link | On SOS or an unanswered safety prompt | Tell Maya ops | Alert log |

Rides and scores are stored under a **hash of Maya's rider id**. ThrottleIQ can't tell who a rider is; Maya can, because it holds the id. Road-pool samples carry no rider at all, only the cell, speed, weekday, hour and weather, plus a "source: maya" tag so they can be removed if needed.

Maya can erase a rider's rides, score, alerts and live links at any time with `ThrottleIqClient.deleteRider` (`DELETE v1/riders/{riderRef}`), for example when she leaves Maya or asks. To remove all of Maya's data, ask ThrottleIQ.

## Consent text for rider onboarding

Show this before the first trip. Recording needs the rider's agreement; don't make it a buried checkbox.

**English**

> **Safety and fair pay, powered by ThrottleIQ**
> While you're on a Maya trip, the app uses your phone's GPS and motion sensors to:
> • work out what each trip really costs you, including the ride to the pickup and back home;
> • give you a riding score, comparing your speed with how Dhaka riders usually ride each road;
> • check on you after a hard impact or a long unexpected stop, and alert Maya if you don't answer;
> • share your live location, only when you choose to, with people you pick.
> Your route never leaves your phone. Only road-by-road average speeds and trip totals go to ThrottleIQ, our safety partner, without your name or number. Crash detection is still learning and may miss a fall or ask by mistake. Always use SOS if you need help.
> [I agree] [Not now]

**বাংলা**

> **ThrottleIQ-এর সহায়তায় নিরাপত্তা ও ন্যায্য আয়**
> মায়া ট্রিপ চলাকালে অ্যাপটি আপনার ফোনের GPS ও মোশন সেন্সর ব্যবহার করে:
> • প্রতিটি ট্রিপে আপনার আসল খরচ হিসাব করতে, পিকআপ পর্যন্ত যাওয়া আর বাসায় ফেরাসহ;
> • আপনাকে রাইডিং স্কোর দিতে, ঢাকার প্রতিটি রাস্তায় সাধারণত যে গতিতে চালানো হয় তার সাথে মিলিয়ে;
> • জোরে ধাক্কা লাগলে বা ট্রিপের মাঝে অনেকক্ষণ অপ্রত্যাশিতভাবে থেমে থাকলে আপনার খোঁজ নিতে, এবং আপনি সাড়া না দিলে মায়াকে জানাতে;
> • আপনি চাইলে, আপনার বেছে নেওয়া মানুষদের সাথে আপনার লাইভ লোকেশন শেয়ার করতে।
> আপনার রুট কখনো ফোনের বাইরে যায় না। শুধু রাস্তাভিত্তিক গড় গতি আর ট্রিপের মোট হিসাব আমাদের নিরাপত্তা সহযোগী ThrottleIQ-এর কাছে যায়, আপনার নাম বা নম্বর ছাড়া। দুর্ঘটনা শনাক্তকরণ এখনও শিখছে, তাই কখনো পড়ে যাওয়া ধরতে না-ও পারে বা ভুল করে জিজ্ঞেস করতে পারে। সাহায্য দরকার হলে সবসময় এসওএস চাপুন।
> [আমি রাজি] [এখন না]

Have a native speaker review the Bangla before release. Maya's privacy policy and the Play Store data-safety form must list location (precise, background), app activity, and the sharing with ThrottleIQ described above. Check them against Bangladesh's current data-protection law before launch.
