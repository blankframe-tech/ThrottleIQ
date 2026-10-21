# ThrottleIQ pitch deck outline

Slide-by-slide outline. Written 2026-08-23; corrected 2026-10-22 to the
current app. Segment messaging and copy are in [`marketing.md`](marketing.md);
the grant submission and its 5-minute script are in
[`iDEA_PITCH_SUBMISSION.md`](iDEA_PITCH_SUBMISSION.md). The **ask** slide is
filled in for the iDEA grant only; other audiences are an open owner call
(owner item "Pitch materials").

## Slide 1: Title

**ThrottleIQ**, *Machine memory for motorcycles.*
Logo: the speedometer-arc mark, `app/assets/images/app_icon.svg`.

## Slide 2: The problem

Motorcyclists have no equivalent of a car's onboard computer.
- Every ride's speed, braking and route disappears the moment it happens.
- Maintenance lives in a notebook, a memory, or nowhere; in a heavy used-bike
  market, service history is usually unknown at resale.
- Strava and similar apps are built for cyclists and runners; they model
  neither motorcycle events (hard braking, long-highway fatigue) nor
  motorcycle upkeep (chain, oil, tyres tied to distance, not a training plan).

## Slide 3: The solution

The phone becomes a logbook and riding companion:
- **Ride recording and analysis.** GPS and motion sensors capture speed,
  acceleration, braking and route, offline-first, so recording never depends
  on a signal.
- **Maintenance tracking.** Service intervals tracked against distance
  actually ridden, with service visits, receipts and paperwork expiry reminders.
- **Live Share.** The rider starts a link that shows location, speed and
  battery in any browser, no login, stops after 24 hours.
- **Social and community.** Audience-tiered ride sharing, brand and model
  forums, group rides with a live map, a rider-built places directory.
- **Garage.** Every bike, its stats and its service history in one place.

Crash detection is built but switched off (shadow mode, alerts nobody) until
it is calibrated on real roads. Do not put it on this slide.

## Slide 4: The core loop

Record a ride, get an analyzed summary (distance, speed, hard-braking counts,
moving time vs stopped), maintenance intervals update, share with privacy
controls, repeat. A ride recorded with no signal syncs when connectivity
returns.

## Slide 5: Who it is for

Daily commuters (100-160cc, price-sensitive, prepaid data), enthusiast and
touring riders (clubs, group rides), and the anxious family (a distribution
channel, not a user). Detail in `marketing.md` section 2.

## Slide 6: Why now

Phones already carry every sensor this needs; the gap is software. Riders
expect the telemetry cars have had for a decade, and road safety is a
high-salience topic in Bangladesh.

## Slide 7: Where it stands today (2026-10-22)

- Beta `1.0.0-beta.4.7.1` (build 29): signed Android APK on GitHub releases
  and Google Play internal testing by invite. No public Play listing, no
  iPhone build.
- The core loop (record, analyze, maintain, share) is built and working,
  including offline recording and sync.
- Bangla and English UI (the Bangla is partly machine-written, native review
  pending).
- Over 2,000 automated tests run before every push; repeated security and
  privacy passes.
- **Not live:** crash detection (off in every build), any SMS, email or call
  alert, public store listings, monetization.

## Slide 8: What is next

- Calibrate crash detection on real roads, and turn it on only if it passes.
- Alert delivery (SMS or voice) to family, once detection is trusted; needs a
  billing-plan decision (Firebase Blaze) and a gateway.
- Public Play listing (Bangladesh first), then an iPhone beta.
- Curvy-road navigation, club events.
- A paid tier: proposed in the iDEA submission, not built or priced in the app.

## Slide 9: Competitive landscape

Strava and similar apps are cyclist and runner tools. Motorcycle-specific apps
exist abroad (Rever, Calimoto, Detecht, Tonit, EatSleepRide), so never claim
"no competitor". The defensible position: a free, Bangla, Bangladesh-road
option that is rider-first by design (maintenance by real distance, offline
recording for weak-signal highways, local places).

## Slide 10: The ask

For the iDEA Project: a BDT 10,00,000 (10 lakh) pre-seed grant, allocated in
[`iDEA_PITCH_SUBMISSION.md`](iDEA_PITCH_SUBMISSION.md) (slide 5 of that deck).
For any other audience the ask is still open: funding, mentorship, pilot
riders, distribution partners or a city-launch budget. Say plainly which before
this slide goes in front of anyone.
