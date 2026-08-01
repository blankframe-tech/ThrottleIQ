/// Encoding for a ride's GPS trail on its way to (and back from) Firestore.
///
/// A ride can hold thousands of points, so one Firestore document per point
/// is out of the question — it would be thousands of writes and reads per
/// ride, and blow through the free tier on a handful of commutes. Instead the
/// trail is chunked into `rides/{rideId}/track/{chunkIndex}` documents, each
/// holding up to [trackChunkSize] points.
///
/// Within a chunk each point is a **fixed-order list**, not a map:
///
/// ```
/// [lat, lng, timestampMillis, speedMs, accelMs2]
/// ```
///
/// Firestore stores map keys verbatim in every single element, so a map-based
/// encoding would repeat the strings 'lat', 'lng', 'timestamp'… once per
/// point — for a 5,000-point ride that is tens of thousands of redundant
/// characters counted against the 1 MiB document limit. The positional form
/// costs nothing per element, at the price of this comment being the schema.
/// Adding a field means appending to the END of the list and treating it as
/// nullable on read, never reordering.
///
/// Everything here is pure so the round-trip is directly testable.
library;

/// Points per `track` document. Firestore's hard limit is 1 MiB per document;
/// 500 positional points is comfortably inside it with room for the trail to
/// grow extra fields later.
const int trackChunkSize = 500;

/// Fields, in the order they appear in an encoded point.
const int _lat = 0;
const int _lng = 1;
const int _ts = 2;
const int _speed = 3;
const int _accel = 4;

/// Encodes one `ride_points` row (as returned by `RidePointDao`) into its
/// positional form. Unknown/absent numerics become 0; an unparseable
/// timestamp becomes 0 rather than throwing, so one bad row can't fail a
/// whole ride's upload.
List<num> encodeTrackPoint(Map<String, dynamic> row) {
  return [
    (row['lat'] as num?)?.toDouble() ?? 0,
    (row['lng'] as num?)?.toDouble() ?? 0,
    _millisOf(row['timestamp']),
    (row['speed_ms'] as num?)?.toDouble() ?? 0,
    (row['acceleration'] as num?)?.toDouble() ?? 0,
  ];
}

/// Inverse of [encodeTrackPoint]. Tolerates a short list (a chunk written by
/// an older build, before a field was appended) by defaulting the tail.
Map<String, dynamic> decodeTrackPoint(List<dynamic> encoded) {
  num at(int i) => i < encoded.length ? (encoded[i] as num? ?? 0) : 0;

  return {
    'lat': at(_lat).toDouble(),
    'lng': at(_lng).toDouble(),
    'timestamp':
        DateTime.fromMillisecondsSinceEpoch(at(_ts).toInt()).toIso8601String(),
    'speed_ms': at(_speed).toDouble(),
    'acceleration': at(_accel).toDouble(),
  };
}

/// Splits [rows] into chunks of at most [trackChunkSize] encoded points.
/// An empty trail yields no chunks (so nothing is uploaded for a ride with
/// no track, rather than one empty document).
List<List<List<num>>> chunkTrack(List<Map<String, dynamic>> rows) {
  final chunks = <List<List<num>>>[];
  for (var start = 0; start < rows.length; start += trackChunkSize) {
    final end = (start + trackChunkSize) < rows.length
        ? start + trackChunkSize
        : rows.length;
    chunks.add([for (var i = start; i < end; i++) encodeTrackPoint(rows[i])]);
  }
  return chunks;
}

/// Flattens downloaded chunks back into an ordered list of point rows.
/// Chunks must be supplied in index order — see `CloudRepository`, which
/// sorts by the numeric doc id rather than trusting Firestore's lexicographic
/// ordering (which would put chunk 10 before chunk 2).
List<Map<String, dynamic>> flattenTrack(List<List<dynamic>> chunks) {
  return [
    for (final chunk in chunks)
      for (final point in chunk) decodeTrackPoint(point as List<dynamic>),
  ];
}

int _millisOf(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}
