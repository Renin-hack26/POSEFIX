/// Central coaching vocabulary (WS8.3) — ONE module owns every coaching line.
///
/// Every line is tagged by [CueSituation] + [CueAction] and flows through
/// [CueLine], so the on-screen cue slot and the spoken voice can never
/// diverge: both render the same entry (display text on screen, spoken text
/// aloud). Per-exercise [FeedbackRule] texts keep their specificity but are
/// funneled through [CueVocabulary.feedback] so they carry the same tags.
///
/// Pure Dart — no widgets, no channels. Integrity pinned in
/// test/unit/ws8_engine_rules_test.dart (≥50 lines, no empty/dupe lines,
/// every situation covered, every engine event maps to a line).
library;

import 'package:fixpose/core/audio/sound_engine.dart';
import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/pose_analyzer.dart';

/// Delivery channel for a coaching line.
enum CueAction {
  /// Rendered in the on-screen cue slot / banner.
  display,

  /// Spoken through the arbiter queue ([SoundEngine.speakCue]).
  speak,

  /// Spoken immediately, cutting the current line ([SoundEngine.speakUrgent]).
  speakUrgent,

  /// Haptic pulse alongside (wrong-pose / safety moments).
  haptic,
}

/// Situation a coaching line belongs to. Every value has at least one line
/// in [CueVocabulary.lines] (pinned by test).
enum CueSituation {
  lockNoPerson,
  lockMultiPerson,
  lockLostTracking,
  lockOccluded,
  lockVideoPlayback,
  framingStepBack,
  framingStepCloser,
  framingMoveLeft,
  framingMoveRight,
  framingTurnSideways,
  repRejectedTooFast,
  repRejectedShortRange,
  sessionCompleteTriumphant,
  sessionCompleteEncouraging,
  sessionCompleteGentle,
  sessionCompleteEnergetic,
  sessionStart,
  sessionPause,
  sessionResume,
  sessionCancel,
  sessionEnd,
  roundComplete,
  lastRound,
  restStart,
  restCountdown,
  restEnd,
  milestone,
  encouragement,
  formWarning,
  formPraise,
  safety,
  holdHalfway,
  holdTarget,
}

/// One coaching line: stable id, situation tag, delivery actions, and the
/// display/spoken copy (spoken defaults to the display text).
class CueLine {
  const CueLine({
    required this.id,
    required this.situation,
    required this.actions,
    required this.display,
    this.speak,
  });

  final String id;
  final CueSituation situation;
  final Set<CueAction> actions;
  final String display;
  final String? speak;

  /// Text the voice speaks (falls back to the display text).
  String get spoken => speak ?? display;
}

/// The full vocabulary. Static entries cover every engine/session-level
/// situation; per-exercise feedback rules flow through [feedback].
class CueVocabulary {
  const CueVocabulary._();

