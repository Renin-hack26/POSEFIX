/// FixPose Pose Analyzer — ML Kit pose detection → BrainEngine pipeline.
///
/// Responsibilities (PLANNING §4.1 vision pipeline):
/// - Throttled streaming inference (default ≥30 ms between starts, frames
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
/// - Any-angle robustness (WS2 6.3, thresholds-only pass — no model change):
///   joint angles are computed from landmark *deltas*, so they are invariant
///   to translation, scale and in-plane rotation of the subject; normalized
///   landmarks are divided by the frame dimensions; confidences are clamped
///   to 0..1; and frames whose mean required-landmark confidence falls below
///   [FormRules.minFrameQuality] are dropped (see the frame-quality gate)
///   instead of feeding the FSM low-fidelity angles from oblique views.
///
/// Accuracy/speed are internal engineering targets — nothing here renders
/// latency or confidence numbers into UI copy.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../audio/cue_vocabulary.dart';
import '../constants/form_rules.dart';
import 'brain_engine.dart';
import 'exercise_definition.dart';
import 'movenet_verifier.dart';
import 'pose_landmarker_source.dart';
import 'pose_math.dart' as pm;
import 'trust_gate.dart';

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

/// Spoken copy per framing cue (single source: [CueVocabulary]).
String framingCueLine(FramingCue cue) =>
    CueVocabulary.lineForFraming(cue)?.display ?? '';

/// EMA base alpha honoring the exercise's [SmoothingConfig] (8.1): the
/// classic `alpha = 2 / (window + 1)` mapping, so a `window: 3` definition
/// responds faster than the `window: 5` default. Definitions without
/// smoothing keep the shared [FormRules.emaSmoothingAlpha] behavior.
double smoothingAlphaFor(SmoothingConfig config) {
  if (!config.enabled) return FormRules.emaSmoothingAlpha;
  return (2.0 / (config.window + 1)).clamp(0.05, 0.9);
}

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
    this.trust,
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

  /// Batch 5 frame trust (null when no pose was found or trust is blind).
  /// The session screen surfaces [TrustBreakdown.reason] while held.
  final TrustBreakdown? trust;
}

class PoseAnalyzer {
  PoseAnalyzer(this.definition, {this.minIntervalMs = 30})
      : _brain = BrainEngine(definition);

  final ExerciseDefinition definition;

  /// Minimum ms between inference starts (frame drops beyond this). 30 ms
  /// allows up to ~33 analyzed frames/s — fast enough that every FSM phase
  /// of a 3-rep/sec cadence gets its 2-frame confirmation in time.
  /// Real throughput stays inference-bound (`_busy` never overlaps work).
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

  /// EMA-smoothed copy of the latest pose — jitter-free coordinates for the
  /// skeleton overlay (every landmark with likelihood >= 0.3 is tracked so
  /// joints and lines stay stable frame-to-frame).
  Pose? _smoothedPose;
  Pose? get smoothedPose => _smoothedPose;

  /// Debug telemetry — read by the session screen to show pipeline health.
  /// These never affect counting; they only explain "no person" states.
  int framesSeen = 0;
  int lastPosesFound = 0;
  String? lastError;
  int lastInferenceMs = 0;

  final Map<int, pm.EmaFilter> _smoothX = {};
  final Map<int, pm.EmaFilter> _smoothY = {};

  /// Consecutive frames below [FormRules.minFrameQuality] (WS2 6.3) — the
  /// second one in a row is dropped as occluded instead of reaching the FSM.
  int _weakQualityFrames = 0;

  /// Per-landmark EMA filters for the overlay copy (separate from the FSM
  /// smoothing so overlay responsiveness can be tuned independently).
  final Map<PoseLandmarkType, pm.EmaFilter> _ovX = {};
  final Map<PoseLandmarkType, pm.EmaFilter> _ovY = {};
  pm.LmPoint? _torsoEma;
  int _stableFrames = 0;

  /// Video-playback guard state: a played demo video repeats reps
  /// near-perfectly. Real humans vary — human jitter clears the suspicion.
  bool _videoSuspected = false;

