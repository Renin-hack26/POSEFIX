import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/pose/pose_landmarker_source.dart';
import '../../core/pose/round_tracker.dart';
import '../../core/pose/trust_gate.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../engines/session_audio/session_audio_cues.dart';
import '../shared/glass_card.dart';
import '../shared/primary_button.dart';
import '../workout/widgets/framing_guide.dart';
import '../workout/widgets/posture_avatar.dart';
import '../workout/widgets/vision_hud.dart';
import 'session_flow.dart';
import 'vision_hud.dart';

/// Live workout vision screen: back-camera preview + [PoseAnalyzer] rep
/// counting with spoken coaching. Live skeleton overlay shows exactly what
/// ML Kit detects on each frame.
///
/// Optional [targetRounds]/[targetReps]/[restSec] carry the plan block's
/// targets (rounds override wins); otherwise the pre-session editor offers
/// the definition defaults and the user confirms. Optional [workoutId]
/// chains the workout's blocks in sequence (Next between exercises);
/// without it the session is a single exercise.
class VisionSessionScreen extends ConsumerStatefulWidget {
  const VisionSessionScreen({
    super.key,
    required this.exerciseId,
    this.targetRounds,
    this.targetReps,
    this.restSec,
    this.workoutId,
  });

  final String exerciseId;
  final int? targetRounds;
  final int? targetReps;
  final int? restSec;
  final String? workoutId;

  @override
  ConsumerState<VisionSessionScreen> createState() =>
      _VisionSessionScreenState();
}

