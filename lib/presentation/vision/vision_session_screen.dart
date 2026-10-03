import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/audio/cue_vocabulary.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/pose/angle_readouts.dart';
import '../../core/pose/brain_engine.dart';
import '../../core/pose/exercise_definition.dart';
import '../../core/pose/pose_analyzer.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../engines/session_audio/session_audio_cues.dart';
import '../shared/glass_card.dart';
import '../shared/primary_button.dart';
import 'vision_hud.dart';

/// Live workout vision screen: back-camera preview + [PoseAnalyzer] rep
/// counting with spoken coaching. Live skeleton overlay shows exactly what
/// ML Kit detects on each frame.
class VisionSessionScreen extends ConsumerStatefulWidget {
  const VisionSessionScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<VisionSessionScreen> createState() =>
      _VisionSessionScreenState();
}

class _VisionSessionScreenState extends ConsumerState<VisionSessionScreen> {
  CameraController? _camera;
  PoseAnalyzer? _analyzer;
  InputImageRotation _rotation = InputImageRotation.rotation270deg; // front cam, portrait
  CameraLensDirection _lens = CameraLensDirection.front;

  bool _initializing = true;
  bool _permissionDenied = false;
  String? _cameraError;
  bool _ready = false;
  bool _paused = false;
  bool _inFlight = false;
  bool _disposed = false;

  LockReason _lastLockReason = LockReason.ok;
  DateTime _lastLockVoiceAt = DateTime.fromMillisecondsSinceEpoch(0);

  int _reps = 0;
  String _state = 'unknown';
  int _formScore = 100;
  LockReason _lockReason = LockReason.noPerson;
  FramingCue _framing = FramingCue.ok;
  FramingCue _lastSpokenFraming = FramingCue.ok;
  String? _coachCue;

  WorkoutSession? _session;
  SessionAudioCues? _audioCues;
  DateTime? _sessionStartTime;
  int _totalFormScoreSum = 0;
  int _formScoreCount = 0;
  int _lastSavedRepCount = 0;
  bool _exitedEarly = false;

  /// Latest raw pose from ML Kit for skeleton overlay.
  Pose? _latestPose;

  /// Exercise definition for this session (readouts + hold target).
  ExerciseDefinition? _definition;

  /// Exercise-aware angle readouts (WS8.4) — rendered bottom-left/right.
  String? _readoutLeft;
  String? _readoutRight;

  /// Hold clock for duration exercises (WS8.1) + its target.
  double _holdSeconds = 0;
  int _holdTarget = 0;

  /// Actual image-stream dimensions (sensor pixels) for overlay transform.
  /// Updated from every frame; falls back to previewSize until first frame.
  double _imageWidth = 0;
  double _imageHeight = 0;
  int _framesSeen = 0;
  int _lastPosesFound = 0;
  String? _pipelineError;

  // --- frame-rate UI plumbing -------------------------------------------------
  // Per-frame data (HUD readouts + skeleton overlay) is pushed through
  // notifiers instead of setState: the camera preview, controls and the
  // screen structure no longer rebuild on every analyzed frame — only the
  // small HUD subtrees re-build and the overlay re-paints.
  final ValueNotifier<_HudSnapshot> _hud = ValueNotifier(_HudSnapshot.initial);
  final _FrameTick _overlayTick = _FrameTick();

  /// One painter instance for the whole session — frame data is mutated in
  /// place and the overlay is repainted via [_overlayTick].
  late final SkeletonOverlayPainter _skeletonPainter = SkeletonOverlayPainter(
    _latestPose,
    _imageWidth,
    _imageHeight,
    _rotation,
    _lens == CameraLensDirection.front,
    repaint: _overlayTick,
  );

  /// Publishes current per-frame fields to the HUD listeners.
  void _publishHud() {
    _hud.value = _HudSnapshot(
      frames: _framesSeen,
      poses: _lastPosesFound,
      error: _pipelineError,
      lens: _lens,
      reps: _reps,
      state: _state,
      formScore: _formScore,
      lockReason: _lockReason,
      framing: _framing,
      coachCue: _coachCue,
      paused: _paused,
      readoutLeft: _readoutLeft,
      readoutRight: _readoutRight,
      holdSeconds: _holdSeconds,
      holdTarget: _holdTarget,
    );
  }

