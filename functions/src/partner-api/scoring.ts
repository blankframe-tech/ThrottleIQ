/**
 * Pure half of the partner API (see partner-api.ts): payload validation,
 * road-segment baselines and the ride score. No Firestore here, so
 * test/partner-scoring.test.js covers it without the emulator.
 *
 * The score keeps ThrottleIQ parity on purpose: `eventScore` is the app's
 * `computeRidingScore` (app/lib/core/utils/riding_score.dart) and the
 * outlier rule is the app's `isSpeedOutlier` (speed_baseline.dart). Change
 * them together or a partner score stops meaning what an app score means.
 */

/** One road cell's pooled speeds: count, sum and sum of squares (km/h). */
export interface Moments {
  n: number;
  sum: number;
  sumSq: number;
}

export type TimeBand = 'night' | 'morningPeak' | 'day' | 'eveningPeak' | 'late';

/** `roadSegmentStats/{segmentId}`: every pooled sample, plus by condition. */
export interface SegmentStats {
  all: Moments;
  bands: Partial<Record<TimeBand, Moments>>;
  wet: Moments;
}

export interface SegmentSample {
  segmentId: string;
  avgSpeedKmh: number;
  pointCount: number;
}

export interface ImpactReport {
  tier: number;
  reason: string;
  peakAccelMs2: number;
  speedBeforeKmh: number;
  /** The rider's answer to "Did you fall?": true, false, or null (unasked). */
  riderSaysFell: boolean | null;
}

export interface RideUpload {
  rideId: string;
  riderRef: string;
  startedAt: Date;
  endedAt: Date;
  distanceKm: number;
  pickupKm: number;
  tripKm: number;
  returnKm: number;
  movingSeconds: number;
  avgSpeedKmh: number;
  maxSpeedKmh: number;
  hardBrakes: number;
  rapidAccels: number;
  highJerks: number;
  overspeeds: number;
  weatherCode: number | null;
  segments: SegmentSample[];
  impacts: ImpactReport[];
}

/** Dhaka (and all of Bangladesh) is UTC+6 with no DST. */
const BD_OFFSET_MS = 6 * 3600 * 1000;

export const bdHour = (d: Date) => new Date(d.getTime() + BD_OFFSET_MS).getUTCHours();

/** ISO weekday 1 (Mon) … 7 (Sun) in Bangladesh time, as the app writes it. */
export function bdWeekday(d: Date): number {
  const day = new Date(d.getTime() + BD_OFFSET_MS).getUTCDay();
  return day === 0 ? 7 : day;
}

/** Dhaka traffic, not clock quarters: the two rush hours ride differently. */
export function timeBand(hour: number): TimeBand {
  if (hour < 6) return 'night';
  if (hour < 11) return 'morningPeak';
  if (hour < 17) return 'day';
  if (hour < 22) return 'eveningPeak';
  return 'late';
}

/** WMO weather codes for drizzle, rain, showers and thunderstorms. */
export function isWet(code: number | null | undefined): boolean {
  if (code == null) return false;
  return (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;
}

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/** Centre of a geohash cell, or null for anything that isn't one. */
export function geohashCentre(hash: string): { lat: number; lng: number } | null {
  let even = true;
  const lat = [-90, 90];
  const lng = [-180, 180];
  for (const ch of hash) {
    const v = BASE32.indexOf(ch);
    if (v < 0) return null;
    for (let bit = 4; bit >= 0; bit--) {
      const range = even ? lng : lat;
      const mid = (range[0] + range[1]) / 2;
      if ((v >> bit) & 1) range[0] = mid;
      else range[1] = mid;
      even = !even;
    }
  }
  return { lat: (lat[0] + lat[1]) / 2, lng: (lng[0] + lng[1]) / 2 };
}

/** Bangladesh with a small margin; a cell outside it is not Dhaka road data. */
export function inBangladesh(p: { lat: number; lng: number }): boolean {
  return p.lat >= 20.3 && p.lat <= 26.8 && p.lng >= 87.9 && p.lng <= 92.8;
}

export const SEGMENT_PRECISION = 7;
export const MAX_SEGMENTS = 3000;
export const MAX_IMPACTS = 20;
/** km/h. Same ceiling as the app's maxPlausibleSpeedMs, rounded. */
export const MAX_SPEED_KMH = 200;

export class ValidationError extends Error {}

const isObj = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);

