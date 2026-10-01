/// Pure session-flow logic for the camera vision session (WS2, TODO 2.2–2.6).
///
/// Everything in this file is deliberately free of Flutter/platform
/// dependencies so round progression, rest timing, popup sequencing, cue
/// priority and target resolution can be unit-tested headlessly
/// (`test/unit/session_flow_test.dart`). The screen is only a renderer of
/// the state machine defined here.
library;

import 'package:flutter/foundation.dart';

import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_definition.dart';
import 'package:fixpose/domain/entities/training_plan.dart';
import 'package:fixpose/domain/entities/workout.dart';

// ---------------------------------------------------------------------------
// Targets (TODO 2.4 pre-session editor + TODO 2.3 roundsOverride)
// ---------------------------------------------------------------------------

/// Rounds/reps/rest targets for one camera session.
@immutable
class RoundPlan {
  const RoundPlan({
    this.rounds = 3,
    this.repsPerRound = 12,
    this.restSec = 45,
  });

  final int rounds;
  final int repsPerRound;
  final int restSec;

  /// Clamps user/plan input into playable bounds (editor steppers use the
  /// same limits so the persisted plan can never be out of range).
  factory RoundPlan.clamped({
    required int rounds,
    required int reps,
    int restSec = 45,
  }) =>
      RoundPlan(
        rounds: rounds.clamp(1, 12),
        repsPerRound: reps.clamp(1, 100),
        restSec: restSec.clamp(0, 600),
      );
}

/// Resolved default targets for the pre-session editor.
@immutable
class SessionTargets {
  const SessionTargets({
    required this.rounds,
    required this.reps,
    required this.restSec,
    this.planSession,
  });

  final int rounds;
  final int reps;
  final int restSec;

  /// Planned session (today) that supplied `roundsOverride`, when any.
  final PlanSession? planSession;

  RoundPlan get plan => RoundPlan.clamped(rounds: rounds, reps: reps, restSec: restSec);
}

/// Normalizes an exercise id for cross-content matching (`push-up` ≡ `pushup`
/// ≡ `push_up`) — same rule the registry uses for content-pack aliases.
String normalizeExerciseId(String id) =>
    id.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

WorkoutBlock? _blockFor(Workout? workout, String key) {
  if (workout == null) return null;
  for (final block in workout.blocks) {
    if (normalizeExerciseId(block.exerciseId) == key) return block;
  }
  return null;
}

/// Resolves the rounds/reps the pre-session editor should offer.
///
/// Priority (WS2 2.3/2.4):
/// 1. today's planned session for a workout that contains this exercise —
///    its `roundsOverride` (user-edited in the Plan tab) wins;
/// 2. the prescription block (`sets`/`reps`/`restSec`) of the workout the
///    session was started from (active session first, then the library);
/// 3. the FSM definition's defaults.
SessionTargets resolveTargets({
  required String exerciseId,
  required ExerciseDefinition? definition,
  Workout? activeWorkout,
  List<Workout> library = const [],
  List<PlanSession> planToday = const [],
}) {
  final String key = normalizeExerciseId(exerciseId);

  final candidates = <Workout>[
    if (activeWorkout != null) activeWorkout,
    ...library,
  ];

  Workout? source;
  PlanSession? plan;
  for (final workout in candidates) {
    if (_blockFor(workout, key) == null) continue;
    source ??= workout;
    for (final session in planToday) {
      if (session.workoutId != workout.id) continue;
      // A plan override beats "first workout that fits"; otherwise remember
      // the first planned candidate so planSessionId context survives.
      if (session.roundsOverride != null || plan == null) {
        plan = session;
        source = workout;
      }
      break;
    }
  }

  final WorkoutBlock? block = _blockFor(source, key);
  return SessionTargets(
    rounds: plan?.roundsOverride ?? block?.sets ?? definition?.defaultSets ?? 3,
    reps: block?.reps ?? definition?.defaultReps ?? 12,
    restSec: block?.restSec ?? 45,
    planSession: plan?.roundsOverride != null ? plan : null,
  );
}

// ---------------------------------------------------------------------------
// Round progression (TODO 2.3)
// ---------------------------------------------------------------------------

/// Where the session currently is.
enum FlowPhase {
  /// Editor visible — nothing counts yet.
  setup,

  /// Counting reps toward the current round target.
  active,

  /// Rest countdown between rounds.
  rest,

  /// Every round finished — congrats popup is up.
  complete,
}

/// What just happened inside [SessionFlow].
enum FlowSignal {
  /// Nothing changed (or the event is not applicable right now).
  none,

