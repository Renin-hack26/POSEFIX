package com.fixpose.fixpose

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Host side of the `fixpose/sfx` channel (PLANNING §4.3).
///
/// Workout SFX are short synthesized WAVs written to the app cache dir by
/// Dart at startup. SoundPool (not MediaPlayer/ExoPlayer) plays them with
/// ~20-50 ms latency — required for rep-count feedback that must land
/// inside 0.5 s of detection. No third-party audio plugin, no extra
/// native dependency, R8-safe (framework APIs only).
class MainActivity : FlutterActivity() {
    private val channelName = "fixpose/sfx"
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private var poseBridge: PoseLandmarkerBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Batch 5 pose stack: MediaPipe PoseLandmarker (heavy) bridge.
        poseBridge = PoseLandmarkerBridge(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(attrs)
            .build()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        val path = call.argument<String>("path")
                        val volume =
                            (call.argument<Double>("volume") ?: 1.0).toFloat()
                        if (path == null) {
                            result.error("ARG", "missing path", null)
                            return@setMethodCallHandler
                        }
                        playSound(path, volume.coerceIn(0f, 1f))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playSound(path: String, volume: Float) {
        val pool = soundPool ?: return
        val existing = soundIds[path]
        if (existing != null) {
            pool.play(existing, volume, volume, 1, 0, 1.0f)
            return
        }
        // First play: load, then fire on completion. Later plays are instant.
        val id = pool.load(path, 1)
        soundIds[path] = id
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) {
                pool.play(sampleId, volume, volume, 1, 0, 1.0f)
            }
        }
    }

    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        poseBridge?.close()
        poseBridge = null
        super.onDestroy()
    }
}
