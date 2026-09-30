/// FixPose Exercise Definitions — Dart representation of YAML FSMs.
///
/// This file contains the parsed structure of the 18 exercise YAMLs from
/// Model samples. Each exercise defines:
/// - Landmarks used
/// - Angles to compute (with point triplets)
/// - State machine (states + conditions)
/// - Counter rules (trigger state, required prior state)
/// - Feedback rules (conditions + messages + audio cues)
/// - Visualization hints (lines, circles for overlay)
///
/// Source: Model samples/fitness-trainer-pose-estimation/exercises/definitions/*.yaml
library;

import 'package:flutter/foundation.dart';

/// MediaPipe Pose landmark indices (33 landmarks, 0-32).
class MpLandmark {
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int mouthLeft = 9;
  static const int mouthRight = 10;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;
}

/// Angle definition: three landmarks forming an angle at the middle point.
@immutable
class AngleDef {
  const AngleDef({
    required this.name,
    required this.points,
    required this.description,
  });

  final String name; // e.g., "primary", "posture", "left_arm"
  final List<int> points; // exactly 3 landmark indices
  final String description;

  factory AngleDef.fromYaml(Map<String, dynamic> yaml) => AngleDef(
        name: yaml['name'] as String? ?? '',
        points: List<int>.from(yaml['points'] as List),
        description: yaml['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'points': points,
        'description': description,
      };
}

/// Single state in the FSM.
@immutable
class ExerciseState {
  const ExerciseState({
    required this.name,
    required this.condition,
    required this.description,
  });

  final String name; // e.g., "standing", "descending", "bottom"
  final String condition; // evaluable expression, e.g., "angle > 160"
  final String description;

  factory ExerciseState.fromYaml(Map<String, dynamic> yaml) => ExerciseState(
        name: yaml['name'] as String? ?? '',
        condition: yaml['condition'] as String? ?? 'False',
        description: yaml['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'condition': condition,
        'description': description,
      };
}

/// Counter rule: when to increment rep count.
@immutable
class CounterRule {
  const CounterRule({
    required this.triggerState,
    this.requiredPriorState,
    this.repIncrement = 1,
    this.minRepDuration = 0.5,
  });

  final String triggerState; // state that triggers count
  final String? requiredPriorState; // must come from this state
  final int repIncrement;
  final double minRepDuration; // seconds, anti-jitter

  factory CounterRule.fromYaml(Map<String, dynamic> yaml) => CounterRule(
        triggerState: yaml['trigger_state'] as String? ?? '',
        requiredPriorState: yaml['required_prior_state'] as String? ??
            yaml['from_state'] as String?,
        repIncrement: yaml['rep_increment'] as int? ?? 1,
        minRepDuration: (yaml['min_rep_duration'] as num?)?.toDouble() ?? 0.5,
      );
}

/// Feedback rule: condition + message + audio cue.
@immutable
class FeedbackRule {
  const FeedbackRule({
    required this.name,
    required this.condition,
    required this.message,
    this.audioCue,
    this.type = 'warning', // warning | info | error
  });

  final String name;
  final String condition;
  final String message; // UI text
  final String? audioCue; // TTS text (can differ from message)
  final String type;

  factory FeedbackRule.fromYaml(Map<String, dynamic> yaml) => FeedbackRule(
        name: yaml['name'] as String? ?? '',
        condition: yaml['condition'] as String? ?? 'False',
        message: yaml['message'] as String? ?? '',
        audioCue: yaml['audio_cue'] as String?,
        type: yaml['type'] as String? ?? 'warning',
      );
}

/// Visualization hints for overlay rendering.
@immutable
class VisualizationConfig {
  const VisualizationConfig({
    this.lines = const [],
    this.circles = const [],
  });

  final List<VisualizationLine> lines;
  final List<VisualizationCircle> circles;

  factory VisualizationConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null) return const VisualizationConfig();
    return VisualizationConfig(
      lines: (yaml['lines'] as List? ?? [])
          .map((e) => VisualizationLine.fromYaml(e))
          .toList(),
      circles: (yaml['circles'] as List? ?? [])
          .map((e) => VisualizationCircle.fromYaml(e))
          .toList(),
    );
  }
}

