/// Performed workout session — the core record for history, reports,
/// strike and analytics (PLANNING §7).
library;

enum SessionStatus { active, paused, completed, abandoned }

/// Snapshot persisted on pause/background so the session is resumable.
class PausedState {
  const PausedState({
    required this.exerciseIndex,
    required this.roundIndex,
    required this.repsInRound,
    required this.elapsedSec,
  });

  final int exerciseIndex;
  final int roundIndex;
  final int repsInRound;
  final int elapsedSec;
}

/// Live/completed results for one exercise inside a session.
class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    this.roundsCompleted = 0,
    this.totalReps = 0,
    this.formAccuracyPct = 0,
    this.perRepTimesSec = const [],
    this.roundTimesSec = const [],
    this.repsPerRound = const [],
  });

  final String exerciseId;
  final int roundsCompleted;
  final int totalReps;

  /// 0..100 — average over analyzed frames/reps.
  final double formAccuracyPct;

  /// Seconds between consecutive reps (cadence source).
  final List<double> perRepTimesSec;
  final List<double> roundTimesSec;
  final List<int> repsPerRound;

  SessionExercise copyWith({
    int? roundsCompleted,
    int? totalReps,
    double? formAccuracyPct,
    List<double>? perRepTimesSec,
    List<double>? roundTimesSec,
    List<int>? repsPerRound,
  }) =>
      SessionExercise(
        exerciseId: exerciseId,
        roundsCompleted: roundsCompleted ?? this.roundsCompleted,
        totalReps: totalReps ?? this.totalReps,
        formAccuracyPct: formAccuracyPct ?? this.formAccuracyPct,
        perRepTimesSec: perRepTimesSec ?? this.perRepTimesSec,
        roundTimesSec: roundTimesSec ?? this.roundTimesSec,
        repsPerRound: repsPerRound ?? this.repsPerRound,
      );
}

/// One workout performance (active → paused/completed/abandoned).
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.startedAt,
    this.planSessionId,
    this.endedAt,
    this.status = SessionStatus.active,
    this.exercises = const [],
    this.restDurationsSec = const [],
    this.pausedState,
    this.durationSec = 0,
    this.totalReps = 0,
    this.avgCadenceRpm = 0,
    this.formAccuracyPct = 0,
    this.syncedAt,
  });

  final String id;
  final String workoutId;
  final String? planSessionId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;
  final List<SessionExercise> exercises;

  /// Actual rest lengths taken (round transitions).
  final List<double> restDurationsSec;
  final PausedState? pausedState;

  // ---- Derived headline metrics (FR-6) ----
  final int durationSec;
  final int totalReps;
  final double avgCadenceRpm;
  final double formAccuracyPct;

  /// Server sync watermark (null → dirty, queued for upload).
  final DateTime? syncedAt;

  WorkoutSession copyWith({
    SessionStatus? status,
    DateTime? endedAt,
    List<SessionExercise>? exercises,
    List<double>? restDurationsSec,
    PausedState? pausedState,
    bool clearPaused = false,
    int? durationSec,
    int? totalReps,
    double? avgCadenceRpm,
    double? formAccuracyPct,
    DateTime? syncedAt,
  }) =>
      WorkoutSession(
        id: id,
        workoutId: workoutId,
        planSessionId: planSessionId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        exercises: exercises ?? this.exercises,
        restDurationsSec: restDurationsSec ?? this.restDurationsSec,
        pausedState: clearPaused ? null : (pausedState ?? this.pausedState),
        durationSec: durationSec ?? this.durationSec,
        totalReps: totalReps ?? this.totalReps,
        avgCadenceRpm: avgCadenceRpm ?? this.avgCadenceRpm,
        formAccuracyPct: formAccuracyPct ?? this.formAccuracyPct,
        syncedAt: syncedAt ?? this.syncedAt,
      );
}
