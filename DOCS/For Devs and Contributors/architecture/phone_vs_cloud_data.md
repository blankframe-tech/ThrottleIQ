# What the phone stores vs what the cloud stores

**Written:** 2026-10-14.

**Sources:**
- a copy of the founder's iPhone database (`DOCS/General/CRASH TESTING/phone_sqlite/throttleiq_2026-10-14.db`, schema v27);
- the live Firestore project `throttleiqfb`, read with the Admin SDK;
- the sync code in `app/lib/core/cloud/`.

## Summary

- **Ride points are the only real gap.** Every ride, bike and maintenance row on the phone also exists in the cloud: all 126 of the founder's rides match ID for ID, and all 126 have a track. But each GPS point stores 16 columns on the phone and only 5 in the cloud.
- **That loss has already happened for most of the history.** Only 11 of the founder's 126 rides (13 Sep to 14 Oct) still have points on the phone. The other 115 rides (30 Aug to 4 Oct) were restored from the cloud after a reinstall, so their altitude, heading, accuracy, confidence and jam/idle labels are gone for good.
- **Raw IMU data is not stored anywhere.** That covers the accelerometer, the gyro and the lean-angle time series. `acceleration` and `jerk` are calculated from GPS speed, and lean is a GPS estimate (`cornering_estimator.dart`). Only the ride's **maximum** lean and peak g values are saved, and they are synced. So a phone switch loses no lean data beyond what was never recorded in the first place.
- **The real cost problem today is indexing, not missing fields.** Firestore indexes every number inside each `track` chunk's `points` array, because `firestore.indexes.json` has no exemption for it. For the founder's account that is about **25 MB of index entries for 1.5 MB of track data**. Fixing that one setting saves more than sending every missing field would cost.

## 1. Inventory: every table on the phone

The row counts come from the founder's phone and include a second test account  that is signed in on the same device.

| Local table | Rows | In the cloud? | Where it goes in Firestore / notes |
|---|---|---|---|
| `rides` | 192 | ✅ All columns except `track_synced`. `route_*`, `overspeed_count` and the v26 lean/g/elevation columns are left out when they are NULL | `users/{uid}/rides/{id}` |
| `ride_points` | 9,991 | ⚠️ **5 of 16 columns** | `users/{uid}/rides/{id}/track/{n}` (flat arrays, 500 points per document) |
| `bikes` | 6 | ✅ The photo is uploaded to Cloudinary. `archived`/`archived_at` are sent only when set | `users/{uid}/bikes/{id}` |
| `maintenance_logs` | 23 | ✅ All columns. ⚠️ `receipt_path` is only a local file path: the receipt image is **never uploaded** (0 receipts exist today) | `users/{uid}/maintenance/{id}` |
| `bike_maintenance_configs`, `bike_running_costs`, `bike_maintenance_profiles`, `bike_paperwork` | 63 / 2 / 2 / 0 | ✅ | `users/{uid}/private/{bikeId}` (`maintenance_settings_sync.dart`) |
| `fuel_logs` | 0 | ✅ Through the outbox. ⚠️ Per the handoff, the matching `firestore.rules` are not deployed yet | `users/{uid}/fuelLogs/{id}` |
| `deleted_rides`, `deleted_bikes`, `deleted_fuel_logs`, `deleted_maintenance_logs` | 3 / 0 / 0 / 0 | n/a. Tombstones that drive cloud deletes | — |
| `auto_detections` | 1 | ❌ Local only | Background ride-detection log |
| `auto_fixes` | 13 | ❌ Local only. Deleted 14 days after summary (`purgeOldSummarizedFixes`) | Raw GPS fixes from auto-detection |
| `detection_odometer_credits` | 0 | ❌ Local only | Distance credited to the odometer by auto-detection |
| `precheck_issues` | 0 | ❌ Local only | Pre-ride checklist issues |
| `saved_places` | 0 | ❌ Local only | Bookmarked places |
| `user_profiles` | 0 | n/a. Cache of a cloud profile | — |
| `outbox` | 0 | n/a. Queue of pending uploads | — |

Data that lives in the cloud only (social, badges, routes, emergency contacts, group rides and so on) isn't stored on the phone, so it doesn't belong in this gap list.

## 2. The ride-point gap in detail

| `ride_points` column | Type | In the cloud? | What it is |
|---|---|---|---|
| `lat`, `lng` | REAL | ✅ | GPS position |
| `timestamp` | TEXT (UTC) | ✅ (as epoch ms) | Fix time |
| `speed_ms` | REAL | ✅ | GPS speed |
| `acceleration` | REAL | ✅ | Change in GPS speed over time, in m/s². **Not the IMU** |
| `jerk` | REAL | ❌ | Rate of change of `acceleration` (also from GPS) |
| `altitude_m` | REAL | ❌ | GPS altitude. Elevation gain/loss totals are synced on the ride row |
| `accuracy_m` | REAL | ❌ | GPS horizontal accuracy |
| `heading_deg` | REAL | ❌ | Fused heading |
| `confidence` | INTEGER | ❌ | Confidence score from 0 to 100 for each fix |
| `imu_quality` | INTEGER | ❌ | IMU health score from 0 to 100 |
| `is_cornering` | INTEGER | ❌ | Cornering flag (lean itself is not stored per point) |
| `period_type` | TEXT | ❌ | `moving` / `idle` (jam/stop labelling) |
| `segment_start` | INTEGER | ❌ | Pause/resume segment boundary |
| `id`, `ride_id` | — | n/a | Keys |

