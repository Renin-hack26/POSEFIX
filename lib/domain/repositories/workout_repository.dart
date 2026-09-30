import '../../domain/entities/workout.dart';

/// Workout library access — 50+ bundled unique workouts, each with its own
/// demo clip. Content is account-independent (never synced); suggestions are
/// derived locally from recent session muscle focus (rule-based).
abstract class WorkoutRepository {
  /// Full library (≥50 unique entries).
  Future<List<Workout>> library();

  Future<Workout?> byId(String id);

  /// Rule-based suggestions: deprioritizes muscles hit in recent sessions.
  Future<List<Workout>> suggestions({int limit = 5});
}
