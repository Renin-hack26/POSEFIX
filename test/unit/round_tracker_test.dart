/// WS2.3/2.6/2.11 — round plan tracking: targets, round events, rest
/// rebase, elapsed labels. The session screen drives [RoundTracker]; the
/// camera/session UI itself is not harness-testable.
library;

import 'package:fixpose/core/audio/cue_vocabulary.dart';
import 'package:fixpose/core/pose/round_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoundTracker', () {
    test('counts rounds and fires one event per round', () {
      final tracker =
          RoundTracker(targetRounds: 3, targetReps: 12, restSec: 30);
      // First observation anchors the baseline, no event.
      expect(tracker.observe(0, 0.0), isNull);
      expect(tracker.observe(11, 10.0), isNull);
      expect(tracker.repsThisRound(11), 11);
      // 12th rep completes round 1 → advances to round 2.
      expect(tracker.observe(12, 12.0), RoundEvent.roundComplete);
      expect(tracker.currentRound, 2);
      expect(tracker.repsPerRound, [12]);
      expect(tracker.roundTimesSec.first, closeTo(12.0, 1e-9));
      // Round 2 completes the same way.
      expect(tracker.observe(23, 30.0), isNull);
      expect(tracker.observe(24, 32.0), RoundEvent.roundComplete);
      expect(tracker.currentRound, 3);
      expect(tracker.isLastRound, isTrue);
      // Final round completes the target instead.
      expect(tracker.observe(36, 50.0), RoundEvent.targetComplete);
      expect(tracker.isComplete, isTrue);
      expect(tracker.repsPerRound, [12, 12, 12]);
    });

    test('rest rebase drops rest-time movement', () {
      final tracker =
          RoundTracker(targetRounds: 2, targetReps: 5, restSec: 30);
      tracker.observe(0, 0.0);
      expect(tracker.observe(5, 5.0), RoundEvent.roundComplete);
      // User fidgets through the rest (3 extra engine counts)…
      tracker.rebase(8, 40.0);
      expect(tracker.repsThisRound(8), 0,
          reason: 'rest-time movement never counts toward the next round');
      expect(tracker.observe(12, 50.0), isNull);
      expect(tracker.observe(13, 52.0), RoundEvent.targetComplete);
      expect(tracker.repsPerRound, [5, 5]);
    });

    test('single-round plans complete immediately', () {
      final tracker =
          RoundTracker(targetRounds: 1, targetReps: 10, restSec: 0);
      tracker.observe(0, 0.0);
      expect(tracker.isLastRound, isTrue);
      expect(tracker.observe(10, 9.0), RoundEvent.targetComplete);
    });
  });

  group('formatElapsed', () {
    test('mm:ss labels for the TIME chip', () {
      expect(formatElapsed(Duration.zero), '00:00');
      expect(formatElapsed(const Duration(seconds: 7)), '00:07');
      expect(formatElapsed(const Duration(minutes: 4, seconds: 35)), '04:35');
      expect(formatElapsed(const Duration(hours: 2)), '99:59',
          reason: 'clamped to the chip width');
    });
  });

  group('session lifecycle vocabulary (WS2.6/2.11 events)', () {
    test('round/rest/session lines exist with queued voice', () {
      for (final id in [
        'round-complete',
        'last-round',
        'rest-start',
        'rest-end',
        'session-start',
      ]) {
        final line = CueVocabulary.byId(id);
        expect(line.spoken.trim(), isNotEmpty, reason: id);
        expect(line.actions, contains(CueAction.speak), reason: id);
      }
      expect(CueVocabulary.byId('rest-countdown').display, isNotEmpty);
      expect(CueVocabulary.byId('session-pause').display, isNotEmpty);
      expect(CueVocabulary.byId('session-cancel').display, isNotEmpty);
    });
  });
}
