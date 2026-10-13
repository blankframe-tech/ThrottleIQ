/**
 * Pure logic behind public/live-viewer.html's two-source position feed.
 *
 * The viewer listens to the same ride twice:
 *
 *   Firestore  liveSessions/{token}            every ~10 s, authoritative for
 *                                              status / battery / shareable
 *   RTDB       live_shares/{token}/location    ~1 Hz, position only
 *
 * and must show whichever position is newer, say which channel it is on, and
 * notice dropped or reordered updates. None of that touches the DOM, so it
 * lives here where node:test can exercise it
 * (scripts/test/live_viewer_core.test.js) instead of only ever being checked
 * by eye in a browser.
 *
 * All times are SERVER milliseconds: RTDB `ts` is forced to the server clock
 * by database.rules.json and Firestore `updatedAt` is a serverTimestamp, so
 * the viewer converts its own clock with `.info/serverTimeOffset` rather than
 * trusting either phone.
 *
 * Contract: DOCS/For Devs and Contributors/architecture/realtime-database.md.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.LiveViewerCore = api;
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /// An RTDB fix younger than this means the 1 Hz channel is genuinely
  /// flowing. A few missed seconds (a short tunnel) still reads as live.
  const REALTIME_FRESH_MS = 5000;

  /// Same threshold as the viewer's long-standing "no updates" warning: past
  /// this, neither channel has said anything recently.
  const STALE_MS = 30000;

  /// Reads a Firestore Timestamp, Date, ISO string or epoch-ms number into
  /// epoch milliseconds; null for anything unusable.
  function toMillis(raw) {
    if (raw == null) return null;
    if (typeof raw === 'number') return Number.isFinite(raw) ? raw : null;
    if (typeof raw.toMillis === 'function') return raw.toMillis();
    if (typeof raw.toDate === 'function') return raw.toDate().getTime();
    const ms = new Date(raw).getTime();
    return Number.isNaN(ms) ? null : ms;
  }

  const isCoord = (v) => typeof v === 'number' && Number.isFinite(v);

  /// The position carried by a liveSessions document, or null.
  function firestorePosition(session) {
    if (!session || !isCoord(session.lastLat) || !isCoord(session.lastLng)) return null;
    return {
      lat: session.lastLat,
      lng: session.lastLng,
      speedMs: typeof session.speedMs === 'number' ? session.speedMs : null,
      headingDeg: null,
      atMs: toMillis(session.updatedAt),
      source: 'firestore',
    };
  }

  /// The position carried by a live_shares/{token}/location value, or null.
  function rtdbPosition(location) {
    if (!location || !isCoord(location.lat) || !isCoord(location.lng)) return null;
    return {
      lat: location.lat,
      lng: location.lng,
      speedMs: typeof location.speedMs === 'number' ? location.speedMs : null,
      headingDeg: typeof location.headingDeg === 'number' ? location.headingDeg : null,
      atMs: toMillis(location.ts),
      seq: typeof location.seq === 'number' ? location.seq : null,
      source: 'rtdb',
    };
  }

  /// Newer of the two; RTDB wins a tie (it is the higher-resolution source)
  /// and a position with a known time beats one without.
  function pickFreshest(fsPos, rtPos) {
    if (!fsPos) return rtPos || null;
    if (!rtPos) return fsPos;
    if (rtPos.atMs == null) return fsPos.atMs == null ? rtPos : fsPos;
    if (fsPos.atMs == null) return rtPos;
    return rtPos.atMs >= fsPos.atMs ? rtPos : fsPos;
  }

  /// Age of [pos] in ms at local time [nowMs], given the RTDB
  /// `.info/serverTimeOffset` [offsetMs]. Infinity when unknown. Never
  /// negative: a fix stamped a moment "in the future" by clock jitter is 0 old.
  function ageMs(pos, nowMs, offsetMs) {
    if (!pos || pos.atMs == null) return Infinity;
    return Math.max(0, nowMs + (offsetMs || 0) - pos.atMs);
  }

  /// 'realtime' — RTDB socket up and its fix is fresh;
  /// 'delayed'  — something (usually Firestore's 10 s tick) is still current;
  /// 'offline'  — nothing new from either channel for STALE_MS.
  function transportState({ rtdbConnected, rtPos, fsPos, nowMs, offsetMs }) {
    if (rtdbConnected && ageMs(rtPos, nowMs, offsetMs) < REALTIME_FRESH_MS) return 'realtime';
    const freshest = pickFreshest(fsPos, rtPos);
    if (ageMs(freshest, nowMs, offsetMs) < STALE_MS) return 'delayed';
    return 'offline';
  }

  const BADGE_LABELS = {
    realtime: 'Live · 1s',
    delayed: 'Updates every 10s',
    offline: 'Waiting for signal',
  };

  function badgeLabel(state) {
    return BADGE_LABELS[state] || BADGE_LABELS.offline;
  }

  /// Watches one writer's `seq` counter. Classifies each value as:
  ///   'first'        nothing seen yet
  ///   'next'         exactly last + 1
  ///   'gap'          skipped ahead (missed = seq - last - 1 updates)
  ///   'duplicate'    same seq again
  ///   'restart'      back to 0 (the app restarted its counter: new ride
  ///                  segment or app relaunch) — not an error
  ///   'out_of_order' went backwards to anything but 0
  /// RTDB `value` listeners deliver the latest state, so a gap here is a
  /// coalesced update rather than a lost one — the counter is a health
  /// signal, not a delivery guarantee.
  function createSeqTracker() {
    let last = null;
    const stats = { received: 0, missed: 0, gaps: 0, outOfOrder: 0, duplicates: 0, restarts: 0 };

    function observe(seq) {
      if (typeof seq !== 'number' || !Number.isFinite(seq)) return 'invalid';
      stats.received++;
      let kind;
      if (last === null) kind = 'first';
      else if (seq === last + 1) kind = 'next';
      else if (seq > last + 1) {
        kind = 'gap';
        stats.gaps++;
        stats.missed += seq - last - 1;
      } else if (seq === last) {
        kind = 'duplicate';
        stats.duplicates++;
      } else if (seq === 0) {
        kind = 'restart';
        stats.restarts++;
      } else {
        kind = 'out_of_order';
        stats.outOfOrder++;
      }
      // An out-of-order or duplicate value must not drag `last` backwards,
      // or the next in-order update would be miscounted as a gap.
      if (kind !== 'out_of_order' && kind !== 'duplicate') last = seq;
      return kind;
    }

    return {
      observe,
      stats: () => ({ ...stats, lastSeq: last }),
      reset() {
        last = null;
        for (const k of Object.keys(stats)) stats[k] = 0;
      },
    };
  }

  /// Whether the "no updates" warning should show: nothing from either
  /// channel for [thresholdMs] of LOCAL time. Local, not server, time on
  /// purpose — it measures "has this tab heard anything", which is exactly
  /// the viewer's own receive clock.
  function isStale(nowMs, lastReceivedMs, thresholdMs = STALE_MS) {
    if (lastReceivedMs == null) return false;
    return nowMs - lastReceivedMs > thresholdMs;
  }

  /// Same point as the last one appended to the trail — skip it, so a
  /// Firestore snapshot that loses the freshness race to an RTDB fix does not
  /// stack duplicate vertices.
  function samePoint(a, b) {
    return !!a && !!b && a.lat === b.lat && a.lng === b.lng;
  }

  return {
    REALTIME_FRESH_MS,
    STALE_MS,
    toMillis,
    firestorePosition,
    rtdbPosition,
    pickFreshest,
    ageMs,
    transportState,
    badgeLabel,
    createSeqTracker,
    isStale,
    samePoint,
  };
});
