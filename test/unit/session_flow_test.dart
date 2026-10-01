import 'package:fixpose/presentation/vision/session_flow.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for WS2 session flow logic (TODO_v1.1.11 §2).
void main() {
  RoundPlan plan({int round = 1, int rounds = 3, int reps = 10, int rest = 45}) =>
      RoundPlan(round: round, rounds: rounds, repsTarget: reps, seconds: reps, restSec: rest);

  SessionFlow newFlow({int rounds = 3, bool calibrated = true}) {
    final f = SessionFlow();
    f.start(roundPlan: plan(rounds: rounds), totalRounds: rounds, calibrated: calibrated);
    return f;
  }

  group('resolveTargets', () {
    test('derives rounds, reps and seconds from exercise entries', () {
      final t = resolveTargets(exercises: [
        const PlanExercise(exerciseId: 'squat', rounds: 3, reps: 12, restSec: 45),
      ]);
      expect(t.rounds, 3);
      expect(t.repTargetFor('squat'), 12);
      expect(t.secondsFor('squat'), 12);
      expect(t.restSec, 45);
    });

    test('roundsOverride wins over plan rounds', () {
      final t = resolveTargets(
        exercises: [const PlanExercise(exerciseId: 'squat', rounds: 3, reps: 10)],
        roundsOverride: 5,
      );
      expect(t.rounds, 5);
      expect(t.repTargetFor('squat'), 10);
    });

    test('secondsOverride wins over reps', () {
      final t = resolveTargets(
        exercises: [const PlanExercise(exerciseId: 'squat', rounds: 2, reps: 10)],
        secondsOverride: 30,
      );
      expect(t.secondsFor('squat'), 30);
    });

    test('unknown exercise falls back to defaults', () {
      final t = resolveTargets(exercises: const []);
      expect(t.repTargetFor('anything'), greaterThan(0));
      expect(t.rounds, greaterThan(0));
    });
  });

  group('SessionFlow rep progression', () {
    test('counts reps and keeps round label in sync', () {
      final f = newFlow();
      expect(f.repsInRound, 0);
      expect(f.repsLabel(), '0 / 10');
      expect(f.roundLabel(), 'Round 1 / 3');

      f.registerRep(DateTime.now(), total: 1);
      expect(f.repsInRound, 1);
      expect(f.repsTotal, 1);
      expect(f.repsLabel(), '1 / 10');
    });

    test('completes a round and advances to the next', () {
      final f = newFlow();
      for (var i = 0; i < 9; i++) {
        f.registerRep(DateTime.now(), total: i + 1);
      }
      final last = f.registerRep(DateTime.now(), total: 10);
      expect(last, RepEvent.roundComplete);
      expect(f.roundsCompleted, 1);
      expect(f.repsInRound, 0);
      expect(f.roundNumber, 2);
      expect(f.roundLabel(), 'Round 2 / 3');
      expect(f.repsTotal, 10);
    });

    test('finishing the last round moves the flow to done', () {
      final f = newFlow(rounds: 1);
      f.registerRep(DateTime.now(), total: 1);
      f.startRest(DateTime.now(), seconds: 10);
      f.skipRest(DateTime.now());
      final last = f.registerRep(DateTime.now(), total: 2);
      expect(last, RepEvent.sessionComplete);
      expect(f.phase, FlowPhase.done);
    });

    test('reps during rest are refused with a non-silent event', () {
      final f = newFlow();
      f.startRest(DateTime.now(), seconds: 30);
      final e = f.registerRep(DateTime.now(), total: 1);
      expect(e, RepEvent.ignoredDuringRest);
      expect(f.repsInRound, 0);
    });

    test('restore() rebuilds counters for a resumed session', () {
      final f = SessionFlow();
      f.restore(
        roundPlan: plan(round: 2, rounds: 3),
        repsInRound: 4,
        totalReps: 14,
        roundsCompleted: 1,
        calibrated: true,
        restRemainingSec: 12,
        elapsedSec: 95,
      );
      expect(f.roundNumber, 2);
      expect(f.repsInRound, 4);
      expect(f.repsTotal, 14);
      expect(f.restRemaining, 12);
      expect(f.elapsedSec, 95);
      expect(f.repsLabel(), '4 / 10');
    });

    test('calibration gate keeps flow in calibration phase until marked', () {
      final f = SessionFlow();
      f.start(roundPlan: plan(), totalRounds: 3, calibrated: false);
      expect(f.phase, FlowPhase.calibration);
      f.markCalibrated();
      expect(f.phase, FlowPhase.active);
    });
  });

  group('SessionFlow rest', () {
    test('tickRest counts down', () {
      final f = newFlow();
      f.startRest(DateTime.now(), seconds: 45);
      expect(f.restRemaining, 45);
      f.tickRest(44);
      expect(f.restRemaining, 44);
      f.tickRest(30);
      expect(f.restRemaining, 30);
    });

    test('skipRest zeroes the countdown and resumes the round', () {
      final f = newFlow();
      f.startRest(DateTime.now(), seconds: 45);
      f.tickRest(20);
      f.skipRest(DateTime.now());
      expect(f.restRemaining, 0);
      expect(f.phase, FlowPhase.active);
    });

    test('addSecond accumulates elapsed time', () {
      final f = newFlow();
      f.addSecond();
      f.addSecond();
      expect(f.elapsedSec, 2);
    });
  });

  group('formatClock', () {
    test('formats seconds as m:ss', () {
      expect(formatClock(0), '0:00');
      expect(formatClock(9), '0:09');
      expect(formatClock(65), '1:05');
      expect(formatClock(600), '10:00');
      expect(formatClock(3599), '59:59');
    });

    test('formats over an hour as h:mm:ss', () {
      expect(formatClock(3600), '1:00:00');
      expect(formatClock(3661), '1:01:01');
    });
  });

  group('resolveCue priority', () {
    test('rejection wins over everything', () {
      final cue = resolveCue(
        phase: FlowPhase.active,
        calibrated: true,
        lock: PoseLockState.searching,
        lockReason: 'no person',
        personCount: 0,
        inFrame: false,
        personTooSmall: false,
        frameHintLow: false,
        detectedState: PoseDetectionState.idle,
        formScore: 0.2,
        fps: 5,
        restRemainingSec: 3,
        rejection: RepRejectedReason.rangeOfMotion,
        error: 'boom',
        roundLabel: 'Round 1 / 3',
        elapsedSec: 10,
      );
      expect(cue, contains('full depth'));
    });

    test('error wins when no rejection', () {
      final cue = resolveCue(
        phase: FlowPhase.active,
        calibrated: true,
        lock: PoseLockState.locked,
        lockReason: null,
        personCount: 1,
        inFrame: true,
        personTooSmall: false,
        frameHintLow: false,
        detectedState: PoseDetectionState.idle,
        formScore: 1.0,
        fps: 30,
        restRemainingSec: 0,
        rejection: null,
        error: 'camera died',
        roundLabel: 'Round 1 / 3',
        elapsedSec: 10,
      );
      expect(cue, contains('camera died'));
    });

    test('lock cue shows when pose is not locked', () {
      final cue = resolveCue(
        phase: FlowPhase.active,
        calibrated: true,
        lock: PoseLockState.searching,
        lockReason: 'no person',
        personCount: 0,
        inFrame: false,
        personTooSmall: false,
        frameHintLow: false,
        detectedState: PoseDetectionState.idle,
        formScore: 1.0,
        fps: 30,
        restRemainingSec: 0,
        rejection: null,
        error: null,
        roundLabel: 'Round 1 / 3',
        elapsedSec: 10,
      );
      expect(cue, isNotNull);
      expect(cue, isNot(contains('REST')));
    });

    test('rest cue appears during rest countdown', () {
      final cue = resolveCue(
        phase: FlowPhase.active,
        calibrated: true,
        lock: PoseLockState.locked,
        lockReason: null,
        personCount: 1,
        inFrame: true,
        personTooSmall: false,
        frameHintLow: false,
        detectedState: PoseDetectionState.idle,
        formScore: 1.0,
        fps: 30,
        restRemainingSec: 12,
        rejection: null,
        error: null,
        roundLabel: 'Round 2 / 3',
        elapsedSec: 10,
      );
      expect(cue, contains('REST'));
      expect(cue, contains('12'));
    });

    test('locked + framed + calibrated yields a coaching cue, not null', () {
      final cue = resolveCue(
        phase: FlowPhase.active,
        calibrated: true,
        lock: PoseLockState.locked,
        lockReason: null,
        personCount: 1,
        inFrame: true,
        personTooSmall: false,
        frameHintLow: false,
        detectedState: PoseDetectionState.down,
        formScore: 0.9,
        fps: 30,
        restRemainingSec: 0,
        rejection: null,
        error: null,
        roundLabel: 'Round 1 / 3',
        elapsedSec: 10,
      );
      expect(cue, isNotNull);
    });
  });

  group('rejectionCueFor', () {
    test('range of motion message mentions depth', () {
      expect(rejectionCueFor(RepRejectedReason.rangeOfMotion).toLowerCase(), contains('depth'));
    });

    test('too fast message asks to slow down', () {
      expect(rejectionCueFor(RepRejectedReason.tooFast).toLowerCase(), contains('slow'));
    });
  });

  group('PopupSequencer', () {
    test('queues popups FIFO and returns null when empty', () {
      final s = PopupSequencer();
      expect(s.next(), isNull);
      s.push(SessionPopup.roundTick(label: 'Round 2 / 3'));
      s.push(const SessionPopup.congrats());
      expect(s.next()?.label, 'Round 2 / 3');
      expect(s.next()?.type, PopupType.congrats);
      expect(s.next(), isNull);
    });

    test('wrong-pose hold is 800ms', () {
      expect(PopupSequencer.wrongPoseHold, 800);
    });

    test('round-tick hold is 1200ms', () {
      expect(PopupSequencer.roundTickHold, 1200);
    });

    test('wrong-pose popup queues behind an active round tick', () {
      final s = PopupSequencer();
      s.push(SessionPopup.roundTick(label: 'Round 2 / 3'));
      s.push(SessionPopup.wrongPose(text: 'Chest up'));
      expect(s.next()?.type, PopupType.roundTick);
      expect(s.next()?.type, PopupType.wrongPose);
    });
  });
}