function num(o: Record<string, unknown>, k: string, min: number, max: number): number {
  const v = o[k];
  if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max) {
    throw new ValidationError(`${k} must be a number in [${min}, ${max}]`);
  }
  return v;
}

const int = (o: Record<string, unknown>, k: string, max: number) => {
  const v = num(o, k, 0, max);
  if (!Number.isInteger(v)) throw new ValidationError(`${k} must be an integer`);
  return v;
};

/** Ids the partner chooses: short, printable, safe as part of a doc id. */
export function ref(o: Record<string, unknown>, k: string): string {
  const v = o[k];
  if (typeof v !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(v)) {
    throw new ValidationError(`${k} must be 1-64 characters of A-Z a-z 0-9 _ -`);
  }
  return v;
}

function date(o: Record<string, unknown>, k: string): Date {
  const v = o[k];
  const d = typeof v === 'string' ? new Date(v) : null;
  if (!d || Number.isNaN(d.getTime())) throw new ValidationError(`${k} must be an ISO date`);
  return d;
}

/**
 * Parses `POST /v1/rides`. Strict on purpose: this data lands in the shared
 * Dhaka pool, and one bad partner build must not be able to skew it.
 */
export function parseRideUpload(body: unknown, now: Date): RideUpload {
  if (!isObj(body)) throw new ValidationError('body must be a JSON object');
  const startedAt = date(body, 'startedAt');
  const endedAt = date(body, 'endedAt');
  if (endedAt < startedAt) throw new ValidationError('endedAt is before startedAt');
  if (endedAt.getTime() - startedAt.getTime() > 24 * 3600 * 1000) {
    throw new ValidationError('a ride is at most 24 h');
  }
  if (endedAt.getTime() > now.getTime() + 10 * 60 * 1000) {
    throw new ValidationError('endedAt is in the future');
  }
  if (now.getTime() - startedAt.getTime() > 30 * 24 * 3600 * 1000) {
    throw new ValidationError('rides older than 30 days are not accepted');
  }

  const rawSegments = body.segments;
  if (!Array.isArray(rawSegments) || rawSegments.length > MAX_SEGMENTS) {
    throw new ValidationError(`segments must be an array of at most ${MAX_SEGMENTS}`);
  }
  const seen = new Set<string>();
  const segments = rawSegments.map((s): SegmentSample => {
    if (!isObj(s)) throw new ValidationError('segment must be an object');
    const id = s.segmentId;
    const centre = typeof id === 'string' && id.length === SEGMENT_PRECISION ? geohashCentre(id) : null;
    if (!centre || !inBangladesh(centre)) {
      throw new ValidationError(`segmentId must be a precision-${SEGMENT_PRECISION} geohash in Bangladesh`);
    }
    if (seen.has(id as string)) throw new ValidationError(`duplicate segment ${id}`);
    seen.add(id as string);
    return {
      segmentId: id as string,
      avgSpeedKmh: num(s, 'avgSpeedKmh', 0, MAX_SPEED_KMH),
      pointCount: int(s, 'pointCount', 100000),
    };
  });

  const rawImpacts = body.impacts ?? [];
  if (!Array.isArray(rawImpacts) || rawImpacts.length > MAX_IMPACTS) {
    throw new ValidationError(`impacts must be an array of at most ${MAX_IMPACTS}`);
  }
  const impacts = rawImpacts.map((i): ImpactReport => {
    if (!isObj(i)) throw new ValidationError('impact must be an object');
    const fell = i.riderSaysFell;
    if (fell !== true && fell !== false && fell !== null && fell !== undefined) {
      throw new ValidationError('riderSaysFell must be true, false or null');
    }
    const reason = typeof i.reason === 'string' ? i.reason : '';
    if (!/^[a-zA-Z]{1,32}$/.test(reason)) throw new ValidationError('impact reason is invalid');
    return {
      tier: int(i, 'tier', 2),
      reason,
      peakAccelMs2: num(i, 'peakAccelMs2', 0, 1000),
      speedBeforeKmh: num(i, 'speedBeforeKmh', 0, MAX_SPEED_KMH),
      riderSaysFell: fell ?? null,
    };
  });

  const weather = body.weatherCode;
  if (weather != null && (typeof weather !== 'number' || !Number.isInteger(weather) || weather < 0 || weather > 99)) {
    throw new ValidationError('weatherCode must be a WMO code 0-99 or null');
  }

  const upload: RideUpload = {
    rideId: ref(body, 'rideId'),
    riderRef: ref(body, 'riderRef'),
    startedAt,
    endedAt,
    distanceKm: num(body, 'distanceKm', 0, 1000),
    pickupKm: num(body, 'pickupKm', 0, 1000),
    tripKm: num(body, 'tripKm', 0, 1000),
    returnKm: num(body, 'returnKm', 0, 1000),
    movingSeconds: int(body, 'movingSeconds', 24 * 3600),
    avgSpeedKmh: num(body, 'avgSpeedKmh', 0, MAX_SPEED_KMH),
    maxSpeedKmh: num(body, 'maxSpeedKmh', 0, MAX_SPEED_KMH),
    hardBrakes: int(body, 'hardBrakes', 10000),
    rapidAccels: int(body, 'rapidAccels', 10000),
    highJerks: int(body, 'highJerks', 10000),
    overspeeds: int(body, 'overspeeds', 10000),
    weatherCode: (weather as number | null | undefined) ?? null,
    segments,
    impacts,
  };
  if (upload.pickupKm + upload.tripKm + upload.returnKm > upload.distanceKm + 0.5) {
    throw new ValidationError('pickupKm + tripKm + returnKm exceeds distanceKm');
  }
  return upload;
}

