/// Extended catalog — cyclic, cardio and mobility/flow exercises. Every
/// remaining bundled exercise gets a real FSM so visual rep counting covers
/// the full library (user directive: counting is by the visuals, never
/// tapping).
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
    // body_line needs the ankle vertex; without it the angle is skipped,
    // angles stay empty and the rep never counts. Six landmarks also meet
    // the visibility gate.
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
      description: 'Body line angle (straight-line hold)',
    ),
  ],
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
    // secondary needs the ankle vertex; without it the angle is skipped
    // (missing context reads as 0), folded can never hold and the rep
    // never counts.
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
    AngleDef(
      name: 'secondary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee flexion angle',
    ),
  ],
  stateOrder: ['folded', 'standing'],
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
    // primary needs the knee vertex; without it the angle is skipped and
    // the chest_tall feedback never evaluates on real data.
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
      description: 'Hip angle (seated torso-to-thigh)',
    ),
  ],
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
      name: 'chest_tall',
      condition: 'angle < 110',
      message: 'Keep the chest tall!',
      audioCue: 'Chest up!',
    ),
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

// ---------------------------------------------------------------------------
// Extended catalog part 3 — mobility flows, yoga holds and crawls. Same DSL;
// the timed entries follow the plank pattern (type 'duration' + holdState,
// hold timing owned by the workout session controller).
// ---------------------------------------------------------------------------