  /// Refreshes the skeleton overlay paint (pose + mapping) without
  /// rebuilding any widget.
  void _publishOverlay() {
    _skeletonPainter.pose = _latestPose;
    _skeletonPainter.imageWidth = _imageWidth;
    _skeletonPainter.imageHeight = _imageHeight;
    _skeletonPainter.rotation = _rotation;
    _skeletonPainter.mirrored = _lens == CameraLensDirection.front;
    _overlayTick.tick();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final definition = ExerciseRegistry.instance.resolve(widget.exerciseId);
    if (definition == null) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Exercise not found. Please try another.';
      });
      return;
    }
    _definition = definition;
    // Duration exercises (plank, wall-sit…) run a hold clock against the
    // definition's target instead of counting reps (WS8.1).
    _holdTarget =
        definition.type == 'duration' ? definition.targetDuration : 0;
    final soundEngine = ref.read(soundEngineProvider);
    _audioCues = SessionAudioCues(soundEngine);

    final sessionRepository = ref.read(sessionRepositoryProvider);
    final active = await sessionRepository.activeSession();
    if (active != null) {
      if (active.exercises.isNotEmpty &&
          active.exercises.first.exerciseId != widget.exerciseId) {
        await sessionRepository.clearActive();
        await _createNewSession(sessionRepository);
      } else {
        await _resumeSession(active, sessionRepository);
      }
    } else {
      await _createNewSession(sessionRepository);
    }

    try {
      final analyzer = ref.read(poseAnalyzerProvider(widget.exerciseId));
      _analyzer = analyzer;
      await analyzer.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'This exercise is not available right now.';
      });
      return;
    }

    await _initCamera();
  }

  Future<void> _createNewSession(SessionRepository repository) async {
    final now = DateTime.now();
    final session = WorkoutSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      workoutId: 'single_${widget.exerciseId}',
      startedAt: now,
      status: SessionStatus.active,
      exercises: [
        SessionExercise(
          exerciseId: widget.exerciseId,
          totalReps: 0,
          formAccuracyPct: 100,
        ),
      ],
    );
    _session = session;
    _sessionStartTime = now;
    await repository.saveActive(session);
  }

  Future<void> _resumeSession(
      WorkoutSession active, SessionRepository repository) async {
    _session = active;
    _sessionStartTime = active.startedAt;
    final exercise = active.exercises.firstWhere(
      (e) => e.exerciseId == widget.exerciseId,
      orElse: () => SessionExercise(exerciseId: widget.exerciseId),
    );
    _reps = exercise.totalReps;
    _lastSavedRepCount = _reps;
    _totalFormScoreSum = (exercise.formAccuracyPct * _reps).round();
    _formScoreCount = _reps;
    _formScore = exercise.formAccuracyPct.round();
    await repository.saveActive(active.copyWith(status: SessionStatus.active));
  }

  Future<void> _initCamera() async {
    if (_disposed) return;
    // Dispose previous controller when toggling lenses.
    final old = _camera;
    _camera = null;
    if (old != null) {
      try {
        await old.stopImageStream();
      } catch (_) {}
      try {
        await old.dispose();
      } catch (_) {}
    }
    setState(() {
      _initializing = true;
      _permissionDenied = false;
      _cameraError = null;
      _ready = false;
    });
    final PermissionStatus status = await Permission.camera.request();
    if (_disposed || !mounted) return;
    if (!status.isGranted) {
      setState(() {
        _initializing = false;
        _permissionDenied = true;
      });
      return;
    }
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera found on this device.');
      }
      // Default to FRONT camera so the user sees themselves while working
      // out. Back camera previously pointed away from the user, which is
      // why every frame returned "no person".
      CameraDescription selected = cameras.first;
      for (final CameraDescription cam in cameras) {
        if (cam.lensDirection == _lens) {
          selected = cam;
          break;
        }
      }
      // Fall back to whatever exists if the preferred lens is missing.
      _lens = selected.lensDirection;
      final CameraController controller = CameraController(
        selected,
        ResolutionPreset.medium, // 720p: reliable ML Kit input, less heat
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }
      _rotation = _rotationFromSensor(selected.sensorOrientation);
      final PoseAnalyzer? analyzer = _analyzer;
      if (analyzer != null) {
        analyzer.reset();
      }
      await controller.startImageStream(_onImage);
      await WakelockPlus.enable();
      if (_disposed || !mounted) return;

      // Fallback size until the first real frame reports its dimensions.
      final size = controller.value.previewSize;
      if (size != null) {
        _imageWidth = size.width;
        _imageHeight = size.height;
      }

      setState(() {
        _camera = controller;
        _initializing = false;
        _ready = true;
      });
      _publishHud(); // lens label changed with the camera
    } catch (e) {
      if (_disposed || !mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Could not start the camera: $e';
      });
    }
  }

  Future<void> _toggleLens() async {
    _lens = _lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _initCamera();
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    // Android camera sensor orientation (deg) → ML Kit rotation enum.
    // Back cameras on most devices use 90 (portrait) or predict; verify on device.
    return switch (sensorOrientation) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
  }

  void _onImage(CameraImage image) {
    if (!_ready || _paused || _disposed) return;
    if (_inFlight) return;
    final PoseAnalyzer? analyzer = _analyzer;
    if (analyzer == null) return;
    _inFlight = true;
    unawaited(_feed(analyzer, image));
  }

  Future<void> _feed(PoseAnalyzer analyzer, CameraImage image) async {
    try {
      _imageWidth = image.width.toDouble();
      _imageHeight = image.height.toDouble();
      final PoseFrameResult? result = await analyzer.processCameraImage(
        image,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        rotation: _rotation,
      );
      if (!mounted || _disposed) return;
      // Always refresh telemetry so the HUD proves the pipeline is alive
      // even when ML Kit returns zero poses — but only notify when the
      // numbers actually changed (dropped/throttled frames stay silent).
      final bool telemetryChanged = analyzer.framesSeen != _framesSeen ||
          analyzer.lastPosesFound != _lastPosesFound ||
          analyzer.lastError != _pipelineError;
      _framesSeen = analyzer.framesSeen;
      _lastPosesFound = analyzer.lastPosesFound;
      _pipelineError = analyzer.lastError;
      if (result != null) {
        _handleResult(result);
        // Prefer the EMA-smoothed pose for the overlay — stable joints and
        // lines instead of raw per-frame jitter.
        _latestPose = analyzer.smoothedPose ?? analyzer.latestPose;
        _publishOverlay();
        _publishHud();
      } else if (telemetryChanged) {
        _publishHud();
      }
    } catch (_) {
      // A bad frame must never break the session.
    } finally {
      _inFlight = false;
    }
  }

  void _handleResult(PoseFrameResult result) {
    final brain = result.brain;
    String? cue;
    if (brain != null) {
      if (brain.repJustCompleted) {
        _reps = brain.repCount;
        _totalFormScoreSum += brain.formScore;
        _formScoreCount++;
        _formScore = (_totalFormScoreSum / _formScoreCount).round();
        _audioCues?.onRep();
        if (_reps > _lastSavedRepCount) {
          _lastSavedRepCount = _reps;
          _saveSession();
        }
      }
      // Every coaching string resolves through the central vocabulary, so
      // the cue slot and the voice render the same entry (WS8.3).
      final List<String> warnings = <String>[];
      final List<String> messages = <String>[];
      for (final fb in brain.feedback) {
        final line = CueVocabulary.feedback(
          name: fb.name,
          message: fb.message,
          audioCue: fb.audioCue,
          severity: fb.severity,
        );
        messages.add(line.display);
        if (line.actions.contains(CueAction.speak)) {
          warnings.add(line.spoken);
        }
      }
      if (warnings.isNotEmpty) {
        _audioCues?.onWarning(warnings.first);
      }
      if (messages.isNotEmpty) {
        cue = messages.first;
      }
      // WS9.3: a gate-refused rep is EXPLAINED (coach bar + rate-limited
      // spoken warning) — never a silent drop that looks like a stuck
      // counter.
      final RepRejectedReason? rejected = brain.repRejectedReason;
      if (rejected != null) {
        final String why =
            CueVocabulary.lineForRejection(rejected).display;
        cue = why;
        _audioCues?.onWarning(why);
      }
    }
    if (result.framing != _lastSpokenFraming) {
      _lastSpokenFraming = result.framing;
      if (result.framing != FramingCue.ok) {
        _audioCues?.onFraming(result.framing);
      }
    }
    if (result.lockReason != _lastLockReason) {
      // WS9.3 anti-fake: every trust-gate transition gets a spoken
      // response (the banner shows the same copy) so a frozen counter is
      // never silent — video playback, no person, multi-person, tracking
      // loss and occlusion all announce themselves. The 3 s cooldown
      // absorbs lock flapping at the frame edge.
      final String line = lockReasonLine(result.lockReason);
      final DateTime now = DateTime.now();
      if (line.isNotEmpty &&
          now.difference(_lastLockVoiceAt) > const Duration(seconds: 3)) {
        _lastLockVoiceAt = now;
        unawaited(_audioCues?.speakUrgent(line));
      }
    }
    _lastLockReason = result.lockReason;
    // Plain field writes — _feed publishes them via _publishHud() right
    // after this returns (no full-screen setState per frame).
    _lockReason = result.lockReason;
    _framing = result.framing;
    if (brain != null) {
      _reps = brain.repCount;
      _state = brain.currentState;
      _coachCue = cue;
      // Exercise-aware angle readouts from the engine's live (smoothed)
      // angles + the duration hold clock (WS8.1/8.4).
      final definition = _definition;
      if (definition != null) {
        final pair = angleReadouts(definition, brain.angles);
        _readoutLeft = pair?.left.text;
        _readoutRight = pair?.right?.text;
      } else {
        _readoutLeft = null;
        _readoutRight = null;
      }
      _holdSeconds = brain.holdSeconds;
    }
  }

  Future<void> _saveSession() async {
    if (_session == null) return;
    final repository = ref.read(sessionRepositoryProvider);
    final updatedExercise = _session!.exercises.first.copyWith(
      totalReps: _reps,
      formAccuracyPct: _formScoreCount > 0
          ? _totalFormScoreSum / _formScoreCount
          : 100,
    );
    final updatedSession = _session!.copyWith(
      exercises: [updatedExercise],
      totalReps: _reps,
      formAccuracyPct: _formScoreCount > 0
          ? _totalFormScoreSum / _formScoreCount
          : 100,
      status: SessionStatus.active,
    );
    _session = updatedSession;
    await repository.saveActive(updatedSession);
  }

  void _retry() {
    unawaited(_initCamera());
  }

  void _openSettings() {
    unawaited(openAppSettings());
  }

  void _togglePause() async {
    setState(() {
      _paused = !_paused;
    });
    _publishHud(); // paused banner lives in the HUD snapshot
    await _saveSession();
  }

  Future<void> _confirmEndSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          'Your progress will be saved. You can review the summary after.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _endSession();
    }
  }

  Future<void> _endSession() async {
    _exitedEarly = _reps == 0;
    final CameraController? controller = _camera;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    if (_session != null) {
      // Route through the EndSession usecase (WS4 4.1): it finalizes the
      // session AND runs the post-workout chain — strike credit, plan credit,
      // report. The old direct repository call bypassed all of it, which is
      // why the strike never moved after a workout.
      final avgForm = _formScoreCount > 0
          ? _totalFormScoreSum / _formScoreCount
          : 0.0;
      final report = await ref.read(endSessionProvider)(
        _session!.copyWith(
          totalReps: _reps,
          formAccuracyPct: avgForm,
          durationSec: _sessionStartTime != null
              ? DateTime.now().difference(_sessionStartTime!).inSeconds
              : 0,
        ),
      );
      final mood = computeMood(
        targetCompletion: 1.0,
        avgForm: avgForm,
        exitedEarly: _exitedEarly,
      );
      await _audioCues?.onComplete(mood);
      if (mounted) {
        context.go('/summary?session=${report.sessionId}');
      }
    } else if (mounted) {
      context.go('/summary');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final CameraController? controller = _camera;
    _camera = null;
    if (controller != null) {
      try {
        controller.stopImageStream();
      } catch (_) {}
      unawaited(controller.dispose());
    }
    unawaited(WakelockPlus.disable());
    final PoseAnalyzer? analyzer = _analyzer;
    _analyzer = null;
    if (analyzer != null) {
      unawaited(analyzer.dispose());
    }
    _hud.dispose();
    _overlayTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = ExerciseRegistry.instance.resolve(widget.exerciseId);
    final String title = definition?.displayName ?? 'Live session';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _lens == CameraLensDirection.front
                ? 'Switch to back camera'
                : 'Switch to front camera',
            icon: Icon(
              _lens == CameraLensDirection.front
                  ? Icons.camera_rear
                  : Icons.camera_front,
            ),
            onPressed: _ready ? _toggleLens : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Starting camera…'),
          ],
        ),
      );
    }
    if (_permissionDenied || _cameraError != null) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Center(child: _ErrorCard(
          permissionDenied: _permissionDenied,
          message: _cameraError,
          onRetry: _retry,
          onOpenSettings: _openSettings,
        )),
      );
    }
    final CameraController? controller = _camera;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Complete-screen layout: the camera preview cover-fits the WHOLE body
    // area (small symmetric side-crop on portrait phones, full height kept
    // so head and feet stay visible), and a translucent HUD floats on top —
    // info at the top, controls at the bottom, the middle stays free for
    // the user's body. The overlay rides inside CameraPreview's child slot,
    // so it scales with the cover-fit exactly — never drifts.
    final double aspect = controller.value.aspectRatio > 0
        ? 1 / controller.value.aspectRatio // portrait display aspect
        : 9 / 16;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-bleed camera preview. This subtree is built once —
        //    per-frame skeleton data reaches it through the persistent
        //    painter + _overlayTick, so no widget rebuild happens at
        //    analysis rate anymore.
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: constraints.maxHeight * aspect,
                    height: constraints.maxHeight,
                    child: CameraPreview(
                      controller,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Skeleton overlay — pixel-perfect over the preview.
                          // Always mounted: the painter itself early-returns
                          // while there is no pose, and _overlayTick drives
                          // its repaints.
                          CustomPaint(
                            painter: _skeletonPainter,
                            size: Size.infinite,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // 2. Floating translucent HUD (never covers the body's center).
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pipeline health — proves frames flow even with no pose.
                // Rebuilds alone when the snapshot ticks.
                ValueListenableBuilder<_HudSnapshot>(
                  valueListenable: _hud,
                  builder: (context, snap, _) => _PipelineStatus(
                    frames: snap.frames,
                    poses: snap.poses,
                    error: snap.error,
                    lens: snap.lens,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<_HudSnapshot>(
                      valueListenable: _hud,
                      builder: (context, snap, _) => _HudOverlay(
                        reps: snap.reps,
                        state: snap.state,
                        formScore: snap.formScore,
                        lockReason: snap.lockReason,
                        framing: snap.framing,
                        coachCue: snap.coachCue,
                        paused: snap.paused,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Exercise-aware angle readouts (WS8.4) — bottom-left +
                // bottom-right over the preview, above the controls.
                ValueListenableBuilder<_HudSnapshot>(
                  valueListenable: _hud,
                  builder: (context, snap, _) => _ReadoutRow(
                    left: snap.readoutLeft,
                    right: snap.readoutRight,
                    holdSeconds: snap.holdSeconds,
                    holdTarget: snap.holdTarget,
                  ),
                ),
                const SizedBox(height: 8),
                _SessionControls(
                  paused: _paused,
                  onPause: _togglePause,
                  onEnd: _confirmEndSession,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One-line pipeline health readout shown above the preview.
class _PipelineStatus extends StatelessWidget {
  const _PipelineStatus({
    required this.frames,
    required this.poses,
    required this.error,
    required this.lens,
  });

  final int frames;
  final int poses;
  final String? error;
  final CameraLensDirection lens;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final String lensLabel = lens == CameraLensDirection.front ? 'front' : 'back';
    final String text;
    if (error != null) {
      text = 'camera $lensLabel · frames $frames · error: $error';
    } else if (frames == 0) {
      text = 'camera $lensLabel · starting feed…';
    } else {
      text = 'camera $lensLabel · frames $frames · poses $poses';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: p.track.withValues(alpha: 0.35),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: p.ink2),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// HUD overlay — rep counter, state, form score, lock/framing banners, controls.
class _HudOverlay extends StatelessWidget {
  const _HudOverlay({
    required this.reps,
    required this.state,
    required this.formScore,
    required this.lockReason,
    required this.framing,
    required this.coachCue,
    required this.paused,
  });

  final int reps;
  final String state;
  final int formScore;
  final LockReason lockReason;
  final FramingCue framing;
  final String? coachCue;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top row: rep counter + state/form score
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepCounter(reps: reps),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ExerciseStateChip(state: state),
                  const SizedBox(height: 8),
                  FormScoreReadout(formScore: formScore),
                ],
              ),
            ),
          ],
        ),
        if (lockReason != LockReason.ok) ...[
          const SizedBox(height: 10),
          PersonLockBanner(reason: lockReason),
        ],
        if (framing != FramingCue.ok) ...[
          const SizedBox(height: 10),
          FramingCueCard(framing: framing),
        ],
        const SizedBox(height: 10),
        if (coachCue != null) ...[
          _CoachCueCard(text: coachCue!),
          const SizedBox(height: 10),
        ],
        if (paused) ...[
          const _PausedBanner(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Bottom floating control bar — pause/resume + end, always reachable.
class _SessionControls extends StatelessWidget {
  const _SessionControls({
    required this.paused,
    required this.onPause,
    required this.onEnd,
  });

  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SessionControlButton(
          icon: paused ? Icons.play_arrow : Icons.pause,
          label: paused ? 'Resume' : 'Pause',
          primary: true,
          onTap: onPause,
        ),
        const SizedBox(width: 16),
        _SessionControlButton(
          icon: Icons.stop,
          label: 'End',
          onTap: onEnd,
        ),
      ],
    );
  }
}

/// Exercise-aware angle readouts (WS8.4) + duration hold chip (WS8.1):
/// bottom-left + bottom-right over the preview, translucent so the body
/// stays visible behind them. Hidden while nothing measurable is live.
class _ReadoutRow extends StatelessWidget {
  const _ReadoutRow({
    required this.left,
    required this.right,
    required this.holdSeconds,
    required this.holdTarget,
  });

  final String? left;
  final String? right;
  final double holdSeconds;
  final int holdTarget;

  @override
  Widget build(BuildContext context) {
    final holdChip = holdTarget > 0
        ? _AngleReadout(
            text: 'HOLD ${holdSeconds.round()}s / ${holdTarget}s')
        : null;
    if (left == null && right == null && holdChip == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        if (left != null)
          _AngleReadout(text: left!)
        else
          const Spacer(),
        if (holdChip != null) ...[
          const SizedBox(width: 8),
          holdChip,
        ],
        const Spacer(),
        if (right != null) _AngleReadout(text: right!),
      ],
    );
  }
}

/// One translucent readout pill (sample-style low-opacity glass, small type).
class _AngleReadout extends StatelessWidget {
  const _AngleReadout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.track.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
      ),
    );
  }
}

