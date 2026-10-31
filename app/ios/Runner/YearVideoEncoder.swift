import AVFoundation
import Accelerate
import Flutter

/// Writes the Year in Review video for `year_video_encoder.dart`: RGBA frames
/// in, H.264 out (AVAssetWriter), then the music segments laid under it and
/// the whole thing exported as one MP4 without re-encoding.
///
/// Channel `throttleiq/year_video`: `start`, `addFrame`, `finish`, `cancel`.
/// All work runs on one serial queue, in call order.
final class YearVideoEncoder {
  private let queue = DispatchQueue(label: "throttleiq.year_video")
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var videoURL: URL?
  private var outURL: URL?
  private var audio: [[String: Any]] = []
  private var width = 0
  private var height = 0
  private var time = CMTime.zero

  /// A held frame is re-sent every frame: a constant 30 fps, which Reels,
  /// Shorts and Status all take without complaint.
  private let repeatEvery = CMTime(value: 1, timescale: 30)

  static func register(messenger: FlutterBinaryMessenger) {
    let encoder = YearVideoEncoder()
    FlutterMethodChannel(name: "throttleiq/year_video", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in encoder.handle(call, result) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      do {
        switch call.method {
        case "start": try self.start(args)
        case "addFrame": try self.addFrame(args)
        case "finish": try self.finish()
        case "cancel": self.cleanUp(deleteOutput: true)
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(nil) }
      } catch {
        self.cleanUp(deleteOutput: true)
        DispatchQueue.main.async {
          result(FlutterError(code: "video", message: "\(error)", details: nil))
        }
      }
    }
  }

  private struct Failure: Error, CustomStringConvertible {
    let description: String
  }

  private func start(_ args: [String: Any]) throws {
    cleanUp(deleteOutput: false)
    guard let path = args["path"] as? String,
      let w = args["width"] as? Int, let h = args["height"] as? Int
    else { throw Failure(description: "bad start arguments") }
    width = w
    height = h
    audio = args["audio"] as? [[String: Any]] ?? []
    outURL = URL(fileURLWithPath: path)
    let tmp = URL(fileURLWithPath: path + ".video.mp4")
    try? FileManager.default.removeItem(at: tmp)
    videoURL = tmp

    let writer = try AVAssetWriter(outputURL: tmp, fileType: .mp4)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: w,
        AVVideoHeightKey: h,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: 6_000_000,
          AVVideoMaxKeyFrameIntervalKey: 30,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
      ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: w,
        kCVPixelBufferHeightKey as String: h,
      ])
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? Failure(description: "startWriting failed")
    }
    writer.startSession(atSourceTime: .zero)
    self.writer = writer
    self.input = input
    self.adaptor = adaptor
    time = .zero
  }

  private func addFrame(_ args: [String: Any]) throws {
    guard let adaptor = adaptor, let input = input, let writer = writer,
      let data = (args["rgba"] as? FlutterStandardTypedData)?.data,
      let ms = args["durationMs"] as? Int
    else { throw Failure(description: "addFrame before start") }
    guard data.count == width * height * 4 else {
      throw Failure(description: "frame is \(data.count) bytes, not \(width)x\(height) RGBA")
    }
    guard let pool = adaptor.pixelBufferPool else {
      throw writer.error ?? Failure(description: "no pixel buffer pool")
    }
    var made: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made)
    guard let buffer = made else { throw Failure(description: "no pixel buffer") }

    CVPixelBufferLockBaseAddress(buffer, [])
    data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      var src = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: raw.baseAddress!),
        height: vImagePixelCount(height), width: vImagePixelCount(width),
        rowBytes: width * 4)
      var dst = vImage_Buffer(
        data: CVPixelBufferGetBaseAddress(buffer),
        height: vImagePixelCount(height), width: vImagePixelCount(width),
        rowBytes: CVPixelBufferGetBytesPerRow(buffer))
      let rgbaToBgra: [UInt8] = [2, 1, 0, 3]
      vImagePermuteChannels_ARGB8888(&src, &dst, rgbaToBgra, vImage_Flags(kvImageNoFlags))
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])

    let duration = CMTime(value: CMTimeValue(ms), timescale: 1000)
    var offset = CMTime.zero
    while offset < duration {
      while !input.isReadyForMoreMediaData {
        if writer.status == .failed {
          throw writer.error ?? Failure(description: "writer failed")
        }
        usleep(2000)
      }
      guard adaptor.append(buffer, withPresentationTime: time + offset) else {
        throw writer.error ?? Failure(description: "append failed")
      }
      offset = offset + repeatEvery
    }
    time = time + duration
  }

  private func finish() throws {
    guard let writer = writer, let input = input, let videoURL = videoURL,
      let outURL = outURL
    else { throw Failure(description: "finish before start") }
    input.markAsFinished()
    // Ending the session at `time` makes the last frame last until the end.
    writer.endSession(atSourceTime: time)
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    guard writer.status == .completed else {
      throw writer.error ?? Failure(description: "finishWriting failed")
    }

    let video = AVURLAsset(url: videoURL)
    let composition = AVMutableComposition()
    guard let source = video.tracks(withMediaType: .video).first,
      let track = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw Failure(description: "no video track") }
    let end = time
    try track.insertTimeRange(CMTimeRange(start: .zero, duration: end), of: source, at: .zero)

    if !audio.isEmpty,
      let music = composition.addMutableTrack(
        withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    {
      var cursor = CMTime.zero
      for segment in audio {
        guard let path = segment["path"] as? String,
          let startMs = segment["startMs"] as? Int,
          let lengthMs = segment["durationMs"] as? Int
        else { continue }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let src = asset.tracks(withMediaType: .audio).first else { continue }
        let start = CMTime(value: CMTimeValue(startMs), timescale: 1000)
        let length = CMTimeMinimum(
          CMTime(value: CMTimeValue(lengthMs), timescale: 1000), asset.duration - start)
        try music.insertTimeRange(
          CMTimeRange(start: start, duration: length), of: src, at: cursor)
        cursor = cursor + length
      }
      if cursor > end {
        music.removeTimeRange(CMTimeRange(start: end, end: cursor))
      }
    }

    try? FileManager.default.removeItem(at: outURL)
    guard
      let export = AVAssetExportSession(
        asset: composition, presetName: AVAssetExportPresetPassthrough)
    else { throw Failure(description: "no export session") }
    export.outputURL = outURL
    export.outputFileType = .mp4
    export.shouldOptimizeForNetworkUse = true
    let exported = DispatchSemaphore(value: 0)
    export.exportAsynchronously { exported.signal() }
    exported.wait()
    guard export.status == .completed else {
      throw export.error ?? Failure(description: "export failed")
    }
    cleanUp(deleteOutput: false)
  }

  /// Drops the writer and the intermediate file; with [deleteOutput], the
  /// finished file too (a cancel or a failure leaves nothing half-made).
  private func cleanUp(deleteOutput: Bool) {
    if writer?.status == .writing { writer?.cancelWriting() }
    writer = nil
    input = nil
    adaptor = nil
    if let url = videoURL { try? FileManager.default.removeItem(at: url) }
    videoURL = nil
    if deleteOutput, let url = outURL { try? FileManager.default.removeItem(at: url) }
  }
}