  /// A rep was counted but the round target is not reached yet.
  repCounted,

  /// The round target was reached — rest starts.
  roundComplete,

  /// Rest hit zero (or was skipped) — next round is ready.
  restEnded,

  /// The final round target was reached.
  sessionComplete,

  /// A rep arrived while resting — it cannot count (never silent).
  ignoredDuringRest,
}

/// Round/rest progression state machine. Pure data + transitions: the screen
/// feeds it engine events and a 1 Hz tick, and renders what comes back.
class SessionFlow {
  SessionFlow({required this.plan});

  final RoundPlan plan;

  FlowPhase phase = FlowPhase.setup;

  /// Reps landed in the CURRENT round (reset when a round completes).
  int repsInRound = 0;

  /// Reps counted across the whole session (report/summary source).
  int repsTotal = 0;

  /// Reps of every FINISHED round, in order.
  final List<int> repsPerRoundLog = [];

  /// Wall-clock duration of every finished round (seconds).
  final List<double> roundTimesSec = [];

  /// Seconds left of the current rest.
  int restLeftSec = 0;

  int get roundsCompleted => repsPerRoundLog.length;

  /// 1-based number of the round the user is on (or about to start).
  int get roundNumber =>
      roundsCompleted < plan.rounds ? roundsCompleted + 1 : plan.rounds;

  bool get allRoundsDone => roundsCompleted >= plan.rounds;
  bool get resting => phase == FlowPhase.rest;

  /// HUD strings (sample `.hud` chips).
  String get roundLabel => '$roundNumber / ${plan.rounds}';
  String get repsLabel => '$repsInRound / ${plan.repsPerRound}';

  /// Opens the counting window (round 1 or the round after calibration).
  void start() {
    if (phase == FlowPhase.complete) return;
    phase = FlowPhase.active;
  }

  /// One engine-counted rep. [roundElapsedSec] is the wall time of the round
  /// just finished when it lands on the target (0 otherwise).
  FlowSignal registerRep({double roundElapsedSec = 0}) {
    switch (phase) {
      case FlowPhase.setup:
      case FlowPhase.complete:
        return FlowSignal.none;
      case FlowPhase.rest:
        return FlowSignal.ignoredDuringRest;
      case FlowPhase.active:
        repsInRound++;
        repsTotal++;
        if (repsInRound < plan.repsPerRound) return FlowSignal.repCounted;
        // Round target hit → record, then rest or finish.
        repsPerRoundLog.add(repsInRound);
        roundTimesSec.add(roundElapsedSec);
        repsInRound = 0;
        if (allRoundsDone) {
          phase = FlowPhase.complete;
          return FlowSignal.sessionComplete;
        }
        restLeftSec = plan.restSec;
        phase = FlowPhase.rest;
        return FlowSignal.roundComplete;
    }
  }

  /// One-second rest tick. Returns [FlowSignal.restEnded] on the tick that
  /// hits zero (the screen announces "ready for next round" there).
  FlowSignal tickRest() {
    if (phase != FlowPhase.rest) return FlowSignal.none;
    if (restLeftSec > 1) {
      restLeftSec--;
      return FlowSignal.none;
    }
    restLeftSec = 0;
    phase = FlowPhase.active;
    return FlowSignal.restEnded;
  }

  /// User pressed "Skip rest".
  FlowSignal skipRest() {
    if (phase != FlowPhase.rest) return FlowSignal.none;
    restLeftSec = 0;
    phase = FlowPhase.active;
    return FlowSignal.restEnded;
  }

