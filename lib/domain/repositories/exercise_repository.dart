import '../../domain/entities/exercise.dart';

/// Exercise catalog access — bundled seed content + per-user progress flags.
///
/// Offline-first: catalog reads resolve from bundled assets instantly;
/// progress flags live in local storage and sync to the account.
abstract class ExerciseRepository {
  /// Full bundled catalog (exercises referenced by the workout library).
  Future<List<Exercise>> catalog();

  Future<Exercise?> byId(String id);

  /// Whether the instruction video was already watched (first-time flow gate).
  Future<bool> videoSeen(String exerciseId);

  Future<void> markVideoSeen(String exerciseId);
}
