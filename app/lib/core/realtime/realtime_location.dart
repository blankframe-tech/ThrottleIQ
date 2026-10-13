import 'realtime_store.dart';

/// One position on a movement channel (`/live_shares/{token}/location`,
/// `/group_rides/{id}/locations/{uid}`). The wire shape is fixed by
/// `database.rules.json` — no other keys are accepted.
class RealtimeLocation {
  const RealtimeLocation({
    required this.lat,
    required this.lng,
    required this.seq,
    this.serverTime,
    this.speedMs,
    this.headingDeg,
    this.accuracyM,
  });

  final double lat;
  final double lng;

  /// Per-writer counter, +1 per write. Readers use it to detect dropped or
  /// reordered updates (see `RealtimeDeliveryStats`).
  final int seq;

  /// Server receive time (`ts`). Null only on a value that hasn't been read
  /// back from the server yet.
  final DateTime? serverTime;

  final double? speedMs;
  final double? headingDeg;
  final double? accuracyM;

  /// The map written to RTDB. `ts` is always the server-timestamp sentinel.
  Map<String, Object?> toWrite() => {
        'lat': lat,
        'lng': lng,
        'ts': kRealtimeServerTimestamp,
        'seq': seq,
        if (speedMs != null && speedMs! >= 0) 'speedMs': speedMs,
        if (headingDeg != null) 'headingDeg': headingDeg,
        if (accuracyM != null && accuracyM! >= 0) 'accuracyM': accuracyM,
      };

  /// Parses a value read back from RTDB, or null if it isn't a usable
  /// location (a partially-deleted node, someone's malformed write).
  static RealtimeLocation? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    final seq = raw['seq'];
    if (lat is! num || lng is! num || seq is! num) return null;
    final ts = raw['ts'];
    return RealtimeLocation(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      seq: seq.toInt(),
      serverTime: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt(), isUtc: true)
          : null,
      speedMs: (raw['speedMs'] as num?)?.toDouble(),
      headingDeg: (raw['headingDeg'] as num?)?.toDouble(),
      accuracyM: (raw['accuracyM'] as num?)?.toDouble(),
    );
  }

  /// How old this fix is by the server's clock. [serverTimeOffsetMs] is
  /// `.info/serverTimeOffset`. Null when [serverTime] is unknown.
  Duration? ageAt(DateTime localNow, {int serverTimeOffsetMs = 0}) {
    final ts = serverTime;
    if (ts == null) return null;
    final serverNow = localNow.toUtc().add(Duration(milliseconds: serverTimeOffsetMs));
    final age = serverNow.difference(ts);
    return age.isNegative ? Duration.zero : age;
  }
}
