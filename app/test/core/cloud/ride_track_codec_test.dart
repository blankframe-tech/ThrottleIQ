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
    test('an empty trail produces no chunks at all', () {
      expect(chunkTrack(const []), isEmpty);
    });

    test('a partial chunk stays a single chunk', () {
      final chunks = chunkTrack([for (var i = 0; i < 10; i++) _row(i)]);
      expect(chunks, hasLength(1));
      expect(chunks.first, hasLength(10));
    });

    test('exactly one chunk-worth is one chunk, not two', () {
      final chunks =
          chunkTrack([for (var i = 0; i < trackChunkSize; i++) _row(i)]);
      expect(chunks, hasLength(1));
      expect(chunks.first, hasLength(trackChunkSize));
    });

    test('one over the boundary spills into a second chunk', () {
      final chunks =
          chunkTrack([for (var i = 0; i < trackChunkSize + 1; i++) _row(i)]);
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(trackChunkSize));
      expect(chunks[1], hasLength(1));
    });

    test('a large trail chunks evenly', () {
      final chunks =
          chunkTrack([for (var i = 0; i < trackChunkSize * 3; i++) _row(i)]);
      expect(chunks, hasLength(3));
      for (final c in chunks) {
        expect(c, hasLength(trackChunkSize));
      }
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
