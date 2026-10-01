import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_engine.dart show Sfx, SoundEngine;
import '../../core/constants/form_rules.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/pose/brain_engine.dart
    show BrainConfig, BrainEngine, BrainResult, FeedbackMessage, RepRejectedReason;
import '../../core/pose/pose_analyzer.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/gaps.dart';
import '../../core/theme/type.dart';
import '../../domain/models/exercise_definition.dart';
import '../../domain/models/workout.dart';
import '../workout/widgets/framing_guide.dart';
import '../workout/widgets/posture_avatar.dart';
import 'session_flow.dart';
import 'vision_hud.dart';

/// Live camera coaching screen (WS2, TODO_v1.1.11 §2).
///
/// Single full-screen surface: the camera feed fills the display and every
/// piece of information rides on top of it (HUD chips, cue bar, posture
/// avatar, framing guide, controls). There is no permanent corner preview.
/// Rest / editor / loading / round-tick / congrats are in-screen overlays —
/// no routes are pushed, so the router and DI stay untouched.
class VisionSessionScreen extends ConsumerStatefulWidget {
  const VisionSessionScreen({
    super.key,
    this.sessionId,
    this.initialExerciseId,
    this.initialRoundPlan,
    this.targetsOverride,
    this.planSessionId,
    this.missingEquipment,
  });

  final String? sessionId;
  final String? initialExerciseId;
  final RoundPlan? initialRoundPlan;
  final SessionTargets? targetsOverride;
  final String? planSessionId;
  final List<String>? missingEquipment;

  @override
  ConsumerState<VisionSessionScreen> createState() => _VisionSessionScreenState();
}