  /// Batch 5 second opinion (throttled — agreement is a slow signal).
  final MoveNetVerifier _verifier = MoveNetVerifier();
  MoveNetResult? _lastMoveNet;
  int _lastVerifyMs = 0;
  static const int _verifyIntervalMs = 250;

  /// World landmarks of the frame being analyzed (landmarker source only;
  /// null on the ML Kit path, which has no metric world space).
  List<List<double>>? _pendingWorld;

  /// Primary-angle history for the temporal trust signal.
  final List<double> _trustAngleHistory = [];

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
    // Batch 5 second opinion — best-effort: without it the trust gate runs
    // single-source (weight redistribution, never inflated agreement).
    await _verifier.load();
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
    framesSeen++;
    try {
      final input = _toInputImage(
        image,
        Size(imageWidth, imageHeight),
        rotation,
      );
      if (input == null) {
        lastError = 'unsupported format group=${image.format.group.name}';
        return null;
      }
      final sw = Stopwatch()..start();
      final poses = await detector.processImage(input);
      sw.stop();
      lastInferenceMs = sw.elapsedMilliseconds;
      lastPosesFound = poses.length;
      lastError = null;
      // ML Kit returns landmarks in the ROTATED (upright) frame it detected
      // in — every normalization below must use display dimensions, not the
      // raw sensor buffer dims (which are swapped for 90°/270° rotation).
      final bool swapped = rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg;
      final double uprightW = swapped ? imageHeight : imageWidth;
      final double uprightH = swapped ? imageWidth : imageHeight;
      final result = _handlePoses(
        poses,
        imageWidth: uprightW,
        imageHeight: uprightH,
        inferenceMs: sw.elapsedMilliseconds,
        nowMs: nowMs,
      );
      if (!_controller.isClosed) _controller.add(result);
      return result;
    } catch (e) {
      lastError = '$e';
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
      TrustBreakdown? trust,
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
          trust: trust,
        );

    if (poses.isEmpty) {
      _latestPose = null;
      _smoothedPose = null;
      _ovX.clear();
      _ovY.clear();
      _stableFrames = 0;
      _weakQualityFrames = 0;
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
      // Drop the overlay too — the subject changed, don't ghost the old one.
      _latestPose = null;
      _smoothedPose = null;
      _ovX.clear();
      _ovY.clear();
      _weakQualityFrames = 0;
      return base(
        reason: LockReason.multiPerson,
        locked: false,
        found: poses.length,
      );
    }

    final pose = poses.first;
    _latestPose = pose; // Store for debug overlay
    _smoothedPose = _smoothOverlay(pose); // Stable coords for the overlay

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

    // WS2 6.3 — frame-quality gate (any-angle robustness, conservative):
    // enough landmarks can still be *present* while their confidence — and
    // with it the angular fidelity at odd camera angles / in blur — has
    // collapsed. Two consecutive weak frames are treated as occluded so the
    // FSM never integrates foreshortened garbage angles; one marginal frame
    // after a good run still passes (no flicker).
    double quality = 0;
    for (final lm in visible.values) {
      quality += lm.likelihood.clamp(0.0, 1.0);
    }
    quality /= visible.length;
    if (quality < FormRules.minFrameQuality) {
      _weakQualityFrames++;
      if (_weakQualityFrames >= 2) {
        return base(
          reason: LockReason.occluded,
          locked: locked,
          visible: visible.length,
        );
      }
    } else {
      _weakQualityFrames = 0;
    }