/** Same as the app's `computeRidingScore`. */
export function eventScore(hardBrakes: number, rapidAccels: number, highJerks: number): number {
  return Math.min(100, Math.max(0, 100 - (hardBrakes * 5 + rapidAccels * 3 + highJerks)));
}

export function tierOf(score: number): 'smooth' | 'steady' | 'aggressive' {
  if (score >= 80) return 'smooth';
  if (score >= 60) return 'steady';
  return 'aggressive';
}

export interface Baseline {
  sampleCount: number;
  meanKmh: number;
  stddevKmh: number;
  /** Which pool the baseline came from. */
  basis: 'wet' | TimeBand | 'all';
}

/** Fewest pooled samples that count as "how this road is usually ridden". */
export const MIN_BASELINE_SAMPLES = 5;

export function baselineOf(m: Moments | undefined): Omit<Baseline, 'basis'> | null {
  if (!m || m.n < MIN_BASELINE_SAMPLES) return null;
  const mean = m.sum / m.n;
  const variance = Math.max(0, m.sumSq / m.n - mean * mean);
  return { sampleCount: m.n, meanKmh: mean, stddevKmh: Math.sqrt(variance) };
}

/**
 * The most specific pool with enough samples: rain first (a wet road is
 * ridden slower), then the ride's time band, then everything.
 */
export function pickBaseline(stats: SegmentStats | undefined, band: TimeBand, wet: boolean): Baseline | null {
  if (!stats) return null;
  const tries: [Baseline['basis'], Moments | undefined][] = [
    ...(wet ? ([['wet', stats.wet]] as [Baseline['basis'], Moments | undefined][]) : []),
    [band, stats.bands?.[band]],
    ['all', stats.all],
  ];
  for (const [basis, m] of tries) {
    const b = baselineOf(m);
    if (b) return { ...b, basis };
  }
  return null;
}

