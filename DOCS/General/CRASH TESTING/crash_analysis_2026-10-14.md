# Crash analysis: 14 Oct 2026, railway crossing near Banani Overpass

The rider `@theabraarrar` (uid `BWDGKFpeOKNtI0BCxc66r2qMMPQ2`) crashed on a Honda CG 125 during a manual ride. This is the first real crash with ThrottleIQ data behind it.

## Files in this folder

> In git: this report, `crash_analysis_and_detection_plan.html`, the four screenshots and `iphone_log_extract_2026-10-14.txt`. The raw exports (`ride_2026-10-14_aac4e04d.*`) and the phone database copy (`phone_sqlite/`) stay on the founder's machine: the full track shows where the ride started, and the database also holds a second account's data.


| File | What it holds |
|---|---|
| `ride_2026-10-14_aac4e04d.json` | The full Firestore ride document, the `crashNotification` lookup (null, so no alert was sent), and all 1,119 decoded track points |
| `ride_2026-10-14_aac4e04d.csv` | One row per point: lat, lng, `ts_ms`, local time (UTC+6), speed in m/s and km/h, GPS-derived accel, cumulative distance |
| `ride_2026-10-14_aac4e04d.gpx` | GPX 1.1 track with UTC times and speed, for Google Earth, Strava, gpx.studio and similar tools |
| 4 × `.jpeg` | The rider's screenshots: the live ride screen at 9:30, Google Maps at 9:30, and the ride-history map at two zoom levels |

Source: Firestore project `throttleiqfb`, document `users/{uid}/rides/aac4e04d-4de7-4711-9e3a-52c01fb9569b` and its `track/0..2` chunks. The export ran on 2026-10-14 using the Admin SDK with application default credentials.

## The ride matches what the rider reported

| Field | Firestore value | What the rider reported |
|---|---|---|
| Bike | `420a693d…`, "CG 125", `bike_confidence: confirmed` | Honda CG125 |
| Start and end | 20:04:16 to 22:07:41 local | 14 Oct |
| `duration_s` | 6817, which is 1h 53m 37s | 1h 53m |
| `moving_s` | 2722, which is 45m 22s | 45:22 |
| `distance_m` | 13,337 | 13.3 km |
| `max_speed_ms` | 19.75, which is 71.1 km/h | 71 |
| `avg_speed_ms` | 4.90, which is 17.6 km/h (distance divided by moving time) | 18 |
| Events | hard_brake 0, rapid_accel 3, high_jerk 1, overspeed 0 | — |
| Peaks | brake 0.18 g, accel 0.15 g, lateral 0.11 g, lean 6.3° | — |

The rider also mentioned a record of 90 and 1.08 min in a jam. Neither number is in the Firestore ride document, which has no jam field or record field. I left them unverified.

## Crash timeline (local time, UTC+6)

All values come straight from the track. Distance is measured from where the phone came to rest, which is the centroid of the 18 stationary fixes: 23.810267, 90.403234.

| Time | Speed (km/h) | Distance from rest point | What it means |
|---|---|---|---|
| 21:27:25 | 42.2 | ~480 m | Cruising north on the service road under Banani Overpass |
| 21:27:28–21:27:36 | 37 → 25 | | Slowing down |
| 21:28:03–21:28:18 | 24 → 20 | 77 m | Approaching the Kamalapur–Tongi railway crossing |
| 21:28:25 | 10.7 | 49 m | Braking for the tracks. The fix gap opens up |
| 21:28:29–21:28:43 | 6.7, 7.4, 4.2, 5.2 | | Walking pace over the rails |
| **21:28:47** | **12.7** (accel +0.70 m/s²) | **9.4 m** | **The last moving fix.** The rider was pulling away from the rails |
| 21:28:47 → 21:29:02 | — | | **15 s with no fixes. This is when the crash happened** |
| 21:29:02–21:29:22 | 0.0 | ≤16 m jitter | Phone lying on the ground |
| 21:29:25–21:29:31 | ~5.5 | | Phone picked up, or a GPS drift artefact. Speed is below 6 km/h |
| 21:29:33–21:33:19 | 0 (with 7 and 5 km/h blips) | | About 4 minutes stopped while the rider recovered |
| 21:30 | — | | Screenshot: 0 km/h, 10.29 km, 19 km/h avg, 74% confidence, 1h 25m |
| 21:33:26 | 10.8 → 24.6 | | Riding again |

