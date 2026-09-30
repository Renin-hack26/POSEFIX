/// FixPose biomechanical form rules — SINGLE source of truth for thresholds.
///
/// Values below are RESEARCHED DEFAULTS (accepted by user; overridable).
/// Never hardcode angle thresholds anywhere else in the codebase.
///
/// Conventions (FR-2 / FR-3):
///  - Angles are interior joint angles in degrees, computed by pose_analyzer.
///  - A rep counts ONLY when full range of motion (ROM) is achieved.
class FormRules {
  const FormRules._();

  // ---------------------------------------------------------------------------
  // SQUAT — Hip-Knee-Ankle tracking (FR-2)
  // Spec example: knee flexion < 90° counts as bottom position (FR-3).
  // ---------------------------------------------------------------------------
  static const double squatKneeFlexionBottomDeg = 90.0; // below = "down" reached
  static const double squatKneeFlexionUpDeg = 160.0; // above = standing "up"
  static const double squatHipFlexionBottomDeg = 100.0;
  static const double squatTorsoLeanWarnDeg = 45.0; // excessive forward lean
  static const double squatKneeCaveInValgusDeg = 15.0; // knee-cave warning (spec: knees caving in)

  // ---------------------------------------------------------------------------
  // PUSHUP — elbow + trunk alignment
  // Spec: "incomplete pushup range of motion" is a key injury risk.
  // ---------------------------------------------------------------------------
  static const double pushupElbowFlexionBottomDeg = 90.0; // chest near floor
  static const double pushupElbowFlexionUpDeg = 165.0; // arms extended = "up"
  static const double pushupHipSagWarnDeg = 165.0; // hip angle too open → sagging hips
  static const double pushupHipPikeWarnDeg = 120.0; // hips piked up

  // ---------------------------------------------------------------------------
  // JUMPING JACK — arm/leg open-close cycles
  // ---------------------------------------------------------------------------
  static const double jackArmRaisedDeg = 140.0; // shoulders abducted overhead
  static const double jackArmDownDeg = 45.0; // arms at sides
  static const double jackLegSpreadDeg = 40.0; // feet apart (hip abduction)
  static const double jackLegClosedDeg = 8.0; // feet together

  // ---------------------------------------------------------------------------
  // Shared detection / counting gates
  // ---------------------------------------------------------------------------
  /// Minimum landmark confidence (0..1) before any state transition is accepted.
  static const double minLandmarkConfidence = 0.5;

  /// Consecutive frames required to confirm a state transition (anti-jitter).
  static const int transitionConfirmFrames = 3;

  /// Landmark smoothing: Exponential Moving Average factor (0..1).
  /// Higher = more responsive, lower = smoother.
  static const double emaSmoothingAlpha = 0.3;

  /// Minimum landmarks that must be visible for an exercise to be analyzed
  /// (handles partial body in frame, e.g. legs cut off during pushups).
  static const Map<String, int> minVisibleLandmarks = {
    'squat': 8, // both hips, knees, ankles + torso
    'pushup': 6, // shoulders, elbows, hips
    'jumpingJack': 8, // wrists, shoulders, hips, ankles
  };
}
