package com.fixpose.fixpose

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
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

    companion object {
        const val MODEL_ASSET = "flutter_assets/assets/models/pose_landmarker_heavy.task"
        const val THUMB_SIZE = 256
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> result.success(init())
                "detect" -> result.success(detect(call))
                "close" -> {
                    close()
                    result.success(mapOf("ok" to true))
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

    @Suppress("UNCHECKED_CAST")
    private fun detect(call: io.flutter.plugin.common.MethodCall): Map<String, Any?> {
        val lm = landmarker ?: return mapOf("ok" to false, "error" to "not initialised")
        if (!busy.compareAndSet(false, true)) {
            return mapOf("ok" to true, "dropped" to true)
        }
        val t0 = System.nanoTime()
        try {
            val y = call.argument<ByteArray>("y") ?: return err("missing y")
            val u = call.argument<ByteArray>("u") ?: return err("missing u")
            val v = call.argument<ByteArray>("v") ?: return err("missing v")
            val width = call.argument<Int>("width") ?: return err("missing width")
            val height = call.argument<Int>("height") ?: return err("missing height")
            val yRowStride = call.argument<Int>("yRowStride") ?: width
            val uvRowStride = call.argument<Int>("uvRowStride") ?: (width / 2)
            val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
            val rotation = call.argument<Int>("rotation") ?: 0
            val timestampMs = call.argument<Long>("timestampMs")
                ?: System.currentTimeMillis()

            val argb = yuv420ToArgb(y, u, v, width, height, yRowStride, uvRowStride, uvPixelStride)
            var bitmap = Bitmap.createBitmap(argb, width, height, Bitmap.Config.ARGB_8888)
            // Pre-rotate to upright: landmarks, thumbnail and frame dims all
            // refer to this upright space (MPImage itself gets rotation 0).
            // `rotation` is sensor-degrees, same convention as the ML Kit path.
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
        } catch (e: Exception) {
            return mapOf("ok" to false, "error" to (e.message ?: "detect failed"))
        } finally {
            busy.set(false)
        }
    }

    private fun err(msg: String): Map<String, Any?> =
        mapOf("ok" to false, "error" to msg)

    private fun yuv420ToArgb(
        y: ByteArray, u: ByteArray, v: ByteArray,
        width: Int, height: Int,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
    ): IntArray {
        val out = IntArray(width * height)
        var o = 0
        for (j in 0 until height) {
            val yRow = j * yRowStride
            val uvRow = (j shr 1) * uvRowStride
            for (i in 0 until width) {
                val yv = (y[yRow + i].toInt() and 0xFF)
                val uvOffset = uvRow + ((i shr 1) * uvPixelStride)
                val uv = (u[uvOffset].toInt() and 0xFF) - 128
                val vv = (v[uvOffset].toInt() and 0xFF) - 128
                var r = (yv + 1.402 * vv).toInt()
                var g = (yv - 0.344136 * uv - 0.714136 * vv).toInt()
                var b = (yv + 1.772 * uv).toInt()
                r = r.coerceIn(0, 255)
                g = g.coerceIn(0, 255)
                b = b.coerceIn(0, 255)
                out[o++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return out
    }

    fun close() {
        try {
            landmarker?.close()
        } catch (_: Exception) {
        }
        landmarker = null
    }
}