@immutable
class VisualizationLine {
  const VisualizationLine({
    required this.points,
    required this.color,
    this.thickness = 2,
  });

  final List<int> points; // landmark indices
  final List<int> color; // RGB
  final int thickness;

  factory VisualizationLine.fromYaml(Map<String, dynamic> yaml) =>
      VisualizationLine(
        points: List<int>.from(yaml['points'] as List),
        color: List<int>.from(yaml['color'] as List),
        thickness: yaml['thickness'] as int? ?? 2,
      );
}

@immutable
class VisualizationCircle {
  const VisualizationCircle({
    required this.point,
    required this.color,
    this.radius = 8,
  });

  final int point; // landmark index
  final List<int> color; // RGB
  final int radius;

  factory VisualizationCircle.fromYaml(Map<String, dynamic> yaml) =>
      VisualizationCircle(
        point: yaml['point'] as int,
        color: List<int>.from(yaml['color'] as List),
        radius: yaml['radius'] as int? ?? 8,
      );
}

/// Calibration config.
@immutable
class CalibrationConfig {
  const CalibrationConfig({
    this.enabled = false,
    this.reps = 3,
  });

  final bool enabled;
  final int reps;

  factory CalibrationConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null) return const CalibrationConfig();
    return CalibrationConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      reps: yaml['reps'] as int? ?? 3,
    );
  }
}

/// Smoothing config.
@immutable
class SmoothingConfig {
  const SmoothingConfig({
    this.enabled = false,
    this.window = 5,
  });

  final bool enabled;
  final int window;

  factory SmoothingConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null) return const SmoothingConfig();
    return SmoothingConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      window: yaml['window'] as int? ?? 5,
    );
  }
}

/// Form score config (ideal angles, tempo range).
@immutable
class FormScoreConfig {
  const FormScoreConfig({
    this.idealAngles = const {},
    this.tempoRange = const {'min': 1.0, 'max': 3.0},
  });

  final Map<String, double> idealAngles;
  final Map<String, double> tempoRange;

  factory FormScoreConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null) return const FormScoreConfig();
    return FormScoreConfig(
      idealAngles: (yaml['ideal_angles'] as Map? ?? {})
          .map<String, double>(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
      tempoRange: (yaml['tempo_range'] as Map? ?? {}).map<String, double>(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
    );
  }
}