/// Permission / camera failure card with a retry action.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.permissionDenied,
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permissionDenied;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            permissionDenied ? Icons.videocam_off : Icons.videocam,
            size: 28,
            color: p.ink,
          ),
          const SizedBox(height: 12),
          Text(
            permissionDenied ? 'Camera access needed' : 'Camera unavailable',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            permissionDenied
                ? 'Allow camera access to start live form tracking. '
                    'Your video never leaves this device.'
                : (message ?? 'Could not start the camera. Try again.'),
            style: TextStyle(fontSize: 13, color: p.ink2),
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
          if (permissionDenied) ...[
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Open settings',
              icon: Icons.settings,
              onPressed: onOpenSettings,
            ),
          ],
        ],
      ),
    );
  }
}

/// Latest spoken coaching cue.
class _CoachCueCard extends StatelessWidget {
  const _CoachCueCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.volume_up, size: 20, color: p.accentDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pause_circle, size: 18, color: p.ink),
          const SizedBox(width: 8),
          Text(
            'Paused — resume when ready',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionControlButton extends StatelessWidget {
  const _SessionControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: primary ? p.selBg : p.solid,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: primary ? p.selFg : p.ink),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primary ? p.selFg : p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton overlay painter — draws the ML Kit pose (33 landmarks), the
/// face jaw line, shoulder/neck bone structure and live joint angles on top
/// of the camera preview.
///
/// Coordinate model (verified against Android CameraX + ML Kit docs —
/// "ML Kit results are relative to the rotated buffer"):
/// - ML Kit landmarks are in the ROTATED (upright) image frame: for 90°/270°
///   rotation the raw buffer's width/height are swapped. The preview shows
///   exactly this upright frame, so NO extra rotation transform is applied
///   (the old switch caused a double rotation and mis-mapped joints).
/// - [imageWidth]/[imageHeight] are the RAW buffer dims; the painter swaps
///   them internally and maps landmarks with a center-crop (cover) fit so
///   slight preview/analysis aspect differences never stretch the skeleton.
/// - The front-camera preview is mirrored by CameraX (selfie mode) while
///   the analysis frames are NOT — so x is flipped for front lenses.
/// ChangeNotifier with a public tick — lets the screen push overlay
/// repaints without exposing the protected [ChangeNotifier.notifyListeners].
class _FrameTick extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Everything the per-frame HUD displays. Immutable — each analyzed frame
/// swaps in a new snapshot, and only the ValueListenableBuilder subtrees
/// re-build (the camera preview and controls do not).
@immutable
class _HudSnapshot {
  const _HudSnapshot({
    required this.frames,
    required this.poses,
    required this.error,
    required this.lens,
    required this.reps,
    required this.state,
    required this.formScore,
    required this.lockReason,
    required this.framing,
    required this.coachCue,
    required this.paused,
    required this.readoutLeft,
    required this.readoutRight,
    required this.holdSeconds,
    required this.holdTarget,
  });

  static const _HudSnapshot initial = _HudSnapshot(
    frames: 0,
    poses: 0,
    error: null,
    lens: CameraLensDirection.front,
    reps: 0,
    state: 'unknown',
    formScore: 100,
    lockReason: LockReason.noPerson,
    framing: FramingCue.ok,
    coachCue: null,
    paused: false,
    readoutLeft: null,
    readoutRight: null,
    holdSeconds: 0,
    holdTarget: 0,
  );

  final int frames;
  final int poses;
  final String? error;
  final CameraLensDirection lens;
  final int reps;
  final String state;
  final int formScore;
  final LockReason lockReason;
  final FramingCue framing;
  final String? coachCue;
  final bool paused;

  /// Exercise-aware angle readouts, preformatted (`Knee 142°`).
  final String? readoutLeft;
  final String? readoutRight;

  /// Duration hold clock + target seconds (0 = repetition exercise).
  final double holdSeconds;
  final int holdTarget;
}

class SkeletonOverlayPainter extends CustomPainter {
  SkeletonOverlayPainter(
    this.pose,
    this.imageWidth,
    this.imageHeight,
    this.rotation,
    this.mirrored, {
    super.repaint,
  });

  // Mutable: the session screen updates these in place and ticks `repaint`,
  // so a camera frame never requires building a new painter widget.
  Pose? pose;

  /// Raw (unrotated) camera buffer dimensions.
  double imageWidth;
  double imageHeight;
  InputImageRotation rotation;
  bool mirrored;

  // Hoisted paints — creating ~8 Paint + a TextPainter per frame was
  // steady GC churn at analysis rate. Statics are created once.
  static final Paint paintDot = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF00E676); // chartreuse accent
  static final Paint paintDotLow = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFF6D00); // low confidence
  static final Paint paintLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF00E676).withValues(alpha: 0.85);
  static final Paint paintLineLow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFF6D00).withValues(alpha: 0.85);
  static final Paint paintFace = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..color = Colors.white.withValues(alpha: 0.55);
  static final Paint paintBone = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFFD740).withValues(alpha: 0.9); // shoulder
  static final Paint paintAnchor = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF00E676);
  static final Paint paintArc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.white.withValues(alpha: 0.9);

  /// Reused across paints — 37 label layouts per frame with fresh
  /// TextPainters was measurable allocation churn.
  final TextPainter paintText = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  /// MediaPipe Pose landmark connections (33-body model, skeleton lines).
  static const List<(int, int)> _body = [
    // Face: nose → eyes → ears → mouth
    (0, 1), (1, 2), (2, 3), (3, 7),
    (0, 4), (4, 5), (5, 6), (6, 8),
    (9, 10),
    // Torso: shoulders → hips
    (11, 12),
    (11, 23), (12, 24), (23, 24),
    // Left arm: shoulder → elbow → wrist → hand
    (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
    // Right arm
    (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
    // Left leg: hip → knee → ankle → heel/foot
    (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
    // Right leg
    (24, 26), (26, 28), (28, 30), (28, 32), (30, 32),
  ];

  /// Face structure: jaw line (ear → mouth → mouth → ear), eyes, nose.
  static const List<(int, int)> _face = [
    (7, 9), (9, 10), (10, 8),
    (0, 9), (0, 10),
    (1, 2), (2, 3), (4, 5), (5, 6),
    (0, 1), (0, 4),
    (3, 7), (6, 8),
  ];

  /// Shoulder bone structure: neck lines ear → shoulder.
  static const List<(int, int)> _shoulderBones = [
    (7, 11), (8, 12),
  ];

  /// Landmark indices drawn as emphasized bone anchors (shoulders + hips).
  static const Set<int> _bigJoints = {11, 12, 23, 24};

  /// Live angle measurement: (a, b, c) — angle drawn AT vertex b.
  /// Elbows and knees — the two joints that drive squat/push-up reps.
  static const List<(int, int, int)> _angleSpecs = [
    (11, 13, 15), // left elbow
    (12, 14, 16), // right elbow
    (23, 25, 27), // left knee
    (24, 26, 28), // right knee
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null || imageWidth <= 0 || imageHeight <= 0) {
      return;
    }

    // Raw buffer → upright frame: ML Kit already rotated the image for
    // detection, so landmarks live in the swapped (display) dimensions.
    final bool swap = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final double upW = swap ? imageHeight : imageWidth;
    final double upH = swap ? imageWidth : imageHeight;

    // Center-crop (cover) mapping: the preview fills its widget box; any
    // small aspect difference between preview and analysis resolutions
    // crops symmetrically instead of stretching the skeleton.
    final double scale = math.max(size.width / upW, size.height / upH);
    final double offX = (size.width - upW * scale) / 2;
    final double offY = (size.height - upH * scale) / 2;

    // Colors — hoisted static paints (see fields); nothing is allocated
    // per frame except the tiny per-frame landmark map.

    // Map landmarks: upright pixels → widget coordinates (cover + mirror).
    final landmarks = <int, Offset>{};
    for (int i = 0; i < 33; i++) {
      final lm = pose!.landmarks[PoseLandmarkType.values[i]];
      if (lm == null || lm.likelihood < 0.3) continue;
      final double nx = (lm.x / upW).clamp(0.0, 1.0);
      final double ny = (lm.y / upH).clamp(0.0, 1.0);
      double wx = offX + nx * upW * scale;
      final double wy = offY + ny * upH * scale;
      if (mirrored) {
        wx = size.width - wx; // front-camera preview is mirrored
      }
      landmarks[i] = Offset(wx, wy);
    }
    if (landmarks.isEmpty) return;

    double? likelihoodOf(int i) =>
        pose!.landmarks[PoseLandmarkType.values[i]]?.likelihood;

    // Body skeleton (lines colored by joint confidence).
    for (final (a, b) in _body) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      if (pa == null || pb == null) continue;
      final conf = math.min(likelihoodOf(a) ?? 0, likelihoodOf(b) ?? 0);
      canvas.drawLine(pa, pb, conf >= 0.5 ? paintLine : paintLineLow);
    }

    // Face jaw line + eyes (thin white).
    for (final (a, b) in _face) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      if (pa != null && pb != null) canvas.drawLine(pa, pb, paintFace);
    }

    // Shoulder bone structure (ear → shoulder neck lines).
    for (final (a, b) in _shoulderBones) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      if (pa != null && pb != null) canvas.drawLine(pa, pb, paintBone);
    }

    // Live angle measurement: arc + degrees at elbows and knees.
    for (final (a, b, c) in _angleSpecs) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      final pc = landmarks[c];
      if (pa == null || pb == null || pc == null) continue;
      final u = pa - pb;
      final v = pc - pb;
      final n = u.distance * v.distance;
      if (n < 1e-6) continue;
      final cos = ((u.dx * v.dx + u.dy * v.dy) / n).clamp(-1.0, 1.0);
      final degrees = math.acos(cos) * 180.0 / math.pi;
      final double a1 = math.atan2(u.dy, u.dx);
      final double a2 = math.atan2(v.dy, v.dx);
      double delta = a2 - a1;
      while (delta > math.pi) {
        delta -= 2 * math.pi;
      }
      while (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      const double r = 24;
      canvas.drawArc(
        Rect.fromCircle(center: pb, radius: r),
        a1,
        delta,
        false,
        paintArc,
      );
      final mid = a1 + delta / 2;
      final lp = pb + Offset(math.cos(mid), math.sin(mid)) * (r * 1.5);
      paintText.text = TextSpan(
        text: '${degrees.round()}°',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      );
      paintText.layout();
      paintText.paint(canvas, lp - Offset(paintText.width / 2, paintText.height / 2));
    }

    // Landmark dots + index labels (bone anchors emphasized).
    // Kept intentionally lean for small phone screens — fingertip nodes,
    // full finger bones and hand tracking live in the PC test bench only.
    for (int i = 0; i < 33; i++) {
      final pt = landmarks[i];
      if (pt == null) continue;
      final lm = pose!.landmarks[PoseLandmarkType.values[i]];
      final dotPaint =
          (lm != null && lm.likelihood >= 0.5) ? paintDot : paintDotLow;
      canvas.drawCircle(pt, 5, dotPaint);
      if (_bigJoints.contains(i)) {
        canvas.drawCircle(pt, 9, paintAnchor); // shoulder / hip ring
      }
      paintText.text = TextSpan(
        text: '$i',
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
      paintText.layout();
      paintText.paint(canvas, pt.translate(-4, -9));
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.rotation != rotation ||
        oldDelegate.mirrored != mirrored;
  }
}
