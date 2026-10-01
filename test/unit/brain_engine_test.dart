/// Brain engine unit tests — FSM rep counting, feedback rules, form score
/// and the condition language, all driven by synthetic angles (no camera).
library;

import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds one frame into [engine] and returns the result.
BrainResult feed(
  BrainEngine engine,
  Map<String, double> angles,
  double t, {
  Map<String, ({double x, double y})> coords = const {},
}) =>
    engine.processFrame(
      angles: angles,
      landmarkCoords: coords,
      timestamp: t,
    );

void main() {
  group('ConditionEvaluator', () {
    test('numeric comparisons', () {
      expect(ConditionEvaluator.evaluate('angle > 160', {'angle': 170}), true);
      expect(ConditionEvaluator.evaluate('angle > 160', {'angle': 150}), false);
      expect(
          ConditionEvaluator.evaluate(
              'angle <= 160 and angle > 90', {'angle': 130}),
          true);
      expect(
          ConditionEvaluator.evaluate(
              'angle <= 160 and angle > 90', {'angle': 85}),
          false);
    });

    test('and / or / not with parentheses', () {
      expect(
          ConditionEvaluator.evaluate('not (angle > 90)', {'angle': 80}), true);
      expect(
          ConditionEvaluator.evaluate(
              'angle < 45 or angle > 135', {'angle': 150}),
          true);
      expect(
          ConditionEvaluator.evaluate(
              'angle < 45 or angle > 135', {'angle': 90}),
          false);
    });

    test('string equality for state rules', () {
      expect(
          ConditionEvaluator.evaluate(
              "state == 'ascending'", {'state': 'ascending'}),
          true);
      expect(
          ConditionEvaluator.evaluate(
              "state == 'ascending'", {'state': 'bottom'}),
          false);
      expect(
          ConditionEvaluator.evaluate(
              "state == 'ascending' and min_angle > 95",
              {'state': 'ascending', 'min_angle': 120}),
          true);
    });

    test('abs / min / max functions', () {
      expect(ConditionEvaluator.evaluate('abs(angle - 90) < 5', {'angle': 92}),
          true);
      expect(
          ConditionEvaluator.evaluate('max(a, b) > 100', {'a': 80, 'b': 120}),
          true);
    });

    test('unknown names and bad syntax never throw', () {
      expect(ConditionEvaluator.evaluate('nope > 1', {}), false);
      expect(ConditionEvaluator.evaluate('angle >> 90', {'angle': 100}), false);
      expect(ConditionEvaluator.evaluate('', {}), false);
      expect(ConditionEvaluator.evaluate("state == 'x", {'state': 'x'}), false);
    });
  });

  group('squat FSM (confirmFrames: 1 for determinism)', () {
    late BrainEngine engine;
    setUp(() => engine = BrainEngine(squatDefinition, confirmFrames: 1));

    BrainResult squat(double primary, double t, {double secondary = 100}) =>
        feed(engine, {'primary': primary, 'secondary': secondary}, t);

    test('full ROM cycle counts exactly one rep', () {
      squat(170, 0.0);
      squat(130, 0.4);
      squat(85, 0.8);
      squat(120, 1.2);
      final done = squat(170, 1.6);
      expect(done.repCount, 1);
      expect(done.repJustCompleted, true);
      expect(done.currentState, 'standing');
    });

    test('shallow squat (no bottom visit) never counts', () {
      squat(170, 0.0);
      squat(130, 0.4);
      squat(120, 0.8);
      squat(130, 1.2);
      final done = squat(170, 1.6);
      expect(done.repCount, 0);
      expect(done.repJustCompleted, false);
    });

    test('min_rep_duration suppresses double counts', () {
      squat(170, 0.0);
      squat(85, 0.4);
      squat(170, 1.6); // rep 1
      expect(engine.processFrame(
        angles: const {'primary': 170.0, 'secondary': 100.0},
        landmarkCoords: const {},
        timestamp: 1.6,
      ).repCount, 1);
      squat(130, 1.7);
      squat(85, 1.8);
      // minRepDuration is 0.3 s (3-rep/sec cadence support) — a 0.25 s
      // wobble cycle right after rep 1 must still be suppressed.
      final fast = squat(170, 1.85);
      expect(fast.repCount, 1);
      expect(fast.repJustCompleted, false);
    });

    test('depth warning fires after a shallow ascent', () {
      squat(170, 0.0);
      squat(130, 0.4);
      squat(120, 0.8); // window min = 120
      final ascending = squat(130, 1.2); // ascending phase, min=120>95
      squat(170, 1.6);
      final depth = ascending.feedback.where((f) => f.name == 'depth');
      expect(depth, isNotEmpty);
      expect(depth.first.audioCue, 'Go deeper!');
      expect(depth.first.severity, 'warning');
    });

    test('chest-up warning fires on torso collapse', () {
      squat(170, 0.0, secondary: 100);
      final warned = squat(130, 0.4, secondary: 40);
      expect(warned.feedback.any((f) => f.name == 'chest'), true);
    });

    test('info feedback never dents the form score', () {
      final r = squat(170, 0.0); // standing → 'Good form' info only
      expect(r.feedback.any((f) => f.severity == 'info'), true);
      expect(r.formScore, 100);
    });

    test('warning feedback dents the form score', () {
      squat(170, 0.0, secondary: 100);
      final r = squat(130, 0.4, secondary: 40);
      expect(r.formScore, lessThan(100));
    });
  });

  group('jumping jack FSM', () {
    late BrainEngine engine;
    setUp(() => engine = BrainEngine(jumpingJackDefinition, confirmFrames: 1));

    BrainResult jack(double arm, double t) =>
        feed(engine, {'left_arm': arm, 'right_arm': arm}, t);

    test('open→closed cycle counts one rep', () {
      jack(20, 0.0);
      jack(80, 0.3);
      jack(150, 0.6);
      jack(80, 0.9);
      final done = jack(20, 1.2);
      expect(done.repCount, 1);
      expect(done.repJustCompleted, true);
    });

    test('partial raise warns hands-higher on closing', () {
      jack(20, 0.0);
      jack(80, 0.3);
      jack(110, 0.6); // never reaches open; window max = 110
      final closing = jack(80, 0.9);
      expect(closing.feedback.any((f) => f.name == 'reach'), true);
    });
  });

  group('StateStabilizer (bad-camera jitter)', () {
    test('single-frame blip never commits at confirmFrames 3', () {
      final engine = BrainEngine(squatDefinition, confirmFrames: 3);
      BrainResult r = feed(engine, const {'primary': 170.0}, 0.0);
      r = feed(engine, const {'primary': 170.0}, 0.2);
      r = feed(engine, const {'primary': 170.0}, 0.4);
      expect(r.currentState, 'standing');
      // One noisy bottom frame must not flip the state.
      r = feed(engine, const {'primary': 85.0}, 0.6);
      expect(r.currentState, 'standing');
      expect(r.stateJustChanged, false);
      // Three consistent frames commit.
      feed(engine, const {'primary': 85.0}, 0.8);
      r = feed(engine, const {'primary': 85.0}, 1.0);
      expect(r.currentState, 'bottom');
    });

    test('full rep with 3-frame holds counts once', () {
      final engine = BrainEngine(squatDefinition, confirmFrames: 3);
      var t = 0.0;
      var r = feed(engine, {'primary': 170.0}, t);
      t += 0.3;
      for (final v in [170.0, 170.0]) {
        r = feed(engine, {'primary': v}, t);
        t += 0.3;
      }
      for (final v in [130.0, 130.0, 130.0, 85.0, 85.0, 85.0]) {
        r = feed(engine, {'primary': v}, t);
        t += 0.3;
      }
      for (final v in [120.0, 120.0, 120.0, 170.0, 170.0, 170.0]) {
        r = feed(engine, {'primary': v}, t);
        t += 0.3;
      }
      expect(r.repCount, 1);
    });
  });

  group('catalog', () {
    test('all bundled defs have consistent FSM wiring', () {
      for (final def in bundledDefinitions) {
        expect(def.angles, isNotEmpty, reason: def.id);
        expect(def.stateOrder, isNotEmpty, reason: def.id);
        for (final s in def.stateOrder) {
          expect(def.getState(s), isNotNull, reason: '${def.id}/$s');
        }
        expect(
          def.stateOrder.contains(def.counterRule.triggerState),
          true,
          reason: '${def.id} trigger',
        );
        if (def.counterRule.requiredPriorState != null) {
          expect(
            def.stateOrder.contains(def.counterRule.requiredPriorState),
            true,
            reason: '${def.id} prior',
          );
        }
      }
    });
  });
}