/// Complete exercise definition (parsed from YAML).
@immutable
class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type, // 'repetition' | 'duration'
    required this.targetMuscles,
    required this.difficulty,
    required this.defaultReps,
    required this.defaultSets,
    required this.targetDuration, // for duration exercises
    required this.description,
    required this.landmarks, // mapping name -> landmark index
    required this.angles,
    required this.stateOrder,
    required this.states,
    required this.counterRule,
    required this.feedbackRules,
    required this.visualization,
    required this.calibration,
    required this.smoothing,
    required this.formScore,
    this.holdState, // for duration exercises
    this.minRepDuration = 0.5,
    this.bilateral = false,
    this.sides = const [],
  });

  // Identity
  final String id; // e.g., "squat", "push_up"
  final String name;
  final String displayName;
  final String type;

  // Metadata
  final List<String> targetMuscles;
  final String difficulty;
  final int defaultReps;
  final int defaultSets;
  final int targetDuration; // seconds (for plank, wall_sit, etc.)
  final String description;

  // Pose analysis
  final Map<String, int> landmarks; // name -> MP index
  final List<AngleDef> angles;
  final List<String> stateOrder; // priority order for state evaluation
  final List<ExerciseState> states;
  final CounterRule counterRule;
  final List<FeedbackRule> feedbackRules;
  final VisualizationConfig visualization;
  final CalibrationConfig calibration;
  final SmoothingConfig smoothing;
  final FormScoreConfig formScore;

  // Duration exercise specific
  final String? holdState;

  // Counting
  final double minRepDuration;

  // Bilateral exercises (left/right tracked separately)
  final bool bilateral;
  final List<String> sides; // e.g., ["left", "right"]

  /// Create from parsed YAML map.
  factory ExerciseDefinition.fromYaml(Map<String, dynamic> yaml) {
    final anglesMap = yaml['angles'] as Map<String, dynamic>? ?? {};
    final angles = anglesMap.entries
        .map((e) => AngleDef.fromYaml({
              'name': e.key,
              ...e.value as Map<String, dynamic>,
            }))
        .toList();

    final statesMap = yaml['states'] as Map<String, dynamic>? ?? {};
    final states = statesMap.entries
        .map((e) => ExerciseState.fromYaml({
              'name': e.key,
              ...e.value as Map<String, dynamic>,
            }))
        .toList();

    final feedbackMap = yaml['feedback'] as Map<String, dynamic>? ?? {};
    final feedbackRules = feedbackMap.entries
        .map((e) => FeedbackRule.fromYaml({
              'name': e.key,
              ...e.value as Map<String, dynamic>,
            }))
        .toList();

    return ExerciseDefinition(
      id: yaml['name'] as String? ?? '',
      name: yaml['name'] as String? ?? '',
      displayName: yaml['display_name'] as String? ??
          (yaml['name'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
      type: yaml['type'] as String? ?? 'repetition',
      targetMuscles: List<String>.from(yaml['target_muscles'] as List? ?? []),
      difficulty: yaml['difficulty'] as String? ?? 'beginner',
      defaultReps: yaml['default_reps'] as int? ?? 10,
      defaultSets: yaml['default_sets'] as int? ?? 3,
      targetDuration: yaml['target_duration'] as int? ?? 30,
      description: yaml['description'] as String? ?? '',
      landmarks: (yaml['landmarks'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      angles: angles,
      stateOrder: List<String>.from(yaml['state_order'] as List? ?? []),
      states: states,
      counterRule: CounterRule.fromYaml(
          Map<String, dynamic>.from(yaml['counter'] as Map? ?? {})),
      feedbackRules: feedbackRules,
      visualization: VisualizationConfig.fromYaml(yaml['visualization']),
      calibration: CalibrationConfig.fromYaml(yaml['calibration']),
      smoothing: SmoothingConfig.fromYaml(yaml['smoothing']),
      formScore: FormScoreConfig.fromYaml(yaml['form_score']),
      holdState: yaml['hold_state'] as String?,
      minRepDuration: (yaml['min_rep_duration'] as num?)?.toDouble() ?? 0.5,
      bilateral: yaml['bilateral'] as bool? ?? false,
      sides: List<String>.from(yaml['sides'] as List? ?? []),
    );
  }

  /// Get state by name.
  ExerciseState? getState(String name) {
    try {
      return states.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Get angle definition by name.
  AngleDef? getAngle(String name) {
    try {
      return angles.firstWhere((a) => a.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Primary angle (first in list or named "primary").
  AngleDef get primaryAngle {
    return angles.firstWhere(
      (a) => a.name == 'primary',
      orElse: () => angles.first,
    );
  }
}

/// Registry of all exercise definitions (loaded from assets).
class ExerciseRegistry {
  ExerciseRegistry._();
  static final ExerciseRegistry _instance = ExerciseRegistry._();
  static ExerciseRegistry get instance => _instance;

  final Map<String, ExerciseDefinition> _definitions = {};

  /// Register a definition (called at startup for each YAML).
  void register(ExerciseDefinition def) {
    _definitions[def.id] = def;
  }

  /// Get definition by ID.
  ExerciseDefinition? get(String id) => _definitions[id];

  /// Tolerant lookup across naming styles: exact first, then a normalized
  /// match (case / separators collapsed) so content-pack ids like `pushup`,
  /// `jumpingJack`, `glute-bridge` resolve to the FSM ids `push_up`,
  /// `jumping_jack`, `glute_bridge`.
  ExerciseDefinition? resolve(String id) {
    final exact = _definitions[id];
    if (exact != null) return exact;
    final key = _normalize(id);
    for (final entry in _definitions.entries) {
      if (_normalize(entry.key) == key) return entry.value;
    }
    return null;
  }

  static String _normalize(String id) =>
      id.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  /// All registered definitions.
  List<ExerciseDefinition> get all => _definitions.values.toList();

  /// All IDs.
  List<String> get ids => _definitions.keys.toList();

  /// Clear (for testing).
  void clear() => _definitions.clear();
}