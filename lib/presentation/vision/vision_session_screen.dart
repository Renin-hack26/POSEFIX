import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/pose/exercise_definition.dart';
import '../../core/pose/pose_analyzer.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../engines/session_audio/session_audio_cues.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import 'vision_hud.dart';

/// Live workout vision screen: back-camera preview + [PoseAnalyzer] rep
/// counting with spoken coaching. No skeleton overlay — per-frame landmarks
/// are not exposed, so nothing is faked on top of the preview.
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
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  bool _initializing = true;
  bool _permissionDenied = false;
  String? _cameraError;
  bool _ready = false;
  bool _paused = false;
  bool _inFlight = false;
  bool _disposed = false;

  /// Last lock reason seen — powers the speak-once notice when a played
  /// video (instead of the user) is detected.
  LockReason _lastLockReason = LockReason.ok;

  int _reps = 0;
  String _state = 'unknown';
  int _formScore = 100;
  bool _personLocked = false;
  LockReason _lockReason = LockReason.noPerson;
  FramingCue _framing = FramingCue.ok;
  FramingCue _lastSpokenFraming = FramingCue.ok;
  String? _coachCue;

  // Session lifecycle
  WorkoutSession? _session;
  SessionAudioCues? _audioCues;
  DateTime? _sessionStartTime;
  int _totalFormScoreSum = 0;
  int _formScoreCount = 0;
  int _lastSavedRepCount = 0;
  bool _exitedEarly = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    // Resolve the exercise (tolerant: `pushup` → `push_up` etc.). Unknown
    // exercises show a friendly error — rep counting is visual-only, so an
    // FSM is required.
    final definition = ExerciseRegistry.instance.resolve(widget.exerciseId);
    if (definition == null) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Exercise not found. Please try another.';
      });
      return;
    }

    // Initialize audio cues
    final soundEngine = ref.read(soundEngineProvider);
    _audioCues = SessionAudioCues(soundEngine);

    // Check for existing active session
    final sessionRepository = ref.read(sessionRepositoryProvider);
    final active = await sessionRepository.activeSession();

    if (active != null) {
      if (active.exercises.isNotEmpty &&
          active.exercises.first.exerciseId != widget.exerciseId) {
        // Different exercise active — clear it before starting new
        await sessionRepository.clearActive();
        await _createNewSession(sessionRepository);
      } else {
        // Resume existing session for same exercise
        await _resumeSession(active, sessionRepository);
      }
    } else {
      await _createNewSession(sessionRepository);
    }

    // Start pose analyzer
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
      CameraDescription selected = cameras.first;
      for (final CameraDescription cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.back) {
          selected = cam;
          break;
        }
      }
      final CameraController controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
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
      setState(() {
        _camera = controller;
        _initializing = false;
        _ready = true;
      });
    } catch (_) {
      if (_disposed || !mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Could not start the camera. Try again.';
      });
    }
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
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
      final PoseFrameResult? result = await analyzer.processCameraImage(
        image,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        rotation: _rotation,
      );
      if (result != null && mounted && !_disposed) {
        _handleResult(result);
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

        // Save progress every rep
        if (_reps > _lastSavedRepCount) {
          _lastSavedRepCount = _reps;
          _saveSession();
        }
      }
      final List<String> warnings = <String>[];
      final List<String> messages = <String>[];
      for (final fb in brain.feedback) {
        messages.add(fb.message);
        if (fb.severity == 'warning' || fb.severity == 'error') {
          warnings.add(fb.audioCue);
        }
      }
      if (warnings.isNotEmpty) {
        _audioCues?.onWarning(warnings.first);
      }
      if (messages.isNotEmpty) {
        cue = messages.first;
      }
    }
    if (result.framing != _lastSpokenFraming) {
      _lastSpokenFraming = result.framing;
      if (result.framing != FramingCue.ok) {
        _audioCues?.onFraming(result.framing);
      }
    }
    if (result.lockReason == LockReason.videoPlayback &&
        _lastLockReason != LockReason.videoPlayback) {
      // Spoken once per entry — proper message when a played video is
      // detected instead of the user working out.
      unawaited(_audioCues?.speakUrgent(
        'Looks like a video is playing. Do the exercise yourself so your '
        'reps count.',
      ));
    }
    _lastLockReason = result.lockReason;
    setState(() {
      _personLocked = result.personLocked;
      _lockReason = result.lockReason;
      _framing = result.framing;
      if (brain != null) {
        _reps = brain.repCount;
        _state = brain.currentState;
        // Form display = running average across reps (updated on rep
        // completion); the per-frame score feeds that average and must not
        // clobber it here.
        _coachCue = cue;
      }
    });
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
      durationSec: _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 0,
      status: _paused ? SessionStatus.paused : SessionStatus.active,
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

    // Stop camera stream
    final CameraController? controller = _camera;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Already stopped — safe to proceed.
      }
    }

    // Complete session
    if (_session != null) {
      final repository = ref.read(sessionRepositoryProvider);
      final completedSession = _session!.copyWith(
        status: SessionStatus.completed,
        endedAt: DateTime.now(),
        durationSec: _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!).inSeconds
            : 0,
        totalReps: _reps,
        formAccuracyPct: _formScoreCount > 0
            ? _totalFormScoreSum / _formScoreCount
            : 0,
      );
      await repository.completeSession(completedSession);

      // Play completion audio
      final avgForm = _formScoreCount > 0
          ? _totalFormScoreSum / _formScoreCount
          : 0.0;
      // Completion: treat as 100% target completion for single-exercise session
      final mood = computeMood(
        targetCompletion: 1.0,
        avgForm: avgForm,
        exitedEarly: _exitedEarly,
      );
      await _audioCues?.onComplete(mood);

      // Navigate to summary
      if (mounted) {
        final sessionId = completedSession.id;
        context.go('/summary?session=$sessionId');
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
      } catch (_) {
        // Stream already stopped.
      }
      unawaited(controller.dispose());
    }
    unawaited(WakelockPlus.disable());
    final PoseAnalyzer? analyzer = _analyzer;
    _analyzer = null;
    if (analyzer != null) {
      unawaited(analyzer.dispose());
    }
    // SoundEngine is disposed by the provider; no need to dispose here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = ExerciseRegistry.instance.resolve(widget.exerciseId);
    final String title = definition?.displayName ?? 'Live session';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridBackground(
        child: SafeArea(child: _buildBody()),
      ),
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
    return Padding(
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepCounter(reps: _reps),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ExerciseStateChip(state: _state),
                            const SizedBox(height: 8),
                            FormScoreReadout(formScore: _formScore),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_personLocked) ...[
                    const SizedBox(height: 10),
                    PersonLockBanner(reason: _lockReason),
                  ],
                  if (_framing != FramingCue.ok) ...[
                    const SizedBox(height: 10),
                    FramingCueCard(framing: _framing),
                  ],
                  const Spacer(),
                  if (_coachCue != null) ...[
                    _CoachCueCard(text: _coachCue!),
                    const SizedBox(height: 10),
                  ],
                  if (_paused) ...[
                    const _PausedBanner(),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SessionControlButton(
                        icon: _paused ? Icons.play_arrow : Icons.pause,
                        label: _paused ? 'Resume' : 'Pause',
                        primary: true,
                        onTap: _togglePause,
                      ),
                      const SizedBox(width: 16),
                      _SessionControlButton(
                        icon: Icons.stop,
                        label: 'End',
                        onTap: _confirmEndSession,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Permission / camera failure card with a retry action. Never blank.
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

/// Latest spoken coaching cue, shown above the session controls.
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