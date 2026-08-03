import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/ride_track_codec.dart';

Map<String, dynamic> _row(int i) => {
      'lat': 23.8103 + i * 0.0001,
      'lng': 90.4125 + i * 0.0001,
      'timestamp': DateTime.utc(2026, 8, 1, 9, 0, i).toIso8601String(),
      'speed_ms': 10.0 + i,
      'acceleration': 0.5,
    };

void main() {
  group('encode/decode round-trip', () {
    test('preserves every field', () {
      final original = _row(3);
      final decoded = decodeTrackPoint(encodeTrackPoint(original));

      expect(decoded['lat'], closeTo(original['lat'] as double, 1e-9));
      expect(decoded['lng'], closeTo(original['lng'] as double, 1e-9));
      expect(decoded['speed_ms'], original['speed_ms']);
      expect(decoded['acceleration'], original['acceleration']);
      expect(
        DateTime.parse(decoded['timestamp'] as String).toUtc(),
        DateTime.parse(original['timestamp'] as String).toUtc(),
      );
    });

    test('encodes to a positional list, not a map', () {
      final encoded = encodeTrackPoint(_row(0));
      expect(encoded, isA<List<num>>());
      expect(encoded, hasLength(5));
    });

    test('missing numerics default to zero rather than throwing', () {
      final decoded = decodeTrackPoint(encodeTrackPoint({'lat': 1.0}));
      expect(decoded['lat'], 1.0);
      expect(decoded['lng'], 0.0);
      expect(decoded['speed_ms'], 0.0);
    });

    test('an unparseable timestamp degrades instead of throwing', () {
      final encoded = encodeTrackPoint({'timestamp': 'not-a-date'});
      expect(encoded[2], 0);
    });

    test('accepts epoch-millis timestamps as well as ISO strings', () {
      final millis = DateTime.utc(2026, 8, 1).millisecondsSinceEpoch;
      expect(encodeTrackPoint({'timestamp': millis})[2], millis);
    });

    // Forward compatibility: a chunk written before a field was appended must
    // still decode, with the tail defaulted.
    test('a short encoded point decodes with defaults', () {
      final decoded = decodeTrackPoint([23.8, 90.4]);
      expect(decoded['lat'], 23.8);
      expect(decoded['lng'], 90.4);
      expect(decoded['speed_ms'], 0.0);
      expect(decoded['acceleration'], 0.0);
    });
  });

  group('chunkTrack', () {
    // THE regression test. Firestore rejects nested arrays with a native
    // Objective-C exception that Dart cannot catch — it aborts the process.
    // Shipping a List<List<num>> here crashed the app on the first sync after
    // a ride (Issues.md #11). Every chunk must be a FLAT array of numbers.
    test('chunks are flat arrays of numbers — never nested', () {
      final chunks = chunkTrack([for (var i = 0; i < 3; i++) _row(i)]);
      for (final chunk in chunks) {
        for (final value in chunk) {
          expect(value, isA<num>(),
              reason: 'a nested array here is what crashed the app');
          expect(value, isNot(isA<List>()));
        }
      }
    });

    test('an empty trail produces no chunks at all', () {
      expect(chunkTrack(const []), isEmpty);
    });

    test('a partial chunk stays a single chunk, strided', () {
      final chunks = chunkTrack([for (var i = 0; i < 10; i++) _row(i)]);
      expect(chunks, hasLength(1));
      expect(chunks.first, hasLength(10 * fieldsPerPoint));
    });

    test('exactly one chunk-worth is one chunk, not two', () {
      final chunks =
          chunkTrack([for (var i = 0; i < trackChunkSize; i++) _row(i)]);
      expect(chunks, hasLength(1));
      expect(chunks.first, hasLength(trackChunkSize * fieldsPerPoint));
    });

    test('one over the boundary spills into a second chunk', () {
      final chunks =
          chunkTrack([for (var i = 0; i < trackChunkSize + 1; i++) _row(i)]);
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(trackChunkSize * fieldsPerPoint));
      expect(chunks[1], hasLength(fieldsPerPoint));
    });

    test('a large trail chunks evenly', () {
      final chunks =
          chunkTrack([for (var i = 0; i < trackChunkSize * 3; i++) _row(i)]);
      expect(chunks, hasLength(3));
      for (final c in chunks) {
        expect(c, hasLength(trackChunkSize * fieldsPerPoint));
      }
    });
  });

  group('decodeChunk', () {
    test('strides the flat array back into points', () {
      final rows = [for (var i = 0; i < 4; i++) _row(i)];
      final decoded = decodeChunk(chunkTrack(rows).single);
      expect(decoded, hasLength(4));
      expect(decoded[2]['lat'], closeTo(rows[2]['lat'] as double, 1e-9));
    });

    // A truncated document would otherwise decode its tail into a point with
    // garbage zeros, putting a phantom (0,0) fix in the middle of the ocean
    // on the rider's map.
    test('drops a trailing partial block rather than decoding garbage', () {
      final flat = [...chunkTrack([_row(0), _row(1)]).single];
      flat.removeLast(); // truncate mid-point
      expect(decodeChunk(flat), hasLength(1));
    });

    test('handles an empty chunk', () {
      expect(decodeChunk(const []), isEmpty);
    });
  });

  group('flattenTrack', () {
    test('reverses chunking, preserving order', () {
      final rows = [for (var i = 0; i < trackChunkSize + 25; i++) _row(i)];
      final restored = flattenTrack(chunkTrack(rows));

      expect(restored, hasLength(rows.length));
      for (var i = 0; i < rows.length; i++) {
        expect(restored[i]['lat'], closeTo(rows[i]['lat'] as double, 1e-9));
        expect(restored[i]['speed_ms'], rows[i]['speed_ms']);
      }
    });

    test('handles no chunks and empty chunks', () {
      expect(flattenTrack(const []), isEmpty);
      expect(flattenTrack([[], []]), isEmpty);
    });
  });
}
