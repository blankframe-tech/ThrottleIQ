import 'dart:collection';
import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data';

/// Keeps the last [keep] of raw sensor samples so an impact can be saved
/// with the seconds before and after it — the calibration data that did not
/// exist for the 14 Oct 2026 crash (DOCS/CRASH TESTING).
///
/// Three streams, each with its own timestamps: the accelerometer including
/// gravity, the motion-filtered acceleration without it, and the gyroscope.
/// [keep] must outlast ImpactDetector.pendingWindow plus the 4 s before the
/// impact, because the window is cut when the impact resolves.
class ImpactWindowRecorder {
  ImpactWindowRecorder({this.keep = const Duration(seconds: 30)});

  final Duration keep;

  /// Bump when the byte layout changes; [decode] rejects other versions.
  static const int formatVersion = 1;

  /// Accelerations are stored in 0.01 m/s² steps (±327 m/s², ±33 g).
  static const double accelScale = 100;

  /// Rotation rates in 0.001 rad/s steps (±32.7 rad/s, ±1,870 °/s).
  static const double gyroScale = 1000;

  static const List<int> _magic = [0x54, 0x49, 0x51, 0x57]; // "TIQW"

  final ListQueue<_Sample> _raw = ListQueue();
  final ListQueue<_Sample> _user = ListQueue();
  final ListQueue<_Sample> _gyro = ListQueue();

  void addRaw(DateTime t, double x, double y, double z) =>
      _add(_raw, t, x, y, z);
  void addUser(DateTime t, double x, double y, double z) =>
      _add(_user, t, x, y, z);
  void addGyro(DateTime t, double x, double y, double z) =>
      _add(_gyro, t, x, y, z);

  void _add(ListQueue<_Sample> q, DateTime t, double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) return;
    final us = t.microsecondsSinceEpoch;
    q.add(_Sample(us, x, y, z));
    final cutoff = us - keep.inMicroseconds;
    while (q.isNotEmpty && q.first.us < cutoff) {
      q.removeFirst();
    }
  }

  /// The samples from [spikeAt] − [before] to [spikeAt] + [after], gzip'd.
  /// Null when none of the three streams has a sample in that span.
  ///
  /// Layout, little-endian: "TIQW", version (u8), 3 reserved bytes, the
  /// impact time (i64, epoch ms), then for each stream (raw, user, gyro) a
  /// count (u16) and that many frames of (offset from the impact in ms, x,
  /// y, z), all i16.
  Uint8List? encodeWindow(
    DateTime spikeAt, {
    Duration before = const Duration(seconds: 4),
    Duration after = const Duration(seconds: 8),
  }) {
    final spikeUs = spikeAt.microsecondsSinceEpoch;
    final from = spikeUs - before.inMicroseconds;
    final to = spikeUs + after.inMicroseconds;
    List<_Sample> pick(ListQueue<_Sample> q) => [
          for (final s in q)
            if (s.us >= from && s.us <= to) s,
        ];
    final streams = [pick(_raw), pick(_user), pick(_gyro)];
    if (streams.every((s) => s.isEmpty)) return null;

    final counts = [for (final s in streams) math.min(s.length, 0xFFFF)];
    final size = 16 + counts.fold<int>(0, (n, c) => n + 2 + c * 8);
    final b = ByteData(size);
    var o = 0;
    for (final c in _magic) {
      b.setUint8(o++, c);
    }
    b.setUint8(o, formatVersion);
    o += 4;
    final spikeMs = spikeAt.millisecondsSinceEpoch;
    b.setInt64(o, spikeMs, Endian.little);
    o += 8;
    for (var i = 0; i < streams.length; i++) {
      final scale = i == 2 ? gyroScale : accelScale;
      b.setUint16(o, counts[i], Endian.little);
      o += 2;
      for (var k = 0; k < counts[i]; k++) {
        final s = streams[i][k];
        b.setInt16(o, _i16((s.us ~/ 1000) - spikeMs), Endian.little);
        b.setInt16(o + 2, _i16(s.x * scale), Endian.little);
        b.setInt16(o + 4, _i16(s.y * scale), Endian.little);
        b.setInt16(o + 6, _i16(s.z * scale), Endian.little);
        o += 8;
      }
    }
    return Uint8List.fromList(gzip.encode(b.buffer.asUint8List()));
  }

  /// Reads back what [encodeWindow] wrote (for tests and the export tools).
  /// Throws a [FormatException] on anything else.
  static ImpactWindow decode(Uint8List bytes) {
    final data = Uint8List.fromList(gzip.decode(bytes));
    final b = ByteData.sublistView(data);
    if (data.length < 16) throw const FormatException('window too short');
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) throw const FormatException('not a window');
    }
    if (data[4] != formatVersion) {
      throw FormatException('unsupported window version ${data[4]}');
    }
    final spikeMs = b.getInt64(8, Endian.little);
    var o = 16;
    final out = <List<ImpactWindowSample>>[];
    for (var i = 0; i < 3; i++) {
      final scale = i == 2 ? gyroScale : accelScale;
      if (o + 2 > data.length) throw const FormatException('truncated');
      final n = b.getUint16(o, Endian.little);
      o += 2;
      if (o + n * 8 > data.length) throw const FormatException('truncated');
      out.add([
        for (var k = 0; k < n; k++)
          ImpactWindowSample(
            b.getInt16(o + k * 8, Endian.little),
            b.getInt16(o + k * 8 + 2, Endian.little) / scale,
            b.getInt16(o + k * 8 + 4, Endian.little) / scale,
            b.getInt16(o + k * 8 + 6, Endian.little) / scale,
          ),
      ]);
      o += n * 8;
    }
    return ImpactWindow(
      spikeAt: DateTime.fromMillisecondsSinceEpoch(spikeMs, isUtc: true),
      raw: out[0],
      user: out[1],
      gyro: out[2],
    );
  }

  void reset() {
    _raw.clear();
    _user.clear();
    _gyro.clear();
  }

  static int _i16(num v) => v.round().clamp(-32768, 32767);
}

class _Sample {
  const _Sample(this.us, this.x, this.y, this.z);
  final int us;
  final double x, y, z;
}

/// A decoded [ImpactWindowRecorder.encodeWindow] blob.
class ImpactWindow {
  const ImpactWindow({
    required this.spikeAt,
    required this.raw,
    required this.user,
    required this.gyro,
  });

  final DateTime spikeAt;
  final List<ImpactWindowSample> raw;
  final List<ImpactWindowSample> user;
  final List<ImpactWindowSample> gyro;
}

class ImpactWindowSample {
  const ImpactWindowSample(this.offsetMs, this.x, this.y, this.z);

  /// Milliseconds from the impact (negative = before it).
  final int offsetMs;
  final double x, y, z;
}
