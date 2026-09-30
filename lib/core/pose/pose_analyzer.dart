/// FixPose Pose Analyzer — ML Kit pose detection → BrainEngine pipeline.
///
/// Responsibilities (PLANNING §4.1 vision pipeline):
/// - Throttled streaming inference (default ≥80 ms between starts, frames
///   dropped while busy — keeps end-to-end latency low on mid-range phones).
/// - Per-landmark EMA smoothing + confidence gating tuned for bad cameras
///   (low light / low resolution): a landmark below
///   [FormRules.minLandmarkConfidence] is invisible, and frames missing the
///   exercise's minimum visible set never reach the FSM.
/// - Person-lock: counting pauses on no-person, on a second person entering
///   the frame, and on subject discontinuity (torso centroid jump). A short
///   re-lock (2 stable frames) resumes counting — no phantom reps.
/// - Per-exercise framing zones: required landmarks clipped by a frame edge
///   (or a tiny subject, or a front view on push-ups which need a wide
///   side-on view) produce a spoken camera-adjustment cue.
///
/// Accuracy/speed are internal engineering targets — nothing here renders
/// latency or confidence numbers into UI copy.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../constants/form_rules.dart';
import 'brain_engine.dart';
import 'exercise_definition.dart';
import 'pose_math.dart' as pm;

/// Why rep counting is currently paused.
enum LockReason {
  /// Locked onto one subject, counting live.
  ok,

  /// Nobody in frame.
  noPerson,

  /// A second person entered the frame — paused until it's just you again.
  multiPerson,

  /// Subject changed abruptly (someone else stepped in).
  lostTracking,

  /// Subject present but too few required landmarks visible.
  occluded,

  /// Rep rhythm is machine-perfect — a played exercise video, not the user.
  /// Counting pauses until human jitter returns.
  videoPlayback,
}

/// Camera-adjustment cue (spoken aloud by the session controller).
enum FramingCue {
  ok,
  stepBack,
  stepCloser,
  moveLeft,
  moveRight,
  turnSideways,
}

/// Spoken copy per framing cue.
String framingCueLine(FramingCue cue) => switch (cue) {
      FramingCue.ok => '',
      FramingCue.stepBack => 'Step back so I can see your full body.',
      FramingCue.stepCloser => 'Move a little closer to the camera.',
      FramingCue.moveLeft => 'Move left to stay in frame.',
      FramingCue.moveRight => 'Move right to stay in frame.',
      FramingCue.turnSideways =>
        'Turn sideways to the camera for this exercise.',
    };

/// One analyzed frame.
class PoseFrameResult {
  const PoseFrameResult({
    required this.timestampMs,
    required this.inferenceMs,
    required this.posesFound,
    required this.lockReason,
    required this.personLocked,
    required this.framing,
    required this.visibleCount,
    required this.requiredCount,
    this.brain,
  });

  final int timestampMs;
  final int inferenceMs;
  final int posesFound;
  final LockReason lockReason;
  final bool personLocked;
  final FramingCue framing;
  final int visibleCount;
  final int requiredCount;
  final BrainResult? brain;
}

class PoseAnalyzer {
  PoseAnalyzer(this.definition, {this.minIntervalMs = 80})
      : _brain = BrainEngine(definition);

  final ExerciseDefinition definition;

  /// Minimum ms between inference starts (frame drops beyond this).
  final double minIntervalMs;

  final BrainEngine _brain;
  BrainEngine get brain => _brain;

  PoseDetector? _detector;
  bool _busy = false;
  int _lastStartMs = 0;

  final _controller = StreamController<PoseFrameResult>.broadcast();
  Stream<PoseFrameResult> get results => _controller.stream;

  /// Latest raw pose from ML Kit (for debug visualization overlay).
  Pose? _latestPose;
  Pose? get latestPose => _latestPose;

  final Map<int, pm.EmaFilter> _smoothX = {};
  final Map<int, pm.EmaFilter> _smoothY = {};
  pm.LmPoint? _torsoEma;
  int _stableFrames = 0;

  /// Video-playback guard state: a played demo video repeats reps
  /// near-perfectly. Real humans vary — human jitter clears the suspicion.
  bool _videoSuspected = false;

  /// Rep-duration samples (seconds) for regularity analysis.
  final List<double> _repDurations = [];

  /// Timestamp (ms) of the last completed movement cycle — rep-rhythm
  /// sampling.
  int? _lastCycleAtMs;

  /// True when the primary angle is above the rolling mid-threshold —
  /// below→above transitions complete one movement cycle.
  bool _rhythmPhaseAbove = false;