/// Bodyweight good morning — hip hinge counted on the return to standing.
const ExerciseDefinition goodMorningDefinition = ExerciseDefinition(
  id: 'good_morning',
  name: 'good_morning',
  displayName: 'Bodyweight Good Morning',
  type: 'repetition',
  targetMuscles: ['Glutes', 'Hamstrings', 'Lower Back'],
  difficulty: 'intermediate',
  defaultReps: 15,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Hip hinge counting the fold-to-stand cycle',
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
      description: 'Hip hinge angle (torso to thigh)',
    ),
    AngleDef(
      name: 'secondary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Knee flexion angle',
    ),
  ],
  stateOrder: ['standing', 'ascending', 'bottom', 'descending'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 160',
      description: 'Standing tall, hinge finished',
    ),
    ExerciseState(
      name: 'ascending',
      condition: 'angle > 100 and angle <= 160 and angle_vel > 0',
      description: 'Driving the hips forward to stand',
    ),
    ExerciseState(
      name: 'bottom',
      condition: 'angle <= 100',
      description: 'Torso near parallel, spine flat',
    ),
    ExerciseState(
      name: 'descending',
      condition: 'angle > 100 and angle <= 160 and angle_vel <= 0',
      description: 'Pushing the hips back',
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
      condition: "state == 'ascending' and min_angle > 110",
      message: 'Hinge deeper — torso closer to parallel!',
      audioCue: 'Hinge deeper!',
    ),
    FeedbackRule(
      name: 'soft_knees',
      condition: "state == 'descending' and secondary_angle > 170",
      message: 'Soften the knees before hinging!',
      audioCue: 'Soften your knees!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'standing'",
      message: 'Good form, drive the hips forward',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Flutter kick — supine alternating kicks counted on each stroke via the
/// ankle heights crossing (coordinate-based like russian_twist).
const ExerciseDefinition flutterKickDefinition = ExerciseDefinition(
  id: 'flutter_kick',
  name: 'flutter_kick',
  displayName: 'Flutter Kick',
  type: 'repetition',
  targetMuscles: ['Abs', 'Hip Flexors', 'Quadriceps'],
  difficulty: 'beginner',
  defaultReps: 40,
  defaultSets: 3,
  targetDuration: 0,
  description: 'Supine flutter counting each alternating kick stroke',
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
  stateOrder: ['left_up', 'right_up'],
  states: [
    ExerciseState(
      name: 'left_up',
      condition: 'left_ankle_y < right_ankle_y - 0.02',
      description: 'Left heel kicked higher',
    ),
    ExerciseState(
      name: 'right_up',
      condition: 'left_ankle_y > right_ankle_y + 0.02',
      description: 'Right heel kicked higher',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'right_up',
    requiredPriorState: 'left_up',
    minRepDuration: 0.25,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'knees_bent',
      condition: 'angle < 120',
      message: 'Kick from the hips — keep the knees nearly straight!',
      audioCue: 'Straighten the legs!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'right_up'",
      message: 'Good rhythm, back pressed down',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Cat-Cow — quadruped spinal flow counted on each cat-to-cow cycle via the
/// hip angle (pelvic tilt proxy: cow opens the angle like a bird-dog
/// extension, cat tucks it closed).
const ExerciseDefinition catCowDefinition = ExerciseDefinition(
  id: 'cat_cow',
  name: 'cat_cow',
  displayName: 'Cat-Cow',
  type: 'repetition',
  targetMuscles: ['Mobility', 'Back', 'Core'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 2,
  targetDuration: 0,
  description: 'Quadruped spinal flow counting each cat-to-cow cycle',
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
      description: 'Hip angle (torso to thigh, pelvic tilt proxy)',
    ),
  ],
  stateOrder: ['cow', 'cat'],
  states: [
    ExerciseState(
      name: 'cat',
      condition: 'angle <= 92',
      description: 'Spine rounded up, tailbone tucked',
    ),
    ExerciseState(
      name: 'cow',
      condition: 'angle >= 108',
      description: 'Belly dropped, chest and tailbone lifted',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'cow',
    requiredPriorState: 'cat',
    minRepDuration: 1.2,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'round',
      condition: "state == 'cat'",
      message: 'Round the spine toward the ceiling',
      type: 'info',
    ),
    FeedbackRule(
      name: 'arch',
      condition: "state == 'cow'",
      message: 'Drop the belly, lift the chest',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// World's Greatest Stretch — lunge flow counted on each reach to the
/// ceiling. Unilateral like the reference engine: the left (moving) arm is
/// tracked; sides alternate per set.
const ExerciseDefinition greatestStretchDefinition = ExerciseDefinition(
  id: 'greatest_stretch',
  name: 'greatest_stretch',
  displayName: "World's Greatest Stretch",
  type: 'repetition',
  targetMuscles: ['Mobility', 'Hamstrings', 'Glutes'],
  difficulty: 'beginner',
  defaultReps: 8,
  defaultSets: 2,
  targetDuration: 0,
  description: 'Lunge flow counting each rotation to the ceiling',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
    'left_ankle': MpLandmark.leftAnkle,
    'right_ankle': MpLandmark.rightAnkle,
    'left_wrist': MpLandmark.leftWrist,
    'right_wrist': MpLandmark.rightWrist,
  },
  angles: [
    AngleDef(
      name: 'primary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Front-leg knee angle',
    ),
  ],
  stateOrder: ['reaching', 'planted'],
  states: [
    ExerciseState(
      name: 'planted',
      condition: 'left_wrist_y > left_shoulder_y',
      description: 'Hands inside the front foot, elbow dropping',
    ),
    ExerciseState(
      name: 'reaching',
      condition: 'left_wrist_y < left_shoulder_y and angle <= 130',
      description: 'Top arm rotated to the ceiling',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'reaching',
    requiredPriorState: 'planted',
    minRepDuration: 0.8,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'depth',
      condition: "state == 'reaching' and min_angle > 110",
      message: 'Sink the hips — deepen the lunge!',
      audioCue: 'Sink deeper!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'planted'",
      message: 'Good, elbow toward the floor',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Thoracic Rotation — quadruped rotation counted on each elbow-up arc via
/// the rotating-arm elbow angle. Unilateral like the reference engine: the
/// left elbow is tracked; sides switch per set.
const ExerciseDefinition thoracicRotationDefinition = ExerciseDefinition(
  id: 'thoracic_rotation',
  name: 'thoracic_rotation',
  displayName: 'Thoracic Rotation',
  type: 'repetition',
  targetMuscles: ['Mobility', 'Back', 'Shoulders'],
  difficulty: 'beginner',
  defaultReps: 10,
  defaultSets: 2,
  targetDuration: 0,
  description: 'Quadruped rotation counting each elbow-up arc',
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
      name: 'primary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Rotating-arm elbow angle',
    ),
  ],
  stateOrder: ['open', 'threading'],
  states: [
    ExerciseState(
      name: 'threading',
      condition: 'angle <= 115',
      description: 'Elbow lowered toward the opposite wrist',
    ),
    ExerciseState(
      name: 'open',
      condition: 'angle >= 150',
      description: 'Chest opened, elbow to the ceiling',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'open',
    requiredPriorState: 'threading',
    minRepDuration: 0.6,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'hips_square',
      condition: 'abs(left_hip_y - right_hip_y) > 0.06',
      message: 'Keep the hips square!',
      audioCue: 'Hips square!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'open'",
      message: 'Good rotation, follow the elbow with your gaze',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Towel shoulder dislocates — full arm arc counted on each pass through
/// the overhead position. Frontal-camera limitation: front-low and
/// behind-low both read as a small hip-shoulder-wrist angle, so each
/// overhead pass counts (a full dislocate is two passes).
const ExerciseDefinition shoulderDislocatesDefinition = ExerciseDefinition(
  id: 'shoulder_dislocates',
  name: 'shoulder_dislocates',
  displayName: 'Towel Shoulder Dislocates',
  type: 'repetition',
  targetMuscles: ['Mobility', 'Shoulders', 'Arms'],
  difficulty: 'beginner',
  defaultReps: 12,
  defaultSets: 2,
  targetDuration: 0,
  description:
      'Towel pass counting each arm arc through the overhead position',
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
        MpLandmark.leftWrist,
      ],
      description: 'Shoulder flexion angle (hip-shoulder-wrist)',
    ),
    AngleDef(
      name: 'secondary',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftElbow,
        MpLandmark.leftWrist,
      ],
      description: 'Elbow extension angle',
    ),
  ],
  stateOrder: ['over', 'front'],
  states: [
    ExerciseState(
      name: 'front',
      condition: 'angle < 110',
      description: 'Towel in front of the thighs or behind the hips',
    ),
    ExerciseState(
      name: 'over',
      condition: 'angle >= 160',
      description: 'Towel passing overhead, elbows straight',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'front',
    requiredPriorState: 'over',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'bent_elbows',
      condition: 'secondary_angle < 150',
      message: 'Keep the elbows straight through the arc!',
      audioCue: 'Straighten the elbows!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'over'",
      message: 'Good, full arc — ribs down',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Warrior Flow — Warrior I/II hold. A single `holding` state covers both
/// poses (the arm angle reads ~90 in Warrior II and ~170 in Warrior I) so
/// the hold timer runs across the whole flow; feedback cues the pose.
const ExerciseDefinition warriorFlowDefinition = ExerciseDefinition(
  id: 'warrior_flow',
  name: 'warrior_flow',
  displayName: 'Warrior Flow',
  type: 'duration',
  targetMuscles: ['Mobility', 'Legs', 'Shoulders'],
  difficulty: 'beginner',
  defaultReps: 0,
  defaultSets: 3,
  targetDuration: 40,
  description: 'Warrior I/II hold for hips and shoulders',
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
      description: 'Arm raise angle (Warrior pose signal)',
    ),
    AngleDef(
      name: 'secondary',
      points: [MpLandmark.leftHip, MpLandmark.leftKnee, MpLandmark.leftAnkle],
      description: 'Front-leg knee angle',
    ),
  ],
  stateOrder: ['holding', 'rest'],
  states: [
    ExerciseState(
      name: 'rest',
      condition: 'angle < 70',
      description: 'Arms lowered — out of the flow',
    ),
    ExerciseState(
      name: 'holding',
      condition: 'angle >= 70',
      description: 'Warrior pose — hold timer runs',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'holding',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'warrior1',
      condition: "state == 'holding' and angle >= 150",
      message: 'Warrior I — reach tall, hips squared',
      type: 'info',
    ),
    FeedbackRule(
      name: 'warrior2',
      condition: "state == 'holding' and angle < 130",
      message: 'Warrior II — arms in a strong T',
      type: 'info',
    ),
    FeedbackRule(
      name: 'stance',
      condition: "state == 'holding' and secondary_angle > 150",
      message: 'Bend into the front knee!',
      audioCue: 'Bend the front knee!',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'holding',
);

/// Downward Dog — inverted-V hold counted on the hip peak.
const ExerciseDefinition downwardDogDefinition = ExerciseDefinition(
  id: 'downward_dog',
  name: 'downward_dog',
  displayName: 'Downward Dog',
  type: 'duration',
  targetMuscles: ['Mobility', 'Hamstrings', 'Shoulders'],
  difficulty: 'beginner',
  defaultReps: 0,
  defaultSets: 2,
  targetDuration: 30,
  description: 'Inverted-V hold for hamstrings and shoulders',
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
      description: 'Hip angle (inverted-V peak)',
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
  stateOrder: ['holding', 'setup', 'rest'],
  states: [
    ExerciseState(
      name: 'rest',
      condition: 'angle >= 150',
      description: 'Standing or lowered out of the pose',
    ),
    ExerciseState(
      name: 'setup',
      condition: 'angle > 100 and angle < 150',
      description: 'Lifting into the inverted V',
    ),
    ExerciseState(
      name: 'holding',
      condition: 'angle <= 100',
      description: 'Hips peaked — hold timer runs',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'holding',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'hips_low',
      condition: "state == 'setup' and angle > 120",
      message: 'Lift the hips higher into the V!',
      audioCue: 'Hips higher!',
    ),
    FeedbackRule(
      name: 'good_form',
      condition: "state == 'holding' and secondary_angle < 105",
      message: 'Good — press the floor away, chest to the thighs',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'holding',
);

/// Cobra Stretch — prone back-extension hold counted on the chest lift
/// (same shoulder-over-hip signal as superman, held for time).
const ExerciseDefinition cobraStretchDefinition = ExerciseDefinition(
  id: 'cobra_stretch',
  name: 'cobra_stretch',
  displayName: 'Cobra Stretch',
  type: 'duration',
  targetMuscles: ['Mobility', 'Lower Back', 'Core'],
  difficulty: 'beginner',
  defaultReps: 0,
  defaultSets: 2,
  targetDuration: 30,
  description: 'Prone chest-lift hold for spinal extension',
  landmarks: {
    'left_shoulder': MpLandmark.leftShoulder,
    'right_shoulder': MpLandmark.rightShoulder,
    'left_hip': MpLandmark.leftHip,
    'right_hip': MpLandmark.rightHip,
    // body_line needs the knee vertex; without it the angle is skipped,
    // angles stay empty and the hold clock has no state to accumulate.
    'left_knee': MpLandmark.leftKnee,
    'right_knee': MpLandmark.rightKnee,
  },
  angles: [
    AngleDef(
      name: 'body_line',
      points: [
        MpLandmark.leftShoulder,
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
      ],
      description: 'Hip extension angle (chest lift)',
    ),
  ],
  stateOrder: ['holding', 'rest'],
  states: [
    ExerciseState(
      name: 'rest',
      condition: 'left_shoulder_y - left_hip_y >= -0.04',
      description: 'Lying flat, chest down',
    ),
    ExerciseState(
      name: 'holding',
      condition: 'left_shoulder_y - left_hip_y < -0.04',
      description: 'Chest lifted — hold timer runs',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'holding',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'lift',
      condition: "state == 'rest'",
      message: 'Press into the hands and lift the chest!',
      audioCue: 'Lift the chest!',
    ),
    FeedbackRule(
      name: 'good_form',
      condition: "state == 'holding'",
      message: 'Good — chest open, hips grounded',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'holding',
);

/// Child's Pose — restorative kneel-fold hold counted on the fold.
const ExerciseDefinition childsPoseDefinition = ExerciseDefinition(
  id: 'childs_pose',
  name: 'childs_pose',
  displayName: "Child's Pose",
  type: 'duration',
  targetMuscles: ['Mobility', 'Lower Back', 'Hips'],
  difficulty: 'beginner',
  defaultReps: 0,
  defaultSets: 2,
  targetDuration: 45,
  description: 'Kneel-fold rest hold for the lower back and hips',
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
      description: 'Hip fold angle',
    ),
  ],
  stateOrder: ['holding', 'setup', 'rest'],
  states: [
    ExerciseState(
      name: 'rest',
      condition: 'angle >= 150',
      description: 'Upright kneeling or standing',
    ),
    ExerciseState(
      name: 'setup',
      condition: 'angle > 90 and angle < 150',
      description: 'Sitting the hips back toward the heels',
    ),
    ExerciseState(
      name: 'holding',
      condition: 'angle <= 90',
      description: 'Folded forward — hold timer runs',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'holding',
    minRepDuration: 1.0,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'sink',
      condition: "state == 'setup'",
      message: 'Sit the hips back toward the heels!',
      audioCue: 'Sit back!',
    ),
    FeedbackRule(
      name: 'good_form',
      condition: "state == 'holding'",
      message: 'Rest here, breathe into the back ribs',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
  holdState: 'holding',
);

/// Bear Crawl — in-place crawl counted on the alternating knee heights
/// (each contralateral step lifts the opposite knee; the frontal camera
/// hides forward steps, so the visible step signal is which knee rides
/// higher). A straight-leg guard keeps the count off while standing.
const ExerciseDefinition bearCrawlDefinition = ExerciseDefinition(
  id: 'bear_crawl',
  name: 'bear_crawl',
  displayName: 'Bear Crawl In Place',
  type: 'repetition',
  targetMuscles: ['Full Body', 'Core', 'Shoulders'],
  difficulty: 'intermediate',
  defaultReps: 12,
  defaultSets: 3,
  targetDuration: 0,
  description: 'In-place crawl counting each alternating knee step',
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
      description: 'Knee flexion angle (crawl-posture guard)',
    ),
  ],
  stateOrder: ['right_step', 'left_step', 'standing'],
  states: [
    ExerciseState(
      name: 'standing',
      condition: 'angle > 140',
      description: 'Hips high — out of the crawl',
    ),
    ExerciseState(
      name: 'right_step',
      condition: 'angle <= 140 and left_knee_y > right_knee_y + 0.015',
      description: 'Right knee riding higher — right step',
    ),
    ExerciseState(
      name: 'left_step',
      condition: 'angle <= 140 and left_knee_y < right_knee_y - 0.015',
      description: 'Left knee riding higher — left step',
    ),
  ],
  counterRule: CounterRule(
    triggerState: 'right_step',
    requiredPriorState: 'left_step',
    minRepDuration: 0.25,
  ),
  feedbackRules: [
    FeedbackRule(
      name: 'knees_down',
      condition: 'angle <= 140 and left_knee_y > left_ankle_y - 0.01',
      message: 'Lift the knees off the floor!',
      audioCue: 'Knees up!',
    ),
    FeedbackRule(
      name: 'good',
      condition: "state == 'right_step'",
      message: 'Good — stay low, back flat',
      type: 'info',
    ),
  ],
  visualization: VisualizationConfig(),
  calibration: CalibrationConfig(),
  smoothing: SmoothingConfig(enabled: true, window: 5),
  formScore: FormScoreConfig(),
);

/// Public list of every extra definition (parts 2 and 3) so the main
/// catalog can spread them into `bundledDefinitions`.
const List<ExerciseDefinition> catalogExtraDefinitions = [
  burpeeDefinition,
  buttKicksDefinition,
  deadBugDefinition,
  birdDogDefinition,
  supermanDefinition,
  inchwormDefinition,
  skaterJumpDefinition,
  bicycleCrunchDefinition,
  russianTwistDefinition,
  vUpDefinition,
  goodMorningDefinition,
  flutterKickDefinition,
  catCowDefinition,
  greatestStretchDefinition,
  thoracicRotationDefinition,
  shoulderDislocatesDefinition,
  warriorFlowDefinition,
  downwardDogDefinition,
  cobraStretchDefinition,
  childsPoseDefinition,
  bearCrawlDefinition,
];