class _VisionSessionScreenState extends ConsumerState<VisionSessionScreen>
    with WidgetsBindingObserver {
  // ── session identity ────────────────────────────────────────────────
  String? _sessionId;
  String? _planSessionId;
  String? _exerciseId;
  String _exerciseName = '';
  ExerciseDefinition? _definition;
  bool _initialized = false;
  bool _starting = false;
  bool _startingRest = false;
  bool _cancelling = false;
  bool _ending = false;
  int? _setsPlannedOverride;
  List<String> _missingEquipment = const [];

  // ── targets / flow (pure logic, see session_flow.dart) ─────────────
  SessionTargets? _targets;
  final SessionFlow _flow = SessionFlow();
  bool _flowDirty = false;

  // ── HUD state ───────────────────────────────────────────────────────
  bool _isPaused = false;
  PausedState _pausedState = PausedState.running;
  String? _roundPauseLabel;
  double _formScore = 1.0;
  PoseLockState _lock = PoseLockState.searching;
  bool _inFrame = false;
  bool _personTooSmall = false;
  bool _calibrated = false;
  bool _frameHintLow = false;
  int _personCount = 0;
  double _frameQuality = 0.0;
  PoseDetectionState _detectedState = PoseDetectionState.idle;
  String? _lockReason;
  String? _hudCue; // final resolved cue (via resolveCue)
  DateTime? _hudCueAt;
  double? _leftAngle;
  double? _rightAngle;
  int? _targetAngle;
  int? _angleThreshold;
  double? _nearestTargetAngle;

  // ── timing ──────────────────────────────────────────────────────────
  int _elapsedSec = 0;
  int _restRemainingSec = 0;
  int _restTotalSec = 0;
  bool _inRest = false;
  int? _lastRepAtMs;
  bool _awaitingPostRepLock = false;
  DateTime? _lastRepAnnounceAt;
  bool _anyRepCounted = false;
  bool _awaitingFormReset = false;
  bool _frameQualityWarned = false;

  // ── popup sequencing (pure logic) ───────────────────────────────────
  final PopupSequencer _popups = PopupSequencer();
  SessionPopup? _activePopup;
  DateTime? _popupShownAt;
  Timer? _popupTimer;

  // ── timed cue (top-of-screen, transient) ────────────────────────────
  _TimedCue? _timedCue;
  Timer? _timedCueTimer;

  // ── overlays ────────────────────────────────────────────────────────
  bool _showLoading = false;
  List<String> _loadingSteps = const [];
  int _loadingStep = 0;
  bool _showEditor = false;
  int _editRound = 1;
  int _editReps = 10;
  int _editSeconds = 45;
  bool _editorAdvanced = false;
  int _editRounds = 1;
  int _editRepsTotal = 10;
  final TextEditingController _editRepsCtrl = TextEditingController();
  final TextEditingController _editSecondsCtrl = TextEditingController();
  final TextEditingController _editRoundsCtrl = TextEditingController();
  final TextEditingController _editRepsTotalCtrl = TextEditingController();

  // ── subsystems ──────────────────────────────────────────────────────
  CameraController? _camera;
  PoseAnalyzer? _analyzer;
  BrainEngine? _engine;
  StreamSubscription<PoseFrame>? _poseSub;
  Timer? _ticker;
  Timer? _pipelineDebounce;
  bool _frameInFlight = false;
  bool _pipelineBusy = false;
  bool _processingFrame = false;
  int _lastProcessedMs = 0;
  bool _disposed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionId = widget.sessionId;
    _planSessionId = widget.planSessionId;
    _exerciseId = widget.initialExerciseId;
    _missingEquipment = widget.missingEquipment ?? const [];
    _bootstrap();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _pipelineDebounce?.cancel();
    _popupTimer?.cancel();
    _timedCueTimer?.cancel();
    _poseSub?.cancel();
    _editRepsCtrl.dispose();
    _editSecondsCtrl.dispose();
    _editRoundsCtrl.dispose();
    _editRepsTotalCtrl.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding mid-session must never leave the camera running or the
    // session silently progressing: pause on the way out, stay paused on
    // return (the pause overlay owns the explicit resume).
    if (!_initialized || _error != null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_isPaused && _pausedState == PausedState.running) {
        _togglePause();
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // boot / session setup
  // ───────────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    if (!_mountedSafe) return;
    setState(() {
      _showLoading = true;
      _loadingSteps = const ['Starting session…'];
      _loadingStep = 0;
    });
    try {
      await _boot();
    } catch (e) {
      if (!_mountedSafe) return;
      setState(() {
        _showLoading = false;
        _error = 'Session could not start. $e';
      });
    }
  }

  Future<void> _boot() async {
    await _loadTargets();
    await _resolveDefinition();
    await _initCamera();
    await _startSession();
    if (!_mountedSafe) return;
    setState(() => _showLoading = false);
    // Calibration is a checkpoint, not a start gate: the first calibrated
    // rep is simply not counted (see _onRepCounted).
    if (_definition?.calibrationRequired == true) {
      _flow.markCalibrationNeeded();
      _setLockCue('Calibration: do 1–2 slow, full reps to set your range.');
    } else {
      _setLockCue(_initialCue());
    }
  }

  String _initialCue() {
    if (_personCount == 0) return 'Step back — no person detected';
    if (!_inFrame) return 'Step back until your full body is in frame';
    if (_personTooSmall) return 'Move closer — you are too small in frame';
    return 'Get into position — waiting for a clean pose lock';
  }

  bool get _mountedSafe => mounted && !_disposed;

  Future<void> _loadTargets() async {
    _targets = widget.targetsOverride;
    if (_targets != null) return;
    final repo = ref.read(planRepositoryProvider);
    if (widget.planSessionId != null) {
      try {
        final s = await repo.getSession(widget.planSessionId!);
        final plan = s?.plan;
        if (plan != null) {
          _targets = resolveTargets(
            exercises: plan.exercises,
            roundsOverride: plan.roundsOverride,
            secondsOverride: plan.secondsOverride,
          );
          _setsPlannedOverride ??= plan.roundsOverride;
          _planSessionId ??= s?.id;
        }
      } catch (_) {
        // fall through to workout-block targets
      }
    }
    _targets ??= resolveTargets(exercises: await _workoutBlocks());
  }

  Future<List<PlanExercise>> _workoutBlocks() async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final id = _exerciseId ?? '';
      Workout? w;
      if (id.isNotEmpty) {
        w = await repo.getWorkout(id);
      }
      w ??= await repo.getWorkout('foundations');
      if (w == null) return const [];
      return [
        for (final b in w.blocks)
          PlanExercise(
            exerciseId: b.exerciseId,
            rounds: b.sets,
            reps: b.reps,
            restSec: b.restSec,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _resolveDefinition() async {
    _definition = null;
    final id = _exerciseId;
    if (id != null && id.isNotEmpty) {
      _definition = exerciseCatalog[id];
      if (_definition == null) {
        try {
          final repo = ref.read(workoutRepositoryProvider);
          final w = await repo.getWorkout(id);
          if (w != null && w.blocks.isNotEmpty) {
            _exerciseId = w.blocks.first.exerciseId;
            _definition = exerciseCatalog[_exerciseId];
          }
        } catch (_) {}
      }
    }
    _definition ??= exerciseCatalog['squat'];
    _exerciseId ??= _definition?.id ?? 'squat';
    _exerciseName = prettifyExerciseId(_exerciseId!);
    _calibrated = _definition?.calibrationRequired != true;
  }

  // ───────────────────────────────────────────────────────────────────
  // camera + pose pipeline
  // ───────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    _camera = await ref.read(cameraControllerProvider.future);
    if (!_mountedSafe) return;
    if (!_camera!.value.isInitialized) {
      await _camera!.initialize();
      try {
        await _camera!.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        final caps = await _camera!.getMinExposureOffset();
        await _camera!.setExposureOffset(caps);
      } catch (_) {}
      try {
        await _camera!.startImageStream(_onCameraImage);
      } catch (_) {}
    }
    if (!_mountedSafe) return;
    setState(() {
      _showEditor = _sessionId == null && !_starting;
    });
    await _prepareAnalyzer();
  }

  Future<void> _prepareAnalyzer() async {
    final analyzer = ref.read(poseAnalyzerProvider);
    try {
      await analyzer.ensureReady();
    } catch (e) {
      if (!_mountedSafe) return;
      setState(() => _error = 'Pose model failed to load. $e');
      return;
    }
    if (_camera != null) {
      try {
        await analyzer.setTargetResolution(
          _camera!.value.previewSize?.width ?? 480,
          _camera!.value.previewSize?.height ?? 640,
        );
      } catch (_) {}
    }
    _analyzer = analyzer;
    _analyzer!.setEnabled(true);
    if (!_disposed) {
      await _analyzer!.warmUp();
    }
    if (!_mountedSafe) return;
    _poseSub = _analyzer!.frames.listen(_onPoseFrame);
    setState(() {});
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_disposed || _analyzer == null) return;
    if (_frameInFlight || _pipelineBusy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessedMs < 66) return; // ~15 fps max
    _lastProcessedMs = now;
    _frameInFlight = true;
    try {
      await _analyzer!.addFrame(image);
    } catch (_) {
      // analyzer not ready yet — drop
    } finally {
      _frameInFlight = false;
    }
  }

  void _onPoseFrame(PoseFrame frame) {
    if (!_mountedSafe || _error != null) return;
    if (!_initialized) return;
    _updateHudFromFrame(frame);
    _pipelineBusy = true;
    _pipelineDebounce?.cancel();
    _pipelineDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!_mountedSafe) return;
      _processFrame(frame);
      _pipelineBusy = false;
    });
  }

  void _updateHudFromFrame(PoseFrame frame) {
    if (frame.poseCount != _personCount) {
      setState(() => _personCount = frame.poseCount);
    }
    final pose = frame.pose;
    if (pose == null) {
      return;
    }
    final qa = _definition?.qualityAspect ?? 0.8;
    final (state, qual, tooSmall) = _analyzer!.evaluateFraming(
      pose,
      aspectQualityThreshold: qa,
    );
    final aspectOk = qual >= qa;
    final inFrame = state == FrameQualityState.ok || state == FrameQualityState.tooClose;
    final tooSmall = state == FrameQualityState.far || !aspectOk;
    final lockOk = _analyzer!.lockStateFor(pose) == PoseLockState.locked;
    setState(() {
      _inFrame = inFrame;
      _personTooSmall = tooSmall;
      _frameHintLow =
          lockOk &&
          (state == FrameQualityState.far || state == FrameQualityState.offCenter);
      _frameQuality = qual;
      _leftAngle = pose.leftBody?.joints[JointName.leftKnee]?.angleDeg;
      _rightAngle = pose.rightBody?.joints[JointName.rightKnee]?.angleDeg;
    });
  }

  void _processFrame(PoseFrame frame) {
    if (!_mountedSafe || _engine == null || _error != null) return;
    final qualityGate = _frameQuality >= FormRules.minFrameQuality;
    final result = _engine!.processFrame(
      frame,
      timestamp: DateTime.now(),
      qualityOk: qualityGate,
    );
    _frameQualityWarned = false;
    _handleResult(result);
  }

  void _handleResult(BrainResult result) {
    _formScore = result.formScore;
    _detectedState = result.detectedState;

    if (_definition?.calibrationRequired == true &&
        !_calibrated &&
        _lock == PoseLockState.locked &&
        (result.detectedState == PoseDetectionState.bottom ||
            result.detectedState == PoseDetectionState.push)) {
      _calibrated = true;
      _flow.markCalibrated();
      _showTimedCue('Range calibrated — reps now count', kind: _CueKind.success);
    }

    final cue = resolveCue(
      phase: _flow.phase,
      calibrated: _calibrated,
      lock: result.lock,
      lockReason: result.lockReason,
      personCount: result.personCount,
      inFrame: _inFrame,
      personTooSmall: _personTooSmall,
      frameHintLow: _frameHintLow,
      detectedState: result.detectedState,
      formScore: result.formScore,
      fps: result.fps,
      restRemainingSec: _restRemainingSec,
      rejection: result.repRejectedReason,
      error: result.error,
      roundLabel: _roundLabel(),
      elapsedSec: _elapsedSec,
    );
    if (cue != null && cue != _hudCue) {
      _hudCue = cue;
      _hudCueAt = DateTime.now();
    }
    _lock = result.lock;

    // A locked rep starts a single calibration rep window.
    if (!_processingFrame && _lock == PoseLockState.locked) {
      _processingFrame = true;
      if (!_anyRepCounted && _lastRepAtMs == null && _awaitingFormReset) {
        _awaitingFormReset = false;
      }
      if (_awaitingPostRepLock && _lastRepAtMs != null) {
        final since = DateTime.now().millisecondsSinceEpoch - _lastRepAtMs!;
        if (since >= 450) _awaitingPostRepLock = false;
      }
    } else if (_lock != PoseLockState.locked) {
      _processingFrame = false;
    }
    if (!_anyRepCounted && _awaitingFormReset && _formScore >= 0.75) {
      _awaitingFormReset = false;
    }

    // Rejected rep: explicit non-silent message (WS2 §2.10).
    if (result.repRejectedReason != null) {
      _onRepRejected(result.repRejectedReason!);
    }
    for (final fm in result.messages) {
      _handleFeedbackMessage(fm);
    }
    if (result.repCounted != null) {
      _onRepCounted(result.repCounted!);
    }
    final rc = result.roundCompleted;
    if (rc != null) {
      _onRoundComplete(rc);
    }
    if (result.lockGained && !_calibrated && _definition?.calibrationRequired == true) {
      _showTimedCue('Do 1–2 slow full reps to calibrate', kind: _CueKind.coach);
    }
    if (result.restEnded) {
      _onRestEnded();
    }
    if (result.formWarning != null && _lock == PoseLockState.locked) {
      _onFormWarning(result.formWarning!);
    }
    if (!_mountedSafe) return;
    setState(() {});
  }

  void _handleFeedbackMessage(FeedbackMessage msg) {
    final now = DateTime.now();
    final text = switch (msg.code) {
      'form_rep_window' => '',
      'form_too_fast' => 'Too fast — control the lowering',
      'form_pause' => 'Pause at the top',
      'form_cheat' => 'No partial reps — use the full range',
      'form_range_low' => 'Go deeper — hit full depth',
      'form_range_high' => 'Stop at parallel',
      'rep_counted' => 'Good rep',
      _ => '',
    };
    if (text.isEmpty) return;
    final isForm = msg.severity == FeedbackSeverity.warning || msg.code.startsWith('form_');
    final nowMs = now.millisecondsSinceEpoch;
    if (isForm) {
      final canShow =
          !_anyRepCounted ||
          !_awaitingFormReset ||
          _lastRepAnnounceAt == null ||
          now.difference(_lastRepAnnounceAt!).inMilliseconds > 4000;
      if (!canShow) return;
      if (_awaitingFormReset) _awaitingFormReset = false;
      _lastRepAnnounceAt = now;
      HapticFeedback.lightImpact();
      _setFormWarning(msg.code, text);
      _showTimedCue(text, kind: _CueKind.coach);
      _sfx(msg.severity);
    } else if (msg.severity == FeedbackSeverity.positive) {
      if (nowMs - _lastRepAnnounceAt!.millisecondsSinceEpoch < 900) return;
      _lastRepAnnounceAt = now;
      HapticFeedback.lightImpact();
      _setLockCue(text);
      _sfx(Sfx.positive);
    } else if (msg.severity == FeedbackSeverity.info) {
      if (_anyRepCounted && _lock != PoseLockState.locked) {
        _lastRepAnnounceAt = now;
        _setLockCue(text);
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // session lifecycle
  // ───────────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    if (_starting) return;
    _starting = true;
    try {
      if (_sessionId == null) {
        final createSession = ref.read(startSessionProvider);
        final created = await createSession(
          exerciseId: _exerciseId!,
          sets: _setsPlannedOverride,
          planSessionId: _planSessionId,
          equipment: _missingEquipment.isEmpty ? null : _missingEquipment,
        );
        if (!_mountedSafe) return;
        _sessionId = created;
      } else {
        await _resumeSession();
      }
      if (!_mountedSafe) return;
      final repTarget = _targets?.repTargetFor(_exerciseId!) ?? 10;
      final seconds = _targets?.secondsFor(_exerciseId!) ?? 45;
      final roundPlan = widget.initialRoundPlan ??
          RoundPlan(
            round: 1,
            rounds: _targets?.rounds ?? 1,
            repsTarget: repTarget,
            seconds: seconds,
            restSec: _targets?.restSec ?? 45,
          );
      _flow.start(
        roundPlan: roundPlan,
        totalRounds: roundPlan.rounds,
        calibrated: _calibrated,
      );
      if (!_mountedSafe) return;
      final def = _definition;
      if (def == null) {
        setState(() => _error = 'Exercise definition not found: $_exerciseId');
        return;
      }
      final engineCfg = BrainConfig(
        exercise: def,
        bilateral: def.bilateral,
        mirror: true,
        minRepDuration: def.minRepDuration,
        triggerState: def.triggerState,
        priorState: def.priorState,
        restSec: _targets?.restSec ?? 45,
        totalRounds: roundPlan.rounds,
        minRepAngle: def.minRepAngle,
        maxRepAngle: def.maxRepAngle,
        targetAngle: def.targetAngle,
        setsPlannedOverride: roundPlan.rounds,
        feedbackSecPerRep: def.feedbackSecPerRep,
        setRepTarget: roundPlan.repsTarget,
        calibrationEnabled: def.calibrationRequired == true,
      );
      _engine = BrainEngine(engineCfg);
      _lastRepAtMs = null;
      _lastRepAnnounceAt = null;
      _processingFrame = false;
      _awaitingPostRepLock = false;
      _awaitingFormReset = false;
      _anyRepCounted = false;
      _isPaused = false;
      _pausedState = PausedState.running;
      _initialized = true;
      _tick();
      setState(() {});
    } finally {
      _starting = false;
    }
  }

  /// Restore counters for a resumed (crashed / restarted) session.
  Future<void> _resumeSession() async {
    if (_sessionId == null) return;
    final repo = ref.read(sessionRepositoryProvider);
    try {
      final s = await repo.getActiveSession();
      if (s == null || s.id != _sessionId || s.exercises.isEmpty) return;
      final ex = s.exercises.firstWhere(
        (e) => e.exerciseId == _exerciseId,
        orElse: () => s.exercises.first,
      );
      _exerciseId = ex.exerciseId;
      await _resolveDefinition();
      final plan = RoundPlan(
        round: (ex.roundsCompleted + 1).clamp(1, ex.roundsPlanned > 0 ? ex.roundsPlanned : 1),
        rounds: ex.roundsPlanned > 0 ? ex.roundsPlanned : 1,
        repsTarget: ex.repsPerRound > 0 ? ex.repsPerRound : 10,
        seconds: ex.repsPerRound > 0 ? ex.repsPerRound : 10,
        restSec: ex.restSec,
      );
      _flow.restore(
        roundPlan: plan,
        repsInRound: ex.repsThisRound,
        totalReps: ex.totalReps,
        roundsCompleted: ex.roundsCompleted,
        calibrated: ex.calibrationCompleted || _definition?.calibrationRequired != true,
        restRemainingSec: ex.remainingRestSec,
        elapsedSec: ex.elapsedSec,
      );
      if (!_mountedSafe) return;
      setState(() {
        _isPaused = ex.status == SessionStatus.paused;
        _restRemainingSec = ex.remainingRestSec;
        _restTotalSec = ex.restSec;
        _inRest = ex.remainingRestSec > 0;
        _elapsedSec = ex.elapsedSec;
        _anyRepCounted = ex.totalReps > 0;
        _pausedState = _isPaused ? PausedState.cancelConfirm : PausedState.running;
        _roundPauseLabel = null;
      });
    } catch (_) {
      // resume is best-effort; a fresh flow still works
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // event handlers (rep / round / rest / complete)
  // ───────────────────────────────────────────────────────────────────

  void _onRepCounted(int total) {
    final event = _flow.registerRep(DateTime.now(), total: total);
    _anyRepCounted = true;
    _lastRepAtMs = DateTime.now().millisecondsSinceEpoch;
    _awaitingPostRepLock = true;
    _awaitingFormReset = true;
    _lastRepAnnounceAt = DateTime.now();
    if (event == RepEvent.ignoredDuringRest) {
      // Never silent: reps done during rest are refused with a reason.
      _showTimedCue('Resting — reps do not count now', kind: _CueKind.coach);
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    _sfx(Sfx.count);
    _flowDirty = true;
    _setLockCue('Good rep — ${_flow.repsLabel()}');
    _audioCount(total);
    if (!_mountedSafe) return;
    setState(() {});
  }

  void _onCalibrationRep(int total) {
    // Calibration reps never count toward the target (WS2 §2.4).
    _anyRepCounted = true;
    _lastRepAtMs = DateTime.now().millisecondsSinceEpoch;
    _awaitingPostRepLock = true;
    _lastRepAnnounceAt = DateTime.now();
    HapticFeedback.selectionClick();
    _showTimedCue('Calibration rep — not counted', kind: _CueKind.coach);
    if (!_mountedSafe) return;
    setState(() {});
  }

  void _onRepRejected(RepRejectedReason reason) {
    final cue = rejectionCueFor(reason);
    HapticFeedback.lightImpact();
    _sfx(Sfx.reject);
    _showTimedCue(cue, kind: _CueKind.reject);
    _setFormWarning(reason.name, cue);
  }

  void _onRoundComplete(RoundPlan? next) {
    if (!_mountedSafe) return;
    HapticFeedback.mediumImpact();
    _sfx(Sfx.roundTick);
    _flowDirty = true;
    final roundNum = _flow.roundNumber;
    _popups.push(SessionPopup.roundTick(label: _roundLabel(), sub: _roundTickSub()));
    if (_flow.phase == FlowPhase.done) {
      _onSessionComplete();
      return;
    }
    setState(() {
      _startingRest = true;
      _inRest = true;
      _restTotalSec = _flow.restRemaining;
      _restRemainingSec = _flow.restRemaining;
      _roundPauseLabel = 'Round $roundNum complete';
    });
    _persistRest();
    _audioRest(_flow.restRemaining);
    _flushIfDirty();
  }

  String _roundTickSub() {
    final done = _flow.roundsCompleted;
    final total = _flow.totalRounds;
    return 'Round $done of $total complete';
  }

  void _onRestEnded() {
    _popups.push(const SessionPopup.congrats());
    _skipRest();
  }

  void _skipRest() {
    if (!_inRest) return;
    _flow.skipRest(DateTime.now());
    _popups.dismissRestRelated();
    if (!_mountedSafe) return;
    setState(() {
      _inRest = false;
      _startingRest = false;
      _restRemainingSec = 0;
      _restTotalSec = 0;
      _roundPauseLabel = null;
      _pausedState = PausedState.running;
      _isPaused = false;
      _hudCue = _initialCue();
    });
    _flushIfDirty();
  }

  void _onSessionComplete() {
    _popups.push(SessionPopup.congrats());
    _sfx(Sfx.success);
    _flushIfDirty(force: true);
    _confirmEndSession(auto: true);
  }

  void _onFormWarning(String code) {
    HapticFeedback.lightImpact();
    _sfx(Sfx.warning);
    _showTimedCue(_formWarningText(code), kind: _CueKind.warn);
    _setFormWarning(code, _formWarningText(code));
  }

  String _formWarningText(String code) {
    return switch (code) {
      'knee_valgus' => 'Push knees out over toes',
      'depth' => 'Go deeper — hit full depth',
      'forward_lean' => 'Chest up — reduce forward lean',
      'heel_rise' => 'Keep heels on the floor',
      'back_round' => 'Keep a neutral spine',
      'elbow_flare' => 'Elbows tucked',
      'shrug' => 'Shoulders down and back',
      'rep_too_fast' => 'Slow down — control the lowering',
      _ => 'Check your form',
    };
  }

  // ───────────────────────────────────────────────────────────────────
  // persistence (batched; only on round/rest/session transitions)
  // ───────────────────────────────────────────────────────────────────

  void _flushIfDirty({bool force = false}) {
    if (!force && !_flowDirty) return;
    _flowDirty = false;
    _persistRest();
  }

  Future<void> _persistRest() async {
    if (_sessionId == null) return;
    try {
      final repo = ref.read(sessionRepositoryProvider);
      await repo.saveSnapshot(
        sessionId: _sessionId!,
        exerciseId: _exerciseId!,
        roundsCompleted: _flow.roundsCompleted,
        repsThisRound: _flow.repsInRound,
        totalReps: _flow.repsTotal,
        elapsedSec: _elapsedSec,
        restSec: _restTotalSec,
        remainingRestSec: _inRest ? _restRemainingSec : 0,
        roundTimesSec: _flow.roundTimesSec,
        perRepTimesSec: _flow.perRepTimesSec,
        status: _isPaused ? SessionStatus.paused : SessionStatus.active,
        calibrationCompleted: _calibrated,
        mood: _flow.phase == FlowPhase.done ? 'complete' : null,
        targetCompletion:
            _flow.totalRounds > 0 ? _flow.roundsCompleted / _flow.totalRounds : null,
      );
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────
  // controls: pause / resume / cancel / end
  // ───────────────────────────────────────────────────────────────────

  void _togglePause() {
    if (_flow.phase == FlowPhase.done) return;
    HapticFeedback.lightImpact();
    if (_isPaused) {
      _resumeFromPause();
    } else {
      setState(() {
        _isPaused = true;
        _pausedState = _inRest ? PausedState.restPause : PausedState.running;
        _roundPauseLabel ??= _roundLabel();
      });
      _persistRest();
    }
  }

  void _resumeFromPause() {
    if (_pausedState == PausedState.cancelConfirm) {
      // stay in the confirm state until resolved
      return;
    }
    setState(() {
      _isPaused = false;
      _pausedState = PausedState.running;
      _roundPauseLabel = null;
    });
    _persistRest();
  }

  void _backToRunning() {
    setState(() => _pausedState = PausedState.running);
  }

  void _requestCancel() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPaused = true;
      _pausedState = PausedState.cancelConfirm;
    });
  }

  Future<void> _confirmCancel() async {
    if (_cancelling) return;
    _cancelling = true;
    try {
      if (_sessionId != null) {
        try {
          await ref.read(sessionRepositoryProvider).clearActive();
        } catch (_) {}
      }
      _showTimedCue('Session cancelled — no credit', kind: _CueKind.coach);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      _cancelling = false;
    }
  }

  void _requestEnd() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPaused = true;
      _pausedState = PausedState.endConfirm;
      _roundPauseLabel ??= _roundLabel();
    });
  }

  Future<void> _confirmEndSession({bool auto = false}) async {
    if (_ending) return;
    _ending = true;
    try {
      await _endSession(auto: auto);
    } finally {
      _ending = false;
    }
  }

  Future<void> _endSession({required bool auto}) async {
    _ticker?.cancel();
    if (_sessionId == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    final repo = ref.read(sessionRepositoryProvider);
    Session? latest;
    try {
      latest = await repo.getActiveSession();
    } catch (_) {}
    final now = DateTime.now();
    final exercises = latest?.exercises.isNotEmpty == true ? latest!.exercises : <SessionExercise>[];
    SessionExercise? completed;
    if (exercises.isEmpty) {
      completed = SessionExercise(
        exerciseId: _exerciseId ?? 'squat',
        roundsPlanned: _flow.totalRounds,
        roundsCompleted: _flow.roundsCompleted,
        repsPerRound: _targets?.repTargetFor(_exerciseId ?? 'squat') ?? 10,
        repsThisRound: _flow.repsInRound,
        totalReps: _flow.repsTotal,
        avgFormScore: _formScore,
        restSec: _restTotalSec,
        remainingRestSec: 0,
        startedAt: latest?.startedAt ?? now,
        completedAt: now,
        calibrationCompleted: _calibrated,
        roundTimesSec: _flow.roundTimesSec,
        perRepTimesSec: _flow.perRepTimesSec,
        elapsedSec: _elapsedSec,
        status: SessionStatus.completed,
      );
    } else {
      completed = exercises.map((e) {
        if (e.exerciseId != _exerciseId) return e;
        return e.copyWith(
          roundsCompleted: _flow.roundsCompleted > 0 ? _flow.roundsCompleted : e.roundsCompleted,
          repsThisRound: _flow.repsInRound > 0 ? _flow.repsInRound : e.repsThisRound,
          totalReps: _flow.repsTotal > 0 ? _flow.repsTotal : e.totalReps,
          avgFormScore: _formScore,
          remainingRestSec: 0,
          completedAt: now,
          status: SessionStatus.completed,
          calibrationCompleted: _calibrated,
          roundTimesSec: _flow.roundTimesSec.isNotEmpty ? _flow.roundTimesSec : e.roundTimesSec,
          perRepTimesSec: _flow.perRepTimesSec.isNotEmpty ? _flow.perRepTimesSec : e.perRepTimesSec,
          elapsedSec: _elapsedSec > 0 ? _elapsedSec : e.elapsedSec,
        );
      }).toList();
      completed = completed.isEmpty ? exercises : completed;
    }
    final totalReps = _flow.repsTotal;
    final completedSession = (latest ?? Session.empty()).copyWith(
      id: _sessionId,
      exercises: exercises.isEmpty ? completed : completed,
      durationSec: _elapsedSec,
      totalReps: totalReps,
      endedAt: now,
      status: auto ? SessionStatus.completed : SessionStatus.completed,
    );
    try {
      await repo.saveSnapshot(
        sessionId: _sessionId!,
        exerciseId: _exerciseId ?? completed.first.exerciseId,
        roundsCompleted: _flow.roundsCompleted,
        repsThisRound: _flow.repsInRound,
        totalReps: totalReps,
        elapsedSec: _elapsedSec,
        restSec: 0,
        remainingRestSec: 0,
        roundTimesSec: _flow.roundTimesSec,
        perRepTimesSec: _flow.perRepTimesSec,
        status: SessionStatus.completed,
        calibrationCompleted: _calibrated,
        mood: 'complete',
        targetCompletion:
            _flow.totalRounds > 0 ? _flow.roundsCompleted / _flow.totalRounds : null,
      );
      await ref.read(endSessionProvider)(completedSession);
    } catch (_) {}
    if (mounted) Navigator.of(context).maybePop();
  }

  // ───────────────────────────────────────────────────────────────────
  // editor (in-screen overlay; no route)
  // ───────────────────────────────────────────────────────────────────

  void _openEditor() {
    HapticFeedback.lightImpact();
    final targets = _targets;
    final def = _definition;
    final rt = targets?.repTargetFor(_exerciseId ?? '') ?? 10;
    final secs = targets?.secondsFor(_exerciseId ?? '') ?? 45;
    setState(() {
      _editorAdvanced = def?.timed ?? false;
      _editRound = _flow.roundNumber;
      _editReps = _targets?.repTargetFor(_exerciseId ?? '') ?? rt;
      _editSeconds = secs;
      _editRounds = _targets?.rounds ?? 1;
      _editRepsTotal = _targets?.repTargetTotal ?? rt;
      _editRepsCtrl.text = '${_editorAdvanced ? _editSeconds : _editReps}';
      _editRoundsCtrl.text = '$_editRounds';
      _editRepsTotalCtrl.text = '$_editRepsTotal';
      _editSecondsCtrl.text = '$_editSeconds';
      _showEditor = true;
      _isPaused = true;
      _pausedState = PausedState.running;
    });
  }

  void _closeEditor({required bool apply}) {
    if (apply) {
      final advanced = _editorAdvanced;
      final reps = int.tryParse(_editRepsCtrl.text) ?? _editReps;
      final secs = int.tryParse(_editSecondsCtrl.text) ?? _editSeconds;
      final rounds = int.tryParse(_editRoundsCtrl.text) ?? _editRounds;
      final repsTotal = int.tryParse(_editRepsTotalCtrl.text) ?? _editRepsTotal;
      if (advanced) {
        _editSeconds = secs.clamp(5, 600);
        _editReps = _editSeconds;
      } else {
        _editReps = reps.clamp(1, 100);
        _editRepsTotal = repsTotal.clamp(1, 500);
        _editRound = _editRound.clamp(1, (_editRepsTotal / _editReps).ceil().clamp(1, 100));
      }
      _editRounds = rounds.clamp(1, 100);
      final next = RoundPlan(
        round: _editRound.clamp(1, _editRounds),
        rounds: _editRounds,
        repsTarget: _editReps,
        seconds: _editSeconds,
        restSec: _targets?.restSec ?? 45,
      );
      _flow.applyPlan(next, calibrated: _calibrated);
      _targets = _targets?.copyWith(
        rounds: _editRounds,
        repTarget: _editReps,
        repTargetTotal: _editRepsTotal,
        seconds: _editSeconds,
      );
      _engine?.applyPlan(next);
      _restTotalSec = next.restSec;
      HapticFeedback.lightImpact();
      _showTimedCue('Targets updated — ${_roundLabel()}', kind: _CueKind.coach);
      _flushIfDirty(force: true);
    }
    setState(() {
      _showEditor = false;
      _isPaused = false;
      _pausedState = PausedState.running;
    });
  }

  // ───────────────────────────────────────────────────────────────────
  // overlays + audio helpers
  // ───────────────────────────────────────────────────────────────────

  void _showPopup(SessionPopup popup) {
    _popups.push(popup);
  }

  void _showTimedCue(String text, {_CueKind kind = _CueKind.coach}) {
    if (!_mountedSafe) return;
    setState(() {
      _timedCue = _TimedCue(text: text, kind: kind, at: DateTime.now());
    });
    _timedCueTimer?.cancel();
    _timedCueTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!_mountedSafe) return;
      setState(() => _timedCue = null);
    });
  }

  void _setLockCue(String text) {
    if (!_mountedSafe) return;
    setState(() {
      _hudCue = text;
      _hudCueAt = DateTime.now();
    });
  }

  void _setFormWarning(String code, String text) {
    if (!_mountedSafe) return;
    setState(() {
      _hudCue = text;
      _hudCueAt = DateTime.now();
    });
  }

  void _sfx(Sfx s) {
    try {
      ref.read(soundEngineProvider).play(s);
    } catch (_) {}
  }

  void _audioCount(int n) {
    try {
      ref.read(sessionAudioProvider).repCount(n);
    } catch (_) {}
  }

  void _audioRest(int sec) {
    try {
      ref.read(sessionAudioProvider).restStart(sec);
    } catch (_) {}
  }

  void _audioRoundTick(int round) {
    try {
      ref.read(sessionAudioProvider).roundTick(round);
    } catch (_) {}
    try {
      ref.read(soundEngineProvider).play(Sfx.roundTick);
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────
  // ticker
  // ───────────────────────────────────────────────────────────────────

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_mountedSafe || _isPaused || _error != null) return;
      setState(() {
        if (_inRest && _restRemainingSec > 0) {
          _restRemainingSec--;
          _flow.tickRest(_restRemainingSec);
          if (_restRemainingSec == 3 || _restRemainingSec == 2 || _restRemainingSec == 1) {
            _sfx(Sfx.tick);
          }
          if (_restRemainingSec <= 0) {
            _inRest = false;
            _startingRest = false;
            _restTotalSec = 0;
            _roundPauseLabel = null;
            _hudCue = 'Get ready — next round';
            _flow.skipRest(DateTime.now());
            _audioRoundTick(_flow.roundNumber);
            _flushIfDirty(force: true);
          }
        } else {
          _elapsedSec++;
          _flow.addSecond();
        }
      });
      _flushIfDirty();
    });
  }

  // ───────────────────────────────────────────────────────────────────
  // build
  // ───────────────────────────────────────────────────────────────────

  String _roundLabel() => _flow.roundLabel();
  String _repsLabel() => _flow.repsLabel();

  @override
  Widget build(BuildContext context) {
    final cue = _hudCue ?? 'Get into position';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _buildCameraPreview()),
            if (_error != null)
              Center(
                child: Padding(
                  padding: Insets.padH20,
                  child: _ErrorCard(
                    message: _error!,
                    onRetry: () {
                      setState(() {
                        _error = null;
                        _initialized = false;
                      });
                      _bootstrap();
                    },
                  ),
                ),
              )
            else ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: FramingGuide(
                    inFrame: _inFrame && !_personTooSmall,
                    lock: _lock,
                    hintLow: _frameHintLow,
                    personCount: _personCount,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  onBack: () => Navigator.of(context).maybePop(),
                  onEditor: _openEditor,
                  onRestart: _requestCancel,
                  elapsedLabel: formatClock(_elapsedSec),
                ),
              ),
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: SessionHud(
                  reps: _repsLabel(),
                  round: _roundLabel(),
                  time: formatClock(_elapsedSec),
                ),
              ),
              if (_timedCue != null)
                Positioned(
                  top: 110,
                  left: 0,
                  right: 0,
                  child: _TimedCueBanner(cue: _timedCue!),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_lock != PoseLockState.locked && !_isPaused && _error == null)
                      Padding(
                        padding: Insets.padH16,
                        child: lockReasonLine(
                          lock: _lock,
                          reason: _lockReason,
                          message: cue,
                        ),
                      ),
                    if (_lock == PoseLockState.locked && _error == null)
                      Padding(
                        padding: Insets.padH16,
                        child: _CueBar(cue: cue),
                      ),
                    if (_inRest && !_isPaused)
                      Padding(
                        padding: Insets.padH16,
                        child: _RestBanner(
                          seconds: _restRemainingSec,
                          total: _restTotalSec,
                          onSkip: _skipRest,
                        ),
                      ),
                    if (!_isPaused && !_inRest)
                      Padding(
                        padding: Insets.padH16,
                        child: _SessionControls(
                          onEnd: _requestEnd,
                          onEditor: _openEditor,
                          onCalibrate: () {
                            _showTimedCue(
                              'Do 1–2 slow, full reps to set your range',
                              kind: _CueKind.coach,
                            );
                          },
                        ),
                      ),
                    if (_isPaused)
                      Padding(
                        padding: Insets.padH16,
                        child: _PausedBanner(
                          state: _pausedState,
                          roundLabel: _roundPauseLabel ?? _roundLabel(),
                          repsLabel: _repsLabel(),
                          onResume: _resumeFromPause,
                          onCancel: _requestCancel,
                          onConfirmCancel: _confirmCancel,
                          onEnd: _requestEnd,
                          onConfirmEnd: () => _confirmEndSession(),
                          onBack: _backToRunning,
                        ),
                      ),
                    Gap.h8,
                  ],
                ),
              ),
              // Posture avatar, bottom-left, on top of the camera feed.
              Positioned(
                left: 16,
                bottom: 168,
                child: IgnorePointer(
                  child: PostureAvatar(
                    lock: _lock,
                    detectedState: _detectedState,
                    formScore: _formScore,
                    leftAngle: _leftAngle,
                    rightAngle: _rightAngle,
                    targetAngle: _nearestTargetAngle ?? _targetAngle,
                    threshold: _frameQuality >= FormRules.minFrameQuality ? _angleThreshold : null,
                    width: 84,
                  ),
                ),
              ),
            ],
            // overlays ── rest / round tick / congrats / editor / loading
            ..._buildOverlays(cue),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF101114));
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: cam.value.previewSize?.height ?? 640,
        height: cam.value.previewSize?.width ?? 480,
        child: CameraPreview(cam),
      ),
    );
  }

  List<Widget> _buildOverlays(String cue) {
    final widgets = <Widget>[];
    final popup = _activePopup;
    if (popup != null) {
      widgets.add(
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.8),
            child: Center(
              child: switch (popup.type) {
                PopupType.roundTick => _RoundTickPopup(popup: popup),
                PopupType.congrats => _CongratsPanel(
                  onContinue: () {
                    _popups.dismissRestRelated();
                    if (_flow.phase == FlowPhase.done) {
                      _confirmEndSession();
                    }
                    setState(() => _activePopup = null);
                  },
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      );
    }
    if (_showEditor) {
      widgets.add(
        Positioned.fill(
          child: _EditorOverlay(
            advanced: _editorAdvanced,
            roundCtrl: _editRepsCtrl,
            secondsCtrl: _editSecondsCtrl,
            roundsCtrl: _editRoundsCtrl,
            repsTotalCtrl: _editRepsTotalCtrl,
            onCancel: () => _closeEditor(apply: false),
            onApply: () => _closeEditor(apply: true),
          ),
        ),
      );
    }
    if (_showLoading) {
      widgets.add(
        Positioned.fill(
          child: _LoadingOverlay(steps: _loadingSteps, current: _loadingStep),
        ),
      );
    }
    return widgets;
  }

  // ───────────────────────────────────────────────────────────────────
  // popup sequencer pump
  // ───────────────────────────────────────────────────────────────────

  void _pumpPopups() {
    if (_activePopup != null) {
      final held = _popupShownAt != null
          ? DateTime.now().difference(_popupShownAt!).inMilliseconds
          : 0;
      final hold = _activePopup!.type == PopupType.roundTick
          ? PopupSequencer.roundTickHold
          : PopupSequencer.wrongPoseHold;
      if (held < hold) return;
      _activePopup = null;
      _popupShownAt = null;
    }
    final next = _popups.next();
    if (next == null) return;
    _activePopup = next;
    _popupShownAt = DateTime.now();
  }
}

// ═════════════════════════════════════════════════════════════════════
// widgets
// ═════════════════════════════════════════════════════════════════════

enum _CueKind { coach, warn, reject, success }

class _TimedCue {
  _TimedCue({required this.text, required this.kind, required this.at});
  final String text;
  final _CueKind kind;
  final DateTime at;
}

class _TimedCueBanner extends StatelessWidget {
  const _TimedCueBanner({required this.cue});
  final _TimedCue cue;

  @override
  Widget build(BuildContext context) {
    final color = switch (cue.kind) {
      _CueKind.warn => AppColors.danger,
      _CueKind.reject => AppColors.danger,
      _CueKind.success => AppColors.ok,
      _CueKind.coach => AppColors.accent,
    };
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: Radii.r12,
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        ),
        child: Text(
          cue.text,
          style: Type.bodySm.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            shadows: [const Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onEditor,
    required this.onRestart,
    required this.elapsedLabel,
  });

  final VoidCallback onBack;
  final VoidCallback onEditor;
  final VoidCallback onRestart;
  final String elapsedLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Back',
          ),
          const Spacer(),
          Text(
            elapsedLabel,
            style: Type.bodySm.copyWith(
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onEditor,
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Adjust targets',
          ),
          IconButton(
            onPressed: onRestart,
            icon: const Icon(Icons.restart_alt, color: Colors.white),
            tooltip: 'Restart',
          ),
        ],
      ),
    );
  }
}

