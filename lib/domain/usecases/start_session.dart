import '../../core/utils/id_gen.dart';
import '../entities/workout_session.dart';
import '../repositories/session_repository.dart';
import '../repositories/workout_repository.dart';

/// Starts (or idempotently returns) the in-flight session.
///
/// The session row is created immediately with one [SessionExercise] per
/// unique block exercise (order preserved) so pause/resume works from the
/// very first frame. If a session is already active/paused, it is returned
/// as-is (the Home slot routes to Resume instead of Start).
class StartSession {
  StartSession(this._sessions, this._workouts);

  final SessionRepository _sessions;
  final WorkoutRepository _workouts;

  Future<WorkoutSession> call({
    required String workoutId,
    String? planSessionId,
  }) async {
    final active = await _sessions.activeSession();
    if (active != null) return active;

    final workout = await _workouts.byId(workoutId);
    final seen = <String>{};
    final exercises = <SessionExercise>[
      for (final block in workout?.blocks ?? const [])
        if (seen.add(block.exerciseId))
          SessionExercise(exerciseId: block.exerciseId),
    ];

    final session = WorkoutSession(
      id: newId(),
      workoutId: workoutId,
      planSessionId: planSessionId,
      startedAt: DateTime.now(),
      exercises: exercises,
    );
    await _sessions.saveActive(session);
    return session;
  }
}
