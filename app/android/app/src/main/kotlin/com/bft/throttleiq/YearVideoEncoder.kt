package com.bft.throttleiq

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Writes the Year in Review video for `year_video_encoder.dart`: RGBA frames
 * in, H.264 out (MediaCodec), muxed with the music segments (AAC, copied
 * as-is) into one MP4.
 *
 * Channel `throttleiq/year_video`: `start`, `addFrame`, `finish`, `cancel`.
 * All work runs on one background thread, in call order.
 */
class YearVideoEncoder {
    private companion object {
        const val FRAME_US = 1_000_000L / 30
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val info = MediaCodec.BufferInfo()

    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var muxing = false
    private var videoTrack = -1
    private var audioTrack = -1
    private var audioFormat: MediaFormat? = null
    private var audio: List<Map<*, *>> = emptyList()
    private var path: String? = null
    private var width = 0
    private var height = 0
    private var ptsUs = 0L

    // The frame being written, as I420, kept for its repeats.
    private var yPlane = ByteArray(0)
    private var uPlane = ByteArray(0)
    private var vPlane = ByteArray(0)

    // Most encoders take semi-planar chroma (U and V interleaved in one
    // buffer). Detected on the first frame; the frame's interleaved rows are
    // then built once and bulk-copied for every repeat.
    private var chroma = Chroma.UNKNOWN
    private var interleaved = ByteArray(0)
    private var interleavedFresh = false

    private enum class Chroma { UNKNOWN, OTHER, NV12, NV21 }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        worker.execute {
            try {
                when (call.method) {
                    "start" -> start(call)
                    "addFrame" -> addFrame(call)
                    "finish" -> finish()
                    "cancel" -> cleanUp(deleteOutput = true)
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(null) }
            } catch (e: Exception) {
                cleanUp(deleteOutput = true)
                main.post { result.error("video", e.toString(), null) }
            }
        }
    }