class _CueBar extends StatelessWidget {
  const _CueBar({required this.cue});
  final String cue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: Radii.r12,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        cue,
        textAlign: TextAlign.center,
        style: Type.bodySm.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.seconds, required this.total, required this.onSkip});
  final int seconds;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (total - seconds) / total : 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: Radii.r14,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'REST — ${seconds}s',
                style: Type.bodySm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: Radii.r8,
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          Gap.h6,
          ClipRRect(
            borderRadius: Radii.r4,
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          Gap.h6,
          const Text(
            'Ready for next round',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SessionControls extends StatelessWidget {
  const _SessionControls({
    required this.onEnd,
    required this.onEditor,
    required this.onCalibrate,
  });

  final VoidCallback onEnd;
  final VoidCallback onEditor;
  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(label: 'End', icon: Icons.stop, onTap: onEnd),
        Gap.w12,
        _ControlBtn(label: 'Targets', icon: Icons.tune, onTap: onEditor),
        Gap.w12,
        _ControlBtn(label: 'Calibrate', icon: Icons.center_focus_strong, onTap: onCalibrate),
      ],
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: Radii.r10,
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            Gap.h2,
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner({
    required this.state,
    required this.roundLabel,
    required this.repsLabel,
    required this.onResume,
    required this.onCancel,
    required this.onConfirmCancel,
    required this.onEnd,
    required this.onConfirmEnd,
    required this.onBack,
  });

  final PausedState state;
  final String roundLabel;
  final String repsLabel;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onConfirmCancel;
  final VoidCallback onEnd;
  final VoidCallback onConfirmEnd;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isConfirm = state == PausedState.cancelConfirm || state == PausedState.endConfirm;
    final title = switch (state) {
      PausedState.cancelConfirm => 'Cancel session?',
      PausedState.endConfirm => 'End session?',
      PausedState.restPause => 'Rest paused',
      _ => 'Paused',
    };
    final body = switch (state) {
      PausedState.cancelConfirm =>
        'Your progress will be discarded — no credit is given for a cancelled session.',
      PausedState.endConfirm => 'End now and keep your progress: $roundLabel · $repsLabel.',
      _ => roundLabel,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: Radii.r14,
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Type.hSm.copyWith(color: Colors.white)),
          Gap.h6,
          Text(
            body,
            textAlign: TextAlign.center,
            style: Type.bodySm.copyWith(color: Colors.white70),
          ),
          Gap.h12,
          if (state == PausedState.cancelConfirm || state == PausedState.endConfirm)
            Row(
              children: [
                Expanded(
                  child: _DialogBtn(
                    label: 'Back',
                    onTap: onBack,
                    filled: false,
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: _DialogBtn(
                    label: state == PausedState.cancelConfirm ? 'Cancel session' : 'End now',
                    onTap: state == PausedState.cancelConfirm ? onConfirmCancel : onConfirmEnd,
                    filled: true,
                    danger: state == PausedState.cancelConfirm,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _DialogBtn(label: 'Resume', onTap: onResume, filled: true),
                ),
                Gap.w12,
                Expanded(
                  child: _DialogBtn(label: 'End', onTap: onEnd, filled: false),
                ),
                Gap.w12,
                Expanded(
                  child: _DialogBtn(label: 'Cancel', onTap: onCancel, filled: false, danger: true),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn({
    required this.label,
    required this.onTap,
    required this.filled,
    this.danger = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppColors.danger : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? bg : Colors.transparent,
          borderRadius: Radii.r10,
          border: Border.all(color: filled ? bg : Colors.white30),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17181D),
        borderRadius: Radii.r16,
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
          Gap.h12,
          Text(message, textAlign: TextAlign.center, style: Type.bodySm),
          Gap.h16,
          _DialogBtn(label: 'Retry', onTap: onRetry, filled: true),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.steps, required this.current});
  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Padding(
          padding: Insets.padH32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      if (i < current)
                        const Icon(Icons.check, size: 16, color: AppColors.ok)
                      else if (i == current)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)
                        )
                      else
                        const Icon(Icons.circle_outlined, size: 16, color: Colors.white30),
                      Gap.w8,
                      Text(
                        steps[i],
                        style: Type.bodySm.copyWith(
                          color: i <= current ? Colors.white : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundTickPopup extends StatelessWidget {
  const _RoundTickPopup({required this.popup});
  final SessionPopup popup;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          popup.label ?? '',
          style: Type.hLg.copyWith(
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 16, color: Colors.black54)],
          ),
        ),
        if (popup.sub != null) ...[
          Gap.h8,
          Text(
            popup.sub!,
            style: Type.bodySm.copyWith(color: Colors.white70),
          ),
        ],
      ],
    );
  }
}

class _CongratsPanel extends StatelessWidget {
  const _CongratsPanel({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: Insets.padH20,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF17181D),
        borderRadius: Radii.r16,
        border: Border.all(color: AppColors.ok.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: AppColors.ok, size: 40),
          Gap.h12,
          Text('Round complete!', style: Type.hSm.copyWith(color: Colors.white)),
          Gap.h8,
          Text(
            'Nice work — keep it up.',
            textAlign: TextAlign.center,
            style: Type.bodySm.copyWith(color: Colors.white70),
          ),
          Gap.h16,
          _DialogBtn(label: 'Continue', onTap: onContinue, filled: true),
        ],
      ),
    );
  }
}

