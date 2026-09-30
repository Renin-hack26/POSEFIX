/// Extended catalog part 2 — cyclic + cardio exercises. Every remaining
/// bundled exercise gets a real FSM so visual rep counting covers the full
/// library (user directive: counting is by the visuals, never tapping).
///
/// Thresholds follow the same biomechanical approach as the ported
/// Model-samples FSMs; the user may override them later (PLANNING §10.1).
library;

import 'exercise_definition.dart';

/// Burpee — squat-thrust-jump cycle counted on the return to standing.
const ExerciseDefinition burpeeDefinition = ExerciseDefinition(
  id: 'burpee',
  name: 'burpee',
  displayName: 'Burpee',
  type: 'repetition',
  targetMuscles: ['Full Body', 'Chest', 'Quadriceps', 'Core'],
  difficulty: 'advanced',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Full-body burpee counting the squat-thrust-stand cycle',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_elbow': MpLandmark.leftElbow,
    'right_elbow': MpLandmark.rightElbow,
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
      description: 'Standing tall',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 120 and angle <= 160 and angle_vel > 0',
      description: 'Rising back to standing',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 120',
      description: 'Crouched / thrust position',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 120 and angle <= 160 and angle_vel <= 0',
      description: 'Dropping into the crouch',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'standing',
    requiredPriorState: 'bottom',
    minRepDuration: 1.2,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'chest',
      condition: 'secondary_angle < 40',
      message: 'Keep your chest up!',
      audioCue: 'Chest up!',
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

/// Butt kicks — rapid heel-to-glute knee flexion cycles.
const ExerciseDefinition buttKicksDefinition = ExerciseDefinition(
  id: 'butt_kicks',
  name: 'butt_kicks',
  displayName: 'Butt Kicks',
  type: 'repetition',
  targetMuscles: ['Hamstrings', 'Calves'],
  difficulty: 'beginner',
  defaultReps: 20,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Jog in place kicking your heels to your glutes',
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
      description: 'Knee flexion angle',
    ),
  ],
  stateOrder: ['kicking', 'standing'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 150',
      description: 'Leg extended under the body',
    ),
    ExerciseState(
      name: 'kicking',
      condition: 'angle <= 70',
      description: 'Heel kicked up to the glute',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'kicking',
    requiredPriorState: 'standing',
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'heel_high',
      condition: "state == 'standing' and min_angle > 110",
      message: 'Kick higher — heels to your glutes!',
      audioCue: 'Kick higher!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'kicking'",
      message: 'Good rhythm',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Dead bug — supine opposite limb extension via the knee cycle.
const ExerciseDefinition deadBugDefinition = ExerciseDefinition(
  id: 'dead_bug',
  name: 'dead_bug',
  displayName: 'Dead Bug',
  type: 'repetition',
  targetMuscles: ['Core', 'Hip Flexors'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Supine core exercise counting the limb-extension cycle',
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
      description: 'Knee flexion angle (moving leg)',
    ),
  ],
  stateOrder: ['extended', 'tucked'],
  states: [
    ExerciseState(
      name: 'tucked',
      condition: 'angle <= 100',
      description: 'Knee bent over the hip',
    ),
    ExerciseState(
      name: 'extended',
      condition: 'angle >= 150',
      description: 'Leg extended away',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'extended',
    requiredPriorState: 'tucked',
    minRepDuration: 0.5,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'extended'",
      message: 'Good form, lower back stays down',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Bird dog — quadruped opposite arm/leg extension via the hip angle.
const ExerciseDefinition birdDogDefinition = ExerciseDefinition(
  id: 'bird_dog',
  name: 'bird_dog',
  displayName: 'Bird Dog',
  type: 'repetition',
  targetMuscles: ['Core', 'Glutes', 'Back'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Quadruped stability exercise counting the extension cycle',
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
      description: 'Hip angle (torso to moving leg)',
    ),
  ],
  stateOrder: ['extended', 'neutral'],
  states: [
    ExerciseState(
      name: 'neutral',
      condition: 'angle < 130',
      description: 'Knee under the hip',
    ),
    ExerciseState(
      name: 'extended',
      condition: 'angle >= 150',
      description: 'Arm and leg extended opposite',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'extended',
    requiredPriorState: 'neutral',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'extended'",
      message: 'Good form, hips level',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Superman hold — prone back extension counted via the shoulder lift.
const ExerciseDefinition supermanDefinition = ExerciseDefinition(
  id: 'superman',
  name: 'superman',
  displayName: 'Superman Hold',
  type: 'repetition',
  targetMuscles: ['Lower Back', 'Glutes', 'Shoulders'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Prone back extension counting the chest-lift cycle',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
  },
  angles: [],
  stateOrder: ['lifted', 'down'],
  states: [
    ExerciseState(
      name: 'down',
      condition: 'abs(left_shoulder_y - left_hip_y) < 0.04',
      description: 'Lying flat on the floor',
    ),
    ExerciseState(
      name: 'lifted',
      condition: 'left_shoulder_y - left_hip_y < -0.04',
      description: 'Chest and legs lifted',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'lifted',
    requiredPriorState: 'down',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'lifted'",
      message: 'Good form, squeeze the back',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Inchworm — walkout counted on the return to standing after the fold.
const ExerciseDefinition inchwormDefinition = ExerciseDefinition(
  id: 'inchworm',
  name: 'inchworm',
  displayName: 'Inchworm',
  type: 'repetition',
  targetMuscles: ['Hamstrings', 'Core', 'Shoulders'],
  difficulty: 'beginner',
  defaultReps: 8,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Walkout flow counting the fold-to-stand cycle',
  landmarks: {
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip fold angle',
    ),
    AngleDef(
      name: 'secondary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee flexion angle',
    ),
  ],
  stateOrder: ['standing', 'folded'],
  states: [
    ExerciseState(
      name: 'folded',
      condition: 'primary_angle < 100 and secondary_angle > 150',
      description: 'Folded forward, legs straight',
    ),
    ExerciseState(
      name: 'standing',
      condition: 'secondary_angle < 160',
      description: 'Walking back to standing',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'standing',
    requiredPriorState: 'folded',
    minRepDuration: 1.5,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'folded'",
      message: 'Good form, legs stay straight',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Skater jump — lateral hop cycle counted on each landing.
const ExerciseDefinition skaterJumpDefinition = ExerciseDefinition(
  id: 'skater_jump',
  name: 'skater_jump',
  displayName: 'Skater Jump',
  type: 'repetition',
  targetMuscles: ['Quadriceps', 'Glutes', 'Calves'],
  difficulty: 'intermediate',
  defaultReps: 16,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Lateral hops counting each landing',
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
      description: 'Knee flexion angle',
    ),
  ],
  stateOrder: ['landed', 'air'],
  states: [
    ExerciseState(
      name: 'air',
      condition: 'angle >= 150',
      description: 'Airborne mid-hop',
    ),
    ExerciseState(
      name: 'landed',
      condition: 'angle <= 120',
      description: 'Landed on one leg',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'landed',
    requiredPriorState: 'air',
    minRepDuration: 0.4,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'landed'",
      message: 'Good form, stick the landing',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Bicycle crunch — fast alternating knee-tuck cycles.
const ExerciseDefinition bicycleCrunchDefinition = ExerciseDefinition(
  id: 'bicycle_crunch',
  name: 'bicycle_crunch',
  displayName: 'Bicycle Crunch',
  type: 'repetition',
  targetMuscles: ['Abs', 'Obliques', 'Hip Flexors'],
  difficulty: 'beginner',
  defaultReps: 20,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Alternating crunch counting each knee-tuck cycle',
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
      description: 'Knee flexion angle',
    ),
  ],
  stateOrder: ['tucked', 'extended'],
  states: [
    ExerciseState(
      name: 'extended',
      condition: 'angle >= 140',
      description: 'Leg extended out',
    ),
    ExerciseState(
      name: 'tucked',
      condition: 'angle <= 90',
      description: 'Knee tucked in',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'tucked',
    requiredPriorState: 'extended',
    minRepDuration: 0.4,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'tucked'",
      message: 'Good form, elbow to knee',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Russian twist — torso rotation counted via the hands crossing centre.
const ExerciseDefinition russianTwistDefinition = ExerciseDefinition(
  id: 'russian_twist',
  name: 'russian_twist',
  displayName: 'Russian Twist',
  type: 'repetition',
  targetMuscles: ['Obliques', 'Abs'],
  difficulty: 'beginner',
  defaultReps: 20,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Seated rotation counting each side-to-side pass',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
  },
  angles: [],
  stateOrder: ['right', 'left'],
  states: [
    ExerciseState(
      name: 'left',
      condition: 'left_wrist_x < (left_hip_x + right_hip_x) / 2',
      description: 'Hands twisted to the left',
    ),
    ExerciseState(
      name: 'right',
      condition: 'left_wrist_x > (left_hip_x + right_hip_x) / 2',
      description: 'Hands twisted to the right',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'right',
    requiredPriorState: 'left',
    minRepDuration: 0.3,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'right'",
      message: 'Good form, core engaged',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// V-up — supine V fold counted at the top of the fold.
const ExerciseDefinition vUpDefinition = ExerciseDefinition(
  id: 'v_up',
  name: 'v_up',
  displayName: 'V-Up',
  type: 'repetition',
  targetMuscles: ['Abs', 'Hip Flexors'],
  difficulty: 'intermediate',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Supine V-fold counting each lift to the V position',
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
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip fold angle',
    ),
  ],
  stateOrder: ['v', 'rising', 'flat', 'lowering'],
  states: [
    ExerciseState(
      name: 'flat',
      condition: 'angle > 160',
      description: 'Lying flat',
    ),
    ExerciseState(
      name: 'rising',
      condition: 'angle > 100 and angle <= 160 and angle_vel <= 0',
      description: 'Folding up into the V',
    ),
    ExerciseState(
      name: 'v',
      condition: 'angle <= 100',
      description: 'Hands to feet at the top of the V',
    ),
    ExerciseState(
      name: 'lowering',
      condition: 'angle > 100 and angle <= 160 and angle_vel > 0',
      description: 'Lowering back down',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'v',
    requiredPriorState: 'flat',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'good',
      condition: "state == 'v'",
      message: 'Good form, legs stay straight',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);