  /// Rolling (time, primary-angle) samples (~4 s) for the mid-threshold.
  final List<(double, double)> _rhythmSamples = [];

  Future<void> start() async {
    _detector ??= PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base, // latency-optimized; accurate is ~3x slower
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  /// Feeds one camera frame through the pipeline. Returns null for dropped
  /// frames (throttled/busy/detector missing) — the caller just continues.
  /// [rotation] comes from the camera sensor orientation (Phase D screen).
  Future<PoseFrameResult?> processCameraImage(
    CameraImage image, {
    required double imageWidth,
    required double imageHeight,
    required InputImageRotation rotation,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final detector = _detector;
    if (detector == null || _busy || nowMs - _lastStartMs < minIntervalMs) {
      return null;
    }
    _busy = true;
    _lastStartMs = nowMs;
    try {
      final input = _toInputImage(
        image,
        Size(imageWidth, imageHeight),
        rotation,
      );
      final sw = Stopwatch()..start();
      final poses = await detector.processImage(input);
      sw.stop();
      final result = _handlePoses(
        poses,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        inferenceMs: sw.elapsedMilliseconds,
        nowMs: nowMs,
      );
      if (!_controller.isClosed) _controller.add(result);
      return result;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  PoseFrameResult _handlePoses(
    List<Pose> poses, {
    required double imageWidth,
    required double imageHeight,
    required int inferenceMs,
    required int nowMs,
  }) {
    PoseFrameResult base({
      required LockReason reason,
      required bool locked,
      int found = 1,
      int visible = 0,
      FramingCue framing = FramingCue.ok,
      BrainResult? brain,
    }) =>
        PoseFrameResult(
          timestampMs: nowMs,
          inferenceMs: inferenceMs,
          posesFound: found,
          lockReason: reason,
          personLocked: locked,
          framing: framing,
          visibleCount: visible,
          requiredCount: _requiredCount,
          brain: brain,
        );

    if (poses.isEmpty) {
      _latestPose = null;
      _stableFrames = 0;
      _torsoEma = null;
      _videoSuspected = false;
      _resetRhythm();
      return base(reason: LockReason.noPerson, locked: false, found: 0);
    }
    if (poses.length > 1) {
      // Another person entered the frame → person-lock pauses counting.
      _stableFrames = 0;
      _videoSuspected = false;
      _resetRhythm();
      return base(
        reason: LockReason.multiPerson,
        locked: false,
        found: poses.length,
      );
    }

    final pose = poses.first;
    _latestPose = pose; // Store for debug overlay

    // Subject continuity: torso centroid jump = someone else stepped in.
    final torso = _torsoCentroid(pose, imageWidth, imageHeight);
    if (torso != null) {
      final prev = _torsoEma;
      if (prev != null && pm.normalizedDistance(torso, prev) > 0.35) {
        _stableFrames = 0;
        _torsoEma = torso;
        _videoSuspected = false;
        _resetRhythm();
        return base(reason: LockReason.lostTracking, locked: false);
      }
      _torsoEma = prev == null
          ? torso
          : (
              x: prev.x * 0.5 + torso.x * 0.5,
              y: prev.y * 0.5 + torso.y * 0.5,
            );
    }
    _stableFrames++;
    final locked = _stableFrames >= 2;

    // Visibility gate on required landmarks.
    final visible = <String, PoseLandmark>{};
    for (final name in definition.landmarks.keys) {
      final type = typeForName(name);
      final lm = type == null ? null : pose.landmarks[type];
      if (lm != null && lm.likelihood >= FormRules.minLandmarkConfidence) {
        visible[name] = lm;
      }
    }
    if (visible.length < _requiredCount) {
      return base(
        reason: LockReason.occluded,
        locked: locked,
        visible: visible.length,
      );
    }

    // Smooth + normalize.
    final px = <int, pm.LmPoint>{};
    final norm = <String, pm.LmPoint>{};
    for (final entry in visible.entries) {
      final idx = definition.landmarks[entry.key]!;
      final fx = (_smoothX[idx] ??=
          pm.EmaFilter(FormRules.emaSmoothingAlpha));
      final fy = (_smoothY[idx] ??=
          pm.EmaFilter(FormRules.emaSmoothingAlpha));
      final sx = fx.push(entry.value.x);
      final sy = fy.push(entry.value.y);
      px[idx] = (x: sx, y: sy);
      norm[entry.key] = (x: sx / imageWidth, y: sy / imageHeight);
    }

    // Angles (skipped when any vertex is missing — never feed zeros).
    final angles = <String, double>{};
    for (final def in definition.angles) {
      final pts = [for (final i in def.points) px[i]];
      if (pts.any((p) => p == null)) continue;
      angles[def.name] = pm.angleBetween(pts[0]!, pts[1]!, pts[2]!);
    }

    final framing = _decideFraming([for (final v in norm.values) v]);

    // Video-playback guard: rep rhythm analysis. A played exercise video
    // repeats reps near-perfectly (coefficient of variation ≈ 0); a real
    // human does not. Rhythm sampling runs EVERY locked frame from the
    // primary angle — so the guard can clear itself while counting is
    // paused, and a real workout resumes counting automatically.
    BrainResult? brain;
    if (locked && angles.isNotEmpty) {
      _sampleRepRhythm(angles, nowMs);
      if (_videoSuspected) {
        // Counting paused — the lock banner shows the proper message and the
        // session screen speaks it once. Rhythm keeps flowing: as soon as
        // human jitter returns, the guard clears and counting resumes.
        return base(
          reason: LockReason.videoPlayback,
          locked: false,
          visible: visible.length,
          framing: framing,
        );
      }
      brain = _brain.processFrame(
        angles: angles,
        landmarkCoords: norm,
        timestamp: nowMs / 1000.0,
      );
    }

    return base(
      reason: LockReason.ok,
      locked: locked,
      visible: visible.length,
      framing: framing,
      brain: brain,
    );
  }

  /// Rep-rhythm sampling from the primary angle: one movement cycle = one
  /// below→above crossing of the rolling mid-threshold. Feeds the
  /// video-playback hysteresis — suspect at CV < 3% over >=4 cycles
  /// (machine-perfect loop), clear at CV > 8% (human jitter).
  void _sampleRepRhythm(Map<String, double> angles, int nowMs) {
    final double t = nowMs / 1000.0;
    final angle = angles[definition.primaryAngle.name];
    if (angle == null) return;

    // Rolling ~4 s window for the mid-threshold.
    _rhythmSamples.add((t, angle));
    while (_rhythmSamples.isNotEmpty && t - _rhythmSamples.first.$1 > 4.0) {
      _rhythmSamples.removeAt(0);
    }
    if (_rhythmSamples.length < 6) return;

    var lo = _rhythmSamples.first.$2;
    var hi = lo;
    for (final s in _rhythmSamples) {
      if (s.$2 < lo) lo = s.$2;
      if (s.$2 > hi) hi = s.$2;
    }
    if (hi - lo < 20) return; // not enough movement to judge rhythm
    final mid = (lo + hi) / 2;

    final bool above = angle > mid;
    if (above && !_rhythmPhaseAbove) {
      // One movement cycle completed.
      final last = _lastCycleAtMs;
      _lastCycleAtMs = nowMs;
      if (last != null) {
        final duration = (nowMs - last) / 1000.0;
        if (duration > 0 && duration <= 30) {
          _repDurations.add(duration);
          if (_repDurations.length > 8) _repDurations.removeAt(0);
          _judgeRhythm();
        }
      }
    }
    _rhythmPhaseAbove = above;
  }

  /// Video-playback hysteresis over the recent cycle durations.
  void _judgeRhythm() {
    if (_repDurations.length < 4) return;
    final mean =
        _repDurations.reduce((a, b) => a + b) / _repDurations.length;
    if (mean <= 0) return;
    final variance = _repDurations
        .map((d) => (d - mean) * (d - mean))
        .reduce((a, b) => a + b) /
        _repDurations.length;
    final stdDev = variance <= 0 ? 0.0 : _sqrtNonNegative(variance);
    final cv = stdDev / mean;

    if (_videoSuspected) {
      if (cv > 0.08) {
        // Human jitter returned — resume counting automatically.
        _videoSuspected = false;
        _repDurations.clear();
        _lastCycleAtMs = null;
      }
    } else if (cv < 0.03) {
      _videoSuspected = true;
    }
  }

  static double _sqrtNonNegative(double x) {
    if (x <= 0) return 0;
    // Newton's method — self-contained, no new import edge.
    var guess = x;
    for (var i = 0; i < 24; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }

  int get _requiredCount {
    const keyById = {
      'squat': 'squat',
      'push_up': 'pushup',
      'jumping_jack': 'jumpingJack',
    };
    return FormRules.minVisibleLandmarks[keyById[definition.id]] ?? 6;
  }

  pm.LmPoint? _torsoCentroid(
    Pose pose,
    double imageWidth,
    double imageHeight,
  ) {
    const torso = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    final pts = <pm.LmPoint>[];
    for (final t in torso) {
      final lm = pose.landmarks[t];
      if (lm != null && lm.likelihood >= FormRules.minLandmarkConfidence) {
        pts.add((x: lm.x / imageWidth, y: lm.y / imageHeight));
      }
    }
    if (pts.length < 2) return null;
    return pm.centroid(pts);
  }

  FramingCue _decideFraming(List<pm.LmPoint> pts) {
    if (pts.isEmpty) return FramingCue.ok;
    final bb = pm.boundingBox(pts);
    if (bb.minX < 0.05) return FramingCue.moveRight;
    if (bb.maxX > 0.95) return FramingCue.moveLeft;
    if (bb.minY < 0.05 || bb.maxY > 0.98) return FramingCue.stepBack;
    final w = bb.maxX - bb.minX;
    final h = bb.maxY - bb.minY;
    if (definition.id == 'push_up') {
      // Push-ups need a wide side-on view; a tall-narrow blob is frontal.
      if (h > 0.01 && w / h < 1.1) return FramingCue.turnSideways;
      return FramingCue.ok;
    }
    if (h < 0.5) return FramingCue.stepBack;
    if (w < 0.2 && h < 0.4) return FramingCue.stepCloser;
    return FramingCue.ok;
  }

  void reset() {
    _brain.reset();
    _smoothX.clear();
    _smoothY.clear();
    _torsoEma = null;
    _stableFrames = 0;
    _busy = false;
    _videoSuspected = false;
    _resetRhythm();
  }

  /// Clears the rep-rhythm state (video-playback guard sampling).
  void _resetRhythm() {
    _repDurations.clear();
    _lastCycleAtMs = null;
    _rhythmPhaseAbove = false;
    _rhythmSamples.clear();
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
    if (!_controller.isClosed) await _controller.close();
  }

  // -- camera → ML Kit -------------------------------------------------------

  InputImage _toInputImage(CameraImage image, Size size, InputImageRotation rotation) {
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;
    final bytes = _concatPlanes(image);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static Uint8List _concatPlanes(CameraImage image) {
    var size = 0;
    for (final plane in image.planes) {
      size += plane.bytes.length;
    }
    final out = Uint8List(size);
    var offset = 0;
    for (final plane in image.planes) {
      out.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return out;
  }
}

/// Landmark name (catalog key) → ML Kit type. Null for unknown names.
PoseLandmarkType? typeForName(String name) => switch (name) {
      'nose' => PoseLandmarkType.nose,
      'left_eye_inner' => PoseLandmarkType.leftEyeInner,
      'left_eye' => PoseLandmarkType.leftEye,
      'left_eye_outer' => PoseLandmarkType.leftEyeOuter,
      'right_eye_inner' => PoseLandmarkType.rightEyeInner,
      'right_eye' => PoseLandmarkType.rightEye,
      'right_eye_outer' => PoseLandmarkType.rightEyeOuter,
      'left_ear' => PoseLandmarkType.leftEar,
      'right_ear' => PoseLandmarkType.rightEar,
      'mouth_left' => PoseLandmarkType.leftMouth,
      'mouth_right' => PoseLandmarkType.rightMouth,
      'left_shoulder' => PoseLandmarkType.leftShoulder,
      'right_shoulder' => PoseLandmarkType.rightShoulder,
      'left_elbow' => PoseLandmarkType.leftElbow,
      'right_elbow' => PoseLandmarkType.rightElbow,
      'left_wrist' => PoseLandmarkType.leftWrist,
      'right_wrist' => PoseLandmarkType.rightWrist,
      'left_pinky' => PoseLandmarkType.leftPinky,
      'right_pinky' => PoseLandmarkType.rightPinky,
      'left_index' => PoseLandmarkType.leftIndex,
      'right_index' => PoseLandmarkType.rightIndex,
      'left_thumb' => PoseLandmarkType.leftThumb,
      'right_thumb' => PoseLandmarkType.rightThumb,
      'left_hip' => PoseLandmarkType.leftHip,
      'right_hip' => PoseLandmarkType.rightHip,
      'left_knee' => PoseLandmarkType.leftKnee,
      'right_knee' => PoseLandmarkType.rightKnee,
      'left_ankle' => PoseLandmarkType.leftAnkle,
      'right_ankle' => PoseLandmarkType.rightAnkle,
      'left_heel' => PoseLandmarkType.leftHeel,
      'right_heel' => PoseLandmarkType.rightHeel,
      'left_foot_index' => PoseLandmarkType.leftFootIndex,
      'right_foot_index' => PoseLandmarkType.rightFootIndex,
      _ => null,
    };