class _EditorOverlay extends StatelessWidget {
  const _EditorOverlay({
    required this.advanced,
    required this.roundCtrl,
    required this.secondsCtrl,
    required this.roundsCtrl,
    required this.repsTotalCtrl,
    required this.onCancel,
    required this.onApply,
  });

  final bool advanced;
  final TextEditingController roundCtrl;
  final TextEditingController secondsCtrl;
  final TextEditingController roundsCtrl;
  final TextEditingController repsTotalCtrl;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Container(
          margin: Insets.padH20,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF17181D),
            borderRadius: Radii.r16,
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adjust targets', style: Type.hSm.copyWith(color: Colors.white)),
              Gap.h12,
              if (advanced)
                _StepperRow(
                  label: 'Seconds per round',
                  ctrl: secondsCtrl,
                  onChanged: () {},
                )
              else ...[
                _StepperRow(label: 'Reps this round', ctrl: roundCtrl, onChanged: () {}),
                Gap.h8,
                _StepperRow(label: 'Reps total', ctrl: repsTotalCtrl, onChanged: () {}),
              ],
              Gap.h8,
              _StepperRow(label: 'Rounds', ctrl: roundsCtrl, onChanged: () {}),
              Gap.h16,
              Row(
                children: [
                  Expanded(child: _DialogBtn(label: 'Cancel', onTap: onCancel, filled: false)),
                  Gap.w12,
                  Expanded(child: _DialogBtn(label: 'Apply', onTap: onApply, filled: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.label, required this.ctrl, required this.onChanged});
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Type.bodySm.copyWith(color: Colors.white70))),
        _StepBtn(
          icon: Icons.remove,
          onTap: () {
            final v = int.tryParse(ctrl.text) ?? 1;
            ctrl.text = '${(v - 1).clamp(1, 600)}';
            onChanged();
          },
        ),
        Gap.w8,
        SizedBox(
          width: 48,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: Type.bodySm.copyWith(color: Colors.white),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
        ),
        Gap.w8,
        _StepBtn(
          icon: Icons.add,
          onTap: () {
            final v = int.tryParse(ctrl.text) ?? 1;
            ctrl.text = '${(v + 1).clamp(1, 600)}';
            onChanged();
          },
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: Radii.r6,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
