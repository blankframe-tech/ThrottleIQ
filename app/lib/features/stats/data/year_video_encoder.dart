import 'package:flutter/services.dart';

/// The native MP4 writer behind the Year in Review video: AVAssetWriter on
/// iOS (`ios/Runner/YearVideoEncoder.swift`), MediaCodec on Android
/// (`YearVideoEncoder.kt`). Frames go in one at a time, so only one is ever
/// held in memory. A failed call throws [PlatformException] and leaves no
/// file behind.
class YearVideoEncoder {
  const YearVideoEncoder();

  static const _channel = MethodChannel('throttleiq/year_video');

  /// [audio]: segments `{path, startMs, durationMs}` played back to back.
  Future<void> start({
    required String path,
    required int width,
    required int height,
    required List<Map<String, Object>> audio,
  }) =>
      _channel.invokeMethod('start', {
        'path': path,
        'width': width,
        'height': height,
        'audio': audio,
      });

  /// One frame of straight RGBA (`width * height * 4` bytes), shown for
  /// [duration].
  Future<void> addFrame(Uint8List rgba, Duration duration) =>
      _channel.invokeMethod('addFrame', {
        'rgba': rgba,
        'durationMs': duration.inMilliseconds,
      });

  /// Closes the video and lays the music under it; the file is then ready.
  Future<void> finish() => _channel.invokeMethod('finish');

  /// Drops a video being made, and its file.
  Future<void> cancel() => _channel.invokeMethod('cancel');
}
