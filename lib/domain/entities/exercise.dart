/// Exercise catalog — pure domain (no Flutter imports).
///
/// Source of truth for form rules / thresholds lives in
/// `core/constants/form_rules.dart` (keyed by [Exercise.id]); the catalog
/// only carries content + classification.
library;

/// How reps are produced for this exercise during a live session.
enum ExerciseKind {
  /// Automatic ROM state-machine counting from pose angles (every bundled
  /// exercise resolves to an FSM definition — the registry is the source
  /// of truth, and the integrity suite pins it).
  counted,

  /// Legacy value: kept for contract stability (old packs). No manual-tap
  /// counting UI exists — every resolved exercise counts automatically.
  manual,
}

enum MuscleGroup {
  chest,
  back,
  legs,
  glutes,
  shoulders,
  arms,
  core,
  cardio,
  fullBody,
  mobility,
}

extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Chest',
        MuscleGroup.back => 'Back',
        MuscleGroup.legs => 'Legs',
        MuscleGroup.glutes => 'Glutes',
        MuscleGroup.shoulders => 'Shoulders',
        MuscleGroup.arms => 'Arms',
        MuscleGroup.core => 'Core',
        MuscleGroup.cardio => 'Cardio',
        MuscleGroup.fullBody => 'Full body',
        MuscleGroup.mobility => 'Mobility',
      };
}

enum Difficulty { beginner, intermediate, advanced }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
        Difficulty.beginner => 'Beginner',
        Difficulty.intermediate => 'Intermediate',
        Difficulty.advanced => 'Advanced',
      };
}

/// A single exercise in the library (content is bundled, account-independent).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.kind,
    required this.primaryMuscles,
    required this.difficulty,
    required this.description,
    required this.formCues,
    required this.met,
    this.secondaryMuscles = const [],
    this.demoVideoAsset,
    this.defaultSets = 3,
    this.defaultReps = 12,
    this.isTimed = false,
    this.defaultSeconds = 30,
  });

  /// Stable slug id — also the key into `form_rules.dart` for counted kinds.
  final String id;
  final String name;
  final ExerciseKind kind;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final Difficulty difficulty;

  /// One-line "what & why" shown on the detail page.
  final String description;

  /// Ordered coaching cues (form page + live correction references).
  final List<String> formCues;

  /// Metabolic equivalent — used for calorie estimates from duration.
  final double met;

  /// Bundled demo clip path (`assets/videos/...`), null until assets land.
  final String? demoVideoAsset;

  final int defaultSets;
  final int defaultReps;

  /// True → target is time (plank-style), not repetitions.
  final bool isTimed;
  final int defaultSeconds;
}
