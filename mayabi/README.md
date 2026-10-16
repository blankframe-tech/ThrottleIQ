# ThrottleIQ for Maya Ride (`throttleiq_mayabi`)

A Dart package for the Maya Ride app. It gives every Mayabi:

| Feature | What the rider sees | Where |
|---|---|---|
| **True trip cost** | Before accepting: "This ride costs you ৳110, and 53% of the km are unpaid. You keep ৳40." After the ride: the same, from the measured km | `CostProfile`, `TripCost` |
| **Riding score** | A 0–100 score after every trip. It counts hard braking, sudden acceleration, jerky riding and overspeeding, and compares her speed on each ~150 m of road with how Dhaka riders usually ride it at that hour and in that weather | `RideRecorder`, `ThrottleIqClient.uploadRide` |
| **Rider history** | Maya ops sees each rider's running average: for vetting, training and rewards | `ThrottleIqClient.riderScore` |
| **Live share** | A link family and Maya ops open in any browser. It shows her position, speed and battery live, with no app needed | `startLive` / `updateLive` / `endLive` |
| **SOS** | One tap texts her emergency contacts the live link and a map pin, or calls 999, and tells Maya ops | `sosSmsUri`, `telUri`, `sendAlert` |
| **Crash and unusual-stop checks** | After a hard impact, or a long stop mid-trip, an "Are you OK?" prompt. If she doesn't answer, Maya ops is alerted | `RideRecorder.onSafetyEvent`, `SafetyCheck` |

The package is pure Dart with no dependencies. Your app keeps its own plugins (GPS, sensors, `url_launcher`) and its own design. The sensor pipeline and scoring are ThrottleIQ's own, copied unchanged from the ThrottleIQ app (`lib/src/vendor`).

**Data:** no raw GPS track leaves the phone. What is sent is described in [PRIVACY.md](PRIVACY.md). The HTTP API is in [API.md](API.md).

---

## 1. Install

```yaml
# pubspec.yaml of the Maya Ride app
dependencies:
  throttleiq_mayabi:
    git:
      url: https://github.com/blankframe-tech/ThrottleIQ.git
      ref: mayabi
      path: mayabi
  # what the app needs anyway, if it doesn't have them yet:
  geolocator: ^13.0.0
  sensors_plus: ^6.0.0
  url_launcher: ^6.2.0
  battery_plus: ^6.0.0 # optional, for the battery % on the live link
```

```dart
import 'package:throttleiq_mayabi/throttleiq_mayabi.dart';

final tiq = ThrottleIqClient(apiKey: const String.fromEnvironment('TIQ_API_KEY'));
```

ThrottleIQ issues the API key. Never commit it: pass it with `--dart-define=TIQ_API_KEY=...` at build time. See §8 for where it should live.

**Recording during a trip needs background location**, because riders lock the phone. On Android that means a foreground service with `ACCESS_BACKGROUND_LOCATION`, using geolocator's `AndroidSettings(foregroundNotificationConfig: ...)`. On iOS it means `UIBackgroundModes: location` and "Always" permission. Ask for it the first time a rider goes online, with the consent text in PRIVACY.md.

---

## 2. Trip cost

Ask once during rider onboarding (editable later). Only fuel is required:

```dart
final profile = CostProfile(
  fuelPricePerLitre: 165,          // octane, Tk/L (21 Sep 2026)
  kmPerLitre: 45,                  // her own mileage
  maintenance: [
    MaintenanceItem(name: 'Engine oil', cost: 900, intervalKm: 2000),
    MaintenanceItem(name: 'Chain set', cost: 2500, intervalKm: 15000),
    MaintenanceItem(name: 'Brake pads', cost: 600, intervalKm: 8000),
    MaintenanceItem(name: 'Tyres', cost: 6000, intervalKm: 20000),
  ],
  purchasePrice: 180000, resaleValue: 80000, lifespanKm: 60000, // depreciation
  monthlyFixedCost: 1500, monthlyKm: 1500,  // insurance, tax token, phone data
  commissionRate: 0.20,                      // Maya's share of the fare
);
```

**Before she accepts** a request, use the km you already estimate for the pickup and the trip, and her distance home from the drop-off:

```dart
final q = profile.trip(pickupKm: 3, tripKm: 8, homeKm: 6, fare: 150);
q.totalCost;     // ৳ for all 17 km
q.unpaidShare;   // 0.53: 53% of the km are unpaid
q.netEarnings;   // fare − commission − cost (negative = a loss)
q.breakEvenFare; // the fare that covers it
q.breakdown;     // fuel, each maintenance item, depreciation, fixed
```

**After the ride**, use the measured legs: `profile.trip(pickupKm: report.pickupKm, tripKm: report.tripKm, homeKm: report.homeKm, fare: paid)`.

Store the profile in your own database. ThrottleIQ never receives money data.

---

## 3. Recording a trip, and the score

Create one `RideRecorder` per hired trip, from accept to arriving home (or the next accept). Then switch phases at moments your app already knows:

```dart
final recorder = RideRecorder(
  rideId: booking.id,          // your id, 1-64 of A-Z a-z 0-9 _ -
  riderRef: rider.id,          // your rider id; ThrottleIQ stores only a hash
  overspeedKmh: 60,            // city limit you want to coach to (default 100)
  onSafetyEvent: safety.raise, // see §5
);

// GPS, 1 Hz
Geolocator.getPositionStream(locationSettings: settings).listen((p) =>
    recorder.addLocation(lat: p.latitude, lng: p.longitude, speedMs: p.speed,
        accuracyM: p.accuracy, at: p.timestamp, headingDeg: p.heading, altitudeM: p.altitude));

// Motion sensors, 50 Hz
const period = Duration(milliseconds: 20);
userAccelerometerEventStream(samplingPeriod: period).listen((e) => recorder.addUserAccel(e.x, e.y, e.z));
accelerometerEventStream(samplingPeriod: period).listen((e) => recorder.addAccel(e.x, e.y, e.z));
gyroscopeEventStream(samplingPeriod: period).listen((e) => recorder.addGyro(e.x, e.y, e.z));

recorder.phase = RidePhase.onTrip;  // passenger on board
recorder.phase = RidePhase.toHome;  // passenger dropped
```

Leave the sensors' `at` empty: samples are stamped on arrival, the same clock the recorder uses.

**When the ride ends:**

```dart
var report = recorder.finish(weatherCode: currentWmoCode /* optional */);

// If the detector saw an impact, ask "Did you fall?" once per impact.
// The answers train crash detection for Dhaka roads.
if (report.impacts.isNotEmpty) {
  report = report.withFellAnswers(await askDidYouFall(report.impacts));
}

try {
  final score = await tiq.uploadRide(report);
  // score.score (0-100), score.tier (smooth / steady / aggressive),
  // score.fasterThanUsual: road cells she rode far faster than Dhaka usually does
} on ApiException catch (e) {
  if (e.retryable) await queue.add(jsonEncode(report.toJson())); // retry later
} on SocketException {
  await queue.add(jsonEncode(report.toJson()));
}
// later: tiq.uploadRide(RideReport.fromJson(jsonDecode(saved)))
```

The upload is **idempotent per `rideId`**, so retry as often as you like. `report.eventScore` gives an offline score straight away, and the server score replaces it.

**How the score works (v1):** start from 100 and subtract 5 per hard brake, 3 per rapid acceleration and 1 per jerk. That is the ThrottleIQ app's own formula. Then subtract 4 for each road cell where she rode at least 20 km/h above, and more than 2.5 standard deviations above, how the pooled Dhaka riders ride it at the same time of day (rush hours count separately) and in the same weather (rain counts separately). That penalty is capped at 30. Finally, subtract 3 per overspeed episode. A cell needs 5 pooled samples before it is compared. Expect the weights to be tuned as data grows; `scoringVersion` tells versions apart.

**Rider history** for Maya ops: `await tiq.riderScore(rider.id)` returns rides, km, average and last-20 average score, tier, and the totals. It returns `null` before her first upload.

---

## 4. Live share

```dart
final live = await tiq.startLive(riderRef: rider.id, lat: p.latitude, lng: p.longitude,
    batteryPct: await Battery().batteryLevel);
Share.share('Follow my Maya ride live: ${live.url}'); // or send to her saved contacts

final gate = LiveShareThrottle(); // send on 100 m, 15 s, or pause change
positions.listen((p) {
  if (gate.shouldSend(DateTime.now(), p.latitude, p.longitude)) {
    tiq.updateLive(live.token, lat: p.latitude, lng: p.longitude, speedMs: p.speed);
  }
});

await tiq.endLive(live.token); // when she's home; the page then says "completed"
```

The link works in any browser, with no login and no app, until it ends or expires after 12 hours. Keep `live.token` with the ride: SOS uses it.

---

## 5. SOS, crash and unusual stops

```dart
final safety = SafetyCheck(
  countdown: const Duration(seconds: 60),
  onChanged: () => setState(() {}),          // show/hide the prompt
  onEscalate: (e) => tiq.sendAlert(
    riderRef: rider.id,
    kind: e.kind == SafetyEventKind.crash ? AlertKind.crash : AlertKind.unusualStop,
    lat: e.lat, lng: e.lng, liveToken: live?.token, rideId: booking.id,
  ),
);
```

- While `safety.pending != null`, show a full-screen prompt with a loud vibration, the countdown, a big **I'm OK** (`safety.riderIsOk()`) and **Get help** (`safety.riderNeedsHelp()`).
- The **SOS button** (always visible during a trip):

  ```dart
  final alert = await tiq.sendAlert(riderRef: rider.id, kind: AlertKind.sos,
      lat: recorder.lastLat, lng: recorder.lastLng, liveToken: live?.token, rideId: booking.id);
  final text = sosMessage(intro: l10n.sosIntro, liveUrl: live?.url.toString(),
      lat: recorder.lastLat, lng: recorder.lastLng,
      liveLabel: l10n.sosLiveLabel, mapLabel: l10n.sosMapLabel);
  final sms = sosSmsUri(rider.emergencyPhones, text, iOS: Platform.isIOS);
  // Offer both; she presses Send / Call:
  if (sms != null) launchUrl(sms);
  launchUrl(telUri(kBangladeshEmergencyNumber)!); // 999
  ```

  Send the alert first and don't wait on it. SMS and 999 must work even when the network doesn't.

