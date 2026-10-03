/// WS8 — engine rule-feeding + feedback vocabulary + angle readouts.
///
/// 8.1: every rule surface of all 46 definitions is either consumed by the
/// engine or explicitly reported (visualization → Batch 5 overlay upgrade,
/// calibration phase → Batch 4 screen wiring).
/// 8.3: the central [CueVocabulary] holds 50+ tagged lines; every engine
/// event maps to a line; display and voice resolve from the same entry.
/// 8.4: [angleReadouts] selects the exercise-aware pair from live angles.
/// (8.2 bilateral one-count-per-cycle is pinned by WS9.2 tests.)
library;

import 'package:fixpose/core/audio/cue_vocabulary.dart';
import 'package:fixpose/core/audio/sound_engine.dart';
import 'package:fixpose/core/pose/angle_readouts.dart';
import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:fixpose/core/pose/exercise_definition.dart';
import 'package:fixpose/core/pose/pose_analyzer.dart';
import 'package:fixpose/core/pose/pose_math.dart' show LmPoint;
import 'package:fixpose/presentation/vision/vision_hud.dart';
import 'package:flutter_test/flutter_test.dart';

List<ExerciseDefinition> _allDefs() {
  registerExerciseCatalog();
  final defs = ExerciseRegistry.instance.all;
  expect(defs.length, 46, reason: 'catalog must keep its 46 definitions');
  return defs;
}

/// Generous synthetic context so every feedback condition parses cleanly.
Map<String, dynamic> _contextFor(ExerciseDefinition def) {
  final ctx = <String, dynamic>{
    'angle': 150.0,
    'angle_vel': 0.0,
    'state': 'standing',
    'min_angle': 90.0,
    'max_angle': 170.0,
    'max_arm_angle': 150.0,
  };
  for (final a in def.angles) {
    ctx['${a.name}_angle'] = 150.0;
    ctx['${a.name}_vel'] = 0.0;
  }
  return ctx;
}

