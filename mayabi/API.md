# ThrottleIQ partner API, v1

`ThrottleIqClient` (README) wraps all of this. Use this page if Maya's server calls the API directly.

- **Base URL:** `https://throttleiqfb.web.app/api/partner/`
- **Auth**, one of:
  - `x-api-key: <key>` from **Maya's server** only. Reaches any Maya rider. Never put it in an app.
  - `authorization: Bearer <rider token>` from **the rider's app**. Reaches only that rider: a different `riderRef` returns `403`, another rider's live link `404`, and minting tokens `403`.
  - A missing, unknown, revoked, expired or tampered key or token returns `401`.
- **Format:** JSON in and out. Errors are `{ "error": "<reason>" }`. `400` means the payload was refused, so don't retry it. `404` means unknown or not yours. `429` means over the rate limit (about 1200 calls a minute per partner, 60 per rider): retry after a minute. `5xx` means retry with backoff.
- **Ids you choose** (`rideId`, `riderRef`): 1-64 characters of `A-Z a-z 0-9 _ -`.
- Server code: `functions/src/partner-api/` (scoring in `scoring.ts`).

---

## `POST v1/riders/{riderRef}/token`: a rider token (API key only)

No body. The response is `201 { token, expiresAt }`. The token is valid for 24 h; mint a new one before then. It is stateless: to cut every token off at once, ask ThrottleIQ to deactivate the partner.

## `POST v1/rides`: upload a finished ride, get its score

The request body is `RideReport.toJson()`:

| Field | Type | Rule |
|---|---|---|
| rideId, riderRef | string | id rules above. A `rideId` is bound to its first rider |
| startedAt, endedAt | ISO 8601 | end ≥ start, at most 24 h, not in the future, started within the last 30 days |
| distanceKm, pickupKm, tripKm, returnKm | number | 0–1000. pickup + trip + return ≤ distance + 0.5 |
| movingSeconds | int | 0–86400 |
| avgSpeedKmh, maxSpeedKmh | number | 0–200 |
| hardBrakes, rapidAccels, highJerks, overspeeds | int | 0–10000 |
| weatherCode | int or null | WMO code 0–99 |
| segments | array, ≤ 3000 | `{ segmentId, avgSpeedKmh, pointCount }`. `segmentId` is a precision-7 geohash (~150 m) inside Bangladesh, with no duplicates |
| impacts | array, ≤ 20 | `{ tier: 0-2, reason, peakAccelMs2, speedBeforeKmh, riderSaysFell: true/false/null }` |

The response is `200`:

```json
{
  "rideId": "trip_1", "replayed": false,
  "score": 86, "tier": "smooth", "eventScore": 93,
  "roadPenalty": 4, "overspeedPenalty": 3, "segmentsCompared": 41,
  "fasterThanUsual": [ { "segmentId": "wh0r3qt", "speedKmh": 70, "typicalKmh": 31.2, "basis": "morningPeak" } ],
  "scoringVersion": 1
}
```

The upload is **idempotent:** sending the same `rideId` again returns the stored score with `"replayed": true` and changes nothing. The ride is scored against the Dhaka pool *before* its own segments are added to it. `basis` is the pool that was compared: `wet`, `night`, `morningPeak`, `day`, `eveningPeak`, `late` or `all`.

## `GET v1/riders/{riderRef}`: a rider's running score

The response is `200`, or `404` before her first ride:

```json
{ "riderRef": "mayabi-42", "rides": 37, "distanceKm": 512.4,
  "averageScore": 84.1, "recentAverageScore": 88.5, "recentScores": [85, 90, "… last 20"],
  "tier": "smooth", "hardBrakes": 41, "rapidAccels": 12, "overspeeds": 3, "fellReports": 0 }
```

## `DELETE v1/riders/{riderRef}`: erase a rider

Deletes her rides, running score, alerts and live links. The response is `200 { riderRef, deleted }`. Her road-pool samples stay. They carry no rider or ride id and no stored per-trip id.

## Live share

| Call | Body | Response |
|---|---|---|
| `POST v1/live` | `{ riderRef, lat, lng, speedMs, batteryPct? }` | `201 { token, url, expiresAt }` |
| `POST v1/live/{token}` | `{ lat, lng, speedMs, batteryPct?, status: "riding" or "paused" }` | `200` |
| `DELETE v1/live/{token}` | none | `200`. The link is revoked at once and her last position is cleared |

`url` opens in any browser for 12 h. After an alert the status stays `sos` or `crash` even if a later update says `riding`. Send updates on 100 m, 15 s or a pause change (`LiveShareThrottle`).

## `POST v1/alerts`: SOS, crash, unusual stop

The body is `{ riderRef, kind: "sos" | "crash" | "unusualStop", lat?, lng?, liveToken?, rideId? }`.

The response is `201 { alertId, delivery, liveUrl }`. `delivery` is one of `delivered`, `no_webhook`, `failed_network`, `failed_unsafe_webhook` (the webhook URL is not HTTPS on a public address at send time) or `failed_http_<code>`. Redirects are not followed: a `3xx` is `failed_http_3xx`. The alert is stored either way. With `liveToken`, the live page turns red. The partner webhook payload and its signature are in README §7.
