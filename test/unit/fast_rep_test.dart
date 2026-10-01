/// Fast-rep accuracy + latency regression tests.
///
/// Motivation (user-reported): correct fast reps were sometimes not counted.
/// Root causes fixed and pinned here:
///  1. EMA amplitude clipping at speed (adaptive alpha added),
///  2. fixed 3-frame confirmation ≈ 240 ms (time-aware window + trigger /
///     ROM-state 2-frame cap),
///  3. minRepDuration 0.8 s gates dropping sub-second reps (now 0.3 s).
///
/// Cadence target: 3 reps/sec (333 ms/cycle) must count; single-frame noise
/// must still never commit; the wobble double-count guard must stay alive.
library;

import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:fixpose/core/pose/pose_math.dart';
import 'package:flutter_test/flutter_test.dart';

BrainResult feed(
  BrainEngine engine,
  Map<String, double> angles,
  double t,
) =>
    engine.processFrame(
      angles: angles,
      landmarkCoords: const {},
      timestamp: t,
    );

void main() {
  group('3-rep/sec squat cadence (33 fps analysis, default stabilizer)', () {
    late BrainEngine engine;
    setUp(() => engine = BrainEngine(squatDefinition)); // confirmFrames: 3

    /// One full squat cycle at 11 frames × 30 ms = 330 ms:
    /// standing×2 → descending×3 → bottom×3 → ascending×3, with the next
    /// cycle's standing×2 committing the trigger.
    BrainResult runCycle(double t0) {
      final seq = <(double, double)>[
        (t0 + 0.00, 170), // standing (holds top)
        (t0 + 0.03, 170),
        (t0 + 0.06, 140), // descending (vel < 0)
        (t0 + 0.09, 110),
        (t0 + 0.12, 95),
        (t0 + 0.15, 85), // bottom — ROM visit (2-frame cap commits)
        (t0 + 0.18, 80),
        (t0 + 0.21, 78),
        (t0 + 0.24, 110), // ascending (vel > 0)
        (t0 + 0.27, 135),
        (t0 + 0.30, 155),
      ];
      BrainResult r = feed(engine, {'primary': 170, 'secondary': 100}, t0);
      for (final (t, angle) in seq.skip(1)) {
        r = feed(engine, {'primary': angle, 'secondary': 100}, t);
      }
      return r;
    }

    test('three 330 ms cycles count three reps', () {
      var r = runCycle(0.0);
      r = runCycle(0.33); // ends with standing commit → rep 1
      expect(r.repCount, 1, reason: 'rep 1 at 3-rep/sec cadence');
      r = runCycle(0.66);
      expect(r.repCount, 2, reason: 'rep 2 — gap 0.33 s ≥ minRepDuration');
      r = runCycle(0.99);
      expect(r.repCount, 3, reason: 'rep 3 — cadence sustained');
    });

    test('brief 60 ms top-hold still commits the trigger (no lost rep)',
        () {
      // Standing visible for exactly 2 frames (60 ms) between reps — the
      // trigger's 2-frame cap must commit it (proven by rep 1 counting).
      runCycle(0.0);
      final r = runCycle(0.33);
      expect(r.repCount, 1,
          reason: '2-frame top-hold committed the trigger');
    });

    test('single noisy frame at 25 fps never flips a confirmed state', () {
      BrainResult r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, 0.0);
      for (final t in [0.04, 0.08]) {
        r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, t);
      }
      expect(r.currentState, 'standing');
      // One bottom blip at 25 fps (40 ms) — must NOT commit.
      r = feed(engine, {'primary': 85.0, 'secondary': 100.0}, 0.12);
      expect(r.currentState, 'standing');
      expect(r.stateJustChanged, false);
      // Two consecutive bottom frames (80 ms) DO commit — fast evidence.
      r = feed(engine, {'primary': 85.0, 'secondary': 100.0}, 0.16);
      expect(r.currentState, 'bottom');
    });

    test('sub-300 ms wobble right after a rep stays suppressed', () {
      // Rep 1 completes at t=0.36; then a full-looking bottom↔stand bounce
      // that commits standing only 0.20 s after the count — shorter than
      // minRepDuration (0.3) so it must not double-count.
      runCycle(0.0);
      feed(engine, {'primary': 170.0, 'secondary': 100.0}, 0.33);
      var r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, 0.36);
      expect(r.repCount, 1, reason: 'rep 1 counted at 0.36');
      feed(engine, {'primary': 140.0, 'secondary': 100.0}, 0.40);
      feed(engine, {'primary': 110.0, 'secondary': 100.0}, 0.42);
      feed(engine, {'primary': 95.0, 'secondary': 100.0}, 0.44);
      feed(engine, {'primary': 85.0, 'secondary': 100.0}, 0.46);
      feed(engine, {'primary': 80.0, 'secondary': 100.0}, 0.48);
      feed(engine, {'primary': 130.0, 'secondary': 100.0}, 0.50);
      feed(engine, {'primary': 155.0, 'secondary': 100.0}, 0.52);
      feed(engine, {'primary': 165.0, 'secondary': 100.0}, 0.54);
      r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, 0.56);
      expect(r.repCount, 1, reason: 'gap 0.20 s < 0.3 s suppressed');
      expect(r.repJustCompleted, false);
    });
  });

  group('velocity-aware EMA (fast reps keep their amplitude)', () {
    test('adaptive filter tracks a moving ramp far better than base', () {
      // Landmark ramping 25 px/frame toward 100 — the adaptive filter gets
      // alpha ≈ 0.6 during motion and stays close to the raw signal; the
      // fixed 0.3-alpha filter lags badly (that lag clipped fast reps below
      // the FSM depth thresholds).
      final adaptive = EmaFilter(0.3, adaptiveGain: 0.012, maxAlpha: 0.75);
      final base = EmaFilter(0.3);
      adaptive.push(0);
      base.push(0);
      double a = 0, b = 0;
      for (final raw in [25.0, 50.0, 75.0, 100.0]) {
        a = adaptive.push(raw);
        b = base.push(raw);
      }
      expect(a, greaterThanOrEqualTo(80),
          reason: 'adaptive follows the ramp (|err| ≤ 20 px)');
      expect(b, lessThan(70), reason: 'base alpha 0.3 lags (|err| ≥ 30 px)');
      expect(a, greaterThan(b));
      // Stationary noise stays smoothed at (nearly) the base alpha.
      final quiet = EmaFilter(0.3, adaptiveGain: 0.012, maxAlpha: 0.75);
      quiet.push(50);
      final smoothed = quiet.push(51); // delta 1 px → alpha ≈ 0.312
      expect(smoothed, greaterThan(50.2));
      expect(smoothed, lessThan(50.5));
    });
  });

  group('time-aware stabilizer window', () {
    test('confirmation targets ~80 ms, floor 2, cap configured frames', () {
      final s = StateStabilizer(3);
      expect(s.requiredFramesFor(0.03), 3); // 33 fps → 3 frames = 90 ms
      expect(s.requiredFramesFor(0.04), 2); // 25 fps → 2 frames = 80 ms
      expect(s.requiredFramesFor(0.08), 2); // 12.5 fps floor
      expect(s.requiredFramesFor(0.0), 3); // unknown dt → full frames
      expect(s.requiredFramesFor(0.5), 2); // slow frames never below 2
    });

    test('frameCap relaxes count-critical states but never to 1 frame', () {
      final s = StateStabilizer(3);
      s.push('standing', 0.03); // need 3 (cap 2 applies only if passed)
      s.push('standing', 0.03);
      expect(s.state, 'unknown', reason: '3-frame state needs 3 without cap');
      s.push('standing', 0.03);
      expect(s.state, 'standing');
      // With cap: trigger commits in 2 frames even at 33 fps.
      final s2 = StateStabilizer(3);
      s2.push('bottom', 0.03, 2);
      expect(s2.state, 'unknown');
      s2.push('bottom', 0.03, 2);
      expect(s2.state, 'bottom');
      // Never a single-frame commit.
      final s3 = StateStabilizer(3);
      s3.push('x', 0.03, 1);
      expect(s3.state, 'unknown');
    });
  });
}