    private fun start(call: MethodCall) {
        cleanUp(deleteOutput = false)
        val out = call.argument<String>("path") ?: error("no path")
        width = call.argument<Int>("width") ?: error("no width")
        height = call.argument<Int>("height") ?: error("no height")
        audio = call.argument<List<Map<*, *>>>("audio").orEmpty()
        path = out
        File(out).delete()

        audioFormat = (audio.firstOrNull()?.get("path") as? String)?.let { p ->
            val ex = MediaExtractor()
            try {
                ex.setDataSource(p)
                ex.getTrackFormat(0)
            } finally {
                ex.release()
            }
        }

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, 6_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Tag what toI420 writes, so players don't guess.
                setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
                setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
                setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
            }
        }
        codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).also {
            it.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            it.start()
        }
        muxer = MediaMuxer(out, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        yPlane = ByteArray(width * height)
        uPlane = ByteArray(width * height / 4)
        vPlane = ByteArray(width * height / 4)
        ptsUs = 0
        chroma = Chroma.UNKNOWN
        interleaved = ByteArray(width * height / 2)
    }

    private fun addFrame(call: MethodCall) {
        val rgba = call.argument<ByteArray>("rgba") ?: error("no frame")
        val durationUs = (call.argument<Int>("durationMs") ?: error("no duration")) * 1000L
        require(rgba.size == width * height * 4) { "frame is ${rgba.size} bytes, not ${width}x$height RGBA" }
        toI420(rgba)
        // A held frame is re-sent every frame: a constant 30 fps, which
        // Reels, Shorts and Status all take without complaint.
        var offset = 0L
        while (offset < durationUs) {
            queueFrame(ptsUs + offset)
            drain(endOfStream = false)
            offset += FRAME_US
        }
        ptsUs += durationUs
    }

    /** BT.709 limited range, chroma from each 2x2 block's top-left pixel. */
    private fun toI420(rgba: ByteArray) {
        interleavedFresh = false
        val w = width
        for (row in 0 until height) {
            var i = row * w * 4
            var y = row * w
            for (col in 0 until w) {
                val r = rgba[i].toInt() and 0xFF
                val g = rgba[i + 1].toInt() and 0xFF
                val b = rgba[i + 2].toInt() and 0xFF
                yPlane[y++] = (((47 * r + 157 * g + 16 * b + 128) shr 8) + 16).toByte()
                if (row and 1 == 0 && col and 1 == 0) {
                    val c = (row / 2) * (w / 2) + col / 2
                    uPlane[c] = (((-26 * r - 87 * g + 112 * b + 128) shr 8) + 128).toByte()
                    vPlane[c] = (((112 * r - 102 * g - 10 * b + 128) shr 8) + 128).toByte()
                }
                i += 4
            }
        }
    }

    private fun queueFrame(pts: Long) {
        val c = codec ?: error("addFrame before start")
        var index: Int
        var waits = 0
        while (true) {
            index = c.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(endOfStream = false)
            if (++waits > 1000) error("encoder stalled")
        }
        val image = c.getInputImage(index) ?: error("no input image")
        if (chroma == Chroma.UNKNOWN) chroma = detectChroma(image)
        copyPlane(yPlane, width, height, image.planes[0])
        when (chroma) {
            Chroma.NV12 -> copyInterleaved(uPlane, vPlane, image.planes[1])
            Chroma.NV21 -> copyInterleaved(vPlane, uPlane, image.planes[2])
            else -> {
                copyPlane(uPlane, width / 2, height / 2, image.planes[1])
                copyPlane(vPlane, width / 2, height / 2, image.planes[2])
            }
        }
        c.queueInputBuffer(index, 0, width * height * 3 / 2, pts, 0)
    }

    /** Whether U and V share one buffer, V right after U (NV12) or before (NV21). */
    private fun detectChroma(image: Image): Chroma {
        val u = image.planes[1]
        val v = image.planes[2]
        if (u.pixelStride != 2 || v.pixelStride != 2 || u.rowStride != v.rowStride) return Chroma.OTHER
        val ub = u.buffer
        val vb = v.buffer
        val probe = (vb.get(0) + 1).toByte()
        ub.put(1, probe)
        if (vb.get(0) == probe) return Chroma.NV12
        val probe2 = (ub.get(0) + 1).toByte()
        vb.put(1, probe2)
        if (ub.get(0) == probe2) return Chroma.NV21
        return Chroma.OTHER
    }

    /** Writes [first]/[second] alternately into [plane], whose buffer holds both. */
    private fun copyInterleaved(first: ByteArray, second: ByteArray, plane: Image.Plane) {
        val cw = width / 2
        val rows = height / 2
        if (!interleavedFresh) {
            for (i in 0 until cw * rows) {
                interleaved[2 * i] = first[i]
                interleaved[2 * i + 1] = second[i]
            }
            interleavedFresh = true
        }
        val buf = plane.buffer
        val rowStride = plane.rowStride
        for (row in 0 until rows) {
            val at = row * rowStride
            buf.position(at)
            // The buffer can end one byte short: its last pixel's partner.
            buf.put(interleaved, row * 2 * cw, minOf(2 * cw, buf.limit() - at))
        }
    }

    private fun copyPlane(src: ByteArray, w: Int, h: Int, plane: Image.Plane) {
        val buf: ByteBuffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        for (row in 0 until h) {
            val base = row * rowStride
            if (pixelStride == 1) {
                buf.position(base)
                buf.put(src, row * w, w)
            } else {
                for (col in 0 until w) buf.put(base + col * pixelStride, src[row * w + col])
            }
        }
    }

    /** Moves encoded output to the muxer; at the end, until end of stream. */
    private fun drain(endOfStream: Boolean) {
        val c = codec ?: return
        val m = muxer ?: return
        var idle = 0
        while (true) {
            val index = c.dequeueOutputBuffer(info, if (endOfStream) 10_000 else 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    if (++idle > 500) error("encoder never finished")
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    videoTrack = m.addTrack(c.outputFormat)
                    audioTrack = audioFormat?.let { m.addTrack(it) } ?: -1
                    m.start()
                    muxing = true
                }
                index >= 0 -> {
                    val buf = c.getOutputBuffer(index) ?: error("no output buffer")
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0 && muxing) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        m.writeSampleData(videoTrack, buf, info)
                    }
                    c.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    private fun finish() {
        val c = codec ?: error("finish before start")
        val m = muxer ?: error("finish before start")
        // The last frame again at the very end, so it lasts until then.
        queueFrame(ptsUs)
        var index: Int
        var waits = 0
        while (true) {
            index = c.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(endOfStream = false)
            if (++waits > 1000) error("encoder stalled")
        }
        c.queueInputBuffer(index, 0, 0, ptsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(endOfStream = true)
        if (!muxing) error("encoder produced nothing")

        if (audioTrack >= 0) {
            val buf = ByteBuffer.allocate(256 * 1024)
            var cursorUs = 0L
            for (segment in audio) {
                val p = segment["path"] as? String ?: continue
                val startUs = ((segment["startMs"] as? Number)?.toLong() ?: 0L) * 1000
                val lengthUs = ((segment["durationMs"] as? Number)?.toLong() ?: 0L) * 1000
                val ex = MediaExtractor()
                try {
                    ex.setDataSource(p)
                    ex.selectTrack(0)
                    ex.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    while (true) {
                        val size = ex.readSampleData(buf, 0)
                        if (size < 0) break
                        val t = ex.sampleTime
                        if (t >= startUs + lengthUs) break
                        val pts = cursorUs + (t - startUs)
                        if (pts > ptsUs) break // past the video's end
                        if (t >= startUs) {
                            info.set(0, size, pts,
                                if (ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                            m.writeSampleData(audioTrack, buf, info)
                        }
                        ex.advance()
                    }
                } finally {
                    ex.release()
                }
                cursorUs += lengthUs
            }
        }
        m.stop()
        muxing = false
        cleanUp(deleteOutput = false)
    }

    /** Releases everything; with [deleteOutput], removes the file too. */
    private fun cleanUp(deleteOutput: Boolean) {
        try { codec?.stop() } catch (_: Exception) {}
        try { codec?.release() } catch (_: Exception) {}
        codec = null
        if (muxing) try { muxer?.stop() } catch (_: Exception) {}
        try { muxer?.release() } catch (_: Exception) {}
        muxer = null
        muxing = false
        if (deleteOutput) path?.let { File(it).delete() }
    }
}