    // Smooth + normalize. Velocity-aware EMA: fast landmark motion raises
    // the effective alpha (up to 0.75) so quick reps keep their full
    // amplitude and still cross the FSM depth thresholds; slow motion keeps
    // the classic 0.3 smoothing against camera noise. The base alpha honors
    // the exercise's smoothing window (8.1).
    final px = <int, pm.LmPoint>{};
    final norm = <String, pm.LmPoint>{};
    final baseAlpha = smoothingAlphaFor(definition.smoothing);
    for (final entry in visible.entries) {
      final idx = definition.landmarks[entry.key]!;
      final fx = (_smoothX[idx] ??= pm.EmaFilter(
          baseAlpha,
          adaptiveGain: 0.012,
          maxAlpha: 0.75));
      final fy = (_smoothY[idx] ??= pm.EmaFilter(
          baseAlpha,
          adaptiveGain: 0.012,
          maxAlpha: 0.75));
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
      // Batch 5 trust gate: a held frame never advances the FSM — the
      // screen surfaces the hold reason instead of counting on a guess.
      final trust = _computeTrust(
        pose: pose,
        angles: angles,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (trust.held) {
        return base(
          reason: LockReason.ok,
          locked: true,
          visible: visible.length,
          framing: framing,
          trust: trust,
        );
      }
      brain = _brain.processFrame(
        angles: angles,
        landmarkCoords: norm,
        timestamp: nowMs / 1000.0,
        frameTrust: trust,
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

  /// Frame trust from the four signals (Batch 5 port of the reference
  /// blend). Single-source when MoveNet has no opinion (ML Kit path or a
  /// throttled/missing pass) — weight redistribution, never inflated.
  TrustBreakdown _computeTrust({
    required Pose pose,
    required Map<String, double> angles,
    required double imageWidth,
    required double imageHeight,
  }) {
    final vis = List<double>.generate(33, (i) {
      final lm = pose.landmarks[PoseLandmarkType.values[i]];
      return lm == null ? 0.0 : lm.likelihood.clamp(0.0, 1.0);
    });
    final primary = angles[definition.primaryAngle.name];
    if (primary != null) {
      _trustAngleHistory.add(primary);
      if (_trustAngleHistory.length > 13) _trustAngleHistory.removeAt(0);
    }
    final mpXY = List<List<double>>.generate(33, (i) {
      final lm = pose.landmarks[PoseLandmarkType.values[i]];
      if (lm == null) return [double.nan, double.nan];
      return [lm.x / imageWidth, lm.y / imageHeight];
    });
    final mv = _lastMoveNet;
    var agreement = 0.0;
    var available = false;
    if (mv != null && mv.hasOpinion) {
      final r = crossModelAgreement(mpXY, vis, mv.imageXY, mv.vis);
      agreement = r.score;
      available = r.perJoint.isNotEmpty;
    }
    return TrustBreakdown(
      visibility: visibilityScore(vis),
      agreement: agreement,
      temporal: temporalScore(_trustAngleHistory),
      geometry: geometryScore(mpXY, _pendingWorld),
      agreementAvailable: available,
    );
  }

  // -- landmarker source (Batch 5 primary) -------------------------------------

  /// Feeds one PoseLandmarker frame through the shared pipeline. The frame
  /// is adapted to the analyzer's landmark space (upright pixels), so
  /// smoothing, angles, trust, rhythm and the brain run unchanged; the ML
  /// Kit path stays as the fallback. Returns null only for malformed
  /// frames — the caller just continues.
  Future<PoseFrameResult?> processLandmarkerFrame(
    LandmarkerFrame33 frame, {
    required int inferenceMs,
    required int nowMs,
  }) async {
    framesSeen++;
    // Throttled second opinion (agreement is a slow signal).
    if (nowMs - _lastVerifyMs >= _verifyIntervalMs) {
      _lastVerifyMs = nowMs;
      _lastMoveNet = await _verifier.verify(frame.thumb);
    }
    _pendingWorld = frame.world;
    try {
      if (frame.imageXY.length != 33) {
        lastError = 'landmarker frame has ${frame.imageXY.length} joints';
        return null;
      }
      final pose = Pose(landmarks: {
        for (var i = 0; i < 33; i++)
          PoseLandmarkType.values[i]: PoseLandmark(
            type: PoseLandmarkType.values[i],
            x: frame.imageXY[i][0] * frame.frameW,
            y: frame.imageXY[i][1] * frame.frameH,
            z: frame.z[i],
            likelihood: frame.vis[i].clamp(0.0, 1.0),
          ),
      });
      lastPosesFound = 1;
      lastError = null;
      final result = _handlePoses(
        [pose],
        imageWidth: frame.frameW,
        imageHeight: frame.frameH,
        inferenceMs: inferenceMs,
        nowMs: nowMs,
      );
      if (!_controller.isClosed) _controller.add(result);
      return result;
    } catch (e) {
      lastError = '$e';
      return null;
    } finally {
      _pendingWorld = null;
    }
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

  /// Builds the EMA-smoothed overlay pose from [pose]. Tracked in the
  /// upright (rotated) pixel space ML Kit returns, so the painter can map it
  /// directly onto the preview. Alpha 0.5 keeps the skeleton responsive
  /// while removing per-frame jitter from lines and joints; fast motion
  /// adapts up to 0.85 so the overlay doesn't visibly trail the body.
  Pose _smoothOverlay(Pose pose) {
    final map = <PoseLandmarkType, PoseLandmark>{};
    for (final entry in pose.landmarks.entries) {
      final lm = entry.value;
      if (lm.likelihood < 0.3) continue;
      final fx = (_ovX[entry.key] ??=
          pm.EmaFilter(0.5, adaptiveGain: 0.006, maxAlpha: 0.85));
      final fy = (_ovY[entry.key] ??=
          pm.EmaFilter(0.5, adaptiveGain: 0.006, maxAlpha: 0.85));
      map[entry.key] = PoseLandmark(
        type: entry.key,
        x: fx.push(lm.x),
        y: fy.push(lm.y),
        z: lm.z,
        // Clamped (WS2 6.3): downstream tinting/thresholds assume 0..1.
        likelihood: lm.likelihood.clamp(0.0, 1.0),
      );
    }
    return Pose(landmarks: map);
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
    _ovX.clear();
    _ovY.clear();
    _latestPose = null;
    _smoothedPose = null;
    _torsoEma = null;
    _stableFrames = 0;
    _weakQualityFrames = 0;
    _busy = false;
    _videoSuspected = false;
    _pendingWorld = null;
    _lastMoveNet = null;
    _lastVerifyMs = 0;
    _trustAngleHistory.clear();
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
    _verifier.close();
    if (!_controller.isClosed) await _controller.close();
  }

  // -- camera → ML Kit -------------------------------------------------------

  /// Builds an [InputImage] from a camera frame. Returns null when the
  /// format cannot be mapped (caller records [lastError] instead of
  /// silently feeding garbage bytes that always yield "no person").
  InputImage? _toInputImage(
      CameraImage image, Size size, InputImageRotation rotation) {
    // Preferred path: controller requests NV21 (single plane) or BGRA8888.
    // Fallback: genuine YUV420_888 (3 planes) converted to NV21.
    final group = image.format.group;
    if (group == ImageFormatGroup.bgra8888) {
      if (image.planes.length != 1) return null;
      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }
    if (group == ImageFormatGroup.nv21) {
      if (image.planes.length != 1) return null;
      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }
    if (group == ImageFormatGroup.yuv420) {
      if (image.planes.length != 3) return null;
      final nv21 = _yuv420ToNv21(image);
      if (nv21 == null) return null;
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }
    // Unknown group (e.g. jpeg on some devices) — do not guess.
    return null;
  }

  /// YUV420_888 (Y + U + V, arbitrary row/pixel strides) → NV21 (Y + VU).
  /// The old code simply concatenated the three planes, which garbles the
  /// chroma whenever pixelStride != 1 and ML Kit then sees noise and
  /// returns zero poses forever.
  static Uint8List? _yuv420ToNv21(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;
      final width = image.width;
      final height = image.height;
      final yRowStride = yPlane.bytesPerRow;
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;

      final out = Uint8List(width * height * 3 ~/ 2);
      // Y: copy row by row (handles rowStride padding).
      var outPos = 0;
      for (var row = 0; row < height; row++) {
        final srcPos = row * yRowStride;
        out.setRange(outPos, outPos + width, yBytes.sublist(srcPos, srcPos + width));
        outPos += width;
      }
      // VU interleaved, subsampled 2x2.
      for (var row = 0; row < height ~/ 2; row++) {
        for (var col = 0; col < width ~/ 2; col++) {
          final uvIndex = row * uvRowStride + col * uvPixelStride;
          out[outPos++] = vBytes[uvIndex];
          out[outPos++] = uBytes[uvIndex];
        }
      }
      return out;
    } catch (_) {
      return null;
    }
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
