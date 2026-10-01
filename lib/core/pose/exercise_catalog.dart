/// FixPose exercise catalog — FSM definitions ported 1:1 from the reference
/// YAMLs (`Model samples/.../exercises/definitions/*.yaml`).
///
/// Port notes (all intentional, documented):
/// - Pixel-space coordinate rules (e.g. lunge `left_knee_x > left_ankle_x+50`)
///   are converted to normalized 0..1 space (+0.08 / -0.03) — the analyzer
///   feeds normalized coords.
/// - Turkish feedback copy in plank/lunge YAMLs is translated to English.
/// - `smoothing` is enabled (window 5) on the counted moves as the bad-camera
///   fine-tune; YAMLs that omit the block get the same default.
/// - `min_rep_duration` per exercise doubles as the anti-double-count gate
///   alongside the brain's consecutive-frame stabilizer.
/// - Jumping-jack `closing` shared `opening`'s angle range in the YAML, so it
///   was unreachable (dead in the reference engine too). The port adds a
///   `<angle>_vel` direction term (engine-provided, ±40 °/s deadband) so the
///   "Hands higher!" cue can actually fire — same shape as the other rules.
/// - Plank is `type: duration` with `holdState: 'hold'` — hold timing is
///   owned by the workout session controller (Phase D); the brain exposes
///   the live state per frame.
library;

import 'exercise_catalog_extra.dart';
import 'exercise_definition.dart';