void main() {
  setUpAll(registerExerciseCatalog);

  // -------------------------------------------------------------------------
  // 8.1/8.5 — every rule surface is consumed or explicitly reported
  // -------------------------------------------------------------------------

  group('definition surfaces', () {
    test('states, order, counter rule are coherent', () {
      for (final def in _allDefs()) {
        expect(def.states, isNotEmpty, reason: '${def.id}: states');
        expect(def.stateOrder, isNotEmpty, reason: '${def.id}: stateOrder');
        for (final name in def.stateOrder) {
          expect(def.getState(name), isNotNull,
              reason: '${def.id}: stateOrder references missing state $name');
        }
        expect(def.getState(def.counterRule.triggerState), isNotNull,
            reason: '${def.id}: trigger state must exist');
        final prior = def.counterRule.requiredPriorState;
        if (prior != null) {
          expect(def.getState(prior), isNotNull,
              reason: '${def.id}: requiredPriorState must exist');
        }
        expect(def.counterRule.minRepDuration, greaterThan(0),
            reason: '${def.id}: minRepDuration');
        expect(def.counterRule.repIncrement, greaterThanOrEqualTo(1),
            reason: '${def.id}: repIncrement');
      }
    });

    test('every feedback condition evaluates without throwing', () {
      for (final def in _allDefs()) {
        final ctx = _contextFor(def);
        for (final rule in def.feedbackRules) {
          expect(
            () => ConditionEvaluator.evaluate(rule.condition, ctx),
            returnsNormally,
            reason: '${def.id}/${rule.name}: ${rule.condition}',
          );
        }
      }
    });

    test('bilateral definitions map sides onto real angle names', () {
      // 8.1: the engine derives side context keys from `sides` — a side
      // without a matching angle would silently evaluate on the primary.
      for (final def in _allDefs()) {
        if (!def.bilateral) continue;
        expect(def.sides.length, 2, reason: '${def.id}: sides');
        final angleNames = def.angles.map((a) => a.name).toSet();
        for (final side in def.sides) {
          final direct = angleNames.contains(side);
          final suffixed =
              angleNames.any((n) => n == '${side}_arm' || n == side);
          expect(direct || suffixed, isTrue,
              reason: '${def.id}: side $side has no angle');
        }
      }
    });

    test('duration definitions carry a hold state + target', () {
      final durations =
          _allDefs().where((d) => d.type == 'duration').toList();
      expect(durations, isNotEmpty, reason: 'plank-style holds exist');
      for (final def in durations) {
        final hold = def.holdState;
        expect(hold, isNotNull, reason: '${def.id}: holdState');
        expect(def.getState(hold!), isNotNull,
            reason: '${def.id}: holdState must be a real state');
        expect(def.targetDuration, greaterThan(0),
            reason: '${def.id}: targetDuration');
      }
    });

    test('calibration-enabled set is exactly the known six', () {
      // Explicitly reported, not silently consumed: the pre-session phase
      // that reads these ships in Batch 4 (WS2.10 screen wiring).
      final enabled = [
        for (final d in _allDefs())
          if (d.calibration.enabled) d.id
      ];
      expect(enabled.length, 6,
          reason: 'calibration-enabled set changed — confirm Batch 4 '
              'still wires exactly these: $enabled');
    });

    test('every angle vertex is a tracked landmark', () {
      // Blind-audit catch: superman/cobra/russian_twist/inchworm referenced
      // vertices absent from their landmarks map, so the analyzer skipped
      // those angles (empty angles / dead states) and the reps never counted.
      final missing = <String>[];
      for (final def in _allDefs()) {
        for (final angle in def.angles) {
          for (final idx in angle.points) {
            if (!def.landmarks.containsValue(idx)) {
              missing.add('${def.id}/${angle.name}: vertex $idx untracked');
            }
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'angle vertices without a tracked landmark: $missing');
    });

    test('smoothing windows are valid; mapping honors them', () {      for (final def in _allDefs()) {
        expect(def.smoothing.window, greaterThanOrEqualTo(1),
            reason: '${def.id}: smoothing window');
      }
      // window: 5 ≈ the historic 0.3 base; window: 3 responds faster;
      // disabled definitions keep the shared constant.
      expect(smoothingAlphaFor(const SmoothingConfig(enabled: true, window: 5)),
          closeTo(1 / 3, 1e-9));
      expect(smoothingAlphaFor(const SmoothingConfig(enabled: true, window: 3)),
          0.5);
      expect(
          smoothingAlphaFor(const SmoothingConfig()), 0.3);
    });
  });

  // -------------------------------------------------------------------------
  // 8.1 — hold clock (duration exercises consume holdState)
  // -------------------------------------------------------------------------

  group('holdSeconds', () {
    test('plank hold accumulates time, repetition work stays zero', () {
      final plank = ExerciseRegistry.instance.resolve('plank')!;
      final engine = BrainEngine(plank);
      const coords = <String, LmPoint>{};
      BrainResult? last;
      // body_line 170° commits the 'hold' state (needs 3-frame confirm).
      for (var i = 0; i < 10; i++) {
        last = engine.processFrame(
          angles: const {'body_line': 170.0, 'arm_angle': 85.0},
          landmarkCoords: coords,
          timestamp: i * 0.1,
        );
      }
      expect(last!.holdSeconds, greaterThan(0.5),
          reason: '10 frames × 0.1 s in hold must accumulate');
      expect(last.holdSeconds, lessThanOrEqualTo(1.0));

      final squat = ExerciseRegistry.instance.resolve('squat')!;
      final counter = BrainEngine(squat);
      final rep = counter.processFrame(
        angles: const {'primary': 170.0, 'secondary': 60.0},
        landmarkCoords: coords,
        timestamp: 0.0,
      );
      expect(rep.holdSeconds, 0.0,
          reason: 'repetition exercises never accrue hold time');
    });
  });

  // -------------------------------------------------------------------------
  // 8.3 — vocabulary integrity + engine-event mappings
  // -------------------------------------------------------------------------

  group('CueVocabulary', () {
    test('holds 50+ unique, non-empty, action-tagged lines', () {
      expect(CueVocabulary.lines.length, greaterThanOrEqualTo(50));
      final ids = <String>{};
      for (final line in CueVocabulary.lines) {
        expect(line.id, isNotEmpty);
        expect(ids.add(line.id), isTrue, reason: 'duplicate id ${line.id}');
        expect(line.display.trim(), isNotEmpty,
            reason: '${line.id}: display text');
        expect(line.spoken.trim(), isNotEmpty,
            reason: '${line.id}: spoken text');
        expect(line.actions, isNotEmpty, reason: '${line.id}: action');
      }
    });

    test('every situation is covered', () {
      final covered = {
        for (final l in CueVocabulary.lines) l.situation
      };
      for (final s in CueSituation.values) {
        expect(covered, contains(s), reason: 'no line for $s');
      }
    });

    test('lock + framing map every event (null only when all-clear)', () {
      expect(CueVocabulary.lineForLock(LockReason.ok), isNull);
      expect(CueVocabulary.lineForFraming(FramingCue.ok), isNull);
      final lockIds = <String>{};
      for (final r in LockReason.values) {
        if (r == LockReason.ok) continue;
        final line = CueVocabulary.lineForLock(r)!;
        expect(line.display, isNotEmpty);
        expect(lockIds.add(line.id), isTrue);
      }
      final framingIds = <String>{};
      for (final c in FramingCue.values) {
        if (c == FramingCue.ok) continue;
        final line = CueVocabulary.lineForFraming(c)!;
        expect(line.display, isNotEmpty);
        expect(framingIds.add(line.id), isTrue);
      }
    });

    test('moods + rejections map to distinct lines', () {
      final moods = {
        for (final m in SessionMood.values)
          CueVocabulary.lineForMood(m).id
      };
      expect(moods.length, SessionMood.values.length);
      expect(CueVocabulary.lineForMood(SessionMood.triumphant).spoken,
          'Workout complete. Outstanding work today.');
      expect(CueVocabulary.lineForRejection(RepRejectedReason.tooFast).display,
          contains('Too fast'));
      expect(
          CueVocabulary.lineForRejection(RepRejectedReason.rangeOfMotion)
              .display,
          contains('full range'));
    });

    test('milestones cycle; feedback funnel tags by severity', () {
      final first = CueVocabulary.milestone(1);
      expect(first.id, 'milestone-1');
      expect(CueVocabulary.milestone(6).id, first.id,
          reason: '5 entries cycle');
      const warnRule = FeedbackRule(
        name: 'depth',
        condition: 'x',
        message: 'Go deeper!',
        audioCue: 'Go deeper!',
      );
      final warn = CueVocabulary.feedback(
        name: warnRule.name,
        message: warnRule.message,
        audioCue: warnRule.audioCue,
        severity: warnRule.type,
      );
      expect(warn.display, 'Go deeper!');
      expect(warn.actions, contains(CueAction.speak));
      const infoRule = FeedbackRule(
        name: 'good',
        condition: 'x',
        message: 'Good form',
        type: 'info',
      );
      final info = CueVocabulary.feedback(
        name: infoRule.name,
        message: infoRule.message,
        audioCue: infoRule.audioCue,
        severity: infoRule.type,
      );
      expect(info.actions, isNot(contains(CueAction.speak)));
      expect(info.spoken, 'Good form',
          reason: 'voice falls back to display text');
    });

    test('legacy entry points still render the same copy', () {
      expect(lockReasonLine(LockReason.noPerson),
          'No person detected. Step into frame to begin.');
      expect(lockReasonLine(LockReason.ok), isEmpty);
      expect(framingCueLine(FramingCue.stepBack),
          'Step back so I can see your full body.');
      expect(framingCueLine(FramingCue.ok), isEmpty);
      expect(completionLine(SessionMood.triumphant),
          'Workout complete. Outstanding work today.');
    });
  });

  // -------------------------------------------------------------------------
  // 8.4 — exercise-aware readout selection
  // -------------------------------------------------------------------------

  group('angleReadouts', () {
    test('squat shows primary + secondary with description labels', () {
      final def = ExerciseRegistry.instance.resolve('squat')!;
      final pair =
          angleReadouts(def, const {'primary': 142.0, 'secondary': 60.0})!;
      expect(pair.left.label, 'Knee flexion angle');
      expect(pair.left.degrees, 142.0);
      expect(pair.right!.label, 'Hip/torso inclination angle');
      expect(pair.right!.degrees, 60.0);
    });

    test('bilateral shows L/R side angles', () {
      final def = ExerciseRegistry.instance.resolve('hammer_curl')!;
      final pair = angleReadouts(
        def,
        const {'left': 90.0, 'right': 95.0, 'left_alignment': 170.0},
      )!;
      expect(pair.left.label, 'L');
      expect(pair.left.degrees, 90.0);
      expect(pair.right!.label, 'R');
      expect(pair.right!.degrees, 95.0);
    });

    test('plank shows the body-line hold angle', () {
      final def = ExerciseRegistry.instance.resolve('plank')!;
      final pair = angleReadouts(
        def,
        const {'body_line': 172.0, 'arm_angle': 85.0},
      )!;
      expect(pair.left.label, 'Body line');
      expect(pair.right!.label, 'Arm angle');
    });

    test('missing angles degrade honestly', () {
      final def = ExerciseRegistry.instance.resolve('squat')!;
      expect(angleReadouts(def, const {}), isNull);
      expect(angleReadouts(def, const {'unknown_thing': 3.0}), isNull);
      final single = angleReadouts(def, const {'primary': 150.0})!;
      expect(single.left.degrees, 150.0);
      expect(single.right, isNull);
    });
  });
}
