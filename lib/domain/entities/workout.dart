/// Workout catalog — a startable program entry (library / plan / suggestions).
///
/// Workouts are bundled seed content (50+ unique); each references [Exercise]s
/// and carries its own demo clip. Not account data → never synced.
library;

import 'exercise.dart';

enum WorkoutCategory {
  strength,
  hiit,
  cardio,
  core,
  fullBody,
  mobility,
}

extension WorkoutCategoryX on WorkoutCategory {
  String get label => switch (this) {
        WorkoutCategory.strength => 'Strength',
        WorkoutCategory.hiit => 'HIIT',
        WorkoutCategory.cardio => 'Cardio',
        WorkoutCategory.core => 'Core',
        WorkoutCategory.fullBody => 'Full body',
        WorkoutCategory.mobility => 'Mobility',
      };
}

/// One block of a workout: an exercise prescription.
class WorkoutBlock {
  const WorkoutBlock({
    required this.exerciseId,
    this.sets = 3,
    this.reps = 12,
    this.seconds = 0,
    this.restSec = 45,
  });

  final String exerciseId;
  final int sets;
  final int reps;

  /// > 0 → timed block (seconds per round) instead of rep target.
  final int seconds;
  final int restSec;
}

/// A unique library workout (≥50), each with its own demo clip.
class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.category,
    required this.level,
    required this.goal,
    required this.durationMin,
    required this.description,
    required this.focusMuscles,
    required this.blocks,
    required this.demoVideoAsset,
    this.estimatedCalories = 0,
    this.tags = const [],
  });

  final String id;
  final String name;
  final WorkoutCategory category;
  final Difficulty level;

  /// Short goal line, e.g. "Build lower-body power".
  final String goal;
  final int durationMin;
  final String description;
  final List<MuscleGroup> focusMuscles;
  final List<WorkoutBlock> blocks;

  /// Bundled demo clip for the library card / detail hero.
  final String demoVideoAsset;
  final int estimatedCalories;
  final List<String> tags;

  /// Every block exercise is [ExerciseKind.counted] → auto rep counting.
  bool get hasCountedMovements => blocks.any((b) => b.exerciseId == 'squat' ||
      b.exerciseId == 'pushup' ||
      b.exerciseId == 'jumpingJack');
}