const ExerciseDefinition squatDefinition = ExerciseDefinition(
  id: 'squat',
  name: 'squat',
  displayName: 'Squats',
  type: 'repetition',
  targetMuscles: ['Quadriceps', 'Glutes', 'Hamstrings'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description:
      'Compound lower body exercise tracking hip, knee, and ankle kinematics',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee flexion angle',
    ),
    AngleDef(
      name: 'secondary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip/torso inclination angle',
    ),
  ],
  stateOrder: ['standing', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 160',
      description: 'Fully upright position',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 90 and angle <= 160 and angle_vel > 0',
      description: 'Pushing back up',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 90',
      description: 'Parallel or below parallel depth',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 90 and angle <= 160 and angle_vel <= 0',
      description: 'Moving into squat',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'standing',
    requiredPriorState: 'bottom',
    // 0.8 dropped fast touch-and-go squats; 0.3 allows a 3-rep/sec cadence
    // (333 ms) while still exceeding the shortest possible wobble chain
    // (4 confirmed frames ≈ 160 ms at 25 fps).
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 95",
      message: 'Go deeper!',
      audioCue: 'Go deeper!',
    ),
    FeedbackRule(
      name: 'chest',
      condition: 'secondary_angle < 45',
      message: 'Keep your chest up!',
      audioCue: 'Keep your chest up!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'standing'",
      message: 'Good form, drive through heels',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition pushUpDefinition = ExerciseDefinition(
  id: 'push_up',
  name: 'push_up',
  displayName: 'Push-ups',
  type: 'repetition',
  targetMuscles: ['Chest', 'Triceps', 'Anterior Deltoids', 'Core'],
  difficulty: 'intermediate',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description:
      'Upper body pushing movement tracking arm flexion and core alignment',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Elbow flexion angle',
    ),
    AngleDef(
      name: 'posture',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftAnkle,
      ],
      description: 'Spine and core alignment',
    ),
  ],
  stateOrder: ['plank_up', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'plank_up',
      condition: 'angle > 155',
      description: 'Arms extended in high plank',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 90 and angle <= 155 and angle_vel > 0',
      description: 'Pushing back to high plank',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 90',
      description: 'Chest down with 90-degree arm bend',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 90 and angle <= 155 and angle_vel <= 0',
      description: 'Lowering body towards floor',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'plank_up',
    requiredPriorState: 'bottom',
    // Fast push-up cadence (up to 3 rep/sec) was gated out at 0.8; 0.3
    // counts it while visit-memory + stabilizer still reject wobble.
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 100",
      message: 'Lower your chest more!',
      audioCue: 'Go deeper!',
    ),
    FeedbackRule(
      name: 'core',
      condition: 'posture_angle < 150',
      message: "Keep your core tight! Don't sag hips.",
      audioCue: 'Keep your core tight!',
    ),
    FeedbackRule(
      name: 'lockout',
      condition: "state == 'plank_up'",
      message: 'Lock out at the top',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition jumpingJackDefinition = ExerciseDefinition(
  id: 'jumping_jack',
  name: 'jumping_jack',
  displayName: 'Jumping Jacks',
  type: 'repetition',
  targetMuscles: ['Calves', 'Deltoids', 'Core', 'Cardiovascular System'],
  difficulty: 'beginner',
  defaultReps: 20,
  defaultSets: 3,
  targetDuration: 0,
  description:
      'Full body aerobic jumping movement tracking arm abduction and leg spread',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'left_arm',
      points: [
        MpLandmark.leftHip,
        MpLandmark.leftShoulder,
        MpLandmark.leftWrist,
      ],
      description: 'Left arm overhead angle',
    ),
    AngleDef(
      name: 'right_arm',
      points: [
        MpLandmark.rightHip,
        MpLandmark.rightShoulder,
        MpLandmark.rightWrist,
      ],
      description: 'Right arm overhead angle',
    ),
  ],
  stateOrder: ['closed', 'opening', 'open', 'closing'],
  states: [
    ExerciseState(
      name: 'closed',
      condition: 'left_arm_angle < 45 and right_arm_angle < 45',
      description: 'Feet together, arms at sides',
    ),
    ExerciseState(
      name: 'opening',
      condition:
          'left_arm_angle >= 45 and left_arm_angle < 135 and left_arm_vel >= -40',
      description: 'Jumping out and raising arms',
    ),
    ExerciseState(
      name: 'open',
      condition: 'left_arm_angle >= 135 and right_arm_angle >= 135',
      description: 'Feet wide, arms overhead',
    ),
    ExerciseState(
      name: 'closing',
      condition:
          'left_arm_angle < 135 and left_arm_angle >= 45 and left_arm_vel < -40',
      description: 'Returning to starting position',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'closed',
    requiredPriorState: 'open',
    // Fast jumping-jack cycles — a 3-rep/sec cadence beats the old 0.6 gate.
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'reach',
      condition: "state == 'closing' and max_arm_angle < 130",
      message: 'Raise your arms all the way up!',
      audioCue: 'Hands higher!',
    ),
    FeedbackRule(
      name: 'great',
      condition: "state == 'open'",
      message: 'Great reach!',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition plankDefinition = ExerciseDefinition(
  id: 'plank',
  name: 'plank',
  displayName: 'Plank',
  type: 'duration',
  targetMuscles: ['Core', 'Shoulders', 'Back'],
  difficulty: 'beginner',
  defaultReps: 3,
  defaultSets: 1,
  targetDuration: 30,
  description: 'Isometric plank hold for core strength',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'body_line',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftAnkle,
      ],
      description: 'Body line angle',
    ),
    AngleDef(
      name: 'arm_angle',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Arm angle',
    ),
  ],
  stateOrder: ['hold', 'setup', 'rest'],
  states: [
    ExerciseState(
      name: 'rest',
      condition: 'body_line_angle < 140',
      description: 'Resting position',
    ),
    ExerciseState(
      name: 'setup',
      condition: 'body_line_angle >= 140 and body_line_angle < 165',
      description: 'Getting into position',
    ),
    ExerciseState(
      name: 'hold',
      condition: 'body_line_angle >= 165',
      description: 'Plank position — hold timer runs',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'hold',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'hips_high',
      condition: 'body_line_angle > 185',
      message: 'Hips too high! Straighten your body.',
    ),
    FeedbackRule(
      name: 'hips_sagging',
      condition: 'body_line_angle < 165 and body_line_angle > 140',
      message: 'Hips sagging! Tighten your core.',
    ),
    FeedbackRule(
      name: 'good_form',
      condition: 'body_line_angle >= 170 and body_line_angle <= 180',
      message: 'Perfect form! Keep going.',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'hold',
);

const ExerciseDefinition lungeDefinition = ExerciseDefinition(
  id: 'lunge',
  name: 'lunge',
  displayName: 'Lunge',
  type: 'repetition',
  targetMuscles: ['Quadriceps', 'Gluteus', 'Hamstrings', 'Calves'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Forward lunge for leg strength and balance',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Front-leg knee angle',
    ),
    AngleDef(
      name: 'back_leg',
      points: [
        MpLandmark.rightHip,
        MpLandmark.rightKnee,
        MpLandmark.rightAnkle,
      ],
      description: 'Back-leg knee angle',
    ),
    AngleDef(
      name: 'torso',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Torso angle',
    ),
  ],
  stateOrder: ['bottom', 'descent', 'start'],
  states: [
    ExerciseState(
      name: 'start',
      condition: 'angle > 160',
      description: 'Start — upright stance',
    ),
    ExerciseState(
      name: 'descent',
      condition: 'angle > 100 and angle <= 160',
      description: 'Lowering phase',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 100',
      description: 'Bottom position — 90 degrees',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'bottom',
    requiredPriorState: 'descent',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'knee_over_toe',
      condition: 'left_knee_x > left_ankle_x + 0.08',
      message: 'Knee passing your toes!',
    ),
    FeedbackRule(
      name: 'torso_leaning',
      condition: 'torso_angle < 70',
      message: 'Keep your torso upright!',
    ),
    FeedbackRule(
      name: 'back_knee',
      condition: 'right_knee_y > right_ankle_y - 0.03',
      message: 'Back knee nearly touching!',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(enabled: true, reps: 3),
  smoothing: SmoothingConfig(enabled: true, window: 3),
  formScore: FormScoreConfig(),
);

/// All 46 bundled FSMs (25 here + 21 extras spread from
/// `exercise_catalog_extra.dart`).
const List<ExerciseDefinition> bundledDefinitions = [
  squatDefinition,
  pushUpDefinition,
  jumpingJackDefinition,
  plankDefinition,
  lungeDefinition,
  bicepCurlDefinition,
  calfRaiseDefinition,
  deadliftDefinition,
  gluteBridgeDefinition,
  hammerCurlDefinition,
  highKneesDefinition,
  lateralRaiseDefinition,
  legRaiseDefinition,
  mountainClimberDefinition,
  shoulderPressDefinition,
  sideLungeDefinition,
  tricepDipDefinition,
  wallSitDefinition,
  kneePushUpDefinition,
  inclinePushUpDefinition,
  pikePushUpDefinition,
  sumoSquatDefinition,
  cossackSquatDefinition,
  hipThrustDefinition,
  sidePlankDefinition,
  ...catalogExtraDefinitions,
];

const ExerciseDefinition bicepCurlDefinition = ExerciseDefinition(
  id: 'bicep_curl',
  name: 'bicep_curl',
  displayName: 'Bicep Curl',
  type: 'repetition',
  targetMuscles: ['Biceps', 'Brachialis'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Classic bicep curl with controlled tempo',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Left elbow angle',
    ),
    AngleDef(
      name: 'right_arm',
      points: [
        MpLandmark.rightShoulder,
        MpLandmark.rightElbow,
        MpLandmark.rightWrist,
      ],
      description: 'Right elbow angle',
    ),
  ],
  stateOrder: ['flex', 'curl', 'down'],
  states: [
    ExerciseState(
      name: 'down',
      condition: 'angle > 150',
      description: 'Arm straight — start position',
    ),
    ExerciseState(
      name: 'curl',
      condition: 'angle > 50 and angle <= 150',
      description: 'Lifting phase',
    ),
    ExerciseState(
      name: 'flex',
      condition: 'angle <= 50',
      description: 'Top squeeze — rep counts here',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'flex',
    requiredPriorState: 'curl',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'partial_rep',
      condition: 'angle > 60',
      message: 'Squeeze more at the top!',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(enabled: true, reps: 2),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// NOTE: YAML sets bilateral:true but defines a single `primary` angle, so
/// the reference engine tracks it unilaterally — ported the same way.
const ExerciseDefinition calfRaiseDefinition = ExerciseDefinition(
  id: 'calf_raise',
  name: 'calf_raise',
  displayName: 'Calf Raise',
  type: 'repetition',
  targetMuscles: ['Calves'],
  difficulty: 'beginner',
  defaultReps: 15,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Standing calf raises for lower leg strength',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
    'left_ankle': MpLandmark.leftAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Leg angle',
    ),
  ],
  stateOrder: ['up', 'raise', 'down'],
  states: [
    ExerciseState(
      name: 'down',
      condition: 'angle > 165',
      description: 'Heels on the ground',
    ),
    ExerciseState(
      name: 'raise',
      condition: 'angle > 155 and angle <= 165',
      description: 'Lifting phase',
    ),
    ExerciseState(
      name: 'up',
      condition: 'angle <= 155',
      description: 'Top position',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'up',
    requiredPriorState: 'raise',
    minRepDuration: 0.5,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'bent_knees',
      condition: 'angle < 150',
      message: 'Keep legs straight',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition deadliftDefinition = ExerciseDefinition(
  id: 'deadlift',
  name: 'deadlift',
  displayName: 'Deadlift',
  type: 'repetition',
  targetMuscles: ['Hamstrings', 'Glutes', 'Back'],
  difficulty: 'intermediate',
  defaultReps: 8,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Hip hinge movement for posterior chain',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip hinge angle',
    ),
  ],
  stateOrder: ['up', 'hinge', 'down'],
  states: [
    ExerciseState(
      name: 'up',
      condition: 'angle > 165',
      description: 'Upright stance',
    ),
    ExerciseState(
      name: 'hinge',
      condition: 'angle > 100 and angle <= 165',
      description: 'Hinging phase',
    ),
    ExerciseState(
      name: 'down',
      condition: 'angle <= 100',
      description: 'Bottom position',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'up',
    requiredPriorState: 'down',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'rounded_back',
      condition: 'angle < 90',
      message: "Keep back flat - don't round",
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition gluteBridgeDefinition = ExerciseDefinition(
  id: 'glute_bridge',
  name: 'glute_bridge',
  displayName: 'Glute Bridge',
  type: 'repetition',
  targetMuscles: ['Glutes', 'Hamstrings'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Hip bridge for glute activation',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip angle',
    ),
  ],
  stateOrder: ['up', 'lift', 'down'],
  states: [
    ExerciseState(
      name: 'down',
      condition: 'angle < 120',
      description: 'Hips on the ground',
    ),
    ExerciseState(
      name: 'lift',
      condition: 'angle >= 120 and angle < 165',
      description: 'Lifting phase',
    ),
    ExerciseState(
      name: 'up',
      condition: 'angle >= 165',
      description: 'Full extension',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'up',
    requiredPriorState: 'lift',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'incomplete',
      condition: 'angle < 160',
      message: 'Squeeze glutes - extend fully',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// True bilateral def: separate `left`/`right` elbow angles (plus alignment
/// angles for future cues). NOTE: YAML state names are inverted vs
/// bicep_curl — here `down` is the flexed top. Ported verbatim.
const ExerciseDefinition hammerCurlDefinition = ExerciseDefinition(
  id: 'hammer_curl',
  name: 'hammer_curl',
  displayName: 'Hammer Curl',
  type: 'repetition',
  targetMuscles: ['Biceps', 'Brachialis', 'Forearms'],
  difficulty: 'beginner',
  defaultReps: 8,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Dumbbell hammer curl for bicep development',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
  },
  angles: [
    AngleDef(
      name: 'left',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Left elbow angle',
    ),
    AngleDef(
      name: 'right',
      points: [
        MpLandmark.rightShoulder,
        MpLandmark.rightElbow,
        MpLandmark.rightWrist,
      ],
      description: 'Right elbow angle',
    ),
    AngleDef(
      name: 'left_alignment',
      points: [
        MpLandmark.leftElbow,
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
      ],
      description: 'Left arm alignment angle',
    ),
    AngleDef(
      name: 'right_alignment',
      points: [
        MpLandmark.rightElbow,
        MpLandmark.rightShoulder,
        MpLandmark.rightHip,
      ],
      description: 'Right arm alignment angle',
    ),
  ],
  stateOrder: ['down', 'up', 'flex'],
  states: [
    ExerciseState(
      name: 'flex',
      condition: 'angle > 155',
      description: 'Start position — arm straight',
    ),
    ExerciseState(
      name: 'up',
      condition: 'angle > 47 and angle <= 155',
      description: 'Lifting phase',
    ),
    ExerciseState(
      name: 'down',
      condition: 'angle <= 47',
      description: 'Top position — rep counts here',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'down',
    requiredPriorState: 'up',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'too_fast',
      condition: 'angle < 40',
      message: 'Good squeeze! Hold briefly at the top.',
      type: 'info',
    ),
    FeedbackRule(
      name: 'partial_rep',
      condition: 'angle > 160',
      message: 'Extend fully between reps.',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(enabled: true, reps: 3),
  smoothing: SmoothingConfig(enabled: true, window: 3),
  formScore: FormScoreConfig(),
  bilateral: true,
  sides: ['left', 'right'],
);

/// NOTE: YAML sets bilateral:true with a single angle — unilateral in
/// effect, ported that way like the reference engine.
const ExerciseDefinition highKneesDefinition = ExerciseDefinition(
  id: 'high_knees',
  name: 'high_knees',
  displayName: 'High Knees',
  type: 'repetition',
  targetMuscles: ['Hip Flexors', 'Quads', 'Cardiovascular System'],
  difficulty: 'beginner',
  defaultReps: 20,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Running in place with high knee lifts',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip angle',
    ),
  ],
  stateOrder: ['up', 'lift', 'down'],
  states: [
    ExerciseState(
      name: 'down',
      condition: 'angle > 150',
      description: 'Leg straight',
    ),
    ExerciseState(
      name: 'lift',
      condition: 'angle > 100 and angle <= 150',
      description: 'Lifting',
    ),
    ExerciseState(
      name: 'up',
      condition: 'angle <= 100',
      description: 'Knee up',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'up',
    requiredPriorState: 'lift',
    minRepDuration: 0.2,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'knee_low',
      condition: 'angle > 110',
      message: 'Drive knee higher!',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// NOTE: pixel-space thresholds converted to normalized space
/// (30px → 0.05, 50px → 0.08); Turkish copy translated.
const ExerciseDefinition lateralRaiseDefinition = ExerciseDefinition(
  id: 'lateral_raise',
  name: 'lateral_raise',
  displayName: 'Lateral Raise',
  type: 'repetition',
  targetMuscles: ['Deltoids'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Side raise for shoulder development',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftHip,
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
      ],
      description: 'Left arm-torso angle',
    ),
    AngleDef(
      name: 'right_arm',
      points: [
        MpLandmark.rightHip,
        MpLandmark.rightShoulder,
        MpLandmark.rightElbow,
      ],
      description: 'Right arm-torso angle',
    ),
  ],
  stateOrder: ['top', 'raise', 'start'],
  states: [
    ExerciseState(
      name: 'start',
      condition: 'angle < 30',
      description: 'Start — arms at sides',
    ),
    ExerciseState(
      name: 'raise',
      condition: 'angle >= 30 and angle < 80',
      description: 'Lifting phase',
    ),
    ExerciseState(
      name: 'top',
      condition: 'angle >= 80',
      description: 'Top position — shoulder height',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'top',
    requiredPriorState: 'raise',
    minRepDuration: 0.6,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'swinging',
      condition: 'abs(left_hip_y - right_hip_y) > 0.05',
      message: "Don't swing! Move with control.",
    ),
    FeedbackRule(
      name: 'too_high',
      condition: 'angle > 100',
      message: "Don't raise arms above shoulder level!",
    ),
    FeedbackRule(
      name: 'bent_elbows',
      condition: 'abs(left_shoulder_x - left_wrist_x) < 0.08',
      message: 'Keep a slight bend — straighten a little more!',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(enabled: true, reps: 3),
  smoothing: SmoothingConfig(enabled: true, window: 3),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition legRaiseDefinition = ExerciseDefinition(
  id: 'leg_raise',
  name: 'leg_raise',
  displayName: 'Leg Raise',
  type: 'repetition',
  targetMuscles: ['Abs', 'Hip Flexors'],
  difficulty: 'intermediate',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Lying leg raises for lower abs',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
    'left_ankle': MpLandmark.leftAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip angle',
    ),
  ],
  stateOrder: ['up', 'raise', 'down'],
  states: [
    ExerciseState(
      name: 'down',
      condition: 'angle > 160',
      description: 'Legs on the ground',
    ),
    ExerciseState(
      name: 'raise',
      condition: 'angle > 100 and angle <= 160',
      description: 'Lifting',
    ),
    ExerciseState(
      name: 'up',
      condition: 'angle <= 100',
      description: 'Legs up',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'up',
    requiredPriorState: 'raise',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'momentum',
      condition: 'angle < 80',
      message: "Control the movement - don't swing",
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// NOTE: YAML sets bilateral:true with a single angle — unilateral in
/// effect, ported that way like the reference engine.
const ExerciseDefinition mountainClimberDefinition = ExerciseDefinition(
  id: 'mountain_climber',
  name: 'mountain_climber',
  displayName: 'Mountain Climber',
  type: 'repetition',
  targetMuscles: ['Core', 'Hip Flexors', 'Cardiovascular System'],
  difficulty: 'intermediate',
  defaultReps: 20,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Dynamic cardio with alternating knee drives',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip angle',
    ),
  ],
  stateOrder: ['tucked', 'driving', 'extended'],
  states: [
    ExerciseState(
      name: 'extended',
      condition: 'angle > 160',
      description: 'Leg straight',
    ),
    ExerciseState(
      name: 'driving',
      condition: 'angle > 90 and angle <= 160',
      description: 'Knee driving forward',
    ),
    ExerciseState(
      name: 'tucked',
      condition: 'angle <= 90',
      description: 'Knee to chest',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'tucked',
    requiredPriorState: 'driving',
    minRepDuration: 0.2,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'hips_high',
      condition: 'angle < 70',
      message: 'Keep hips level',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// NOTE: pixel-space thresholds converted to normalized space
/// (100px → 0.15, 50px → 0.08); Turkish copy translated.
const ExerciseDefinition shoulderPressDefinition = ExerciseDefinition(
  id: 'shoulder_press',
  name: 'shoulder_press',
  displayName: 'Shoulder Press',
  type: 'repetition',
  targetMuscles: ['Deltoids', 'Triceps'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Overhead press for shoulder development',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftHip,
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
      ],
      description: 'Left shoulder angle',
    ),
    AngleDef(
      name: 'right_shoulder',
      points: [
        MpLandmark.rightHip,
        MpLandmark.rightShoulder,
        MpLandmark.rightElbow,
      ],
      description: 'Right shoulder angle',
    ),
    AngleDef(
      name: 'left_elbow',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Left elbow angle',
    ),
    AngleDef(
      name: 'right_elbow',
      points: [
        MpLandmark.rightShoulder,
        MpLandmark.rightElbow,
        MpLandmark.rightWrist,
      ],
      description: 'Right elbow angle',
    ),
  ],
  stateOrder: ['top', 'press', 'start'],
  states: [
    ExerciseState(
      name: 'start',
      condition: 'angle < 90',
      description: 'Start — shoulder height',
    ),
    ExerciseState(
      name: 'press',
      condition: 'angle >= 90 and angle < 160',
      description: 'Pressing phase',
    ),
    ExerciseState(
      name: 'top',
      condition: 'angle >= 160',
      description: 'Top position — arms overhead',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'top',
    requiredPriorState: 'press',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'arching_back',
      condition: 'left_shoulder_y < left_hip_y - 0.15',
      message: "Don't arch your back! Brace your core.",
    ),
    FeedbackRule(
      name: 'uneven_arms',
      condition: 'abs(left_wrist_y - right_wrist_y) > 0.08',
      message: 'Raise both arms evenly!',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(enabled: true, reps: 3),
  smoothing: SmoothingConfig(enabled: true, window: 3),
  formScore: FormScoreConfig(),
);

/// NOTE: knee-x comparison is direction-preserving in normalized space
/// (no conversion needed); Turkish copy translated.
const ExerciseDefinition sideLungeDefinition = ExerciseDefinition(
  id: 'side_lunge',
  name: 'side_lunge',
  displayName: 'Side Lunge',
  type: 'repetition',
  targetMuscles: ['Quadriceps', 'Glutes', 'Hip Adductors'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Lateral lunge for inner thigh and hip mobility',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Bent-leg knee angle',
    ),
    AngleDef(
      name: 'standing_leg',
      points: [
        MpLandmark.rightHip,
        MpLandmark.rightKnee,
        MpLandmark.rightAnkle,
      ],
      description: 'Standing-leg angle',
    ),
  ],
  stateOrder: ['bottom', 'descent', 'start'],
  states: [
    ExerciseState(
      name: 'start',
      condition: 'angle > 160',
      description: 'Start — feet wide',
    ),
    ExerciseState(
      name: 'descent',
      condition: 'angle > 100 and angle <= 160',
      description: 'Lowering sideways',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 100',
      description: 'Bottom position',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'bottom',
    requiredPriorState: 'descent',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'knee_caving',
      condition: 'left_knee_x < left_ankle_x',
      message: 'Knee caving inward!',
    ),
    FeedbackRule(
      name: 'standing_leg_bent',
      condition: 'standing_leg_angle < 160',
      message: 'Keep your standing leg straight!',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(enabled: true, reps: 3),
  smoothing: SmoothingConfig(enabled: true, window: 3),
  formScore: FormScoreConfig(),
);

const ExerciseDefinition tricepDipDefinition = ExerciseDefinition(
  id: 'tricep_dip',
  name: 'tricep_dip',
  displayName: 'Tricep Dip',
  type: 'repetition',
  targetMuscles: ['Triceps', 'Chest'],
  difficulty: 'intermediate',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Chair or bench dips for tricep strength',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'left_wrist': MpLandmark.leftWrist,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Elbow angle',
    ),
  ],
  stateOrder: ['up', 'lower', 'down'],
  states: [
    ExerciseState(
      name: 'up',
      condition: 'angle > 160',
      description: 'Arms straight',
    ),
    ExerciseState(
      name: 'lower',
      condition: 'angle > 90 and angle <= 160',
      description: 'Lowering',
    ),
    ExerciseState(
      name: 'down',
      condition: 'angle <= 90',
      description: 'Bottom position',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'up',
    requiredPriorState: 'down',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'shallow',
      condition: 'angle > 100',
      message: 'Go deeper - 90 degree bend',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Duration exercise: `default_reps: 30` is seconds → targetDuration 30,
/// logical hold state `holding`. Hold timing owned by the session
/// controller (Phase D); the brain exposes live state per frame.
const ExerciseDefinition wallSitDefinition = ExerciseDefinition(
  id: 'wall_sit',
  name: 'wall_sit',
  displayName: 'Wall Sit',
  type: 'duration',
  targetMuscles: ['Quadriceps', 'Glutes'],
  difficulty: 'beginner',
  defaultReps: 30,
  defaultSets: 3,
  targetDuration: 30,
  description: 'Isometric hold against wall for quad endurance',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'left_knee': MpLandmark.leftKnee,
    'left_ankle': MpLandmark.leftAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee angle',
    ),
  ],
  stateOrder: ['holding', 'lowering', 'standing'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 150',
      description: 'Standing',
    ),
    ExerciseState(
      name: 'lowering',
      condition: 'angle > 100 and angle <= 150',
      description: 'Lowering',
    ),
    ExerciseState(
      name: 'holding',
      condition: 'angle <= 100',
      description: 'Hold position',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'holding',
    requiredPriorState: 'lowering',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'too_high',
      condition: 'angle > 100',
      message: 'Lower down - aim for 90 degrees',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'holding',
);

// ---------------------------------------------------------------------------
// Extended catalog — every remaining bundled exercise gets a real FSM so
// visual rep counting works for the full library (user directive: counting
// is by the visuals, never manual tapping).
// ---------------------------------------------------------------------------

/// Push-up on the knees — same elbow cycle as the full push-up, knees down.
const ExerciseDefinition kneePushUpDefinition = ExerciseDefinition(
  id: 'knee_push_up',
  name: 'knee_push_up',
  displayName: 'Knee Push-Up',
  type: 'repetition',
  targetMuscles: ['Chest', 'Triceps', 'Core'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Knee-supported push-up tracking the elbow flexion cycle',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Elbow flexion angle',
    ),
    AngleDef(
      name: 'secondary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Body line angle (knees down)',
    ),
  ],
  stateOrder: ['plank_up', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'plank_up',
      condition: 'angle > 155',
      description: 'Arms extended in knee plank',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 90 and angle <= 155 and angle_vel > 0',
      description: 'Pushing back to knee plank',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 90',
      description: 'Chest towards the floor',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 90 and angle <= 155 and angle_vel <= 0',
      description: 'Lowering body towards floor',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'plank_up',
    requiredPriorState: 'bottom',
    // Fast push-up cadence (up to 3 rep/sec) was gated out at 0.8; 0.3
    // counts it while visit-memory + stabilizer still reject wobble.
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 100",
      message: 'Go deeper!',
      audioCue: 'Go deeper!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'plank_up'",
      message: 'Good form, core tight',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Incline push-up — hands elevated, shallower bottom threshold.
const ExerciseDefinition inclinePushUpDefinition = ExerciseDefinition(
  id: 'incline_push_up',
  name: 'incline_push_up',
  displayName: 'Incline Push-Up',
  type: 'repetition',
  targetMuscles: ['Chest', 'Triceps', 'Core'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Hands-elevated push-up tracking the elbow flexion cycle',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Elbow flexion angle',
    ),
    AngleDef(
      name: 'secondary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftAnkle,
      ],
      description: 'Body line angle',
    ),
  ],
  stateOrder: ['plank_up', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'plank_up',
      condition: 'angle > 155',
      description: 'Arms extended on the incline',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 95 and angle <= 155 and angle_vel > 0',
      description: 'Pushing back up',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 95',
      description: 'Chest towards the elevated surface',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 95 and angle <= 155 and angle_vel <= 0',
      description: 'Lowering towards the surface',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'plank_up',
    requiredPriorState: 'bottom',
    // Fast push-up cadence (up to 3 rep/sec) was gated out at 0.8; 0.3
    // counts it while visit-memory + stabilizer still reject wobble.
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 105",
      message: 'Go deeper!',
      audioCue: 'Go deeper!',
    ),
    FeedbackRule(
      name: 'body_line',
      condition: 'secondary_angle < 155 and state == \'plank_up\'',
      message: 'Keep your body straight!',
      audioCue: 'Keep your body straight!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'plank_up'",
      message: 'Good form',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Pike push-up — shoulder-driven cycle (hip-shoulder-wrist angle).
const ExerciseDefinition pikePushUpDefinition = ExerciseDefinition(
  id: 'pike_push_up',
  name: 'pike_push_up',
  displayName: 'Pike Push-Up',
  type: 'repetition',
  targetMuscles: ['Shoulders', 'Triceps', 'Upper Chest'],
  difficulty: 'intermediate',
  defaultReps: 8,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Pike push-up tracking the shoulder flexion cycle',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftHip,
        MpLandmark.leftShoulder,
        MpLandmark.leftWrist,
      ],
      description: 'Shoulder flexion angle (hip-shoulder-wrist)',
    ),
  ],
  stateOrder: ['pike_up', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'pike_up',
      condition: 'angle > 150',
      description: 'Back in the pike position',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 100 and angle <= 150 and angle_vel > 0',
      description: 'Pushing back to the pike',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 100',
      description: 'Head lowered towards hands',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 100 and angle <= 150 and angle_vel <= 0',
      description: 'Lowering the head towards hands',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'pike_up',
    requiredPriorState: 'bottom',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 105",
      message: 'Lower your head closer to the floor!',
      audioCue: 'Lower your head!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'pike_up'",
      message: 'Good form, hips high',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Sumo squat — wide-stance knee cycle with a slightly higher bottom bar.
const ExerciseDefinition sumoSquatDefinition = ExerciseDefinition(
  id: 'sumo_squat',
  name: 'sumo_squat',
  displayName: 'Sumo Squat',
  type: 'repetition',
  targetMuscles: ['Quadriceps', 'Glutes', 'Inner Thighs'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Wide-stance squat tracking the knee flexion cycle',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee flexion angle',
    ),
    AngleDef(
      name: 'secondary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Torso inclination angle',
    ),
  ],
  stateOrder: ['standing', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 160',
      description: 'Fully upright wide stance',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 100 and angle <= 160 and angle_vel > 0',
      description: 'Pushing back up',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 100',
      description: 'Wide-stance depth',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 100 and angle <= 160 and angle_vel <= 0',
      description: 'Squatting down',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'standing',
    requiredPriorState: 'bottom',
    // 0.8 dropped fast touch-and-go squats; 0.3 allows a 3-rep/sec cadence
    // (333 ms) while still exceeding the shortest possible wobble chain
    // (4 confirmed frames ≈ 160 ms at 25 fps).
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 105",
      message: 'Go deeper!',
      audioCue: 'Go deeper!',
    ),
    FeedbackRule(
      name: 'chest',
      condition: 'secondary_angle < 45',
      message: 'Keep your chest up!',
      audioCue: 'Keep your chest up!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'standing'",
      message: 'Good form',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Cossack squat — deep lateral squat, stricter depth bar and slower tempo.
const ExerciseDefinition cossackSquatDefinition = ExerciseDefinition(
  id: 'cossack_squat',
  name: 'cossack_squat',
  displayName: 'Cossack Squat',
  type: 'repetition',
  targetMuscles: ['Quadriceps', 'Glutes', 'Adductors'],
  difficulty: 'advanced',
  defaultReps: 8,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Deep lateral squat tracking the working-knee flexion cycle',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee flexion angle (working leg)',
    ),
    AngleDef(
      name: 'secondary',
      points: [
        MpLandmark.rightHip,
        MpLandmark.rightKnee,
        MpLandmark.rightAnkle,
      ],
      description: 'Knee flexion angle (extended leg)',
    ),
  ],
  stateOrder: ['standing', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 160',
      description: 'Upright, weight shifted',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 95 and angle <= 160 and angle_vel > 0',
      description: 'Driving back up',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 95',
      description: 'Deep lateral depth',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 95 and angle <= 160 and angle_vel <= 0',
      description: 'Shifting into the lateral squat',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'standing',
    requiredPriorState: 'bottom',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 100",
      message: 'Go deeper!',
      audioCue: 'Go deeper!',
    ),
    FeedbackRule(
      name: 'chest',
      condition: 'angle < 130 and secondary_angle < 40',
      message: 'Keep your chest up!',
      audioCue: 'Keep your chest up!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'standing'",
      message: 'Good form',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Hip thrust — hip-extension cycle (shoulder-hip-knee angle).
const ExerciseDefinition hipThrustDefinition = ExerciseDefinition(
  id: 'hip_thrust',
  name: 'hip_thrust',
  displayName: 'Hip Thrust',
  type: 'repetition',
  targetMuscles: ['Glutes', 'Hamstrings', 'Core'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Hip thrust tracking the hip-extension cycle',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip extension angle',
    ),
  ],
  stateOrder: ['top', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'top',
      condition: 'angle > 165',
      description: 'Hips fully extended — squeeze at the top',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 130 and angle <= 165 and angle_vel > 0',
      description: 'Driving the hips up',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 130',
      description: 'Hips lowered',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 130 and angle <= 165 and angle_vel <= 0',
      description: 'Lowering the hips',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'top',
    requiredPriorState: 'bottom',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'ascending' and min_angle > 135",
      message: 'Drive your hips higher!',
      audioCue: 'Hips higher!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'top'",
      message: 'Squeeze at the top',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Side plank — duration hold like the front plank (shoulder-hip-ankle line).
const ExerciseDefinition sidePlankDefinition = ExerciseDefinition(
  id: 'side_plank',
  name: 'side_plank',
  displayName: 'Side Plank',
  type: 'duration',
  targetMuscles: ['Obliques', 'Core', 'Shoulders'],
  difficulty: 'intermediate',
  defaultReps: 3,
  defaultSets: 1,
  targetDuration: 30,
  description: 'Isometric side plank hold for obliques',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
  },
  angles: [
    AngleDef(
      name: 'body_line',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftAnkle,
      ],
      description: 'Body line angle',
    ),
  ],
  stateOrder: ['holding', 'setup', 'rest'],
  states: [
    ExerciseState(
      name: 'rest',
      condition: 'body_line_angle < 140',
      description: 'Resting position',
    ),
    ExerciseState(
      name: 'setup',
      condition: 'body_line_angle >= 140 and body_line_angle < 165',
      description: 'Getting into position',
    ),
    ExerciseState(
      name: 'holding',
      condition: 'body_line_angle >= 165',
      description: 'Side plank position — hold timer runs',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'holding',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'hips_high',
      condition: 'body_line_angle > 185',
      message: 'Hips too high! Straighten your body.',
      audioCue: 'Hips too high!',
    ),
    FeedbackRule(
      name: 'hips_sagging',
      condition: 'body_line_angle < 165 and body_line_angle > 140',
      message: 'Hips sagging! Tighten your core.',
      audioCue: 'Hips up!',
    ),
    FeedbackRule(
      name: 'good_form',
      condition: 'body_line_angle >= 170 and body_line_angle <= 180',
      message: 'Perfect form! Keep going.',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'holding',
);

/// Registers every bundled definition. Call once at startup (and in tests).
void registerExerciseCatalog() {
  final registry = ExerciseRegistry.instance;
  for (final def in bundledDefinitions) {
    registry.register(def);
  }
}