  static const List<CueLine> lines = [
    // -- person-lock gate (display banner + urgent voice) -------------------
    CueLine(
      id: 'lock-no-person',
      situation: CueSituation.lockNoPerson,
      actions: {CueAction.display, CueAction.speakUrgent},
      display: 'No person detected. Step into frame to begin.',
    ),
    CueLine(
      id: 'lock-multi-person',
      situation: CueSituation.lockMultiPerson,
      actions: {CueAction.display, CueAction.speakUrgent},
      display:
          'More than one person visible. Train solo so reps stay accurate.',
    ),
    CueLine(
      id: 'lock-lost-tracking',
      situation: CueSituation.lockLostTracking,
      actions: {CueAction.display, CueAction.speakUrgent},
      display: 'Tracking lost. Hold still so the coach can lock on again.',
    ),
    CueLine(
      id: 'lock-occluded',
      situation: CueSituation.lockOccluded,
      actions: {CueAction.display, CueAction.speakUrgent},
      display: 'Body partly hidden. Adjust so your key joints stay visible.',
    ),
    CueLine(
      id: 'lock-video-playback',
      situation: CueSituation.lockVideoPlayback,
      actions: {CueAction.display, CueAction.speakUrgent},
      display: 'Looks like a video is playing — do the exercise yourself so '
          'your reps count.',
    ),
    // -- framing (urgent voice) ----------------------------------------------
    CueLine(
      id: 'framing-step-back',
      situation: CueSituation.framingStepBack,
      actions: {CueAction.speakUrgent},
      display: 'Step back so I can see your full body.',
    ),
    CueLine(
      id: 'framing-step-closer',
      situation: CueSituation.framingStepCloser,
      actions: {CueAction.speakUrgent},
      display: 'Move a little closer to the camera.',
    ),
    CueLine(
      id: 'framing-move-left',
      situation: CueSituation.framingMoveLeft,
      actions: {CueAction.speakUrgent},
      display: 'Move left to stay in frame.',
    ),
    CueLine(
      id: 'framing-move-right',
      situation: CueSituation.framingMoveRight,
      actions: {CueAction.speakUrgent},
      display: 'Move right to stay in frame.',
    ),
    CueLine(
      id: 'framing-turn-sideways',
      situation: CueSituation.framingTurnSideways,
      actions: {CueAction.speakUrgent},
      display: 'Turn sideways to the camera for this exercise.',
    ),
    // -- rejected reps (coach bar + rate-limited voice) -----------------------
    CueLine(
      id: 'rejected-too-fast',
      situation: CueSituation.repRejectedTooFast,
      actions: {CueAction.display, CueAction.speak},
      display: 'Too fast — rep not counted',
    ),
    CueLine(
      id: 'rejected-short-range',
      situation: CueSituation.repRejectedShortRange,
      actions: {CueAction.display, CueAction.speak},
      display: 'Not counted — go through your full range',
    ),
    // -- session completion (fanfare voice) -----------------------------------
    CueLine(
      id: 'complete-triumphant',
      situation: CueSituation.sessionCompleteTriumphant,
      actions: {CueAction.speakUrgent},
      display: 'Workout complete. Outstanding work today.',
    ),
    CueLine(
      id: 'complete-encouraging',
      situation: CueSituation.sessionCompleteEncouraging,
      actions: {CueAction.speakUrgent},
      display: 'Workout complete. You showed up and finished — that counts.',
    ),
    CueLine(
      id: 'complete-gentle',
      situation: CueSituation.sessionCompleteGentle,
      actions: {CueAction.speakUrgent},
      display:
          'Session saved. Every bit of movement matters — see you next time.',
    ),
    CueLine(
      id: 'complete-energetic',
      situation: CueSituation.sessionCompleteEnergetic,
      actions: {CueAction.speakUrgent},
      display: 'Workout complete. High intensity, well earned. Recover well.',
    ),
    // -- session lifecycle ----------------------------------------------------
    CueLine(
      id: 'session-start',
      situation: CueSituation.sessionStart,
      actions: {CueAction.display, CueAction.speak},
      display: 'Session started — settle into your start position.',
      speak: "Let's begin — settle into your start position.",
    ),
    CueLine(
      id: 'session-pause',
      situation: CueSituation.sessionPause,
      actions: {CueAction.display},
      display: 'Paused — take a breath. Resume when ready.',
    ),
    CueLine(
      id: 'session-resume',
      situation: CueSituation.sessionResume,
      actions: {CueAction.display, CueAction.speak},
      display: 'Back at it — pick up where you left off.',
    ),
    CueLine(
      id: 'session-cancel',
      situation: CueSituation.sessionCancel,
      actions: {CueAction.display},
      display: 'Session discarded — nothing was recorded.',
    ),
    CueLine(
      id: 'session-end',
      situation: CueSituation.sessionEnd,
      actions: {CueAction.display},
      display: 'Session saved — nice work showing up.',
    ),
    // -- rounds & rest ----------------------------------------------------------
    CueLine(
      id: 'round-complete',
      situation: CueSituation.roundComplete,
      actions: {CueAction.display, CueAction.speak},
      display: 'Round complete — shake it out.',
    ),
    CueLine(
      id: 'last-round',
      situation: CueSituation.lastRound,
      actions: {CueAction.display, CueAction.speak},
      display: 'Last round — finish strong.',
    ),
    CueLine(
      id: 'rest-start',
      situation: CueSituation.restStart,
      actions: {CueAction.display, CueAction.speak},
      display: 'Rest — breathe and sip water.',
    ),
    CueLine(
      id: 'rest-countdown',
      situation: CueSituation.restCountdown,
      actions: {CueAction.display},
      display: 'Rest almost over — get into position.',
    ),
    CueLine(
      id: 'rest-end',
      situation: CueSituation.restEnd,
      actions: {CueAction.display, CueAction.speak},
      display: 'Rest over — back to work.',
    ),
    // -- milestones (cycled every 5 reps) ---------------------------------------
    CueLine(
      id: 'milestone-1',
      situation: CueSituation.milestone,
      actions: {CueAction.display, CueAction.speak},
      display: '5 in — steady rhythm.',
    ),
    CueLine(
      id: 'milestone-2',
      situation: CueSituation.milestone,
      actions: {CueAction.display, CueAction.speak},
      display: '10 down — the habit is building.',
    ),
    CueLine(
      id: 'milestone-3',
      situation: CueSituation.milestone,
      actions: {CueAction.display, CueAction.speak},
      display: '15 — past the quitting point.',
    ),
    CueLine(
      id: 'milestone-4',
      situation: CueSituation.milestone,
      actions: {CueAction.display, CueAction.speak},
      display: '20 — genuinely strong work.',
    ),
    CueLine(
      id: 'milestone-5',
      situation: CueSituation.milestone,
      actions: {CueAction.display, CueAction.speak},
      display: '25 and rolling — keep the streak alive.',
    ),
    // -- encouragement (display) --------------------------------------------------
    CueLine(
      id: 'encourage-steady',
      situation: CueSituation.encouragement,
      actions: {CueAction.display},
      display: "Steady — you've got this.",
    ),
    CueLine(
      id: 'encourage-breathe',
      situation: CueSituation.encouragement,
      actions: {CueAction.display},
      display: 'Breathe through it.',
    ),
    CueLine(
      id: 'encourage-small-steps',
      situation: CueSituation.encouragement,
      actions: {CueAction.display},
      display: 'Small steps — every rep counts.',
    ),
    CueLine(
      id: 'encourage-smooth',
      situation: CueSituation.encouragement,
      actions: {CueAction.display},
      display: 'Smooth and controlled.',
    ),
    CueLine(
      id: 'encourage-progress',
      situation: CueSituation.encouragement,
      actions: {CueAction.display},
      display: "You're doing better than you think.",
    ),
    CueLine(
      id: 'encourage-show-up',
      situation: CueSituation.encouragement,
      actions: {CueAction.display},
      display: 'Showing up is the hardest rep.',
    ),
    // -- generic form warnings (voice) --------------------------------------------
    CueLine(
      id: 'warn-slow-down',
      situation: CueSituation.formWarning,
      actions: {CueAction.speak},
      display: 'Slow down — control the movement.',
    ),
    CueLine(
      id: 'warn-full-range',
      situation: CueSituation.formWarning,
      actions: {CueAction.speak},
      display: 'Use your full range on every rep.',
    ),
    CueLine(
      id: 'warn-smooth',
      situation: CueSituation.formWarning,
      actions: {CueAction.speak},
      display: 'Keep it smooth — no rushing.',
    ),
    CueLine(
      id: 'warn-reset',
      situation: CueSituation.formWarning,
      actions: {CueAction.speak},
      display: 'Reset your stance and go again.',
    ),
    // -- generic form praise (display) ----------------------------------------------
    CueLine(
      id: 'praise-clean',
      situation: CueSituation.formPraise,
      actions: {CueAction.display},
      display: 'Clean rep.',
    ),
    CueLine(
      id: 'praise-solid',
      situation: CueSituation.formPraise,
      actions: {CueAction.display},
      display: 'Solid form.',
    ),
    CueLine(
      id: 'praise-depth',
      situation: CueSituation.formPraise,
      actions: {CueAction.display},
      display: 'Nice depth.',
    ),
    CueLine(
      id: 'praise-finish',
      situation: CueSituation.formPraise,
      actions: {CueAction.display},
      display: 'Strong finish.',
    ),
    // -- safety (urgent voice + haptic for the stop line) -----------------------------
    CueLine(
      id: 'safety-stop',
      situation: CueSituation.safety,
      actions: {CueAction.display, CueAction.speakUrgent, CueAction.haptic},
      display: 'Stop — clear some space around you first.',
    ),
    CueLine(
      id: 'safety-weights',
      situation: CueSituation.safety,
      actions: {CueAction.display, CueAction.speak},
      display: 'Set weights down gently between sets.',
    ),
    CueLine(
      id: 'safety-pain',
      situation: CueSituation.safety,
      actions: {CueAction.display, CueAction.speak},
      display: 'If anything hurts sharply, stop the set.',
    ),
    CueLine(
      id: 'safety-water',
      situation: CueSituation.safety,
      actions: {CueAction.display},
      display: 'Keep water nearby between rounds.',
    ),
    // -- hold timing (duration exercises) ----------------------------------------------
    CueLine(
      id: 'hold-halfway',
      situation: CueSituation.holdHalfway,
      actions: {CueAction.display},
      display: 'Halfway there — hold steady.',
    ),
    CueLine(
      id: 'hold-target',
      situation: CueSituation.holdTarget,
      actions: {CueAction.display, CueAction.speak},
      display: 'Target reached — nicely held.',
    ),
  ];

