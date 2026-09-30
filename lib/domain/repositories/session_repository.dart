import '../../domain/entities/workout_session.dart';

/// Workout session persistence — offline-first.
///
/// * One **active/paused** session row survives process death (resume on reopen).
/// * Completed sessions are append-only history + FR-6 aggregates.
/// * `syncedAt` watermarks drive the periodic upload sweep.
abstract class SessionRepository {
  /// The in-flight session (active or paused), if any.
  Future<WorkoutSession?> activeSession();

  /// Persist live progress (called every round transition / pause).
  Future<void> saveActive(WorkoutSession session);

  Future<void> clearActive();

  /// Finalize: moves the session to history (append-only) + clears active.
  Future<void> completeSession(WorkoutSession session);

  /// Recent sessions, newest first.
  Future<List<WorkoutSession>> history({int limit = 100});

  /// Sessions with `startedAt` in [from, to) — feeds graphs and VEDA context.
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to);
}
