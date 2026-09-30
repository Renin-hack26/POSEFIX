import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/workout.dart';
import '../../../domain/repositories/workout_repository.dart';
import '../datasources/content/content_loader.dart';
import '../datasources/local/session_dao.dart';

/// Workout library (bundled) + rule-based suggestions derived from the
/// user's recent sessions (deprioritises recently trained muscles).
class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl(this._content, this._sessions);

  final ContentLoader _content;
  final SessionDao _sessions;

  @override
  Future<List<Workout>> library() => _content.workouts();

  @override
  Future<Workout?> byId(String id) async {
    final all = await _content.workouts();
    for (final w in all) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async {
    final all = await _content.workouts();
    final exercises = {for (final e in await _content.exercises()) e.id: e};

    // Muscles hit in the last 7 days of completed sessions.
    final from = DateTime.now().subtract(const Duration(days: 7));
    final recent = await _sessions.between(from, DateTime.now());
    final hit = <MuscleGroup>{};
    for (final session in recent) {
      for (final se in session.exercises) {
        final exercise = exercises[se.exerciseId];
        if (exercise == null) continue;
        hit.addAll(exercise.primaryMuscles);
      }
    }

    int score(Workout w) => w.focusMuscles.where(hit.contains).length;

    final ranked = [...all]..sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        if (byScore != 0) return byScore;
        // Tie-break: shorter sessions first (lower friction), then by id.
        final byDuration = a.durationMin.compareTo(b.durationMin);
        return byDuration != 0 ? byDuration : a.id.compareTo(b.id);
      });
    // When nothing was trained yet, rotate by day so suggestions vary.
    if (hit.isEmpty) {
      final day = DateTime.now().day % ranked.length;
      return [...ranked.sublist(day), ...ranked.sublist(0, day)]
          .take(limit)
          .toList();
    }
    return ranked.take(limit).toList();
  }
}