  /// Line for a person-lock reason, or null while counting is live.
  static CueLine? lineForLock(LockReason reason) => switch (reason) {
        LockReason.ok => null,
        LockReason.noPerson => _byId('lock-no-person'),
        LockReason.multiPerson => _byId('lock-multi-person'),
        LockReason.lostTracking => _byId('lock-lost-tracking'),
        LockReason.occluded => _byId('lock-occluded'),
        LockReason.videoPlayback => _byId('lock-video-playback'),
      };

  /// Line for a framing cue, or null when framing is fine.
  static CueLine? lineForFraming(FramingCue cue) => switch (cue) {
        FramingCue.ok => null,
        FramingCue.stepBack => _byId('framing-step-back'),
        FramingCue.stepCloser => _byId('framing-step-closer'),
        FramingCue.moveLeft => _byId('framing-move-left'),
        FramingCue.moveRight => _byId('framing-move-right'),
        FramingCue.turnSideways => _byId('framing-turn-sideways'),
      };

  /// Line for a session-completion mood.
  static CueLine lineForMood(SessionMood mood) => switch (mood) {
        SessionMood.triumphant => _byId('complete-triumphant'),
        SessionMood.encouraging => _byId('complete-encouraging'),
        SessionMood.gentle => _byId('complete-gentle'),
        SessionMood.energetic => _byId('complete-energetic'),
      };

