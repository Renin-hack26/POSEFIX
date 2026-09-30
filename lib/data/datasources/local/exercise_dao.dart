import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

part 'exercise_dao.g.dart';

/// Device-local exercise flags (instruction video seen) — never synced.
@DriftAccessor(tables: [ExerciseProgress])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Future<bool> videoSeen(String exerciseId) async {
    final rows = await (select(exerciseProgress)
          ..where((t) => t.exerciseId.equals(exerciseId))
          ..limit(1))
        .get();
    return rows.firstOrNull?.videoSeen ?? false;
  }

  Future<void> setVideoSeen(String exerciseId) =>
      into(exerciseProgress).insertOnConflictUpdate(
        ExerciseProgressCompanion.insert(
          exerciseId: exerciseId,
          videoSeen: const Value(true),
        ),
      );
}