/** Same as the app's `isSpeedOutlier` defaults: z > 2.5 AND ≥ 20 km/h over. */
export function isSpeedOutlier(speedKmh: number, b: Baseline, zThreshold = 2.5, minDeltaKmh = 20): boolean {
  const delta = speedKmh - b.meanKmh;
  if (delta < minDeltaKmh) return false;
  if (b.stddevKmh === 0) return true;
  return delta / b.stddevKmh > zThreshold;
}

/** Points off per road cell ridden far faster than the pool, and the cap. */
export const OUTLIER_PENALTY = 4;
export const MAX_ROAD_PENALTY = 30;
export const OVERSPEED_PENALTY = 3;

export interface FasterThanUsual {
  segmentId: string;
  speedKmh: number;
  typicalKmh: number;
  basis: Baseline['basis'];
}

export interface RideScore {
  score: number;
  tier: 'smooth' | 'steady' | 'aggressive';
  eventScore: number;
  roadPenalty: number;
  overspeedPenalty: number;
  segmentsCompared: number;
  fasterThanUsual: FasterThanUsual[];
  scoringVersion: number;
}

export const SCORING_VERSION = 1;

/**
 * v1 score: the app's event score, minus points for road cells ridden far
 * faster than the Dhaka pool rides them in the same conditions, minus
 * overspeed episodes. The weights are a starting heuristic, not a fitted
 * model; `scoringVersion` lets stored scores be told apart when they change.
 */
export function scoreRide(ride: RideUpload, stats: Map<string, SegmentStats>): RideScore {
  const band = timeBand(bdHour(ride.startedAt));
  const wet = isWet(ride.weatherCode);
  const faster: FasterThanUsual[] = [];
  let compared = 0;
  for (const s of ride.segments) {
    const b = pickBaseline(stats.get(s.segmentId), band, wet);
    if (!b) continue;
    compared++;
    if (isSpeedOutlier(s.avgSpeedKmh, b)) {
      faster.push({ segmentId: s.segmentId, speedKmh: s.avgSpeedKmh, typicalKmh: b.meanKmh, basis: b.basis });
    }
  }
  const events = eventScore(ride.hardBrakes, ride.rapidAccels, ride.highJerks);
  const roadPenalty = Math.min(MAX_ROAD_PENALTY, faster.length * OUTLIER_PENALTY);
  const overspeedPenalty = ride.overspeeds * OVERSPEED_PENALTY;
  const score = Math.max(0, events - roadPenalty - overspeedPenalty);
  return {
    score,
    tier: tierOf(score),
    eventScore: events,
    roadPenalty,
    overspeedPenalty,
    segmentsCompared: compared,
    fasterThanUsual: faster,
    scoringVersion: SCORING_VERSION,
  };
}

/** Adds one sample's speed to a cell's stats (pure; the trigger persists it). */
export function addSample(
  stats: SegmentStats | undefined,
  speedKmh: number,
  hour: number,
  weatherCode: number | null | undefined,
): SegmentStats {
  const add = (m: Moments | undefined): Moments => ({
    n: (m?.n ?? 0) + 1,
    sum: (m?.sum ?? 0) + speedKmh,
    sumSq: (m?.sumSq ?? 0) + speedKmh * speedKmh,
  });
  const band = timeBand(hour);
  const next: SegmentStats = {
    all: add(stats?.all),
    bands: { ...(stats?.bands ?? {}), [band]: add(stats?.bands?.[band]) },
    wet: isWet(weatherCode) ? add(stats?.wet) : stats?.wet ?? { n: 0, sum: 0, sumSq: 0 },
  };
  return next;
}