  /// Line for a gate-refused rep.
  static CueLine lineForRejection(RepRejectedReason reason) => switch (reason) {
        RepRejectedReason.tooFast => _byId('rejected-too-fast'),
        RepRejectedReason.rangeOfMotion => _byId('rejected-short-range'),
      };

  /// Milestone line, cycling every 5 reps (1-based milestone index).
  static CueLine milestone(int milestoneIndex) {
    final pool = lines
        .where((l) => l.situation == CueSituation.milestone)
        .toList(growable: false);
    return pool[(milestoneIndex - 1) % pool.length];
  }

  /// Funnels a per-exercise feedback message through the vocabulary: the
  /// rule keeps its specific copy, but the entry carries the shared
  /// situation/action tags, so display and voice resolve from one place.
  /// Accepts the fields of [FeedbackRule] (or [FeedbackMessage] — same
  /// shape): warnings/errors speak, info lines display only.
  static CueLine feedback({
    required String name,
    required String message,
    String? audioCue,
    required String severity,
  }) {
    final warning = severity == 'warning' || severity == 'error';
    return CueLine(
      id: 'fb:$name',
      situation:
          warning ? CueSituation.formWarning : CueSituation.formPraise,
      actions: warning
          ? const {CueAction.display, CueAction.speak}
          : const {CueAction.display},
      display: message,
      speak: audioCue,
    );
  }

  static CueLine _byId(String id) =>
      lines.firstWhere((l) => l.id == id);
}
