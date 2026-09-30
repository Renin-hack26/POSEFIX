import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/exercise_repository.dart';
import '../datasources/content/content_loader.dart';
import '../datasources/local/exercise_dao.dart';

/// Catalog from bundled assets + seen-flags from local storage (no network).
class ExerciseRepositoryImpl implements ExerciseRepository {
  ExerciseRepositoryImpl(this._content, this._dao);

  final ContentLoader _content;
  final ExerciseDao _dao;

  @override
  Future<List<Exercise>> catalog() => _content.exercises();

  @override
  Future<Exercise?> byId(String id) async {
    final all = await _content.exercises();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<bool> videoSeen(String exerciseId) => _dao.videoSeen(exerciseId);

  @override
  Future<void> markVideoSeen(String exerciseId) => _dao.setVideoSeen(exerciseId);
}