**Impact timing:** the phone stopped moving by about 21:28:49. The iPhone system log then shows a motion wake ("Lift detected", face covered) at 21:28:58.9. So the fall came either at the stop or as a tip-over from a standstill about 10 s later (see `crash_analysis_and_detection_plan.html`), a few metres past the second rail. That fits the rider's account of a low-speed slip at the crossing: left hand down first, then the bike falling onto the rider. The rider had already slowed from about 40 km/h well before the crossing, so this was not a high-energy crash.

### The "star" pattern in the history map is GPS noise from a stationary phone

The ride-history screenshots show a zig-zag star at the crash site. The 18 fixes from 21:28:47 to 21:33:19 all fall within **16 m** of one point. The app drew them as straight lines between consecutive noisy fixes. Three things made the noise worse:
- the phone was lying on the ground, which shields the antenna;
- the site is next to Banani Overpass and the elevated expressway, which both cause signal multipath;
- the stationary filter recorded noise as small movements.

This also explains why the track adds up to more distance than the summary:
- the raw track sums to 14.39 km, but the ride says 13.34 km;
- at 21:30 the track says 11.08 km, but the live screen showed 10.29 km.

The ride calculator filters jitter, so its distance is the correct one.

## Why ThrottleIQ did not detect the crash

1. **Live crash detection is switched off in code.** `SensorConstants.impactDetectorLiveEnabled = false` (`app/lib/core/constants/sensor_constants.dart`). This is the founder decision of 2026-09-21 recorded as issues_open §78.1. Because the flag is off, the recorder does not build `ImpactDetector` at all. No alert fired and no near-miss was logged. Firestore confirms it: there is no `crashNotifications/aac4e04d…` document and no `falseCrashPositives` entry for this ride.
2. **The old GPS-based crash path could never have fired.** It needs a speed change of 80 m/s². The largest GPS accel value in the whole ride is 13.5 m/s², at 21:52:29 and 48.7 km/h, not at the crash. Around the crash, every value is under 1 m/s².
3. **The raw IMU impact data was never saved.** The cloud track stores only lat, lng, ts, speed and GPS accel. `jerk`, `confidence`, `period_type` and `is_cornering` exist only in the phone's local SQLite `ride_points` table. `ImpactDetector` near-misses are kept only in memory. So the actual g-force of the phone hitting the ground cannot be recovered. (Update: the phone's data shows the single `high_jerk_count` was at 21:52:29, so it was not this crash.)

### Would `ImpactDetector` have caught it if it were on?

The confirmation rules are in `impact_detector.dart`. A spike of 4 g or more counts as a crash only if both of these follow it:
- within 5 s, either a GPS fix under 2 m/s, or GPS silence while the phone is still;
- a speed drop of at least 2 m/s compared with the fastest fix in the 5 s before the spike.

Here is how this crash measures up:
- **The spike:** a phone thrown from a pocket onto the road almost certainly goes past 4 g. Budget phones can clip at 4–8 g, which the saturation rule covers.
- **Stopped:** satisfied. GPS was silent for 15 s while the phone lay still.
- **Speed drop:** this is the borderline rule. If the spike came right after the 12.7 km/h (3.5 m/s) fix, the drop is about 3.5 m/s, which passes. If the rider fell during the 4–7 km/h stretch over the rails (1.2–2.0 m/s), the drop is under 2 m/s and the crash would not have been confirmed.

**Conclusion:** if the detector had been on, it would probably have caught this crash, but not for certain. Low-speed slips at crossings, speed bumps and in jams sit right on the 2 m/s line. In Dhaka those are likely to be the most common kind of crash.

## The rider's account (15 Oct 2026)

- The bike stopped at the level crossing in a small jam.
- The rider crossed the first rail easily. Horns and flashing headlights from behind pushed them to hurry, so they opened the throttle to cross the second rail.
- They were crossing it **at an angle**. The rear end "shot up, with massive momentum to the left". They fell to the left, hands first, and the bike landed on their foot.
- They were on unfamiliar roads, so they had unlocked the phone to check Google Maps and then opened ThrottleIQ. The iPhone log has this at 21:27:30–21:28:15.
- They took the 9:30 screenshot about a minute after the fall; the system log puts it at 21:30:11.

