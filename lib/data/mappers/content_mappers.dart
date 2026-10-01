/// Mappers: bundled JSON content → domain entities (content is
/// account-independent seed data; parsing fails loud with StorageException).
library;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/plan_template.dart';
import '../../domain/entities/workout.dart';

Never _field(String file, String key) => throw StorageException(
    'Content "$file" is missing or malformed (field "$key")');

Exercise exerciseFromJson(Map<String, dynamic> m, String file) {
  try {
    return Exercise(
      id: m['id'] as String,
      name: m['name'] as String,
      kind: ExerciseKind.values.byName(m['kind'] as String),
      primaryMuscles: (m['primaryMuscles'] as List<dynamic>)
          .map((e) => MuscleGroup.values.byName(e as String))
          .toList(),
      secondaryMuscles: ((m['secondaryMuscles'] as List?) ?? const [])
          .map((e) => MuscleGroup.values.byName(e as String))
          .toList(),
      difficulty: Difficulty.values.byName(m['difficulty'] as String),
      description: m['description'] as String,
      formCues: (m['formCues'] as List<dynamic>).cast<String>(),
      met: (m['met'] as num).toDouble(),
      demoVideoAsset: m['demoVideoAsset'] as String?,
      defaultSets: (m['defaultSets'] as num).toInt(),
      defaultReps: (m['defaultReps'] as num).toInt(),
      isTimed: m['isTimed'] as bool,
      defaultSeconds: (m['defaultSeconds'] as num).toInt(),
    );
  } catch (_) {
    _field(file, 'id');
  }
}

Workout workoutFromJson(Map<String, dynamic> m, String file) {
  try {
    return Workout(
      id: m['id'] as String,
      name: m['name'] as String,
      category: WorkoutCategory.values.byName(m['category'] as String),
      level: Difficulty.values.byName(m['level'] as String),
      goal: m['goal'] as String,
      durationMin: (m['durationMin'] as num).toInt(),
      description: m['description'] as String,
      focusMuscles: (m['focusMuscles'] as List<dynamic>)
          .map((e) => MuscleGroup.values.byName(e as String))
          .toList(),
      estimatedCalories: (m['estimatedCalories'] as num).toInt(),
      tags: ((m['tags'] as List?) ?? const []).cast<String>(),
      // Tolerant: a null/absent path simply means "no hero clip bundled"
      // (the workouts-level assets/videos/*.mp4 are intentionally not
      // shipped yet) — normalize to '' so no screen has to null-check and
      // a partial content pack can never crash the mapper.
      demoVideoAsset: (m['demoVideoAsset'] as String?) ?? '',
      blocks: (m['blocks'] as List<dynamic>)
          .map((b) => workoutBlockFromJson(b as Map<String, dynamic>, file))
          .toList(),
    );
  } catch (_) {
    _field(file, 'id');
  }
}

WorkoutBlock workoutBlockFromJson(Map<String, dynamic> m, String file) {
  try {
    return WorkoutBlock(
      exerciseId: m['exerciseId'] as String,
      sets: (m['sets'] as num).toInt(),
      reps: (m['reps'] as num).toInt(),
      seconds: (m['seconds'] as num).toInt(),
      restSec: (m['restSec'] as num).toInt(),
    );
  } catch (_) {
    _field(file, 'exerciseId');
  }
}

FoodItem foodFromJson(Map<String, dynamic> m, String file) {
  try {
    return FoodItem(
      id: m['id'] as String,
      name: m['name'] as String,
      calories: (m['calories'] as num).toInt(),
      serving: m['serving'] as String,
    );
  } catch (_) {
    _field(file, 'id');
  }
}

PlanTemplate planTemplateFromJson(Map<String, dynamic> m, String file) {
  try {
    return PlanTemplate(
      id: m['id'] as String,
      levels: (m['levels'] as List<dynamic>).cast<String>(),
      goals: (m['goals'] as List<dynamic>).cast<String>(),
      days: (m['days'] as List<dynamic>)
          .map((d) => templateDayFromJson(d as Map<String, dynamic>, file))
          .toList(),
    );
  } catch (_) {
    _field(file, 'id');
  }
}

TemplateDay templateDayFromJson(Map<String, dynamic> m, String file) {
  try {
    return TemplateDay(
      dayOffset: (m['dayOffset'] as num).toInt(),
      kind: TemplateDayKind.values.byName(m['kind'] as String),
      categories: ((m['categories'] as List?) ?? const []).cast<String>(),
      startMin: (m['startMin'] as num?)?.toInt() ?? 420,
    );
  } catch (_) {
    _field(file, 'dayOffset');
  }
}