- `sendAlert` turns her live link red ("SOS" or "CRASH") and POSTs to **Maya's ops webhook** (§7). `alert.delivered` says whether ops received it.

**Be honest with riders.** Crash detection is new and still learning Dhaka's roads. It will sometimes ask after a pothole, and it could miss a fall. The unusual-stop check fires after 10 minutes stopped mid-trip (`unusualStopAfter`). Neither replaces a rider pressing SOS. This is not a monitored emergency service: someone at Maya must act on the webhook during service hours.

---

## 6. Suggested copy (EN / বাংলা)

| Key | English | বাংলা |
|---|---|---|
| tripCost | This ride costs you ৳{cost} | এই রাইডে আপনার খরচ ৳{cost} |
| unpaid | {p}% of the distance is unpaid | দূরত্বের {p}% এর ভাড়া পাবেন না |
| keep | You keep ৳{x} | আপনার থাকবে ৳{x} |
| loss | You lose ৳{x} on this ride | এই রাইডে আপনার ক্ষতি ৳{x} |
| breakEven | Break-even fare: ৳{x} | লাভ-ক্ষতি সমান হবে ভাড়া ৳{x} হলে |
| score | Riding score {s}/100 | রাইডিং স্কোর {s}/100 |
| smooth / steady / aggressive | Smooth / Steady / Aggressive | মসৃণ / স্থির / আগ্রাসী |
| fasterHere | Faster than usual here: {v} km/h (usually {t}) | এখানে স্বাভাবিকের চেয়ে দ্রুত: {v} কিমি/ঘণ্টা (সাধারণত {t}) |
| areYouOk | Are you OK? | আপনি ঠিক আছেন? |
| imOk | I'm OK | আমি ঠিক আছি |
| getHelp | Get help | সাহায্য দরকার |
| countdown | Maya will be alerted in {s} s | {s} সেকেন্ডে মায়াকে জানানো হবে |
| didYouFall | Did you fall during this ride? | এই রাইডে কি আপনি পড়ে গিয়েছিলেন? |
| sosIntro | SOS: I need help. Sent from my Maya ride. | এসওএস: আমার সাহায্য দরকার। মায়া রাইড থেকে পাঠানো। |
| sosLiveLabel / sosMapLabel | Live location / Last known spot | লাইভ লোকেশন / সর্বশেষ জানা অবস্থান |
| call999 | Call 999 | 999-এ কল করুন |

Use Western digits in Bangla strings (999, not ৯৯৯), as the ThrottleIQ app does.

---

## 7. Maya ops webhook

ThrottleIQ POSTs each alert to the HTTPS URL Maya gives us:

```json
{ "alertId": "…", "kind": "sos | crash | unusualStop", "riderRef": "<your rider id>",
  "rideId": "…", "lat": 23.79, "lng": 90.41,
  "liveUrl": "https://throttleiqfb.web.app/live/…", "createdAt": "2026-10-17T09:12:00.000Z" }
```

Verify the `x-throttleiq-signature` header (hex HMAC-SHA256 of the raw body with the webhook secret) before trusting it:

```js
// Node/Express
const ok = crypto.timingSafeEqual(
  Buffer.from(req.get('x-throttleiq-signature'), 'hex'),
  crypto.createHmac('sha256', process.env.TIQ_WEBHOOK_SECRET).update(req.rawBody).digest());
```

Respond `2xx` within 5 s. Then call the rider, and the contacts if she doesn't answer. There is one attempt per alert; if it fails, `delivery` in the API response says so.

---

## 8. Security and keys

- **The key identifies Maya,** not a rider. Anyone holding it can upload rides and raise alerts in Maya's name. Best: call `uploadRide`, `riderScore` and `sendAlert` from Maya's own server, with the key there. Calling from the app is supported, but treat the key as extractable from the APK. Tell ThrottleIQ to rotate it if a build leaks.
- The server checks every upload: road cells must be in Bangladesh, speeds plausible, times sane, and counts bounded. Every sample is tagged with its source, so bad data can be removed later.
- ThrottleIQ never stores Maya's rider ids (only a hash), names, phone numbers, emergency contacts or fares.

---

## 9. Testing this package

```bash
cd mayabi && dart pub get && dart test
```

There are 30 tests: cost maths, the full recorder pipeline (including ThrottleIQ's tier-2 crash scenario), safety prompts, SOS links, the HTTP client against a local server, and a contract fixture that the server's own tests also check.

**Not yet checked on a real phone:** sensor rates, background recording on OEM Android builds, battery cost of 50 Hz sensors, and the iOS multi-recipient SMS link. Pilot with a few riders first.