**What is lost when the phone is switched or the app reinstalled:** the 11 ❌ columns, for every ride. After a restore the app still draws the map line and speed graph. It cannot redo the jam/idle split, GPS-quality analysis, elevation profile, heading, or the segment breaks. The crash analysis on 14 Oct relied on `accuracy_m`, `confidence`, `heading_deg` and `period_type`, all of which exist only on the phone.

**Also not stored anywhere, not even on the phone:**
- raw accelerometer and gyro samples;
- lean angle per point;
- `ImpactDetector` spike near-misses (kept in memory only, and the detector is turned off anyway, see issues §78.1).

## 3. Why these fields aren't in the cloud today

No decision on record ever said "keep these local". The gap is left over from how track sync was built:

1. **Track sync was added late, and only to bring back map lines.** Ride rows have synced since 2026-07-23. Points were not uploaded at all until August, when `uploadRideTrack` was added. Its own comment says the goal was that "a rider reinstalling the app got their ride list back with no lines on any map". Five fields are enough to draw a map line, a speed graph and the distance.
2. **The format was tuned to stay small.** `ride_track_codec.dart` stores flat numeric arrays. Firestore bans nested arrays (that crashed the app in §11), and repeating field names on every point would waste space. Keeping the field count low was the conservative choice.
3. **The project runs on the free Spark plan** (handoff): 1 GiB of storage, 20k writes and 50k reads a day, and no Cloud Functions. Anything that grows storage gets cautious treatment.
4. **Adding a field is not as safe as the codec comment says. ⚠️** The comment says to "append at the END" and read new fields as optional. But the chunks are *flat* arrays read in steps of `fieldsPerPoint = 5`. An older build reading a 14-field chunk would step through it 5 values at a time and turn it into garbage points: wrong lat/lng, wrong times. "Append at the end" only works within one point, not for the array as a whole. The safe change is to add a `fields: N` number to each chunk document, which older builds would ignore, and either:
   - write the wider rows into a new `track` subcollection name (for example `track2`), or
   - require a minimum app version before switching over.
5. **Privacy.** Heading, accuracy and jam labels add little to what lat/lng/time already reveal, so this reason is weak.

## 4. What it would cost

Measured on the founder's account: 126 rides, 164 chunks, 36,114 points. Sizes use Firestore's documented storage formulas: 8 bytes per number, document-name and index-entry overheads included. These are **estimates**; the console's real storage number could not be read with the credentials available.

| | Data | Index on `points` | Total |
|---|---|---|---|
| **Today** (5 fields, indexed by default) | 1.47 MB (40.8 B per point) | **25.1 MB** (695 B per point) | ~26.6 MB |
| Today + index exemption | 1.47 MB | 0 | **~1.5 MB** |
| All 14 fields, with exemption | ~4.1 MB (≈113 B per point) | 0 | **~4.1 MB** |
| All 14 fields, **no** exemption | ~4.1 MB | ~60+ MB (each extra value adds its own index entry) | ~65 MB |

The other limits:
- **Writes don't change.** It is still one write per 500 points, so about 3 writes for a 2-hour ride. Firestore index entries don't count as writes.
- **Reads don't change.** Tracks are downloaded only when needed, one read per chunk.
- **Document size:** 500 points × 14 fields is about 56 KB, well under the 1 MiB limit. It is also 7,000 index entries, under the 40,000-per-document cap.
- **Spark headroom:** today about 38 riders as heavy as the founder would fill the free 1 GiB with track data alone. With the exemption plus all 14 fields, about 250 such riders would. On the paid Blaze plan, Firestore storage costs roughly $0.15–0.18 per GiB per month, depending on region, so a few MB per rider costs nearly nothing either way.

**Conclusion:** cost is not a valid reason to keep these fields off the cloud, once the index exemption is in place.

## 5. Recommended order (nothing built yet)

1. **Exempt `track.points` from indexing.** *(Done on `feat/crash-shadow-mode`, 2026-10-15; live once `firestore.indexes.json` is deployed.)* Add a `fieldOverrides` entry to `firestore.indexes.json` for collection group `track`, field `points`, with `indexes: []`, then deploy indexes. This cuts the estimated track storage by about 94%. It's one config change, nothing queries these arrays, and no code changes.
2. **Version the track format.** Add `fields` to each chunk document and teach the decoder to step through the array by that number. Write the full rows into a new subcollection (or require a minimum app version) so older builds never see a wider chunk.
3. **Keep the raw IMU off the cloud for now.** Instead, save `ImpactDetector` spikes locally as small events, then sync them. That is the crash-calibration data issues §78.1 is missing. Only a few rows per ride.
4. **Optional:** sync `auto_detections` summaries, `saved_places` and `precheck_issues`, and upload receipt images. These are small and low priority.

## Not verified

- The Firestore storage numbers are calculated with the documented formulas, not read from the console. The available service account has no access to `throttleiqfb` billing or console metrics.
- I didn't check whether iOS iCloud backup includes `throttleiq.db`.
- I didn't check the per-point data for the second account's  rides.