This confirms the first reading of the timing: the fall at about **21:28:48**, while accelerating at about 13 km/h. It was not a tip-over from a standstill. The iPhone's "Lift detected" wake at 21:28:58.9 was the phone being moved after the fall.

Public write-up: blankframe.tech/throttleiq/crash/1.

## Update: the phone's local database (pulled later on 2026-10-14)

`phone_sqlite/throttleiq_2026-10-14.db` is a copy of the whole app database, taken from the iPhone with `xcrun devicectl`. The file passes SQLite's integrity check and is at schema v27. Two exports sit next to it:
- `ride_aac4e04d_points_full.csv` holds all 16 columns for each of the 1,119 points (timestamps are UTC);
- `ride_aac4e04d_ride_row.json` holds the ride row.

The phone has the same 1,119 points as the cloud. What it adds is the columns the cloud lacks. This is what they show for the crash window (local time):

| Time | Speed (km/h) | GPS accuracy | Heading | Confidence | Period |
|---|---|---|---|---|---|
| 21:28:03–21:28:18 | 24 → 20 | 8.0–8.2 m | ~350–010° (north) | 88–89 | moving |
| 21:28:25–21:28:43 | 10.7 → 4.2 | 11.2 → 13.1 m | 002–015° | 81 → 77 | moving |
| **21:28:47** | 12.7 | 13.3 m | 343° | 77 | moving |
| **21:29:02** | 0 | 13.8 m | **280°** | 75 | **idle** |
| 21:29:07–21:29:33 | 0 / ~5.5 | 14–**21.6 m** | 284–339° | 75 → **58** | idle, with one short "moving" blip |
| 21:29:34–21:33:19 | 0 | 14.2 m | wandering | 70–74 | idle |

- **GPS quality fell sharply around the crash.** Accuracy went from 8 m to 13–22 m, and confidence went from 89 to 58. That fits a phone lying on the road next to the overpass, and it explains the "star".
- **The heading swung by 63° (343° → 280°) across the 15-second gap.** That is what you'd expect if the phone had tumbled. Heading is unreliable while stopped, though, so this supports the timing but proves nothing by itself.
- **Correction to the analysis above:** the ride's single `high_jerk` event was at **21:52:29**, at 48.7 km/h. That is 23 minutes after the crash, so it is **not** the crash.
- **`jerk` and `acceleration` come from GPS speed, not the accelerometer.** `imu_quality` reads 100 at every point. Every jerk value in the crash window is under 1.5 m/s³.
- **There is no raw accelerometer or gyro data on the phone either.** The impact force of this crash can't be recovered from anything the app stores. See `DOCS/For Devs and Contributors/architecture/phone_vs_cloud_data.md`.

## Data-quality notes

- **The GPS fixes are sparse.** There are 1,119 points over 6,817 s, which is one every 6 s on average. 11 gaps run longer than 60 s, the longest being 93 s at 21:30:59 while stopped after the crash. The distance filter and the stationary thinning are working as designed.
- **The last 10 minutes have no points.** The track ends at 21:57:48, but the ride ends at 22:07:41. The bike was probably parked while the ride was still running, so the distance filter recorded nothing.
- **The phone timestamps are fine.** Times end in either `.000` or `.999`; that comes from GPS clock rounding and appears all through the ride, so it says nothing about the crash.

## Recommendations (none built; the founder decides)

1. **Save `ImpactDetector` spike data to disk even with alerts off.** Logging every spike, confirmed or not, with its peak g, timestamp and post-spike speeds would have given a real impact value for this crash. That is the calibration data §78.1 says is missing.
2. **Add the IMU fields to the cloud track.** If `jerk` or the peak IMU magnitude went into the codec as a 6th field (see the append-only rule in `ride_track_codec.dart`), a crash like this could be analysed after the fact.
3. **Lower the speed-drop rule for low speeds.** For example, accept a drop of 1 m/s when the pre-spike speed is under 3 m/s and the phone is still for 3 s or more. The aim is to catch slow tip-overs at crossings and speed bumps.
4. **Damp jitter while stopped on the ride-history map.** Collapse fixes within about 20 m of each other while speed is 0, so a stationary phone does not draw a star.

## Not verified

- The "record 90" and the 1.08 min jam time do not appear in the ride document.
- The exact moment of impact cannot be recovered: there was no IMU log, and GPS was silent from 21:28:47 to 21:29:02.