class _VisionSessionScreenState extends ConsumerState<VisionSessionScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  PoseAnalyzer? _analyzer;
  InputImageRotation _rotation = InputImageRotation.rotation270deg; // front cam, portrait
  CameraLensDirection _lens = CameraLensDirection.front;

  bool _initializing = true;
  bool _permissionDenied = false;
  String? _cameraError;
  bool _ready = false;
  bool _paused = false;

  /// Pause window start — the elapsed clock shifts forward on resume so
  /// paused time never counts (WS2.12).
  DateTime? _pauseBegan;
  bool _inFlight = false;
  bool _disposed = false;

  /// Boot-step label for the loading overlay (WS2.8), null once live.
  String? _bootStep;

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

  // --- Workout chain (multi-block sessions) ------------------------------------
  /// Sequenced blocks (empty = single-exercise session).
  List<ChainBlock> _chain = const [];

  /// Index of the live block.
  int _blockIdx = 0;

  /// Saved reps of the live exercise when its block started — the display
  /// total is offset + engine count, so resume never loses history.
  int _repsOffset = 0;

  /// Per-exercise form sums (parallel to the session's exercises).
  final List<int> _exFormSum = [];
  final List<int> _exFormCount = [];

  /// Timed-block completion fired (hold target reached once per block).
  bool _holdDone = false;

  // --- Batch 5 pose stack ------------------------------------------------------
  /// MediaPipe PoseLandmarker (heavy) source; ML Kit stays the fallback.
  final PoseLandmarkerSource _landmarkerSource = PoseLandmarkerSource();

  /// True once the landmarker backend is up for this session.
  bool _useLandmarker = false;

  /// Overlay rotation: the landmarker pre-rotates to upright natively.
  InputImageRotation _overlayRotation =
      InputImageRotation.rotation270deg;

  /// Exercise-aware angle readouts (WS8.4) — rendered bottom-left/right.
  String? _readoutLeft;
  String? _readoutRight;

  /// Hold clock for duration exercises (WS8.1) + its target.
  double _holdSeconds = 0;
  int _holdTarget = 0;

  // --- WS2 rounds / rest / milestones ---------------------------------------
  RoundTracker? _rounds;
  int _targetReps = 0;
  bool _resting = false;
  DateTime? _restEndsAt;
  int _lastMilestone = 0;

  // --- WS2.10 calibration phase ----------------------------------------------
  bool _calibrating = false;
  int _calibRemaining = 0;
  final RomCapture _rom = RomCapture();

  // --- WS2.5/2.6/2.9 transient popups ------------------------------------------
  /// 'tooFast' | 'range' while the 0.8 s wrong-pose flash is up.
  String? _rejectFlash;

  /// True while swapping analyzers between chain blocks — frames in flight
  /// from the outgoing analyzer are dropped, never applied.
  bool _switchingBlocks = false;

  /// True while the round-complete tick is up (auto-dismiss).
  bool _tickFlash = false;

  /// True while the all-rounds congrats sheet is up.
  bool _showCongrats = false;
  Timer? _flashTimer;

  /// 1 s ticker: elapsed TIME chip, rest countdown, calibration countdown.
  Timer? _ticker;

  /// Overlay form signal for the skeleton painter (WS6.2): -1 bad, 0
  /// neutral, +1 good — derived from the live feedback severities.
  int _formSignal = 0;

  /// Trust-hold banner copy (null = counting live).
  String? _trustHoldLabel;

  /// Whether the current cue bar copy is a warning (warn/ok color states).
  bool _cueWarn = false;

  /// Latest engine clock (rep count + timestamp) — rest rebase anchors here.
  int _lastEngineCount = 0;
  double _lastEngineT = 0;

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
    final tracker = _rounds;
    final now = DateTime.now();
    final roundReps = _calibrating
        ? 0
        : (tracker != null
            ? tracker.repsThisRound(_lastEngineCount).clamp(0, 1 << 30)
            : _reps);
    final roundLabel = tracker != null
        ? '${tracker.currentRound}/${tracker.targetRounds}'
        : '—';
    final timeLabel = _sessionStartTime != null
        ? formatElapsed(now.difference(_sessionStartTime!))
        : '00:00';
    var restRemaining = 0;
    if (_resting && _restEndsAt != null) {
      restRemaining =
          _restEndsAt!.difference(now).inSeconds.clamp(0, 1 << 30);
    }
    _hud.value = _HudSnapshot(
      frames: _framesSeen,
      poses: _lastPosesFound,
      error: _pipelineError,
      lens: _lens,
      backend: _useLandmarker ? 'landmarker' : 'mlkit',
      reps: _reps,
      roundReps: roundReps,
      roundLabel: roundLabel,
      timeLabel: timeLabel,
      targetReps: tracker?.targetReps ?? _targetReps,
      state: _state,
      formScore: _formScore,
      lockReason: _lockReason,
      framing: _framing,
      coachCue: _coachCue,
      cueWarn: _cueWarn,
      trustHold: _trustHoldLabel,
      paused: _paused,
      readoutLeft: _readoutLeft,
      readoutRight: _readoutRight,
      holdSeconds: _holdSeconds,
      holdTarget: _holdTarget,
      rejectKind: _rejectFlash,
      tickFlash: _tickFlash,
      showCongrats: _showCongrats,
      calibRemaining: _calibrating ? _calibRemaining : -1,
      restRemaining: restRemaining,
    );
  }

  /// Refreshes the skeleton overlay paint (pose + mapping) without
  /// rebuilding any widget.
  void _publishOverlay() {
    _skeletonPainter.pose = _latestPose;
    _skeletonPainter.imageWidth = _imageWidth;
    _skeletonPainter.imageHeight = _imageHeight;
    _skeletonPainter.rotation = _overlayRotation;
    _skeletonPainter.mirrored = _lens == CameraLensDirection.front;
    _skeletonPainter.formSignal = _formSignal;
    _overlayTick.tick();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WS2.12: backgrounding auto-pauses the session — counting never runs
    // while the user can't see the cue bar. Resume is always manual.
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _ready &&
        !_paused &&
        !_disposed &&
        mounted) {
      _togglePause();
    }
  }

  /// Boot-step labels for the loading overlay (WS2.8).
  static const List<String> _bootSteps = [
    'Finding your exercise',
    'Warming up the coach voice',
    'Loading your session',
    'Setting repetition targets',
    'Starting the analyzer',
    'Loading the pose model',
    'Starting the camera',
  ];

  void _setBootStep(int? index) {
    if (!mounted || _disposed) return;
    setState(() => _bootStep =
        (index == null || index < 0) ? null : _bootSteps[index]);
  }

  Future<void> _boot() async {
    _setBootStep(0);
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

    _setBootStep(1);
    final soundEngine = ref.read(soundEngineProvider);
    _audioCues = SessionAudioCues(soundEngine);
    try {
      await soundEngine.initialize();
    } catch (_) {
      // Voice is best-effort; the session runs silent if TTS fails.
    }

    _setBootStep(2);
    final sessionRepository = ref.read(sessionRepositoryProvider);
    // Workout chain: resolve the sequenced blocks + session via
    // StartSession (active-or-create, one record per unique exercise).
    // Single mode keeps the legacy one-exercise flow.
    var startIdx = 0;
    final wid = widget.workoutId;
    if (wid != null && !wid.startsWith('single_')) {
      Workout? chainWorkout;
      try {
        chainWorkout = await ref.read(workoutRepositoryProvider).byId(wid);
      } catch (_) {
        chainWorkout = null;
      }
      if (chainWorkout != null && chainWorkout.blocks.isNotEmpty) {
        final blocks = chainWorkout.blocks;
        _chain = uniqueBlocks(
          exerciseIds: [for (final b in blocks) b.exerciseId],
          setsFor: (id) =>
              blocks.firstWhere((b) => b.exerciseId == id).sets,
          repsFor: (id) =>
              blocks.firstWhere((b) => b.exerciseId == id).reps,
          secondsFor: (id) =>
              blocks.firstWhere((b) => b.exerciseId == id).seconds,
          restFor: (id) =>
              blocks.firstWhere((b) => b.exerciseId == id).restSec,
        );
      }
    }
    if (_chain.isEmpty) {
      _chain = [
        ChainBlock(
          exerciseId: widget.exerciseId,
          sets: widget.targetRounds ?? definition.defaultSets,
          reps: widget.targetReps ?? definition.defaultReps,
          seconds: 0,
          restSec: widget.restSec ?? 30,
        ),
      ];
    }
    if (_chain.length > 1) {
      try {
        final current = await sessionRepository.activeSession();
        if (current != null && current.workoutId != wid) {
          await sessionRepository.clearActive();
        }
        final session =
            await ref.read(startSessionProvider)(workoutId: wid!);
        _session = session;
        _sessionStartTime = session.startedAt;
        final exCount = session.exercises.length;
        startIdx = chainResumeIndex(
          exerciseCount: exCount,
          pausedIndex: session.pausedState?.exerciseIndex,
          roundsDone: (i) =>
              i < exCount ? session.exercises[i].repsPerRound.length : 0,
          setsTarget: (i) => i < _chain.length ? _chain[i].sets : 1,
        ).clamp(0, _chain.length - 1);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _cameraError = 'This workout is not available right now.';
        });
        return;
      }
    } else {
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
    }

    // Pre-session target editor (WS2.4) — plan values win, definition
    // defaults otherwise; dismissing backs out of the session. Chain
    // resumes past block 0 skip it (block prescriptions apply).
    _setBootStep(3);
    if (!mounted || _disposed) return;
    _Targets? targets;
    if (startIdx == 0) {
      final editorDef =
          ExerciseRegistry.instance.resolve(_chain[0].exerciseId) ??
              definition;
      targets = await _editTargets(editorDef);
      if (targets == null) {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/plan');
        }
        return;
      }
    }

    // Batch 5 primary backend: PoseLandmarker (heavy). Any failure here —
    // missing model, native load error — falls back to ML Kit (step 4
    // already warmed it), so the camera never dies on the new stack.
    _setBootStep(5);
    try {
      _useLandmarker = await _landmarkerSource.init();
    } catch (_) {
      _useLandmarker = false;
    }
    debugPrint(
        'VisionSession: pose backend = ${_useLandmarker ? 'landmarker-heavy' : 'mlkit-fallback'}');

    _setBootStep(6);
    await _initCamera();
    if (!mounted || _disposed) return;
    _setBootStep(4);
    await _beginBlock(startIdx, preset: targets);
    if (!mounted || _disposed || _cameraError != null) return;
    _setBootStep(-1);
    _startTicker();
  }

  /// Begins one chain block: swaps in its analyzer (fresh engine), applies
  /// targets, re-anchors counters on the saved record (resume-safe), then
  /// runs calibration where enabled or announces the start.
  Future<void> _beginBlock(int index, {_Targets? preset}) async {
    if (!mounted || _disposed) return;
    if (index < 0 || index >= _chain.length) return;
    final block = _chain[index];
    final blockDef = ExerciseRegistry.instance.resolve(block.exerciseId);
    if (blockDef == null) {
      _switchingBlocks = false;
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Exercise not found. Please try another.';
      });
      return;
    }
    // Fresh analyzer per exercise (engine, smoothing, rhythm all reset).
    final old = _analyzer;
    _analyzer = null;
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }
    try {
      final analyzer = ref.read(poseAnalyzerProvider(block.exerciseId));
      _analyzer = analyzer;
      await analyzer.start();
    } catch (_) {
      _switchingBlocks = false;
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'This exercise is not available right now.';
      });
      return;
    }
    _definition = blockDef;
    _blockIdx = index;
    final isDuration = blockDef.type == 'duration';
    if (preset != null) {
      if (isDuration) {
        _holdTarget = preset.holdSecs;
        _rounds = null;
        _targetReps = 0;
      } else {
        _rounds = RoundTracker(
          targetRounds: preset.rounds,
          targetReps: preset.reps,
          restSec: preset.rest,
        );
        _targetReps = preset.reps;
        _holdTarget = 0;
      }
    } else if (isDuration) {
      _holdTarget =
          block.seconds > 0 ? block.seconds : blockDef.targetDuration;
      _rounds = null;
      _targetReps = 0;
    } else {
      _rounds = RoundTracker(
        targetRounds: block.sets,
        targetReps: block.reps,
        restSec: block.restSec,
      );
      _targetReps = block.reps;
      // Stale duration state from a previous block must not leak into
      // repetition work (ghost hold chip / wrong OF-target).
      _holdTarget = 0;
    }
    // Re-anchor on the saved record: display totals continue where the
    // record left off (resume never loses history to a fresh engine).
    final saved = (index >= 0 && index < (_session?.exercises.length ?? 0))
        ? _session!.exercises[index]
        : SessionExercise(exerciseId: block.exerciseId);
    _repsOffset = saved.totalReps;
    _reps = saved.totalReps;
    _lastSavedRepCount = _reps;
    _lastMilestone = _reps ~/ 5;
    _lastEngineCount = 0;
    while (_exFormSum.length <= index) {
      _exFormSum.add(0);
      _exFormCount.add(0);
    }
    _resting = false;
    _restEndsAt = null;
    _holdDone = false;
    _holdSeconds = 0;
    _showCongrats = false;
    _tickFlash = false;
    _rejectFlash = null;
    if (blockDef.calibration.enabled) {
      _startCalibration();
    } else {
      var line =
          CueVocabulary.lines.firstWhere((l) => l.id == 'session-start');
      if (_chain.length > 1) {
        final prefix = 'Exercise ${index + 1} of ${_chain.length} — ';
        line = CueLine(
          id: line.id,
          situation: line.situation,
          actions: line.actions,
          display: '$prefix${line.display}',
          speak: line.speak == null ? null : '$prefix${line.speak}',
        );
      }
      _coachCue = line.display;
      unawaited(_audioCues?.announce(line.spoken));
      _publishHud();
    }
    // Swap window over — frames flow to the new analyzer from here.
    _switchingBlocks = false;
  }

  /// Pre-session target editor (WS2.4): plan route values win, definition
  /// defaults otherwise. Null = dismissed → back out of the session.
  Future<_Targets?> _editTargets(ExerciseDefinition definition) {
    final isDuration = definition.type == 'duration';
    final initial = _Targets(
      rounds: widget.targetRounds ?? definition.defaultSets,
      reps: widget.targetReps ?? definition.defaultReps,
      rest: widget.restSec ?? 30,
      holdSecs: _holdTarget > 0 ? _holdTarget : definition.targetDuration,
    );
    return showModalBottomSheet<_Targets>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TargetEditorSheet(
        definition: definition,
        initial: initial,
        isDuration: isDuration,
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !mounted) return;
      // Rest countdown expiry.
      if (_resting && _restEndsAt != null) {
        final left = _restEndsAt!.difference(DateTime.now()).inSeconds;
        if (left <= 0) _finishRest();
      }
      // Calibration countdown.
      if (_calibrating) {
        _calibRemaining--;
        if (_calibRemaining <= 0) {
          _finishCalibration();
          return;
        }
      }
      _publishHud();
    });
  }

  // --- calibration phase (WS2.10) --------------------------------------------

  void _startCalibration() {
    _rom.reset();
    _calibrating = true;
    _calibRemaining = 5;
    _coachCue = 'Move through your full range — calibrating…';
    _publishHud();
  }

  void _finishCalibration() {
    _calibrating = false;
    _calibRemaining = 0;
    final line =
        calibrationCompleteLine(judgeCalibrationDepth(_rom.spanDeg));
    _coachCue = line;
    unawaited(_audioCues?.speakUrgent(line));
    // Fresh counting state — calibration movement never counts.
    try {
      _analyzer?.reset();
    } catch (_) {}
    _publishHud();
  }

  // --- rounds / rest / milestones (WS2.3/2.6/2.11) ------------------------------

  /// Milestones (every 5 reps) + round events for a freshly counted rep.
  void _onRepCounted(BrainResult brain, double tSec) {
    final milestone = _reps ~/ 5;
    if (milestone > _lastMilestone && milestone > 0) {
      _lastMilestone = milestone;
      unawaited(
          _audioCues?.announce(CueVocabulary.milestone(milestone).spoken));
    }
    final tracker = _rounds;
    if (tracker == null || tracker.isComplete || _resting) return;
    final event = tracker.observe(brain.repCount, tSec);
    if (event == null) return;
    if (event == RoundEvent.targetComplete) {
      _presentCongrats();
      return;
    }
    // Round complete: tick flash + set sound + (optional) rest break.
    _tickFlash = true;
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _tickFlash = false;
      _rejectFlash = null;
      _publishHud();
    });
    unawaited(_audioCues?.onSet());
    final enteringLast = tracker.isLastRound;
    unawaited(_audioCues?.announce(CueVocabulary.byId(
            enteringLast ? 'last-round' : 'round-complete')
        .spoken));
    if (tracker.restSec <= 0) {
      tracker.rebase(brain.repCount, tSec);
    } else {
      _resting = true;
      _restEndsAt = DateTime.now().add(Duration(seconds: tracker.restSec));
      unawaited(_audioCues?.onRestStart());
      unawaited(
          _audioCues?.announce(CueVocabulary.byId('rest-start').spoken));
    }
    _publishHud();
  }

  void _finishRest() {
    _resting = false;
    _restEndsAt = null;
    _rounds?.rebase(_lastEngineCount, _lastEngineT);
    unawaited(_audioCues?.onRestEnd());
    unawaited(_audioCues?.announce(CueVocabulary.byId('rest-end').spoken));
    _publishHud();
  }

  void _presentCongrats() {
    _showCongrats = true;
    unawaited(_audioCues?.onMilestone());
    _publishHud();
  }

  /// Wrong-pose flash (WS2.5/2.9): 0.8 s severity card + haptic.
  /// Timed-block completion: the hold target held → record one timed
  /// completion and run the congrats flow (Log ends, Next advances).
  void _completeHold() {
    _holdDone = true;
    _reps = _repsOffset + 1;
    _lastSavedRepCount = _reps;
    _saveSession();
    unawaited(_audioCues?.announce(CueVocabulary.byId('hold-target').spoken));
    _presentCongrats();
  }

  /// Wrong-pose flash (WS2.5/2.9): 0.8 s severity card + haptic.
  void _flashReject(RepRejectedReason rejected) {
    _rejectFlash =
        rejected == RepRejectedReason.tooFast ? 'tooFast' : 'range';
    HapticFeedback.mediumImpact();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _rejectFlash = null;
      _tickFlash = false;
      _publishHud();
    });
    _publishHud();
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
    _lastMilestone = 0;
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
    _lastMilestone = _reps ~/ 5;
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
    // Drop frames during an exercise swap — the outgoing analyzer is
    // being disposed and its one stale result must never land.
    if (_switchingBlocks) return;
    final PoseAnalyzer? analyzer = _analyzer;
    if (analyzer == null) return;
    _inFlight = true;
    unawaited(_feed(analyzer, image));
  }

  int get _rotationDegrees => switch (_rotation) {
        InputImageRotation.rotation0deg => 0,
        InputImageRotation.rotation90deg => 90,
        InputImageRotation.rotation180deg => 180,
        InputImageRotation.rotation270deg => 270,
      };

  Future<void> _feed(PoseAnalyzer analyzer, CameraImage image) async {
    try {
      _imageWidth = image.width.toDouble();
      _imageHeight = image.height.toDouble();
      PoseFrameResult? result;
      if (_useLandmarker) {
        // Batch 5 primary path: heavy landmarker natively, ML Kit types
        // downstream (adapter), same pipeline either way. A dropped frame
        // just yields to the next one.
        final frame =
            await _landmarkerSource.detect(image, _rotationDegrees);
        if (frame == null) return;
        _imageWidth = frame.frameW;
        _imageHeight = frame.frameH;
        _overlayRotation = InputImageRotation.rotation0deg;
        result = await analyzer.processLandmarkerFrame(
          frame,
          inferenceMs: frame.inferenceMs.round(),
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        _overlayRotation = _rotation;
        result = await analyzer.processCameraImage(
          image,
          imageWidth: image.width.toDouble(),
          imageHeight: image.height.toDouble(),
          rotation: _rotation,
        );
      }
      // Analyzer swapped mid-flight (chain Next) — the stale result
      // belongs to the previous exercise; drop it, don't apply.
      if (!identical(analyzer, _analyzer)) return;
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
    bool cueWarn = false;
    if (brain != null) {
      final tSec = result.timestampMs / 1000.0;
      _lastEngineCount = brain.repCount;
      _lastEngineT = tSec;
      if (_calibrating) {
        // WS2.10: learn the primary-angle ROM on locked frames; counting
        // stays frozen until the phase ends with an engine reset.
        if (result.lockReason == LockReason.ok && _definition != null) {
          final v = brain.angles[_definition!.primaryAngle.name];
          if (v != null) _rom.add(v);
        }
      } else {
        if (brain.repJustCompleted) {
          // Display totals continue from the saved record (offset +
          // engine count) — a fresh engine after resume/advance never
          // loses history.
          _reps = _repsOffset + brain.repCount;
          _totalFormScoreSum += brain.formScore;
          _formScoreCount++;
          if (_blockIdx < _exFormSum.length) {
            _exFormSum[_blockIdx] += brain.formScore;
            _exFormCount[_blockIdx]++;
          }
          _formScore = (_totalFormScoreSum / _formScoreCount).round();
          _audioCues?.onRep();
          if (_reps > _lastSavedRepCount) {
            _lastSavedRepCount = _reps;
            _saveSession();
          }
          _onRepCounted(brain, tSec);
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
      cueWarn = warnings.isNotEmpty;
      // WS9.3: a gate-refused rep is EXPLAINED (coach bar + rate-limited
      // spoken warning) — never a silent drop that looks like a stuck
      // counter. WS2.5/2.9: plus the 0.8 s severity flash + haptic.
      final RepRejectedReason? rejected = brain.repRejectedReason;
      if (rejected != null && !_calibrating) {
        final String why =
            CueVocabulary.lineForRejection(rejected).display;
        cue = why;
        cueWarn = true;
        _audioCues?.onWarning(why);
        _flashReject(rejected);
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
      if (!_calibrating) _reps = _repsOffset + brain.repCount;
      _state = brain.currentState;
      _coachCue = cue;
      _cueWarn = cueWarn;
      // Batch 5 trust surface: a vetoed rep or a held frame explains
      // itself in the trust banner instead of freezing silently.
      if (brain.repHoldReason != HoldReason.none) {
        _trustHoldLabel = 'Rep held — ${brain.repHoldReason.label}';
      } else if (result.trust?.held == true) {
        _trustHoldLabel =
            'Counting paused — ${result.trust!.reason.label}';
      } else {
        _trustHoldLabel = null;
      }
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
      // Timed blocks complete once: hold target reached → one timed
      // completion, same congrats flow as a final round.
      if (_rounds == null &&
          !_holdDone &&
          !_calibrating &&
          _holdTarget > 0 &&
          _holdSeconds >= _holdTarget) {
        _completeHold();
      }
      // Overlay form signal (WS6.2): warnings/errors paint the skeleton
      // red, pure praise paints it green, otherwise neutral.
      var signal = 0;
      for (final fb in brain.feedback) {
        if (fb.severity == 'warning' || fb.severity == 'error') {
          signal = -1;
          break;
        }
      }
      if (signal == 0) {
        for (final fb in brain.feedback) {
          if (fb.severity == 'info') {
            signal = 1;
            break;
          }
        }
      }
      _formSignal = signal;
    }
  }

  Future<void> _saveSession() async {
    if (_session == null) return;
    final repository = ref.read(sessionRepositoryProvider);
    final tracker = _rounds;
    final exercises = [..._session!.exercises];
    // Chain growth guard: indices always line up with the session record.
    while (exercises.length <= _blockIdx) {
      final id = _blockIdx < _chain.length
          ? _chain[_blockIdx].exerciseId
          : widget.exerciseId;
      exercises.add(SessionExercise(
          exerciseId: id, totalReps: 0, formAccuracyPct: 100));
    }
    final avgForm = _formScoreCount > 0
        ? _totalFormScoreSum / _formScoreCount
        : 100.0;
    final updated = <SessionExercise>[];
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      if (i != _blockIdx) {
        updated.add(e);
        continue;
      }
      final exAvg = (i < _exFormCount.length && _exFormCount[i] > 0)
          ? _exFormSum[i] / _exFormCount[i]
          : e.formAccuracyPct;
      updated.add(e.copyWith(
        totalReps: _reps,
        formAccuracyPct: exAvg,
        // WS2.3: round progress persists per save (summary + dashboard).
        roundsCompleted:
            tracker?.repsPerRound.length ?? e.roundsCompleted,
        repsPerRound: tracker != null
            ? List<int>.of(tracker.repsPerRound)
            : e.repsPerRound,
        roundTimesSec: tracker != null
            ? List<double>.of(tracker.roundTimesSec)
            : e.roundTimesSec,
      ));
    }
    final now = DateTime.now();
    final elapsed = _sessionStartTime != null
        ? now.difference(_sessionStartTime!).inSeconds
        : 0;
    final updatedSession = _session!.copyWith(
      exercises: updated,
      totalReps: updated.fold<int>(0, (s, e) => s + e.totalReps),
      formAccuracyPct: avgForm,
      status: SessionStatus.active,
      // Chain resume position for the next boot (or after a kill).
      pausedState: PausedState(
        exerciseIndex: _blockIdx,
        roundIndex: (tracker?.currentRound ?? 1) - 1,
        repsInRound: tracker?.repsThisRound(_lastEngineCount) ?? _reps,
        elapsedSec: elapsed,
      ),
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
    final now = DateTime.now();
    setState(() {
      _paused = !_paused;
    });
    if (_paused) {
      _pauseBegan = now;
    } else if (_pauseBegan != null && _sessionStartTime != null) {
      // Freeze the elapsed clock across the pause.
      _sessionStartTime = _sessionStartTime!.add(now.difference(_pauseBegan!));
      _pauseBegan = null;
    }
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

  /// Cancel (WS2.7): confirm + discard — the active session is cleared with
  /// no credit, no strike, no summary.
  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard session?'),
        content: const Text(
          'This workout will not be saved and earns no credit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(sessionRepositoryProvider).clearActive();
    } catch (_) {
      // Discarding is best-effort; navigation still leaves the session.
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/plan');
    }
  }

  Future<void> _endSession() async {
    final CameraController? controller = _camera;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    // Persist the live block first — the headline totals below sum the
    // whole record, so multi-block chains credit every exercise.
    await _saveSession();
    final exercises = _session?.exercises ?? const <SessionExercise>[];
    final total = exercises.fold<int>(0, (s, e) => s + e.totalReps);
    _exitedEarly = total == 0;
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
          totalReps: total,
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
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _ticker = null;
    _flashTimer?.cancel();
    _flashTimer = null;
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
      // Loading popup (WS2.8): step labels track sound + FSM + session +
      // targets + analyzer + camera readiness.
      final stepIndex =
          _bootStep == null ? _bootSteps.length : _bootSteps.indexOf(_bootStep!);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              for (var i = 0; i < _bootSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        i < stepIndex
                            ? Icons.check_circle
                            : (i == stepIndex
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                        size: 18,
                        color: i <= stepIndex ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _bootSteps[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == stepIndex ? FontWeight.w800 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
        // 1b. Frame guide (WS2.1) — only until the coach locks on.
        Positioned.fill(
          child: ValueListenableBuilder<_HudSnapshot>(
            valueListenable: _hud,
            builder: (context, snap, _) =>
                snap.lockReason == LockReason.noPerson && _ready
                    ? const FramingGuide()
                    : const SizedBox.shrink(),
          ),
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
                    backend: snap.backend,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<_HudSnapshot>(
                      valueListenable: _hud,
                      builder: (context, snap, _) => _HudOverlay(
                        roundReps: snap.roundReps,
                        roundLabel: snap.roundLabel,
                        timeLabel: snap.timeLabel,
                        targetReps: snap.targetReps,
                        state: snap.state,
                        formScore: snap.formScore,
                        lockReason: snap.lockReason,
                        framing: snap.framing,
                        paused: snap.paused,
                        exerciseName:
                            _definition?.displayName ?? 'Live session',
                        trustHold: snap.trustHold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // 2b. Single fixed cue slot (WS2.2): rest > calibration >
                // live cue. Warn/ok color states, never stacked.
                ValueListenableBuilder<_HudSnapshot>(
                  valueListenable: _hud,
                  builder: (context, snap, _) {
                    if (snap.restRemaining > 0) {
                      return _CoachCueCard(
                        text: 'REST ${snap.restRemaining}s — '
                            'next up: Round ${_rounds?.currentRound ?? ''}',
                        warn: false,
                      );
                    }
                    if (snap.calibRemaining >= 0) {
                      return _CoachCueCard(
                        text: 'Calibrating — move through your full range '
                            '(${snap.calibRemaining}s)',
                        warn: false,
                      );
                    }
                    if (snap.coachCue == null) {
                      return const SizedBox.shrink();
                    }
                    return _CoachCueCard(
                      text: snap.coachCue!,
                      warn: snap.cueWarn,
                    );
                  },
                ),
                const SizedBox(height: 8),
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
                  onCancel: _confirmCancel,
                  onEnd: _confirmEndSession,
                ),
              ],
            ),
          ),
        ),
        // 3. Transient popups (WS2.5/2.6) — centered, non-blocking.
        Positioned.fill(
          child: ValueListenableBuilder<_HudSnapshot>(
            valueListenable: _hud,
            builder: (context, snap, _) {
              if (snap.showCongrats) {
                return Center(
                  child: _CongratsSheet(
                    onLog: () {
                      setState(() => _showCongrats = false);
                      unawaited(_endSession());
                    },
                    onNext: () {
                      setState(() {
                        _showCongrats = false;
                        // Freeze the feed across the analyzer swap so no
                        // stale frame lands on the next exercise.
                        _switchingBlocks = true;
                        _coachCue = 'Get ready — next exercise…';
                      });
                      if (_blockIdx + 1 < _chain.length) {
                        // Next exercise in the chain (targets from its
                        // block; no editor mid-flow).
                        unawaited(_beginBlock(_blockIdx + 1));
                      } else {
                        // Bonus rounds past the target — still credited.
                        _switchingBlocks = false;
                        _publishHud();
                      }
                    },
                  ),
                );
              }
              if (snap.rejectKind != null) {
                return Center(child: _RejectFlash(kind: snap.rejectKind!));
              }
              if (snap.tickFlash) {
                return const Center(child: _TickFlash());
              }
              return const SizedBox.shrink();
            },
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
    required this.backend,
  });

  final int frames;
  final int poses;
  final String? error;
  final CameraLensDirection lens;

  /// Active pose backend tag.
  final String backend;

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
      text = 'camera $lensLabel · frames $frames · poses $poses · $backend';
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

/// HUD overlay — top cluster (reps/round/time + avatar + state/form),
/// lock/framing banners. The cue bar lives in its own fixed bottom slot
/// (WS2.1/2.2) — never stacked inside this scrolling column.
class _HudOverlay extends StatelessWidget {
  const _HudOverlay({
    required this.roundReps,
    required this.roundLabel,
    required this.timeLabel,
    required this.targetReps,
    required this.state,
    required this.formScore,
    required this.lockReason,
    required this.framing,
    required this.paused,
    required this.exerciseName,
    required this.trustHold,
  });

  final int roundReps;
  final String roundLabel;
  final String timeLabel;
  final int targetReps;
  final String state;
  final int formScore;
  final LockReason lockReason;
  final FramingCue framing;
  final bool paused;
  final String exerciseName;

  /// Trust-hold banner copy (null = counting live).
  final String? trustHold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top row: reps/round/time cluster + posture avatar (WS2.1).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VisionHud(
              reps: roundReps,
              round: roundLabel,
              time: timeLabel,
              targetReps: targetReps > 0 ? targetReps : null,
            ),
            const Spacer(),
            PostureAvatar(
              caption: exerciseName.toUpperCase(),
              phase: state == 'unknown'
                  ? null
                  : prettifyExerciseState(state),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // State + form chips under the row (full width, compact).
        Row(
          children: [
            Expanded(child: ExerciseStateChip(state: state)),
            const SizedBox(width: 10),
            Expanded(child: FormScoreReadout(formScore: formScore)),
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
        if (trustHold != null) ...[
          const SizedBox(height: 10),
          _TrustHoldBanner(label: trustHold!),
        ],
        if (paused) ...[
          const _PausedBanner(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Bottom floating control bar — pause/resume + cancel + end (WS2.7),
/// always reachable.
class _SessionControls extends StatelessWidget {
  const _SessionControls({
    required this.paused,
    required this.onPause,
    required this.onCancel,
    required this.onEnd,
  });

  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onCancel;
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
          icon: Icons.close,
          label: 'Cancel',
          onTap: onCancel,
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

/// Single fixed cue slot (WS2.2): the latest coaching line with warn/ok
/// color states — never stacked, never scattered.
class _CoachCueCard extends StatelessWidget {
  const _CoachCueCard({required this.text, required this.warn});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = warn ? p.amberPillFg : p.accentDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warn ? p.amberPillFg : p.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(warn ? Icons.warning_amber : Icons.volume_up,
              size: 20, color: accent),
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

/// Wrong-pose flash (WS2.5): ✕ mark, 0.8 s, severity-colored.
class _RejectFlash extends StatelessWidget {
  const _RejectFlash({required this.kind});

  /// 'tooFast' (amber) or 'range' (red).
  final String kind;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = kind == 'range' ? AppColors.danger : p.amberPillFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.close, size: 34, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              kind == 'range'
                  ? 'Not counted — go through your full range'
                  : 'Too fast — rep not counted',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round-complete tick flash (WS2.6): ✓ mark, auto-dismiss.
class _TickFlash extends StatelessWidget {
  const _TickFlash();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.glass,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00E676), width: 2.5),
      ),
      child: const Icon(Icons.check, size: 44, color: Color(0xFF00E676)),
    );
  }
}

/// All-rounds congrats sheet (WS2.6): Log → summary, Next → bonus rounds.
class _CongratsSheet extends StatelessWidget {
  const _CongratsSheet({required this.onLog, required this.onNext});

  final VoidCallback onLog;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 44, color: Color(0xFF00E676)),
          const SizedBox(height: 10),
          Text(
            'Target reached — outstanding!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Log it to the summary, or keep going for bonus reps.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.ink3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(label: 'Log', onPressed: onLog),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(label: 'Next', onPressed: onNext),
              ),
            ],
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

/// Trust-hold banner (Batch 5): why counting is frozen — the hold reason
/// surfaced instead of a silent counter.
class _TrustHoldBanner extends StatelessWidget {
  const _TrustHoldBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.amberPillFg, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: p.amberPillFg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
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
    required this.backend,
    required this.reps,
    required this.roundReps,
    required this.roundLabel,
    required this.timeLabel,
    required this.targetReps,
    required this.state,
    required this.formScore,
    required this.lockReason,
    required this.framing,
    required this.coachCue,
    required this.cueWarn,
    required this.trustHold,
    required this.paused,
    required this.readoutLeft,
    required this.readoutRight,
    required this.holdSeconds,
    required this.holdTarget,
    required this.rejectKind,
    required this.tickFlash,
    required this.showCongrats,
    required this.calibRemaining,
    required this.restRemaining,
  });

  static const _HudSnapshot initial = _HudSnapshot(
    frames: 0,
    poses: 0,
    error: null,
    lens: CameraLensDirection.front,
    backend: 'mlkit',
    reps: 0,
    roundReps: 0,
    roundLabel: '—',
    timeLabel: '00:00',
    targetReps: 0,
    state: 'unknown',
    formScore: 100,
    lockReason: LockReason.noPerson,
    framing: FramingCue.ok,
    coachCue: null,
    cueWarn: false,
    trustHold: null,
    paused: false,
    readoutLeft: null,
    readoutRight: null,
    holdSeconds: 0,
    holdTarget: 0,
    rejectKind: null,
    tickFlash: false,
    showCongrats: false,
    calibRemaining: -1,
    restRemaining: 0,
  );

  final int frames;
  final int poses;
  final String? error;
  final CameraLensDirection lens;

  /// Active pose backend (`landmarker` heavy or `mlkit` fallback).
  final String backend;
  final int reps;

  /// Reps in the current round + `current/total` round + elapsed labels.
  final int roundReps;
  final String roundLabel;
  final String timeLabel;
  final int targetReps;

  final String state;
  final int formScore;
  final LockReason lockReason;
  final FramingCue framing;
  final String? coachCue;

  /// Warn/ok color state of the cue slot.
  final bool cueWarn;

  /// Trust-hold banner copy (null = counting live).
  final String? trustHold;
  final bool paused;

  /// Exercise-aware angle readouts, preformatted (`Knee 142°`).
  final String? readoutLeft;
  final String? readoutRight;

  /// Duration hold clock + target seconds (0 = repetition exercise).
  final double holdSeconds;
  final int holdTarget;

  /// 'tooFast' | 'range' while the 0.8 s wrong-pose flash is up.
  final String? rejectKind;

  /// Round-complete tick flash + congrats sheet flags.
  final bool tickFlash;
  final bool showCongrats;

  /// Calibration countdown seconds (-1 = phase off).
  final int calibRemaining;

  /// Rest-break countdown seconds (0 = not resting).
  final int restRemaining;
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

  /// Form signal (WS6.2): -1 bad, 0 neutral, +1 good.
  int formSignal = 0;

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

  /// Form signals (WS6.2/FR-5): bad form paints the skeleton red, clean
  /// praise-worthy form paints it full chartreuse; neutral keeps the
  /// standard paint. Confidence tiers still dim shaky segments.
  static final Paint paintLineBad = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFF5252).withValues(alpha: 0.95);
  static final Paint paintLineGood = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF00E676);

  /// Batch 5 overlay tiers (port of the 39-bone 3-tier rendering):
  /// structural bones thick, appendages medium, facial detail thin.
  /// Widths scale with the canvas height (nominal 720p, like the
  /// reference) so phones and tablets render the same hierarchy.
  static final Paint paintSecond = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF00E676).withValues(alpha: 0.75);
  static final Paint paintSecondLow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFF6D00).withValues(alpha: 0.75);

  /// Hollow ring for occluded joints (Batch 5): a joint below the solid
  /// threshold still reads as "there, but hidden" rather than gone.
  static final Paint paintGhost = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = Colors.white;

  /// Dark halo under every bone (visibility hardening): the skeleton
  /// reads on any background — bright gym walls included — because the
  /// color line always sits on its own dark bed.
  static final Paint paintHaloMajor = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round
    ..color = Colors.black.withValues(alpha: 0.45);
  static final Paint paintHaloSecond = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round
    ..color = Colors.black.withValues(alpha: 0.45);
  static final Paint paintHaloDetail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..color = Colors.black.withValues(alpha: 0.45);

  /// Dark bed under joint dots (same hardening as the bone halos).
  static final Paint paintDotBed = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.black.withValues(alpha: 0.45);
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
  /// Tiered per the Batch 5 merge (structural = major, hands/feet =
  /// second, face = detail via [_face]): facial pairs live ONLY in [_face]
  /// so the jaw is drawn once, thin — never a thick double stroke.
  /// Hand links follow the reference topology (wrist→pinky→index→thumb
  /// chain + wrist→thumb); every segment is a real anatomical connection.
  static const List<(int, int)> _body = [
    // Torso: shoulders → hips
    (11, 12),
    (11, 23), (12, 24), (23, 24),
    // Left arm: shoulder → elbow → wrist → hand
    (11, 13), (13, 15), (15, 17), (17, 19), (19, 21), (15, 21),
    // Right arm
    (12, 14), (14, 16), (16, 18), (18, 20), (20, 22), (16, 22),
    // Left leg: hip → knee → ankle → heel/foot
    (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
    // Right leg
    (24, 26), (26, 28), (28, 30), (28, 32), (30, 32),
  ];

  /// Appendage bones (hands + feet) — medium tier. Everything else in
  /// [_body] is structural (thick tier).
  static const Set<(int, int)> _secondBones = {
    (15, 17), (17, 19), (19, 21), (15, 21),
    (16, 18), (18, 20), (20, 22), (16, 22),
    (27, 29), (27, 31), (29, 31),
    (28, 30), (28, 32), (30, 32),
  };

  /// Face structure: jaw line (ear → mouth → mouth → ear), eyes, nose.
  /// Nose spokes land on the eye centres (reference topology).
  static const List<(int, int)> _face = [
    (7, 9), (9, 10), (10, 8),
    (0, 9), (0, 10),
    (1, 2), (2, 3), (4, 5), (5, 6),
    (0, 2), (0, 5),
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
    // Defensive: a missing, low-confidence or non-finite joint has no
    // trustworthy position — it draws nothing, never a line to nowhere.
    final landmarks = <int, Offset>{};
    for (int i = 0; i < 33; i++) {
      final lm = pose!.landmarks[PoseLandmarkType.values[i]];
      if (lm == null || lm.likelihood < 0.3) continue;
      if (!lm.x.isFinite || !lm.y.isFinite) continue;
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

    // Body skeleton: tiered widths (structural thick, appendages medium),
    // confidence tiers (shaky segments dim), form signal overrides the
    // confident tier (WS6.2/FR-5 green/red form coloring). Every bone rides
    // on a dark halo so the full skeleton stays visible on any background.
    for (final (a, b) in _body) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      if (pa == null || pb == null) continue;
      final conf = math.min(likelihoodOf(a) ?? 0, likelihoodOf(b) ?? 0);
      final secondTier = _secondBones.contains((a, b));
      final Paint linePaint;
      if (conf < 0.5) {
        linePaint = secondTier ? paintSecondLow : paintLineLow;
      } else if (formSignal < 0) {
        linePaint = paintLineBad;
      } else if (formSignal > 0) {
        linePaint = paintLineGood;
      } else {
        linePaint = secondTier ? paintSecond : paintLine;
      }
      canvas.drawLine(pa, pb, secondTier ? paintHaloSecond : paintHaloMajor);
      canvas.drawLine(pa, pb, linePaint);
    }

    // Face jaw line + eyes (thin white on a dark bed).
    for (final (a, b) in _face) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      if (pa == null || pb == null) continue;
      canvas.drawLine(pa, pb, paintHaloDetail);
      canvas.drawLine(pa, pb, paintFace);
    }

    // Shoulder bone structure (ear → shoulder neck lines).
    for (final (a, b) in _shoulderBones) {
      final pa = landmarks[a];
      final pb = landmarks[b];
      if (pa == null || pb == null) continue;
      canvas.drawLine(pa, pb, paintHaloSecond);
      canvas.drawLine(pa, pb, paintBone);
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
      final solid = lm != null && lm.likelihood >= 0.5;
      // Dark bed first so every node reads on any background.
      canvas.drawCircle(pt, 6, paintDotBed);
      if (solid) {
        canvas.drawCircle(pt, 5, paintDot);
      } else {
        // Occluded joint: hollow ring — "there, but hidden".
        canvas.drawCircle(pt, 5, paintGhost);
      }
      if (_bigJoints.contains(i)) {
        canvas.drawCircle(pt, 9, paintAnchor); // shoulder / hip ring
      }
      // NOTE: joint index numbers used to render here (debug aid) — removed:
      // 33 white labels stamped on every joint read as clutter over the
      // lines/nodes. Live angles still show on the elbow/knee arcs above.
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.rotation != rotation ||
        oldDelegate.mirrored != mirrored ||
        oldDelegate.formSignal != formSignal;
  }
}

/// Repetition/hold targets confirmed in the pre-session editor (WS2.4).
class _Targets {
  const _Targets({
    required this.rounds,
    required this.reps,
    required this.rest,
    required this.holdSecs,
  });

  final int rounds;
  final int reps;
  final int rest;
  final int holdSecs;
}

/// Pre-session editor sheet (WS2.4): rounds + reps per round + rest
/// editable before the camera starts; duration work edits hold seconds.
class _TargetEditorSheet extends StatefulWidget {
  const _TargetEditorSheet({
    required this.definition,
    required this.initial,
    required this.isDuration,
  });

  final ExerciseDefinition definition;
  final _Targets initial;
  final bool isDuration;

  @override
  State<_TargetEditorSheet> createState() => _TargetEditorSheetState();
}

class _TargetEditorSheetState extends State<_TargetEditorSheet> {
  late int _rounds = widget.initial.rounds.clamp(1, 10);
  late int _reps = widget.initial.reps.clamp(1, 200);
  late int _rest = widget.initial.rest.clamp(0, 300);
  late int _holdSecs = widget.initial.holdSecs.clamp(10, 600);

  void _confirm() => Navigator.of(context).pop(_Targets(
        rounds: _rounds,
        reps: _reps,
        rest: _rest,
        holdSecs: _holdSecs,
      ));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.definition.displayName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isDuration
                  ? 'Set your hold target — the clock runs while you hold.'
                  : 'Set your rounds — the coach tracks each one.',
              style: TextStyle(fontSize: 13, color: p.ink3),
            ),
            const SizedBox(height: 16),
            if (widget.isDuration)
              _StepperRow(
                label: 'Hold target',
                value: '$_holdSecs s',
                onMinus: () => setState(
                    () => _holdSecs = (_holdSecs - 5).clamp(10, 600)),
                onPlus: () => setState(
                    () => _holdSecs = (_holdSecs + 5).clamp(10, 600)),
              )
            else ...[
              _StepperRow(
                label: 'Rounds',
                value: '$_rounds',
                onMinus: () =>
                    setState(() => _rounds = (_rounds - 1).clamp(1, 10)),
                onPlus: () =>
                    setState(() => _rounds = (_rounds + 1).clamp(1, 10)),
              ),
              _StepperRow(
                label: 'Reps per round',
                value: '$_reps',
                onMinus: () =>
                    setState(() => _reps = (_reps - 1).clamp(1, 200)),
                onPlus: () =>
                    setState(() => _reps = (_reps + 1).clamp(1, 200)),
              ),
              _StepperRow(
                label: 'Rest between rounds',
                value: _rest == 0 ? 'none' : '${_rest}s',
                onMinus: () =>
                    setState(() => _rest = (_rest - 5).clamp(0, 300)),
                onPlus: () =>
                    setState(() => _rest = (_rest + 5).clamp(0, 300)),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Start',
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onMinus,
          ),
          SizedBox(
            width: 64,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}