  /// Re-hydrates a resumed session's completed work (TODO 2.3 — the model
  /// fields exist but were always 0 before).
  void restore({
    required int totalReps,
    required List<int> repsPerRound,
    required List<double> roundTimes,
  }) {
    repsTotal = totalReps;
    repsPerRoundLog
      ..clear()
      ..addAll(repsPerRound.take(plan.rounds));
    roundTimesSec
      ..clear()
      ..addAll(roundTimes.take(plan.rounds));
    repsInRound = 0;
    restLeftSec = 0;
    if (allRoundsDone) phase = FlowPhase.complete;
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

/// `MM:SS` clock label (`04:35`), minutes grow past 59 instead of wrapping.
String formatClock(int totalSeconds) {
  final int s = totalSeconds < 0 ? 0 : totalSeconds;
  final int minutes = s ~/ 60;
  final int seconds = s % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Coach-bar copy for a rejected (never-counted) rep — WS2 2.9: a skip is
/// always spoken/shown, never silent.
String? rejectionCueFor(RepRejectedReason? reason) => switch (reason) {
      null => null,
      RepRejectedReason.rangeOfMotion =>
        'Not counted — go through the full range of motion.',
      RepRejectedReason.tooFast =>
        'Not counted — slow the rep down and control it.',
    };

// ---------------------------------------------------------------------------
// Single cue slot (TODO 2.2)
// ---------------------------------------------------------------------------

enum CueSeverity {
  /// Green — ready/rest/info.
  ok,

  /// Amber — fixable form/framing issues.
  warn,

  /// Red — hard faults and rejected reps.
  error,
}

@immutable
class Cue {
  const Cue(this.text, {this.sub, this.severity = CueSeverity.ok});

  final String text;
  final String? sub;
  final CueSeverity severity;
}

/// The ONE resolver every feedback source flows through. Priority matches
/// the coach bar: an immediate "not counted"/fault outranks a lock/framing
/// notice, which outranks rest state, which outranks standing guidance.
/// Returns null when there is nothing to say (bar hidden — never stacked).
Cue? resolveCue({
  String? rejection,
  String? error,
  String? lock,
  String? framing,
  String? warning,
  String? rest,
  String? info,
}) {
  if (rejection != null) return Cue(rejection, severity: CueSeverity.error);
  if (error != null) return Cue(error, severity: CueSeverity.error);
  if (lock != null) return Cue(lock, severity: CueSeverity.warn);
  if (framing != null) return Cue(framing, severity: CueSeverity.warn);
  if (warning != null) return Cue(warning, severity: CueSeverity.warn);
  if (rest != null) return Cue(rest, severity: CueSeverity.ok);
  if (info != null) return Cue(info, severity: CueSeverity.ok);
  return null;
}

// ---------------------------------------------------------------------------
// Popup sequencing (TODO 2.5/2.6)
// ---------------------------------------------------------------------------

/// Transient overlays on the vision screen. All popups are overlays on the
/// SAME screen — no router involvement.
enum SessionPopup {
  none,

  /// Wrong-pose ✕ flash (0.8 s).
  wrongPose,

  /// Round-complete ✓ flash.
  roundTick,

  /// All-rounds congrats card (sticky until dismissed).
  congrats,
}

/// Priority/hold bookkeeping for the popup layer — pure and time-injected so
/// the sequencing rules are unit-testable.
class PopupSequencer {
  /// Wrong-pose cross: exactly 0.8 s (user requirement).
  static const Duration wrongPoseHold = Duration(milliseconds: 800);

  /// Round tick stays a beat longer so it reads.
  static const Duration roundTickHold = Duration(milliseconds: 1200);

  /// Minimum gap between two wrong-pose flashes (stop flicker storms).
  static const Duration wrongPoseCooldown = Duration(milliseconds: 1200);

  SessionPopup _active = SessionPopup.none;
  DateTime? _until;
  DateTime? _lastWrongPose;

  SessionPopup get active => _active;

  /// Whether a wrong-pose flash may fire at [now] (cooldown respected).
  bool wantWrongPose(DateTime now) {
    if (_active == SessionPopup.congrats) return false;
    final DateTime? last = _lastWrongPose;
    if (last != null && now.difference(last) < wrongPoseCooldown) return false;
    _lastWrongPose = now;
    return true;
  }

  /// Requests [kind] visible at [now]. Returns false when superseded by a
  /// higher-priority popup (caller then shows nothing).
  bool show(SessionPopup kind, DateTime now) {
    if (kind == SessionPopup.congrats) {
      _set(kind, null); // sticky until dismiss()
      return true;
    }
    // Congrats blocks the transient layers until dismissed.
    if (_active == SessionPopup.congrats) return false;
    // A wrong-pose flash never cuts a round tick short.
    if (kind == SessionPopup.wrongPose && _active == SessionPopup.roundTick) {
      if (_until != null && now.isBefore(_until!)) return false;
    }
    _set(kind, now.add(kind == SessionPopup.wrongPose
        ? wrongPoseHold
        : roundTickHold));
    return true;
  }

  /// Visible popup at [now] — auto-clears timed popups once past their hold.
  SessionPopup visibleAt(DateTime now) {
    final DateTime? until = _until;
    if (until != null && !now.isBefore(until)) {
      _active = SessionPopup.none;
      _until = null;
    }
    return _active;
  }

  /// Manual dismissal (congrats "Next", test teardown).
  void dismiss() {
    _active = SessionPopup.none;
    _until = null;
  }

  void _set(SessionPopup kind, DateTime? until) {
    _active = kind;
    _until = until;
  }
}
