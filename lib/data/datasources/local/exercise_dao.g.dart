// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_dao.dart';

// ignore_for_file: type=lint
mixin _$ExerciseDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExerciseProgressTable get exerciseProgress =>
      attachedDatabase.exerciseProgress;
  ExerciseDaoManager get managers => ExerciseDaoManager(this);
}

class ExerciseDaoManager {
  final _$ExerciseDaoMixin _db;
  ExerciseDaoManager(this._db);
  $$ExerciseProgressTableTableManager get exerciseProgress =>
      $$ExerciseProgressTableTableManager(
        _db.attachedDatabase,
        _db.exerciseProgress,
      );
}
