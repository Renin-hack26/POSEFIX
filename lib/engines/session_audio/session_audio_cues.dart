/// Session-audio glue — maps workout events onto [SoundEngine] sounds.
///
/// Pure helpers ([computeMood], [warningCueFor]) are fully testable without
/// platform channels; [SessionAudioCues] is a thin never-throwing wrapper so
/// audio can never break a workout.
library;

import 'package:fixpose/core/audio/sound_engine.dart';
import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/pose_analyzer.dart';

/// Maps end-of-session stats onto a completion mood.
///
/// - triumphant when the session was finished with high completion + form.
/// - energetic when finished with high completion but lower form (hard one).
/// - encouraging when finished without hitting the completion bar.
/// - gentle when the user exited early (never judgmental).
SessionMood computeMood({
  required double targetCompletion,
  required double avgForm,
  required bool exitedEarly,
}) {
  if (exitedEarly) {
    return SessionMood.gentle;
  }
  if (targetCompletion >= 0.9 && avgForm >= 80) {
    return SessionMood.triumphant;
  }
  if (targetCompletion >= 0.9) {
    return SessionMood.energetic;
  }
  return SessionMood.encouraging;
}

/// First warning/error audio cue in [feedback], or null when there is none.
///
/// Info lines (e.g. "Good form") are never spoken as warnings.
String? warningCueFor(List<FeedbackMessage> feedback) {
  for (final FeedbackMessage message in feedback) {
    final String severity = message.severity;
    if (severity == 'warning' || severity == 'error') {
      return message.audioCue;
    }
  }
  return null;
}

/// Thin, never-throwing bridge between workout events and [SoundEngine].
class SessionAudioCues {
  SessionAudioCues(this._engine);

  final SoundEngine _engine;

  /// Per-cue cooldown for form warnings (stricter than the engine default).
  static const Duration warningCooldown = Duration(seconds: 3);

  final Map<String, DateTime> _lastWarningAt = {};
  FramingCue _lastFraming = FramingCue.ok;

  /// Last framing cue seen (exposed for tests / debugging).
  FramingCue get lastFraming => _lastFraming;

  /// Clean rep completed.
  Future<void> onRep() async {
    try {
      await _engine.play(Sfx.rep);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Full set finished.
  Future<void> onSet() async {
    try {
      await _engine.play(Sfx.set);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Rest period started.
  Future<void> onRestStart() async {
    try {
      await _engine.play(Sfx.restStart);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Rest over — back to work.
  Future<void> onRestEnd() async {
    try {
      await _engine.play(Sfx.restEnd);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Spoken form warning + warning blip, rate-limited per distinct cue.
  Future<void> onWarning(String cue) async {
    try {
      if (cue.isEmpty) {
        return;
      }
      final DateTime now = DateTime.now();
      final DateTime? last = _lastWarningAt[cue];
      if (last != null && now.difference(last) < warningCooldown) {
        return;
      }
      _lastWarningAt[cue] = now;
      await _engine.speakCue(cue);
      await _engine.play(Sfx.warning);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Camera-adjustment cue, spoken urgently only when the cue changes.
  ///
  /// [FramingCue.ok] never speaks; it just resets the latch so the next
  /// real cue fires immediately.
  Future<void> onFraming(FramingCue cue) async {
    try {
      if (cue == _lastFraming) {
        return;
      }
      _lastFraming = cue;
      if (cue == FramingCue.ok) {
        return;
      }
      await _engine.speakUrgent(framingCueLine(cue));
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Urgent one-off spoken line (e.g. the video-playback notice), spoken
  /// immediately and interrupting any queued cue.
  Future<void> speakUrgent(String text) async {
    try {
      await _engine.speakUrgent(text);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Mood-matched session-complete fanfare + spoken line.
  Future<void> onComplete(SessionMood mood) async {
    try {
      await _engine.completeSession(mood);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Major milestone (PR, streak record).
  Future<void> onMilestone() async {
    try {
      await _engine.play(Sfx.celebration);
    } catch (_) {
      // Audio must never break the workout flow.
    }
  }

  /// Dispose the underlying [SoundEngine].
  Future<void> dispose() => _engine.dispose();
}
