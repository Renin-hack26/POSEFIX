package com.fixpose.fixpose

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/// Host side of the `fixpose/pose_landmarker` channel (Batch 5).
///
/// Runs the bundled `pose_landmarker_heavy.task` (BlazePose heavy, VIDEO
/// mode) on camera frames and returns the 33 landmarks + world landmarks +
/// a letterboxed 256x256 RGB thumbnail for the MoveNet second opinion.
///
/// Frame flow is one-in-flight: `detect` replies `{dropped: true}`
/// immediately while an inference is running — the Dart side simply sends
/// the next frame. Thumbnail math mirrors the reference `_prepare`
/// (aspect-preserving + symmetric pad), and its pad parameters ride along
/// so Dart can map MoveNet outputs back into frame coordinates.
///
/// **Threading:** the heavy path (YUV→RGB conversion, rotation, MediaPipe
/// inference, thumbnail) runs on a dedicated background executor — it used
/// to run synchronously on the Android main thread, which froze the camera
/// preview and the whole UI for the duration of every inference (the
/// "laggy camera"). The result is posted back to the main thread, which is
/// where MethodChannel.Result must be invoked.
///
/// **Resolution:** frames are converted at half resolution (`SCALE`). The
/// model consumes 256×256 internally, so a 360×640 input loses no pose
/// accuracy while cutting conversion, bitmap churn and resize cost ~4×.
///
/// Never throws across the channel: every failure is a result map with
/// `ok: false`, so the Dart side can fall back to ML Kit and the camera
/// never dies because of this bridge.
class PoseLandmarkerBridge(
    messenger: BinaryMessenger,
    private val appContext: Context,
) {
    private val channel = MethodChannel(messenger, "fixpose/pose_landmarker")
    private var landmarker: PoseLandmarker? = null
    private val busy = AtomicBoolean(false)
    private var modelPath: String? = null

    /// Background worker: conversions + inference never touch the UI
    /// thread. Single-threaded, so detections are naturally serialised.
    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "pose-landmarker").apply {
            priority = Thread.NORM_PRIORITY - 1
        }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    /// Guards `landmarker` between the worker and `close()` (both can now
    /// run on different threads).
    private val lock = Any()

    companion object {
        const val MODEL_ASSET = "flutter_assets/assets/models/pose_landmarker_heavy.task"
        const val THUMB_SIZE = 256

        /// Luma/chroma subsample factor for the YUV→RGB conversion.
        /// Camera frames arrive 720p (1280×720 = 921k px); at SCALE 2 the
        /// conversion touches 230k px — well above the model's 256×256
        /// input, so accuracy is unchanged while per-frame cost drops
        /// sharply (less CPU, far fewer GC pauses from bitmap churn).
        const val SCALE = 2
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Model copy + MediaPipe creation are heavy too — off the
                // main thread as well (Dart awaits `init` before use).
                "init" -> {
                    executor.execute {
                        val out = init()
                        mainHandler.post { result.success(out) }
                    }
                }
                "detect" -> detect(call, result)
                "close" -> {
                    executor.execute {
                        close()
                        mainHandler.post { result.success(mapOf("ok" to true)) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun modelFile(): File {
        val out = File(appContext.filesDir, "pose_landmarker_heavy.task")
        val existing = modelPath?.let { File(it) }
        if (existing != null && existing.exists()) return existing
        if (out.exists()) {
            modelPath = out.absolutePath
            return out
        }
        // Flutter app assets live under flutter_assets/ in the APK.
        appContext.assets.open(MODEL_ASSET).use { input ->
            out.outputStream().use { output -> input.copyTo(output) }
        }
        modelPath = out.absolutePath
        return out
    }

    private fun init(): Map<String, Any?> {
        synchronized(lock) {
            if (landmarker != null) return mapOf("ok" to true)
            return try {
                val file = modelFile()
                val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(
                        BaseOptions.builder().setModelAssetPath(file.absolutePath).build(),
                    )
                    .setRunningMode(RunningMode.VIDEO)
                    .setNumPoses(1)
                    .setMinPoseDetectionConfidence(0.5f)
                    .setMinPosePresenceConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .build()
                landmarker = PoseLandmarker.createFromOptions(appContext, options)
                mapOf("ok" to true)
            } catch (e: Exception) {
                mapOf("ok" to false, "error" to (e.message ?: "init failed"))
            }
        }
    }

    /// Handles one `detect` call. Replies synchronously for the fast
    /// paths (not initialised / already busy) and hops to the background
    /// executor for the heavy path, posting the result back to the main
    /// thread when done. `busy` stays claimed until the background work
    /// finishes, so while a frame is being processed further frames get
    /// the immediate `{dropped: true}` reply — same one-in-flight contract
    /// as before, but the UI thread is free throughout.
    private fun detect(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        if (landmarker == null) {
            result.success(mapOf("ok" to false, "error" to "not initialised"))
            return
        }
        if (!busy.compareAndSet(false, true)) {
            result.success(mapOf("ok" to true, "dropped" to true))
            return
        }
        executor.execute {
            val out = try {
                runDetect(call)
            } catch (e: Exception) {
                mapOf("ok" to false, "error" to (e.message ?: "detect failed"))
            } finally {
                busy.set(false)
            }
            mainHandler.post { result.success(out) }
        }
    }

    /// The heavy path — runs on [executor], never the main thread.
    /// Conversion at SCALE, rotation, inference, thumbnail, packing.
    @Suppress("UNCHECKED_CAST")
    private fun runDetect(call: io.flutter.plugin.common.MethodCall): Map<String, Any?> {
        val t0 = System.nanoTime()
        synchronized(lock) {
            val lm = landmarker ?: return mapOf("ok" to false, "error" to "not initialised")
            val y = call.argument<ByteArray>("y") ?: return err("missing y")
            val u = call.argument<ByteArray>("u") ?: return err("missing u")
            val v = call.argument<ByteArray>("v") ?: return err("missing v")
            // "nv21" = single-plane buffer (Y + interleaved VU) as delivered
            // by the app's camera controller; "yuv420" = 3 separate planes.
            val format = call.argument<String>("format") ?: "yuv420"
            val width = call.argument<Int>("width") ?: return err("missing width")
            val height = call.argument<Int>("height") ?: return err("missing height")
            val yRowStride = call.argument<Int>("yRowStride") ?: width
            val uvRowStride = call.argument<Int>("uvRowStride") ?: (width / 2)
            val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
            val rotation = call.argument<Int>("rotation") ?: 0
            val timestampMs = call.argument<Long>("timestampMs")
                ?: System.currentTimeMillis()

            val argb = if (format == "nv21") {
                nv21ToArgb(y, width, height, yRowStride, uvRowStride)
            } else {
                yuv420ToArgb(y, u, v, width, height, yRowStride, uvRowStride, uvPixelStride)
            }
            var bitmap = Bitmap.createBitmap(argb, width / SCALE, height / SCALE, Bitmap.Config.ARGB_8888)
            // Pre-rotate to upright: landmarks, thumbnail and frame dims all
            // refer to this upright space (MPImage itself gets rotation 0).
            // `rotation` is sensor-degrees, same convention as the ML Kit path.
            // Cheap now: the bitmap is already downsampled.
            if (rotation != 0) {
                val matrix = android.graphics.Matrix()
                matrix.postRotate(rotation.toFloat())
                val rotated = Bitmap.createBitmap(
                    bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                bitmap.recycle()
                bitmap = rotated
            }

            val mpImage: MPImage = BitmapImageBuilder(bitmap).build()
            val imgOptions = ImageProcessingOptions.builder()
                .setRotationDegrees(0)
                .build()
            val res: PoseLandmarkerResult =
                lm.detectForVideo(mpImage, imgOptions, timestampMs)

            val image = res.landmarks().firstOrNull()
            if (image == null || image.size < 33) {
                bitmap.recycle()
                return mapOf("ok" to true, "found" to false)
            }
            val world = res.worldLandmarks().firstOrNull()

            // Letterboxed thumbnail for MoveNet (aspect-preserving + pad).
            val scale = minOf(
                THUMB_SIZE.toFloat() / bitmap.width,
                THUMB_SIZE.toFloat() / bitmap.height,
            )
            val sw = (bitmap.width * scale).toInt().coerceAtLeast(1)
            val sh = (bitmap.height * scale).toInt().coerceAtLeast(1)
            val padLeft = ((THUMB_SIZE - sw) / 2.0)
            val padTop = ((THUMB_SIZE - sh) / 2.0)
            val thumb = Bitmap.createBitmap(THUMB_SIZE, THUMB_SIZE, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(thumb)
            canvas.drawColor(Color.BLACK)
            val small = Bitmap.createScaledBitmap(bitmap, sw, sh, true)
            canvas.drawBitmap(small, padLeft.toFloat(), padTop.toFloat(), Paint())
            small.recycle()
            val px = IntArray(THUMB_SIZE * THUMB_SIZE)
            thumb.getPixels(px, 0, THUMB_SIZE, 0, 0, THUMB_SIZE, THUMB_SIZE)
            thumb.recycle()
            bitmap.recycle()
            val rgb = ByteArray(THUMB_SIZE * THUMB_SIZE * 3)
            for (i in px.indices) {
                val c = px[i]
                rgb[i * 3] = ((c shr 16) and 0xFF).toByte()
                rgb[i * 3 + 1] = ((c shr 8) and 0xFF).toByte()
                rgb[i * 3 + 2] = (c and 0xFF).toByte()
            }

            val imageLm = image.map { l ->
                listOf(l.x(), l.y(), l.z(), l.visibility().orElse(0f), l.presence().orElse(0f))
            }
            val worldLm = world?.map { l -> listOf(l.x(), l.y(), l.z()) }
            val ms = (System.nanoTime() - t0) / 1_000_000.0
            return mapOf(
                "ok" to true,
                "found" to true,
                "image" to imageLm,
                "world" to worldLm,
                "thumb" to rgb,
                "frameW" to bitmap.width,
                "frameH" to bitmap.height,
                "srcW" to bitmap.width,
                "srcH" to bitmap.height,
                "size" to THUMB_SIZE,
                "padLeft" to padLeft,
                "padTop" to padTop,
                "scaledW" to sw.toDouble(),
                "scaledH" to sh.toDouble(),
                "inferenceMs" to ms,
            )
        }
    }

    private fun err(msg: String): Map<String, Any?> =
        mapOf("ok" to false, "error" to msg)

    /// Single-plane NV21 (Y + interleaved VU) → ARGB at [SCALE]
    /// subsampling. This is what the app's camera controller delivers;
    /// the chroma plane starts right after `yRowStride * height` bytes,
    /// V before U in each pair.
    ///
    /// Fixed-point math (coefficients ×1024) instead of Double — the old
    /// per-pixel `Double` conversions were the slowest part of the path.
    /// Output is `width/SCALE × height/SCALE`; luma samples (2i, 2j),
    /// chroma from the co-located 2×2 block.
    private fun nv21ToArgb(
        yuv: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
    ): IntArray {
        val outW = width / SCALE
        val outH = height / SCALE
        val out = IntArray(outW * outH)
        val ySize = yRowStride * height
        var o = 0
        for (j in 0 until outH) {
            val yRow = (j * SCALE) * yRowStride
            // Source row j*SCALE → chroma row (j*SCALE)/2.
            val uvRow = ySize + (((j * SCALE) shr 1) * uvRowStride)
            for (i in 0 until outW) {
                val yv = yuv[yRow + i * SCALE].toInt() and 0xFF
                val vu = uvRow + i * 2
                val vv = ((yuv[vu].toInt() and 0xFF) - 128)
                val uv = ((yuv[vu + 1].toInt() and 0xFF) - 128)
                var r = yv + (vv * 1436 shr 10)
                var g = yv - (uv * 352 shr 10) - (vv * 731 shr 10)
                var b = yv + (uv * 1815 shr 10)
                r = r.coerceIn(0, 255)
                g = g.coerceIn(0, 255)
                b = b.coerceIn(0, 255)
                out[o++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return out
    }

    private fun yuv420ToArgb(
        y: ByteArray, u: ByteArray, v: ByteArray,
        width: Int, height: Int,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
    ): IntArray {
        val outW = width / SCALE
        val outH = height / SCALE
        val out = IntArray(outW * outH)
        var o = 0
        for (j in 0 until outH) {
            val yRow = (j * SCALE) * yRowStride
            val uvRow = (j * SCALE shr 1) * uvRowStride
            for (i in 0 until outW) {
                val yv = y[yRow + i * SCALE].toInt() and 0xFF
                val uvOffset = uvRow + ((i * SCALE) shr 1) * uvPixelStride
                val uv = (u[uvOffset].toInt() and 0xFF) - 128
                val vv = (v[uvOffset].toInt() and 0xFF) - 128
                var r = yv + (vv * 1436 shr 10)
                var g = yv - (uv * 352 shr 10) - (vv * 731 shr 10)
                var b = yv + (uv * 1815 shr 10)
                r = r.coerceIn(0, 255)
                g = g.coerceIn(0, 255)
                b = b.coerceIn(0, 255)
                out[o++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return out
    }

    fun close() {
        synchronized(lock) {
            try {
                landmarker?.close()
            } catch (_: Exception) {
            }
            landmarker = null
        }
    }
}
