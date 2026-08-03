/// Encoding for a ride's GPS trail on its way to (and back from) Firestore.
///
/// A ride can hold thousands of points, so one Firestore document per point
/// is out of the question — it would be thousands of writes and reads per
/// ride, and blow through the free tier on a handful of commutes. Instead the
/// trail is chunked into `rides/{rideId}/track/{chunkIndex}` documents, each
/// holding up to [trackChunkSize] points.
///
/// Within a chunk the points are stored **flattened into one array of
/// numbers**, [fieldsPerPoint] values per point, in fixed order:
///
/// ```
/// [lat, lng, tsMillis, speed, accel,  lat, lng, tsMillis, speed, accel,  …]
/// ```
///
/// Two constraints force this shape, and both matter:
///
/// 1. **Firestore does not support nested arrays.** An array may not contain
///    another array. The obvious encoding — a list of 5-element point lists —
///    is rejected by the native SDK with an "Invalid argument" exception from
///    `FSTUserDataReader parseData:`. That is an Objective-C exception, NOT a
///    Dart one, so it cannot be caught by `try`/`catch` around the write: it
///    aborts the process. This shipped that way on 2026-08-01 and crashed the
///    app on the first sync after a ride (see `Issues.md` §11). **Do not
///    reintroduce nesting here** — a flat array is not a style choice.
/// 2. Firestore stores map keys verbatim in every element, so a list of maps
///    would repeat 'lat'/'lng'/'timestamp' once per point — tens of thousands
///    of redundant characters against the 1 MiB document limit on a long ride.
///
/// The price is that this comment is the schema. Adding a field means bumping
/// [fieldsPerPoint], appending at the END of the per-point block, and treating
/// it as nullable on read. Never reorder.
///
/// Everything here is pure so the round-trip is directly testable — though
/// note that pure round-trip tests are exactly what MISSED the nested-array
/// bug, because Dart happily round-trips a shape Firestore refuses.
library;

/// Points per `track` document. Firestore's hard limit is 1 MiB per document;
/// 500 points (2,500 numbers) is comfortably inside it.
const int trackChunkSize = 500;

/// How many numbers each point occupies in the flattened array.
const int fieldsPerPoint = 5;

/// Offsets within one point's block.
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

/// Splits [rows] into chunks of at most [trackChunkSize] points, each chunk a
/// **flat** array of numbers ([fieldsPerPoint] per point).
///
/// Flat, not a list of lists — Firestore rejects nested arrays outright. See
/// the library comment above; this is the shape that crashed the app.
///
/// An empty trail yields no chunks, so a ride with no track uploads nothing
/// rather than one empty document.
List<List<num>> chunkTrack(List<Map<String, dynamic>> rows) {
  final chunks = <List<num>>[];
  for (var start = 0; start < rows.length; start += trackChunkSize) {
    final end = (start + trackChunkSize) < rows.length
        ? start + trackChunkSize
        : rows.length;
    final flat = <num>[];
    for (var i = start; i < end; i++) {
      flat.addAll(encodeTrackPoint(rows[i]));
    }
    chunks.add(flat);
  }
  return chunks;
}

/// Rebuilds point rows from one flat chunk, striding [fieldsPerPoint] at a
/// time. A trailing partial block (a truncated or corrupted document) is
/// dropped rather than decoded into a point with garbage tail values.
List<Map<String, dynamic>> decodeChunk(List<dynamic> flat) {
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i + fieldsPerPoint <= flat.length; i += fieldsPerPoint) {
    out.add(decodeTrackPoint(flat.sublist(i, i + fieldsPerPoint)));
  }
  return out;
}

/// Flattens downloaded chunks back into an ordered list of point rows.
/// Chunks must be supplied in index order — see `CloudRepository`, which
/// sorts by the numeric doc id rather than trusting Firestore's lexicographic
/// ordering (which would put chunk 10 before chunk 2).
List<Map<String, dynamic>> flattenTrack(List<List<dynamic>> chunks) {
  return [
    for (final chunk in chunks) ...decodeChunk(chunk),
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
